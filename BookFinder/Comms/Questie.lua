-- Talking to party members who use Questie (docs/study/questie-protocol.md): BookFinder shares the player's quests
-- and progress the way Questie does, and keeps what they share, so each sees the other's objectives.
--
--   prefix "questie"   msgId 1 quest update, 2 quest removed, 10 / 12 full quest list (v1 / v2), 11 ask for it,
--                      13 yelled progress (nearby players), 14 quest update (v2)
--   prefix "QuestieV1" which of a player's quests their party should draw (tracked and not hidden)
--
-- What others share: BF.Party.quests[questID][player] = { {id, type, have, need, finished}, ... }
-- Messages: BF_PARTY_CHANGED(questID or nil)

local _, BF = ...
local L = BF.L

local Party = { quests = {}, classes = {}, nearby = {}, visibility = {}, group = {} }
BF.Party = Party

local Serial, Wire, Log, Objectives = BF.QuestieSerial, BF.Wire, BF.Log, BF.Objectives

local PREFIX, VISIBILITY = "questie", "QuestieV1"
local MSG_VER = 5
-- The version BookFinder gives: three numbers (Questie reads it as such), low enough that no Questie user is told to
-- update, and at most 5 so Questie answers a quest-log request with the v1 list (both lists are read here).
local VERSION = "1.0.0"
local CLASS_INDEX = { DRUID = 1, HUNTER = 2, MAGE = 3, PRIEST = 4, ROGUE = 5, SHAMAN = 6, WARLOCK = 7, WARRIOR = 8 }
local CLASS_OF = {}
for k, v in pairs(CLASS_INDEX) do CLASS_OF[v] = k end
-- Capital cities and battlegrounds: no yelling there (Questie's list).
local NO_YELL = { [1453] = true, [1455] = true, [1457] = true, [1947] = true, [1454] = true, [1456] = true, [1458] = true,
	[1954] = true, [1955] = true, [1459] = true, [1460] = true, [1461] = true, [1957] = true }

-- The group --------------------------------------------------------------------------------------------------------

--- "raid", "instance", "party" or nil (Questie's group types).
function Party:GroupType()
	if UnitInRaid("player") then return "raid" end
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "instance" end
	if UnitInParty("player") then return "party" end
	return nil
end

local CHANNEL = { raid = "RAID", instance = "INSTANCE_CHAT", party = "PARTY" }

local function inGroup(name)
	return (UnitInParty(name) or UnitInRaid(name)) and true or false
end

local function me() return UnitName("player") end

-- Packets ------------------------------------------------------------------------------------------------------------

local function packet(msgId)
	return { ver = VERSION, msgVer = MSG_VER, msgId = msgId }
end

local function send(p, channel, target, priority)
	-- Questie sends nothing to groups over 15 or in battlegrounds, except whispers.
	if channel ~= "WHISPER" and (GetNumGroupMembers() > 15 or UnitInBattleground("player")) then return end
	if channel == "YELL" then
		p.msgVer = nil
		Wire:Send(PREFIX, Serial:Write(p, "b89"), "YELL", nil, "BULK")
	else
		Wire:Send(PREFIX, Serial:Write(p), channel, target, priority)
	end
end

local function typeLetter(o) return (o.type or "m"):sub(1, 1) end

-- The data ID behind each of the player's objectives (0 when there is none), in the log's order.
local function objectiveIDs(questID)
	local ids = {}
	for _, rec in ipairs(Objectives:For(questID)) do
		if rec.index then ids[rec.index] = rec.id or 0 end
	end
	return ids
end

--- msgId 1's quest table: { id, objectives = { {id, typ, fin, ful, req}, ... } }.
function Party:QuestPacket(questID)
	local q = Log:Get(questID)
	local quest = { id = questID, objectives = {} }
	if not q then return quest end
	local ids = objectiveIDs(questID)
	for i, o in ipairs(q.objectives) do
		quest.objectives[i] = { id = ids[i] or 0, typ = typeLetter(o), fin = o.finished or nil, ful = o.have, req = o.need }
	end
	return quest
end

--- The v2 list shape for one quest, appended to `list` from `offset`; with the class index for yells.
local function appendV2(list, offset, questID, withClass)
	local q = Log:Get(questID)
	if not q or #q.objectives == 0 then return offset, 0 end
	local ids = objectiveIDs(questID)
	list[offset] = questID
	list[offset + 1] = #q.objectives
	offset = offset + 2
	if withClass then
		list[offset] = CLASS_INDEX[select(2, UnitClass("player"))] or 0
		offset = offset + 1
	end
	for i, o in ipairs(q.objectives) do
		list[offset] = ids[i] or 0
		list[offset + 1] = string.byte(typeLetter(o))
		list[offset + 2] = o.have
		list[offset + 3] = o.need
		offset = offset + 4
	end
	return offset, #q.objectives
end

-- Sending ------------------------------------------------------------------------------------------------------------

local yellQueue, yelling, loadedAt = {}, false, 0

local function yellNext()
	local questID = table.remove(yellQueue, 1)
	if not questID then
		yelling = false
		return
	end
	local list = {}
	local _, count = appendV2(list, 1, questID, true)
	if count > 0 then
		local p = packet(13)
		p[1] = list
		send(p, "YELL")
	end
	BF:After(2, yellNext)
end

--- Yells a quest's progress to players nearby (Questie's rules: small group or solo, not in a city, not just loaded).
function Party:Yell(questID)
	if GetNumGroupMembers() > 4 or GetTime() - loadedAt < 8 then return end
	if NO_YELL[C_Map.GetBestMapForUnit("player") or 0] then return end
	for _, q in ipairs(yellQueue) do if q == questID then return end end
	table.insert(yellQueue, questID)
	if not yelling then
		yelling = true
		BF:After(2, yellNext)
	end
end

function Party:SendUpdate(questID)
	local group = Party:GroupType()
	if group ~= "raid" then Party:Yell(questID) end
	if not group then return end
	local p = packet(1)
	p.quest = Party:QuestPacket(questID)
	send(p, CHANNEL[group], nil, "NORMAL")
end

function Party:SendRemove(questID)
	local group = Party:GroupType()
	if not group then return end
	local p = packet(2)
	p.id = questID
	send(p, CHANNEL[group], nil, "ALERT")
end

function Party:RequestLogs()
	local group = Party:GroupType()
	if not group then return end
	send(packet(11), CHANNEL[group], nil, "NORMAL")
end

-- The whole quest log, in blocks of about 200 serialized bytes, one every 3 s (Questie's pace).
function Party:SendLog(target, v2)
	local group = Party:GroupType()
	if not group then return end
	local ids = {}
	for id in pairs(Log.quests) do ids[#ids + 1] = id end
	table.sort(ids)
	-- Each quest's piece, then pieces packed into blocks that stay near 200 serialized bytes.
	local blocks = {}
	if v2 then
		local block = { 0 }
		for _, id in ipairs(ids) do
			local piece = {}
			local _, n = appendV2(piece, 1, id, false)
			if n > 0 then
				local trial = {}
				for i, v in ipairs(block) do trial[i] = v end
				for _, v in ipairs(piece) do trial[#trial + 1] = v end
				trial[1] = block[1] + 1
				if block[1] > 0 and #Serial:Write(trial) > 200 then
					blocks[#blocks + 1] = block
					block = { 1 }
					for _, v in ipairs(piece) do block[#block + 1] = v end
				else
					block = trial
				end
			end
		end
		if block[1] > 0 then blocks[#blocks + 1] = block end
	else
		local block, count = {}, 0
		for _, id in ipairs(ids) do
			block[id] = Party:QuestPacket(id)
			count = count + 1
			if count > 1 and #Serial:Write(block) > 200 then
				block[id] = nil
				blocks[#blocks + 1] = block
				block, count = { [id] = Party:QuestPacket(id) }, 1
			end
		end
		if count > 0 then blocks[#blocks + 1] = block end
	end
	local channel = target and "WHISPER" or CHANNEL[group]
	local function sendNext()
		local b = table.remove(blocks, 1)
		if not b then return end
		local p = packet(v2 and 12 or 10)
		if v2 then p[1] = b else p.rawQuestList = b end
		send(p, channel, target, target and "NORMAL" or (group == "party" and "NORMAL" or "BULK"))
		BF:After(3, sendNext)
	end
	BF:After(math.random() * 3, sendNext)
end

-- Visibility (QuestieV1): which of the player's quests the party should draw ------------------------------------------

local function hasCodec()
	return C_EncodingUtil and C_EncodingUtil.SerializeCBOR and C_EncodingUtil.CompressString
		and C_EncodingUtil.DecompressString and C_EncodingUtil.DeserializeCBOR
		and Enum.CompressionMethod and Enum.CompressionMethod.Deflate ~= nil
end

local function snapshot()
	local s = {}
	for id in pairs(Log.quests) do
		if BF.Rules:HiddenByPlayer(id) then s[id] = false
		else s[id] = C_QuestLog.GetQuestWatchType(id) ~= nil end
	end
	return s
end

local visibilityTimer
function Party:ScheduleVisibility()
	if visibilityTimer then visibilityTimer:Cancel() end
	if not hasCodec() or GetNumGroupMembers() > 5 then return end
	visibilityTimer = BF:After(math.random() * 2, function()
		visibilityTimer = nil
		local group = Party:GroupType()
		if not group or GetNumGroupMembers() > 5 then return end
		local ok, text = pcall(function()
			local cbor = C_EncodingUtil.SerializeCBOR(snapshot())
			local packed = C_EncodingUtil.CompressString(cbor, Enum.CompressionMethod.Deflate, Enum.CompressionLevel.Default)
			return Wire.Escape(packed)
		end)
		if ok and type(text) == "string" and #text <= 762 then Wire:Send(VISIBILITY, text, CHANNEL[group]) end
	end)
end

local function readVisibility(message, channel, sender)
	if sender == me() or not (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" or channel == "WHISPER") then return end
	if not inGroup(sender) or not hasCodec() or #message > 762 then return end
	local ok, payload = pcall(function()
		local packed = Wire.Unescape(message)
		if not packed then return nil end
		local cbor = C_EncodingUtil.DecompressString(packed, Enum.CompressionMethod.Deflate)
		return cbor and C_EncodingUtil.DeserializeCBOR(cbor)
	end)
	if not ok or type(payload) ~= "table" then return end
	local limit = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 25
	local n = 0
	for k, v in pairs(payload) do
		n = n + 1
		if n > limit or type(k) ~= "number" or k <= 0 or k % 1 ~= 0 or type(v) ~= "boolean" then return end
	end
	Party.visibility[sender] = payload
	BF:Send("BF_PARTY_CHANGED")
end

--- Whether a party member wants their objectives of a quest drawn (yes, until they say otherwise).
function Party:Visible(player, questID)
	local v = Party.visibility[player]
	if not v then return true end
	return v[questID] == true
end

-- Receiving ----------------------------------------------------------------------------------------------------------

local function setQuest(questID, player, objectives)
	Party.quests[questID] = Party.quests[questID] or {}
	Party.quests[questID][player] = objectives
	BF:Send("BF_PARTY_CHANGED", questID)
end

local function removeQuest(questID, player)
	if Party.quests[questID] and Party.quests[questID][player] then
		Party.quests[questID][player] = nil
		if not next(Party.quests[questID]) then Party.quests[questID] = nil end
		BF:Send("BF_PARTY_CHANGED", questID)
	end
end

-- msgId 1 and 10's quest table.
local function readV1Quest(quest, player)
	if type(quest) ~= "table" or type(quest.id) ~= "number" or type(quest.objectives) ~= "table" then return end
	local list = {}
	for i, o in pairs(quest.objectives) do
		if type(i) == "number" and type(o) == "table" then
			list[i] = { id = o.id, type = o.typ, have = o.ful or 0, need = o.req or 0, finished = o.fin == true }
		end
	end
	Party.group[player] = true
	setQuest(quest.id, player, list)
end

-- The v2 shape at `offset`; returns the next offset.
local function readV2Quest(list, offset, player, withClass, nearby)
	local questID, count = list[offset], list[offset + 1]
	if type(questID) ~= "number" or type(count) ~= "number" then return nil end
	offset = offset + 2
	if withClass then
		Party.classes[player] = CLASS_OF[list[offset]]
		offset = offset + 1
	end
	local objectives, allDone = {}, true
	for i = 1, count do
		local id, typ, have, need = list[offset], list[offset + 1], list[offset + 2], list[offset + 3]
		if have == nil then break end
		objectives[i] = { id = id ~= 0 and id or nil, type = type(typ) == "number" and string.char(typ) or nil,
			have = have, need = need, finished = have == need }
		allDone = allDone and objectives[i].finished
		offset = offset + 4
	end
	if nearby and allDone then
		removeQuest(questID, player)
	else
		if not nearby then Party.group[player] = true end
		setQuest(questID, player, objectives)
	end
	return offset
end

local warned = false

local function read(message, channel, sender)
	if sender == me() then return end
	local group = channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT"
	if group and not inGroup(sender) then return end
	if channel == "YELL" then
		local p = Serial:Read(message, "b89")
		if type(p) ~= "table" or p.msgId ~= 13 or type(p[1]) ~= "table" then return end
		if NO_YELL[C_Map.GetBestMapForUnit("player") or 0] then return end
		Party.nearby[sender] = GetTime()
		readV2Quest(p[1], 1, sender, true, true)
		return
	end
	local p = Serial:Read(message)
	if type(p) ~= "table" or type(p.msgVer) ~= "number" then return end
	if math.floor(p.msgVer) ~= MSG_VER then
		if not warned then
			warned = true
			BF:Print(L["%s uses a version of Questie that BookFinder can't share quests with."], sender)
		end
		return
	end
	local id = p.msgId
	if id == 1 then
		readV1Quest(p.quest, sender)
	elseif id == 2 then
		if type(p.id) == "number" then removeQuest(p.id, sender) end
	elseif id == 10 then
		for _, quest in pairs(type(p.rawQuestList) == "table" and p.rawQuestList or {}) do readV1Quest(quest, sender) end
	elseif id == 11 then
		local major = tonumber((tostring(p.ver or ""):match("^(%d+)")))
		Party:SendLog(sender, major ~= nil and major > 5)
		Party:ScheduleVisibility()
	elseif id == 12 then
		local list = p[1]
		if type(list) ~= "table" or type(list[1]) ~= "number" then return end
		local offset = 2
		for _ = 1, list[1] do
			offset = readV2Quest(list, offset, sender, false, false)
			if not offset then break end
		end
	elseif id == 14 then
		if type(p[1]) == "table" then readV2Quest(p[1], 1, sender, false, false) end
	end
end

-- Keeping it current -------------------------------------------------------------------------------------------------

--- Forgets the group's players (the group was left) and players no longer in it; nearby players after 4 minutes.
function Party:Prune(all)
	local changed = false
	for questID, players in pairs(Party.quests) do
		for player in pairs(players) do
			local gone
			if Party.group[player] then gone = all or not inGroup(player)
			else gone = not Party.nearby[player] or GetTime() - Party.nearby[player] > 240 end
			if gone then
				players[player] = nil
				changed = true
			end
		end
		if not next(players) then Party.quests[questID] = nil end
	end
	for player in pairs(Party.group) do if all or not inGroup(player) then Party.group[player] = nil end end
	for player in pairs(Party.visibility) do if all or not inGroup(player) then Party.visibility[player] = nil end end
	if changed then BF:Send("BF_PARTY_CHANGED") end
end

--- The nearby (yelling) players shown: the 3 heard from most recently.
function Party:NearbyShown(player)
	if Party.group[player] then return true end
	local t = Party.nearby[player]
	if not t then return false end
	local newer = 0
	for _, other in pairs(Party.nearby) do if other > t then newer = newer + 1 end end
	return newer < 3
end

local pending = {}
local flush = BF:Debounce(0.5, function()
	for questID in pairs(pending) do
		if Log:Has(questID) then Party:SendUpdate(questID) end
	end
	wipe(pending)
end)

local wasInGroup = false

BF:At("login", function()
	loadedAt = GetTime()
	Wire:Listen(PREFIX, read)
	Wire:Listen(VISIBILITY, readVisibility)
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id)
		pending[id] = true
		flush()
		Party:ScheduleVisibility()
	end)
	BF:Listen("BF_QUEST_PROGRESS", function(_, id) pending[id] = true flush() end)
	BF:Listen("BF_QUEST_COMPLETE_CHANGED", function(_, id) pending[id] = true flush() end)
	BF:Listen("BF_QUEST_REMOVED", function(_, id)
		Party:SendRemove(id)
		Party:ScheduleVisibility()
	end)
	BF:Listen("BF_QUEST_HIDDEN_CHANGED", function() Party:ScheduleVisibility() end)
	BF:On("GROUP_ROSTER_UPDATE", function()
		local now = Party:GroupType() ~= nil and GetNumGroupMembers() > 1
		if now and not wasInGroup then
			-- Joined: ask everyone for their quests (Questie asks once someone else is in the group).
			Party:RequestLogs()
		end
		if not now and wasInGroup then Party:Prune(true) else Party:Prune(false) end
		wasInGroup = now
		if now then Party:ScheduleVisibility() end
	end)
	BF:Every(60, function() Party:Prune(false) end)
	wasInGroup = Party:GroupType() ~= nil and GetNumGroupMembers() > 1
	if wasInGroup then Party:RequestLogs() end
end, 40)
