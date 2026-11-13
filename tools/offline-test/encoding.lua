-- The game's C_EncodingUtil, in plain Lua, for the offline test (tools/offline-test/merged.py): QuestieDB's database
-- and Shortest Path's terrain are base64, zlib and CBOR. zlib is LibDeflate's, the copy Questie ships (loaded by the
-- time anything decodes); base64 and CBOR are written here. Enough of each for what these addons store.

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64INV = {}
for i = 1, 64 do B64INV[B64:byte(i)] = i - 1 end

local function DecodeBase64(s)
	if type(s) ~= "string" then return nil end
	local out, n, bits, acc = {}, 0, 0, 0
	for i = 1, #s do
		local v = B64INV[s:byte(i)]
		if v then
			acc = acc * 64 + v
			bits = bits + 6
			if bits >= 8 then
				bits = bits - 8
				local byte = math.floor(acc / 2 ^ bits) % 256
				n = n + 1
				out[n] = string.char(byte)
				acc = acc % 2 ^ bits
			end
		end
	end
	return table.concat(out)
end

local function DecompressString(s, method)
	local LD = LibStub and LibStub("LibDeflate", true)
	if not LD or type(s) ~= "string" then return nil end
	if method == 0 or method == "deflate" then return LD:DecompressDeflate(s) end
	return LD:DecompressZlib(s)
end

-- CBOR (RFC 8949): integers, strings, arrays, maps, tags (their value), simple values and floats
local function DeserializeCBOR(s)
	if type(s) ~= "string" then return nil end
	local pos = 1
	local function byte() local b = s:byte(pos) pos = pos + 1 return b end
	local function uint(n)
		local v = 0
		for _ = 1, n do v = v * 256 + byte() end
		return v
	end
	local function half(h)
		local sign = h >= 0x8000 and -1 or 1
		local e, m = math.floor(h / 0x400) % 32, h % 0x400
		if e == 0 then return sign * m * 2 ^ -24 end
		if e == 31 then return m == 0 and sign * math.huge or 0 / 0 end
		return sign * (1 + m / 1024) * 2 ^ (e - 15)
	end
	local function single(u)
		local sign = u >= 0x80000000 and -1 or 1
		local e, m = math.floor(u / 0x800000) % 256, u % 0x800000
		if e == 0 then return sign * m * 2 ^ -149 end
		if e == 255 then return m == 0 and sign * math.huge or 0 / 0 end
		return sign * (1 + m / 0x800000) * 2 ^ (e - 127)
	end
	local function double(hi, lo)
		local sign = hi >= 0x80000000 and -1 or 1
		local e = math.floor(hi / 0x100000) % 2048
		local m = (hi % 0x100000) * 2 ^ 32 + lo
		if e == 0 then return sign * m * 2 ^ -1074 end
		if e == 2047 then return m == 0 and sign * math.huge or 0 / 0 end
		return sign * (1 + m / 2 ^ 52) * 2 ^ (e - 1023)
	end
	local item
	local function length(info)
		if info < 24 then return info end
		if info == 24 then return uint(1) end
		if info == 25 then return uint(2) end
		if info == 26 then return uint(4) end
		if info == 27 then return uint(8) end
		return nil   -- (31: indefinite)
	end
	item = function()
		local ib = byte()
		if not ib then return nil end
		local major, info = math.floor(ib / 32), ib % 32
		if major == 0 then return length(info) end
		if major == 1 then return -1 - length(info) end
		if major == 2 or major == 3 then
			local n = length(info)
			if not n then
				local parts = {}
				while s:byte(pos) ~= 0xFF do parts[#parts + 1] = item() end
				pos = pos + 1
				return table.concat(parts)
			end
			local v = s:sub(pos, pos + n - 1)
			pos = pos + n
			return v
		end
		if major == 4 then
			local n, t = length(info), {}
			if not n then
				local i = 0
				while s:byte(pos) ~= 0xFF do i = i + 1 t[i] = item() end
				pos = pos + 1
				return t
			end
			for i = 1, n do t[i] = item() end
			return t
		end
		if major == 5 then
			local n, t = length(info), {}
			if not n then
				while s:byte(pos) ~= 0xFF do local k = item() t[k] = item() end
				pos = pos + 1
				return t
			end
			for _ = 1, n do
				local k = item()
				local v = item()
				if k ~= nil then t[k] = v end
			end
			return t
		end
		if major == 6 then length(info) return item() end
		-- major 7
		if info == 20 then return false end
		if info == 21 then return true end
		if info == 22 or info == 23 then return nil end
		if info == 25 then return half(uint(2)) end
		if info == 26 then return single(uint(4)) end
		if info == 27 then local hi = uint(4) return double(hi, uint(4)) end
		if info == 24 then return uint(1) end
		return info
	end
	return item()
end

C_EncodingUtil = { DecodeBase64 = DecodeBase64, DecompressString = DecompressString, DeserializeCBOR = DeserializeCBOR }
