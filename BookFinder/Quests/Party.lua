-- Party quest sharing that speaks Questie's own party messages, so a group member playing with Questie and one
-- playing with BookFinder see each other's quests: what you are on and how far along you are shows in their
-- tooltips and on their map, and theirs in yours (party.objectives: their objectives on your map).
--
-- The messages are Questie's "questie" addon prefix, written byte for byte as Questie writes them (BookFinder's own
-- code; the format is described here so it can be checked against Questie's):
--
--   framing   the common addon-message chunking: a message longer than 255 bytes goes in parts, each started
--             with \001 (first), \002 (next) or \003 (last); a single message starting with a byte \001-\009 is
--             sent with \004 in front.
--   bytes     "1short" encoding: every byte as itself, except 0 -> 238, 237 -> 237 1, 238 -> 237 2.
--   values    a type byte, then its body:
--               32..253   the whole number (type - 32), 0..221
--               12 / 13   one byte, the number (+ / -)       14 / 15   two bytes (+ / -)
--               2 / 3     four bytes (+ / -)                 4 / 5     eight bytes (+ / -)
--               6         a float, IEEE single as four bytes
--               7         a string, its length in one byte   8         a string, its length in two bytes
--               9         a string said before in this message (longer than 4), as its 32-bit hash
--                         (djb2: h = 5381; h = (31 h + byte) mod 2^32)
--               10 / 11   a map, its entry count in one / two bytes, then key, value, key, value...
--               20/21/22  a list, its count in one / two / four bytes, then the values
--               16 / 17   false / true                       1, 18, 19   nil
--             The message is a map of one entry: 1 -> the packet. Entries whose value is false or nil are left out.
--   packet    { ver = "x.y.z", msgVer = 5, msgId = n, ... }: compatible while floor(msgVer) is 5.
--               1   a quest's progress: quest = { id, objectives = { { id, typ, fin, ful, req }, ... } }
--               2   a quest left the log: id
--               10  the whole log (in parts of about 200 bytes, one every 3 s): rawQuestList = { [questID] = quest }
--               11  "send me your log" (answered by a whisper of 10s)
--               12  the whole log, packed: [1] = { count, questID, objectiveCount, (id, type byte, have, need)... }
--               14  one quest, packed the same way, from position 1
--             (13, progress yelled to players nearby, and QuestieV1's "which objectives to show" are not spoken yet.)
--
-- Nothing is sent in groups of more than 15 or in battlegrounds, as Questie does.

local _, BF = ...
local L = BF.L

local Party = { quests = {} }   -- quests[questID][playerName] = { {index, id, type, fulfilled, required, finished}, ... }
BF.Party = Party

local PREFIX = "questie"
local MSG_VER = 5
local VERSION = "6.0.0"          -- (what Questie compares its own version with: lower, so it never says "update")

BF.Settings:Define("party.share", { default = true, page = "Quests/Auto", label = "Share quests with my group (Questie's way)" })

-- Bytes ("1short") ---------------------------------------------------------------------------------------------------

local char, byte, floor = string.char, string.byte, math.floor

local Writer = {}
Writer.__index = Writer

local function newWriter() return setmetatable({ out = {}, n = 0, hash = {}, seen = {} }, Writer) end

function Writer:raw(b) self.n = self.n + 1 self.out[self.n] = char(b) end
function Writer:byte(b)
	if b == 237 then self:raw(237) self:raw(1)
	elseif b == 238 then self:raw(237) self:raw(2)
	elseif b == 0 then self:raw(238)
	else self:raw(b) end
end
function Writer:short(v) self:byte(floor(v / 256) % 256) self:byte(v % 256) end
function Writer:int(v) v = v % 4294967296 self:byte(floor(v / 16777216) % 256) self:byte(floor(v / 65536) % 256) self:short(v % 65536) end
function Writer:long(v) self:int(floor(v / 4294967296)) self:int(v % 4294967296) end

local function djb2(s)
	local h = 5381
	for i = 1, #s do h = (31 * h + byte(s, i)) % 4294967296 end
	return h
end
Party.Hash = djb2

local function remember(self, s)
	if type(s) ~= "string" then return end
	local h = djb2(s)
	if self.seen[h] then return end
	self.hash[s], self.seen[h] = h, s
end

-- A float as IEEE single bits (sign, exponent, mantissa).
local function floatBits(n)
	local sign = 0
	if n < 0 then sign, n = 0x80000000, -n end
	if n ~= n then return 0xFF880000 end
	local m, e = math.frexp(n)
	if m == math.huge or e > 0x80 then return sign + 0x7F800000 end
	if (m == 0 and e == 0) or e < -0x7E then return sign end
	e = e + 0x7E
	m = floor((m * 2 - 1) * 0x800000)
	return sign + e * 0x800000 + m
end
local function bitsFloat(v)
	local sign = v >= 0x80000000 and -1 or 1
	v = v % 0x80000000
	local e, m = floor(v / 0x800000), v % 0x800000
	if e == 0 and m == 0 then return sign * 0 end
	if e == 0xFF then return m == 0 and sign * math.huge or 0 / 0 end
	return sign * math.ldexp(1 + m / 0x800000, e - 0x7F)
end

local isList

function Writer:value(v)
	local t = type(v)
	if t == "number" then
		local _, fract = math.modf(v)
		if fract > 0 then
			self:byte(6) self:int(floatBits(v))
			return
		end
		local neg = 0
		if v < 0 then v, neg = -v, 1 end
		if v > 2147483646 then self:byte(4 + neg) self:long(v)
		elseif v < 222 and neg == 0 then self:byte(32 + v)
		elseif v < 255 then self:byte(12 + neg) self:byte(v)
		elseif v < 65530 then self:byte(14 + neg) self:short(v)
		else self:byte(2 + neg) self:int(v) end
	elseif t == "string" then
		if self.hash[v] and #v > 4 then self:byte(9) self:int(self.hash[v])
		elseif #v > 254 then self:byte(8) self:short(#v) for i = 1, #v do self:byte(byte(v, i)) end
		else self:byte(7) self:byte(#v) for i = 1, #v do self:byte(byte(v, i)) end end
	elseif t == "boolean" then
		self:byte(v and 17 or 16)
	elseif t == "table" then
		local count = 0
		for k, x in pairs(v) do if k and x then count = count + 1 end end
		if isList(v) then
			if count > 65530 then self:byte(22) self:int(count)
			elseif count > 254 then self:byte(21) self:short(count)
			else self:byte(20) self:byte(count) end
			for _, x in pairs(v) do
				self:value(x)
				remember(self, x)
			end
		else
			if count > 254 then self:byte(11) self:short(count) else self:byte(10) self:byte(count) end
			for k, x in pairs(v) do if k and x then self:pair(k, x) end end
		end
	else
		self:byte(1)
	end
end

function Writer:pair(k, v)
	if not k or not v then return end
	self:value(k)
	remember(self, k)
	self:value(v)
	remember(self, v)
end

isList = function(t)
	local i = 0
	for k in pairs(t) do
		i = i + 1
		if i ~= k then return false end
	end
	return true
end

--- The packet as Questie's bytes.
function Party.Serialize(packet)
	local w = newWriter()
	w:pair(1, packet)
	return table.concat(w.out)
end

local Reader = {}
Reader.__index = Reader

function Reader:raw()
	local p = self.p
	self.p = p + 1
	return byte(self.s, p) or error("short message")
end
function Reader:byte()
	local b = self:raw()
	if b == 238 then return 0 end
	if b == 237 then
		local c = self:raw()
		return c == 1 and 237 or c == 2 and 238 or error("bad escape")
	end
	return b
end
function Reader:short() return self:byte() * 256 + self:byte() end
function Reader:int() return self:short() * 65536 + self:short() end
function Reader:long() return self:int() * 4294967296 + self:int() end
function Reader:string(len)
	local t = {}
	for i = 1, len do t[i] = char(self:byte()) end
	return table.concat(t)
end

local reads
function Reader:value()
	local typ = self:byte()
	if typ > 31 then return typ - 32 end
	local f = reads[typ]
	if not f then error("unknown type " .. typ) end
	return f(self)
end

local function readMap(self, n)
	local t = {}
	for _ = 1, n do
		local k = self:value()
		remember(self, k)
		local v = self:value()
		remember(self, v)
		if k ~= nil then t[k] = v end
	end
	return t
end

local function readList(self, n)
	local t = {}
	for i = 1, n do
		local v = self:value()
		remember(self, v)
		t[i] = v
	end
	return t
end

reads = {
	[1] = function() return nil end, [18] = function() return nil end, [19] = function() return nil end,
	[2] = function(r) return r:int() end, [3] = function(r) return -r:int() end,
	[4] = function(r) return r:long() end, [5] = function(r) return -r:long() end,
	[6] = function(r) return bitsFloat(r:int()) end,
	[7] = function(r) return r:string(r:byte()) end, [8] = function(r) return r:string(r:short()) end,
	[9] = function(r) return r.seen[r:int()] end,
	[10] = function(r) return readMap(r, r:byte()) end, [11] = function(r) return readMap(r, r:short()) end,
	[12] = function(r) return r:byte() end, [13] = function(r) return -r:byte() end,
	[14] = function(r) return r:short() end, [15] = function(r) return -r:short() end,
	[16] = function() return false end, [17] = function() return true end,
	[20] = function(r) return readList(r, r:byte()) end, [21] = function(r) return readList(r, r:short()) end,
	[22] = function(r) return readList(r, r:int()) end,
}

--- Questie's bytes back into the packet (nil when they don't read).
function Party.Deserialize(s)
	local r = setmetatable({ s = s, p = 1, hash = {}, seen = {} }, Reader)
	local ok, t = pcall(readMap, r, 1)
	if ok and type(t) == "table" then return t[1] end
end

-- Framing --------------------------------------------------------------------------------------------------------

local MAX = 255

local function sendRaw(text, channel, target)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then C_ChatInfo.SendAddonMessage(PREFIX, text, channel, target) end
end

--- The message, in parts as needed.
function Party.Frame(text)
	local parts = {}
	local len = #text
	local force = false
	if text:find("^[\001-\009]") then
		if len + 1 > MAX then force = true else text = "\004" .. text end
	end
	if not force and len <= MAX then
		parts[1] = text
		return parts
	end
	local size = MAX - 1
	parts[1] = "\001" .. text:sub(1, size)
	local pos = 1 + size
	while pos + size <= len do
		parts[#parts + 1] = "\002" .. text:sub(pos, pos + size - 1)
		pos = pos + size
	end
	parts[#parts + 1] = "\003" .. text:sub(pos)
	return parts
end

local function send(packet, channel, target)
	local text = Party.Serialize(packet)
	for _, part in ipairs(Party.Frame(text)) do sendRaw(part, channel, target) end
end

local partial = {}   -- [sender .. channel] = { pieces }

--- One addon message in: the whole message once its last part has come (nil before).
function Party.Unframe(msg, channel, sender)
	local key = sender .. "\031" .. channel
	local c = msg:sub(1, 1)
	if c == "\001" then
		partial[key] = { msg:sub(2) }
	elseif c == "\002" then
		if partial[key] then table.insert(partial[key], msg:sub(2)) end
	elseif c == "\003" then
		local p = partial[key]
		partial[key] = nil
		if p then
			p[#p + 1] = msg:sub(2)
			return table.concat(p)
		end
	elseif c == "\004" then
		return msg:sub(2)
	else
		return msg
	end
end

-- Who and where ------------------------------------------------------------------------------------------------------

local function me() return GetUnitName("player", true) end

local function groupChannel()
	if IsInRaid() then return "RAID" end
	if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInGroup() then return "PARTY" end
end

local function mayBroadcast()
	if not BF:Get("party.share") then return false end
	if GetNumGroupMembers() > 15 then return false end
	if UnitInBattleground and UnitInBattleground("player") then return false end
	return groupChannel() ~= nil
end

local function inGroup(name) return UnitInParty(name) or UnitInRaid(name) end

local function packet(id)
	return { ver = VERSION, msgVer = MSG_VER, msgId = id }
end

-- Our quests, as Questie writes them ----------------------------------------------------------------------------------

local function questPacket(questID)
	local quest = { id = questID, objectives = {} }
	for i, rec in ipairs(BF.Objectives:For(questID)) do
		if rec.index then
			quest.objectives[rec.index] = {
				id = rec.id, typ = (rec.type or "m"):sub(1, 1), fin = rec.finished or nil,
				ful = rec.have, req = rec.need,
			}
		end
	end
	return quest
end
Party.QuestPacket = questPacket

function Party:SendQuest(questID)
	if not mayBroadcast() then return end
	local p = packet(1)
	p.quest = questPacket(questID)
	send(p, groupChannel())
end

function Party:SendRemoved(questID)
	if not mayBroadcast() then return end
	local p = packet(2)
	p.id = questID
	send(p, groupChannel())
end

function Party:RequestLogs()
	if not mayBroadcast() then return end
	send(packet(11), groupChannel())
end

-- The whole log, in parts of about 200 bytes, one part every 3 seconds.
local sending
function Party:SendLog(channel, target)
	if not BF:Get("party.share") then return end
	local blocks, block = {}, {}
	for id in pairs(BF.Log.quests) do
		block[id] = questPacket(id)
		if #Party.Serialize(block) > 200 then
			block[id] = nil
			if next(block) then blocks[#blocks + 1] = block end
			block = { [id] = questPacket(id) }
		end
	end
	if next(block) then blocks[#blocks + 1] = block end
	if #blocks == 0 then return end
	if sending then sending:Cancel() end
	local i = 0
	local function step()
		i = i + 1
		local b = blocks[i]
		if not b then sending = nil return end
		local p = packet(10)
		p.rawQuestList = b
		send(p, channel, target)
		sending = BF:After(3, step)
	end
	sending = BF:After(math.random() * 3, step)
end

-- Theirs ---------------------------------------------------------------------------------------------------------

local changed = BF:Debounce(0.3, function() BF:Send("BF_PARTY_CHANGED") end)

local function store(questID, player, objectives)
	if type(questID) ~= "number" then return end
	Party.quests[questID] = Party.quests[questID] or {}
	Party.quests[questID][player] = objectives
	changed()
end

local function insert(quest, player)
	if type(quest) ~= "table" or not quest.id or type(quest.objectives) ~= "table" then return end
	local list = {}
	for index, o in pairs(quest.objectives) do
		if type(index) == "number" and type(o) == "table" then
			list[index] = { index = index, id = o.id, type = o.typ, finished = o.fin and true or false,
				fulfilled = o.ful, required = o.req }
		end
	end
	store(quest.id, player, list)
end

-- The packed form (12 and 14): from `offset`, questID, count, then (id, type byte, have, need) per objective.
local function insertPacked(t, player, offset)
	if type(t) ~= "table" or not t[offset + 1] then return offset end
	local questID, count = t[offset], t[offset + 1]
	offset = offset + 2
	local list, i = {}, 0
	while i < (count or 0) and t[offset + 1] do
		i = i + 1
		local have, need = t[offset + 2], t[offset + 3]
		list[i] = { index = i, id = t[offset] ~= 0 and t[offset] or nil, type = char(t[offset + 1]),
			fulfilled = have, required = need, finished = have == need }
		offset = offset + 4
	end
	store(questID, player, list)
	return offset
end

local function remove(questID, player)
	local q = Party.quests[questID]
	if q and q[player] then
		q[player] = nil
		if not next(q) then Party.quests[questID] = nil end
		changed()
	end
end

local function forget(player)
	for questID, q in pairs(Party.quests) do
		if q[player] then
			q[player] = nil
			if not next(q) then Party.quests[questID] = nil end
		end
	end
	changed()
end

local handlers = {
	[1] = function(p, from) insert(p.quest, from) end,
	[2] = function(p, from) remove(p.id, from) end,
	[10] = function(p, from)
		for _, quest in pairs(type(p.rawQuestList) == "table" and p.rawQuestList or {}) do insert(quest, from) end
	end,
	[11] = function(_, from) Party:SendLog("WHISPER", from) end,
	[12] = function(p, from)
		local t = p[1]
		if type(t) ~= "table" then return end
		local offset = 2
		for _ = 1, t[1] or 0 do offset = insertPacked(t, from, offset) end
	end,
	[14] = function(p, from) insertPacked(p[1], from, 1) end,
}

function Party.Receive(msg, channel, sender)
	if not BF:Get("party.share") then return end
	if channel == "YELL" then return end
	local name = Ambiguate and Ambiguate(sender, "none") or sender
	if name == me() then return end
	if (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" or channel == "WHISPER") and not inGroup(name) then
		return
	end
	local whole = Party.Unframe(msg, channel, name)
	if not whole then return end
	local p = Party.Deserialize(whole)
	if type(p) ~= "table" or type(p.msgVer) ~= "number" or floor(p.msgVer) ~= MSG_VER then return end
	local h = handlers[p.msgId]
	if h then h(p, name) end
end

-- What the rest of BookFinder asks ----------------------------------------------------------------------------------

--- Party members' progress on things this NPC / object / item counts for: { {quest, player, objective}, ... }.
--- kind: "m" (creature), "o" (object), "i" (item). An item's droppers count for it too.
local index, indexStale = {}, true
BF:Listen("BF_PARTY_CHANGED", function() indexStale = true end)

local function rebuild()
	index, indexStale = {}, false
	local function add(key, e) index[key] = index[key] or {} table.insert(index[key], e) end
	for questID, players in pairs(Party.quests) do
		for player, objectives in pairs(players) do
			for _, o in pairs(objectives) do
				if o.id and o.type then
					local e = { quest = questID, player = player, objective = o }
					add(o.type .. o.id, e)
					if o.type == "i" then
						local item = BF:Item(o.id)
						for _, npc in ipairs(item and item[BF.I.npcDrops] or {}) do add("m" .. npc, e) end
						for _, obj in ipairs(item and item[BF.I.objectDrops] or {}) do add("o" .. obj, e) end
					end
				end
			end
		end
	end
end

function Party:For(kind, id)
	if indexStale then rebuild() end
	return index[kind .. id]
end

--- The objective's words: the name of what it counts, with the progress ("3/10 Kobold Vermin").
function Party:Text(o)
	local name
	if o.type == "m" then name = BF:NpcName(o.id)
	elseif o.type == "o" then name = BF:ObjectName(o.id)
	elseif o.type == "i" then name = BF:ItemName(o.id) end
	local count = (o.fulfilled and o.required) and (o.fulfilled .. "/" .. o.required) or ""
	return (count .. " " .. (name or "")):gsub("^%s+", "")
end

-- Their objectives on the map (party.objectives): quests not in the player's own log, where their unfinished
-- objectives are.
local PARTY_MARKS_PER_MAP = 4

BF.Marks:RegisterLayer("party", function(addRole)
	if not BF:Get("party.objectives") or not IsInGroup() or GetNumGroupMembers() > 5 then return end
	for questID, players in pairs(Party.quests) do
		if not BF.Log:Has(questID) then
			for player, objectives in pairs(players) do
				for _, o in pairs(objectives) do
					if o.id and not o.finished then
						local sources = {}
						if o.type == "m" then sources[1] = { type = "npc", id = o.id }
						elseif o.type == "o" then sources[1] = { type = "object", id = o.id }
						elseif o.type == "i" then
							local item = BF:Item(o.id)
							for _, npc in ipairs(item and item[BF.I.npcDrops] or {}) do sources[#sources + 1] = { type = "npc", id = npc } end
							for _, obj in ipairs(item and item[BF.I.objectDrops] or {}) do sources[#sources + 1] = { type = "object", id = obj } end
						end
						local rec = { name = Party:Text(o), text = player .. L[": "] .. Party:Text(o),
							icon = o.type == "i" and "loot" or o.type == "o" and "object" or "slay" }
						local role = { role = "objective", quest = questID, objective = rec, party = player }
						-- Their spawns merged into a few marks per map (as the player's own objectives are, a little wider),
						-- and only the biggest few of those: a party member's quest is a hint, not a carpet of icons.
						local radius = math.max(0.04, BF:Get("icons.clusterObjectives") / 100 * 1.5)
						local clusters = {}
						for _, source in ipairs(sources) do
							BF.Zones:EachSpawn(BF.Objectives:Spawns(source), function(map, x, y, inside)
								if inside then return end
								local list = clusters[map] or {}
								clusters[map] = list
								for _, c in ipairs(list) do
									local dx, dy = c.x - x, c.y - y
									if dx * dx + dy * dy <= radius * radius then
										c.n = c.n + 1
										c.sx, c.sy = c.sx + x, c.sy + y
										c.x, c.y = c.sx / c.n, c.sy / c.n
										return
									end
								end
								list[#list + 1] = { x = x, y = y, sx = x, sy = y, n = 1, source = source }
							end)
						end
						for map, list in pairs(clusters) do
							table.sort(list, function(a, b) return a.n > b.n end)
							for i = 1, math.min(#list, PARTY_MARKS_PER_MAP) do
								local c = list[i]
								addRole(map, c.x, c.y, "party:" .. questID .. ":" .. player .. ":" .. (o.index or 0) .. ":" .. i, role, nil)
							end
						end
					end
				end
			end
		end
	end
end)

-- Wiring ---------------------------------------------------------------------------------------------------------

local wasInGroup = false
local function rosterChanged()
	local now = IsInGroup()
	if now and not wasInGroup then
		-- Joined: ask for theirs, tell them ours (as Questie does on joining).
		Party:RequestLogs()
		local ch = groupChannel()
		if ch and mayBroadcast() then Party:SendLog(ch) end
	end
	wasInGroup = now
	-- Former members' quests go.
	local gone = {}
	for _, players in pairs(Party.quests) do
		for player in pairs(players) do if not inGroup(player) then gone[player] = true end end
	end
	for player in pairs(gone) do forget(player) end
end

BF:At("login", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
	BF:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
		if prefix ~= PREFIX or type(msg) ~= "string" or type(sender) ~= "string" then return end
		if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then return end
		Party.Receive(msg, channel, sender)
	end)
	BF:On("GROUP_ROSTER_UPDATE", rosterChanged)
	BF:Listen("BF_QUEST_PROGRESS", function(_, questID) Party:SendQuest(questID) end)
	BF:Listen("BF_QUEST_ACCEPTED", function(_, questID) Party:SendQuest(questID) end)
	BF:Listen("BF_QUEST_REMOVED", function(_, questID) Party:SendRemoved(questID) end)
	local rebuildLayer = BF:Debounce(0.5, function() BF.Marks:RebuildLayer("party") end)
	BF:Listen("BF_PARTY_CHANGED", rebuildLayer)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "party.objectives" then rebuildLayer() end end)
	wasInGroup = IsInGroup()
	if wasInGroup then BF:After(5, function() Party:RequestLogs() end) end
end, 67)
