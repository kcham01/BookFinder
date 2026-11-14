-- Party sharing with Questie users: the wire's framing, the messages BookFinder sends, what it does with theirs.
-- (The serializer itself was checked byte for byte against Questie 12.9.0's own; see docs/BUILD.md.)

local function quest(id, title, objectives)
	return { questID = id, title = title, level = 2, objectives = objectives or {} }
end
local function obj(text, have, need, kind)
	return { text = text, type = kind or "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

local BOB = "Bob Builder"

local function setup(inGroup)
	World.player.level = 3
	World.completed[783] = true
	World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }) }
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	if inGroup then World.group = { BOB } end
	Login()
	Tick(10)
end

-- Every whole message sent under a prefix (pieces joined), decoded with BookFinder's reader.
local function sent(BF, prefix)
	local list, pieces = {}, {}
	for _, m in ipairs(World.sentMessages) do
		if m[1] == prefix then
			local c, rest = m[2]:match("^([\001-\004])(.*)$")
			if c == "\001" then pieces = { rest }
			elseif c == "\002" then pieces[#pieces + 1] = rest
			elseif c == "\003" then pieces[#pieces + 1] = rest list[#list + 1] = { table.concat(pieces), m[3], m[4] }
			elseif c == "\004" then list[#list + 1] = { rest, m[3], m[4] }
			else list[#list + 1] = { m[2], m[3], m[4] } end
		end
	end
	return list
end

local function packets(BF, msgId)
	local out = {}
	for _, m in ipairs(sent(BF, "questie")) do
		local p = BF.QuestieSerial:Read(m[1], m[2] == "YELL" and "b89" or nil)
		if p and p.msgId == msgId then out[#out + 1] = { p = p, channel = m[2], target = m[3] } end
	end
	return out
end

local function from(BF, sender, p, channel)
	Fire("CHAT_MSG_ADDON", "questie", BF.QuestieSerial:Write(p, channel == "YELL" and "b89" or nil), channel or "PARTY", sender)
end

return {
	["the wire: a long message goes in AceComm's pieces and comes back whole"] = function(BF)
		setup(false)
		local got
		BF.Wire:Listen("BFTEST", function(message, channel, sender) got = { message, channel, sender } end)
		local long = string.rep("abcdefghij", 60)
		BF.Wire:Send("BFTEST", long, "PARTY")
		Tick(3)
		local pieces = {}
		for _, m in ipairs(World.sentMessages) do if m[1] == "BFTEST" then pieces[#pieces + 1] = m[2] end end
		equal(#pieces, 3, "three pieces")
		equal(pieces[1]:sub(1, 1), "\001", "first")
		equal(pieces[2]:sub(1, 1), "\002", "middle")
		equal(pieces[3]:sub(1, 1), "\003", "last")
		equal(#pieces[1], 255, "full size")
		for _, piece in ipairs(pieces) do Fire("CHAT_MSG_ADDON", "BFTEST", piece, "PARTY", BOB .. "-Forever") end
		equal(got and got[1], long, "joined")
		equal(got[3], BOB, "the sender's name shortened")
	end,

	["the wire: a message starting with a control byte is escaped"] = function(BF)
		setup(false)
		BF.Wire:Send("BFTEST", "\002hello", "PARTY")
		equal(World.sentMessages[#World.sentMessages][2], "\004\002hello", "escaped with byte 4")
	end,

	["joining a group asks for everyone's quests"] = function(BF)
		setup(false)
		World.group = { BOB }
		Fire("GROUP_ROSTER_UPDATE")
		Tick(1)
		local asks = packets(BF, 11)
		equal(#asks, 1, "one request")
		equal(asks[1].channel, "PARTY", "to the party")
		equal(asks[1].p.ver, "1.0.0", "BookFinder's version as three numbers")
		equal(asks[1].p.msgVer, 5, "protocol 5")
	end,

	["progress goes to the party as Questie's quest update"] = function(BF)
		setup(true)
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 4/10", 4, 10) })
		Fire("QUEST_LOG_UPDATE")
		Tick(3)
		local updates = packets(BF, 1)
		local last = updates[#updates]
		expect(last, "an update")
		equal(last.p.quest.id, 7, "the quest")
		local o = last.p.quest.objectives[1]
		equal(o.id, 6, "the creature's ID")
		equal(o.typ, "m", "monster")
		equal(o.ful, 4, "have")
		equal(o.req, 10, "need")
		equal(o.fin, nil, "not finished: no field")
	end,

	["a Questie user's quests: kept, on the map, on tooltips; removed when they drop them"] = function(BF)
		setup(true)
		World.questLog = {} -- the player hands the quest in: only Bob still has it
		Fire("QUEST_LOG_UPDATE")
		Tick(1)
		from(BF, BOB, { ver = "12.9.0", msgVer = 5, msgId = 1,
			quest = { id = 7, objectives = { { id = 6, typ = "m", ful = 2, req = 10 } } } })
		Tick(1)
		local mine = BF.Party.quests[7] and BF.Party.quests[7][BOB]
		expect(mine, "kept")
		equal(mine[1].have, 2, "progress")
		local onMap = false
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, r in ipairs(pin.roles) do if r.party == BOB and r.quest == 7 then onMap = true end end
		end
		expect(onMap, "Bob's kobolds on the map")
		local t = table.concat(World.ShowTooltip("Unit", { guid = "Creature-0-1-0-12-6-0000AB12CD" }, "Kobold Vermin"), "\n")
		expect(t:find(BOB .. ": 2/10", 1, true), "Bob's progress on the tooltip")
		from(BF, BOB, { ver = "12.9.0", msgVer = 5, msgId = 2, id = 7 })
		expect(not BF.Party.quests[7], "gone when Bob drops it")
	end,

	["someone not in the group is not listened to"] = function(BF)
		setup(true)
		from(BF, "Eve Stranger", { ver = "12.9.0", msgVer = 5, msgId = 1,
			quest = { id = 7, objectives = { { id = 6, typ = "m", ful = 2, req = 10 } } } })
		expect(not BF.Party.quests[7], "ignored")
	end,

	["a request from Questie 12 is answered by whisper with the v2 list"] = function(BF)
		setup(true)
		from(BF, BOB, { ver = "12.9.0", msgVer = 5, msgId = 11 })
		Tick(8)
		local lists = packets(BF, 12)
		equal(#lists, 1, "one block")
		equal(lists[1].channel, "WHISPER", "whispered")
		equal(lists[1].target, BOB, "to Bob")
		local l = lists[1].p[1]
		equal(l[1], 1, "one quest")
		equal(l[2], 7, "Kobold Camp Cleanup")
		equal(l[3], 1, "one objective")
		equal(l[4], 6, "Kobold Vermin")
		equal(l[5], string.byte("m"), "monster")
		equal(l[6], 3, "have")
		equal(l[7], 10, "need")
	end,

	["a request from an old version is answered with the v1 list"] = function(BF)
		setup(true)
		from(BF, BOB, { ver = "5.2.0", msgVer = 5, msgId = 11 })
		Tick(8)
		local lists = packets(BF, 10)
		equal(#lists, 1, "one v1 block")
		equal(lists[1].p.rawQuestList[7].objectives[1].ful, 3, "the quest in it")
	end,

	["the v2 list from a Questie user is read"] = function(BF)
		World.questLog = {}
		setup(true)
		from(BF, BOB, { ver = "12.9.0", msgVer = 5, msgId = 12, { 2, 7, 1, 6, 109, 3, 10, 33, 1, 750, 105, 8, 8 } })
		equal(BF.Party.quests[7][BOB][1].have, 3, "first quest")
		equal(BF.Party.quests[33][BOB][1].finished, true, "second quest done")
	end,

	["a nearby player's yell is read (the strings Questie itself cannot read)"] = function(BF)
		setup(false)
		from(BF, "Nia Nearby", { ver = "12.9.0", msgId = 13, { 7, 1, 8, 6, 109, 5, 10 } }, "YELL")
		local n = BF.Party.quests[7] and BF.Party.quests[7]["Nia Nearby"]
		expect(n, "kept")
		equal(n[1].have, 5, "progress")
		equal(BF.Party.classes["Nia Nearby"], "WARRIOR", "class from the yell")
		local t = table.concat(World.ShowTooltip("Unit", { guid = "Creature-0-1-0-12-6-0000AB12CD" }, "Kobold Vermin"), "\n")
		expect(t:find("Nia Nearby (Nearby): 5/10", 1, true), "on the tooltip, as nearby")
	end,

	["an incompatible Questie version is said once"] = function(BF)
		setup(true)
		from(BF, BOB, { ver = "20.0.0", msgVer = 6, msgId = 1, quest = { id = 7, objectives = {} } })
		from(BF, BOB, { ver = "20.0.0", msgVer = 6, msgId = 1, quest = { id = 7, objectives = {} } })
		local said = 0
		for _, line in ipairs(World.printed) do if line:find("Questie", 1, true) then said = said + 1 end end
		equal(said, 1, "once")
		expect(not BF.Party.quests[7], "not read")
	end,

	["leaving the group forgets the group's quests"] = function(BF)
		setup(true)
		from(BF, BOB, { ver = "12.9.0", msgVer = 5, msgId = 1, quest = { id = 33, objectives = { { id = 750, typ = "i", ful = 1, req = 8 } } } })
		expect(BF.Party.quests[33], "kept")
		World.group = {}
		Fire("GROUP_ROSTER_UPDATE")
		expect(not BF.Party.quests[33], "forgotten")
	end,

	["QuestieV1: the player's tracked quests go to the party; a member's choice is kept"] = function(BF)
		setup(true)
		World.watched[7] = true
		BF.Party:ScheduleVisibility()
		Tick(3)
		local msgs = sent(BF, "QuestieV1")
		expect(#msgs >= 1, "sent")
		local text = msgs[#msgs][1]
		expect(text:sub(1, 2) == "\001\002", "escaped for the addon channel (byte 0 as 1, 2)")
		local payload = C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(BF.Wire.Unescape(text)))
		equal(payload[7], true, "Kobold Camp Cleanup tracked")
		-- Bob hides quest 33 from his party.
		table.insert(World.cbor, { [33] = false })
		local theirs = BF.Wire.Escape(C_EncodingUtil.CompressString("cbor" .. #World.cbor))
		-- AceComm puts byte 4 before a message that starts with a control byte.
		Fire("CHAT_MSG_ADDON", "QuestieV1", "\004" .. theirs, "PARTY", BOB)
		equal(BF.Party:Visible(BOB, 33), false, "kept")
		equal(BF.Party:Visible(BOB, 7), false, "not in the snapshot: not shown")
		equal(BF.Party:Visible("Someone Else", 7), true, "no snapshot: shown")
	end,
}
