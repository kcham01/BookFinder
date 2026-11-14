-- The value format of Questie's `questie` messages (docs/study/questie-protocol.md, sections 2.1 and 2.2), written
-- and read by BookFinder: one type byte per value, small whole numbers inside it, repeated strings as a hash, and the
-- bytes carried as text by one of two streams ("1short" for every message, "b89" for yells).
--
--   BF.QuestieSerial:Write(value, stream?) -> text      BF.QuestieSerial:Read(text, stream?) -> value or nil

local _, BF = ...

local Serial = {}
BF.QuestieSerial = Serial

local band, lshift, rshift = bit.band, bit.lshift, bit.rshift
local char, byte = string.char, string.byte
local floor, frexp, ldexp = math.floor, math.frexp, math.ldexp

--- The string hash both sides keep (the game's own bit.band, as Questie uses it).
function Serial.Hash(s)
	if type(s) ~= "string" or #s == 0 then return 0 end
	local h = 5381
	for i = 1, #s do h = band(31 * h + byte(s, i), 4294967295) end
	return h
end

-- Streams: value bytes <-> message text ----------------------------------------------------------------------------

local B89_LEVEL_CHAR = { [0] = 120, 121, 122 }         -- "x", "y", "z"
local B89_LEVEL_OF = { [120] = 0, [121] = 1, [122] = 2 }
local B89_OUT = { [34] = 123, [39] = 124, [92] = 125 }  -- ", ', \ are not written as themselves
local B89_IN = { [123] = 1, [124] = 6, [125] = 59 }

local function newWriter(mode)
	local w = { out = {}, level = 0, mode = mode }
	if mode == "b89" then
		function w:byte(e)
			local level = floor(e / 86)
			if self.level ~= level then
				self.level = level
				self.out[#self.out + 1] = char(B89_LEVEL_CHAR[level])
			end
			local c = (e % 86) + 33
			self.out[#self.out + 1] = char(B89_OUT[c] or c)
		end
		-- Questie writes a string's characters raw in this stream (only its length is encoded).
		function w:rawByte(e) self.out[#self.out + 1] = char(e) end
	else
		function w:byte(e)
			if e == 237 then self.out[#self.out + 1] = "\237\001"
			elseif e == 238 then self.out[#self.out + 1] = "\237\002"
			elseif e == 0 then self.out[#self.out + 1] = "\238"
			else self.out[#self.out + 1] = char(e) end
		end
		w.rawByte = w.byte
	end
	return w
end

local function newReader(text, mode)
	local r = { bytes = { byte(text, 1, -1) }, pos = 1, level = 0 }
	function r:raw()
		local v = self.bytes[self.pos]
		self.pos = self.pos + 1
		if v == nil then error("end of message", 0) end
		return v
	end
	if mode == "b89" then
		function r:byte()
			local v = self:raw()
			if B89_LEVEL_OF[v] then
				self.level = B89_LEVEL_OF[v]
				v = self:raw()
			end
			return self.level * 86 + (B89_IN[v] or (v - 33))
		end
		r.stringByte = r.raw -- read a yell's strings the way they were written
	else
		function r:byte()
			local v = self:raw()
			if v == 238 then return 0 end
			if v == 237 then
				local n = self:raw()
				return n == 1 and 237 or 238
			end
			return v
		end
		r.stringByte = r.byte
	end
	return r
end

local function writeShort(w, v) w:byte(rshift(v, 8) % 256) w:byte(v % 256) end
local function writeInt(w, v)
	w:byte(rshift(v, 24) % 256) w:byte(rshift(v, 16) % 256) w:byte(rshift(v, 8) % 256) w:byte(v % 256)
end
local function writeLong(w, v)
	local hi, lo = floor(v / 4294967296), v % 4294967296
	writeInt(w, hi)
	writeInt(w, lo)
end
local function readShort(r) return r:byte() * 256 + r:byte() end
local function readInt(r)
	return lshift(r:byte(), 24) + lshift(r:byte(), 16) + lshift(r:byte(), 8) + r:byte()
end
local function readLong(r)
	local hi = r:byte() * 16777216 + r:byte() * 65536 + r:byte() * 256 + r:byte()
	local lo = r:byte() * 16777216 + r:byte() * 65536 + r:byte() * 256 + r:byte()
	return hi * 4294967296 + lo
end

-- Floats: 32-bit IEEE single precision, as four bytes.
local function floatBits(n)
	local sign = 0
	if n < 0 then sign, n = 0x80, -n end
	local mant, expo = frexp(n)
	if mant ~= mant then return 0xFF880000 end
	if mant == math.huge or expo > 0x80 then return sign == 0 and 0x7F800000 or 0xFF800000 end
	if (mant == 0 and expo == 0) or expo < -0x7E then return sign * 16777216 end
	expo = expo + 0x7E
	mant = floor((mant * 2 - 1) * ldexp(0.5, 24))
	return (sign + floor(expo / 2)) * 16777216 + ((expo % 2) * 0x80 + floor(mant / 0x10000)) * 65536
		+ (floor(mant / 0x100) % 0x100) * 256 + mant % 0x100
end
local function bitsFloat(v)
	local b1, b2 = floor(v / 16777216) % 256, floor(v / 65536) % 256
	local b3, b4 = floor(v / 256) % 256, v % 256
	local sign = b1 > 0x7F and -1 or 1
	local expo = (b1 % 0x80) * 2 + floor(b2 / 0x80)
	local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4
	if mant == 0 and expo == 0 then return sign * 0 end
	if expo == 0xFF then return mant == 0 and sign * math.huge or 0 / 0 end
	return sign * ldexp(1 + mant / 0x800000, expo - 0x7F)
end

-- Values -----------------------------------------------------------------------------------------------------------

local function isArray(t)
	local i = 0
	for k in pairs(t) do
		i = i + 1
		if k ~= i then return false end
	end
	return true
end

local writeValue

local function remember(state, s)
	local h = Serial.Hash(s)
	if state.byHash[h] then return end
	state.hashOf[s], state.byHash[h] = h, s
end

local function writeNumber(w, v)
	local _, fract = math.modf(v)
	if fract > 0 then
		w:byte(6)
		writeInt(w, floatBits(v))
		return
	end
	local sign = 0
	if v < 0 then v, sign = -v, 1 end
	if v > 2147483646 then w:byte(4 + sign) writeLong(w, v)
	elseif v < 222 and sign == 0 then w:byte(32 + v)
	elseif v < 255 then w:byte(12 + sign) w:byte(v)
	elseif v < 65530 then w:byte(14 + sign) writeShort(w, v)
	else w:byte(2 + sign) writeInt(w, v) end
end

local function writeString(w, state, s)
	if state.hashOf[s] and #s > 4 then
		w:byte(9)
		writeInt(w, state.hashOf[s])
	elseif #s > 254 then
		w:byte(8)
		writeShort(w, #s)
		for i = 1, #s do w:byte(byte(s, i)) end
	else
		w:byte(7)
		w:byte(#s)
		for i = 1, #s do w:rawByte(byte(s, i)) end
	end
end

local function writePair(w, state, k, v, depth)
	if not k or not v then return end
	writeValue(w, state, k, depth)
	if type(k) == "string" then remember(state, k) end
	writeValue(w, state, v, depth)
	if type(v) == "string" then remember(state, v) end
end

writeValue = function(w, state, v, depth)
	local t = type(v)
	if t == "number" then writeNumber(w, v)
	elseif t == "string" then writeString(w, state, v)
	elseif t == "boolean" then w:byte(v and 17 or 16)
	elseif t == "table" then
		depth = depth or 0
		if depth > 100 then return end
		local count = 0
		for k, x in pairs(v) do if k and x then count = count + 1 end end
		if isArray(v) then
			if count > 65530 then w:byte(22) writeInt(w, count)
			elseif count > 254 then w:byte(21) writeShort(w, count)
			else w:byte(20) w:byte(count) end
			for i = 1, #v do
				writeValue(w, state, v[i], depth)
				if type(v[i]) == "string" then remember(state, v[i]) end
			end
		else
			if count > 254 then w:byte(11) writeShort(w, count) else w:byte(10) w:byte(count) end
			for k, x in pairs(v) do writePair(w, state, k, x, depth + 1) end
		end
	else
		w:byte(1) -- anything else reads as nil
	end
end

--- The message text for a value (a packet), as Questie writes it: the value under key 1 of a one-pair table.
function Serial:Write(value, mode)
	local w = newWriter(mode or "1short")
	local state = { hashOf = {}, byHash = {} }
	writePair(w, state, 1, value, 0)
	return table.concat(w.out)
end

-- Reading ----------------------------------------------------------------------------------------------------------

local readValue

local function readString(r, n)
	local t = {}
	for i = 1, n do t[i] = r:stringByte() end
	return char(unpack(t))
end

local function readTable(r, state, n)
	local t = {}
	for _ = 1, n do
		local k = readValue(r, state)
		if type(k) == "string" then remember(state, k) end
		local v = readValue(r, state)
		if type(v) == "string" then remember(state, v) end
		if k ~= nil then t[k] = v end
	end
	return t
end

local function readArray(r, state, n)
	local t = {}
	for i = 1, n do
		local v = readValue(r, state)
		if type(v) == "string" then remember(state, v) end
		t[i] = v
	end
	return t
end

readValue = function(r, state)
	local typ = r:byte()
	if typ > 31 then return typ - 32 end
	if typ == 2 then return readInt(r) end
	if typ == 3 then return -readInt(r) end
	if typ == 4 then return readLong(r) end
	if typ == 5 then return -readLong(r) end
	if typ == 6 then return bitsFloat(readInt(r)) end
	if typ == 7 then return readString(r, r:byte()) end
	if typ == 8 then
		local n = readShort(r)
		local t = {}
		for i = 1, n do t[i] = char(r:byte()) end
		return table.concat(t)
	end
	if typ == 9 then return state.byHash[readInt(r)] end
	if typ == 10 then return readTable(r, state, r:byte()) end
	if typ == 11 then return readTable(r, state, readShort(r)) end
	if typ == 12 then return r:byte() end
	if typ == 13 then return -r:byte() end
	if typ == 14 then return readShort(r) end
	if typ == 15 then return -readShort(r) end
	if typ == 16 then return false end
	if typ == 17 then return true end
	if typ == 20 then return readArray(r, state, r:byte()) end
	if typ == 21 then return readArray(r, state, readShort(r)) end
	if typ == 22 then return readArray(r, state, readInt(r)) end
	return nil -- 1, 18, 19: nil
end

--- The value a message carries, or nil when it cannot be read.
function Serial:Read(text, mode)
	if type(text) ~= "string" or text == "" then return nil end
	local ok, result = pcall(function()
		local r = newReader(text, mode or "1short")
		local state = { hashOf = {}, byHash = {} }
		return readTable(r, state, 1)[1]
	end)
	if ok then return result end
	return nil
end
