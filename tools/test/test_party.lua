local function stubs()
	World.sent = {}
	C_ChatInfo.SendAddonMessage = function(prefix, text, channel, target) table.insert(World.sent, { prefix = prefix, text = text, channel = channel, target = target }) end
	C_ChatInfo.RegisterAddonMessagePrefix = function() end
	Ambiguate = function(n) return n end
	GetUnitName = function() return World.player.name end
	UnitInParty = function(n) return n == "Ada" end
	UnitInRaid = function() return nil end
	UnitInBattleground = function() return nil end
	LE_PARTY_CATEGORY_INSTANCE = 2
	IsInGroup = function(c) return c ~= 2 end
	GetNumGroupMembers = function() return 2 end
end

return {
	before = stubs,

	["party: a Questie user's packed quest log shows in tooltips and on the map"] = function(BF)
		Login()
		-- Questie 12.9.0 answering a request: msgId 12, its packed list. Kobold Camp Cleanup (7): Kobold Vermin (6) 4/10.
		local p = { ver = "12.9.0", msgVer = 5, msgId = 12, [1] = { 1, 7, 1, 6, string.byte("m"), 4, 10 } }
		for _, part in ipairs(BF.Party.Frame(BF.Party.Serialize(p))) do Fire("CHAT_MSG_ADDON", "questie", part, "WHISPER", "Ada") end
		Tick(1)
		expect(BF.Party.quests[7] and BF.Party.quests[7].Ada, "stored")
		local list = BF.Party:For("m", 6)
		expect(list and list[1].player == "Ada", "Kobold Vermin counts for Ada")
		equal(BF.Party:Text(list[1].objective), "4/10 Kobold Vermin", "her progress")
		local found = false
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, r in ipairs(pin.roles) do if r.party == "Ada" then found = true end end
		end
		expect(found, "her objective on the Elwynn map")
		equal(#World.errors, 0, "no errors")
	end,

	["party: our progress goes to the group in Questie's format, a stranger is ignored"] = function(BF)
		World.questLog = { { questID = 7, title = "Kobold Camp Cleanup", level = 2,
			objectives = { { text = "Kobold Vermin slain: 4/10", type = "monster", numFulfilled = 4, numRequired = 10, finished = false } } } }
		Login()
		Fire("QUEST_LOG_UPDATE"); Tick(0.3)
		World.sent = {}
		BF.Party:SendQuest(7)
		local msg = World.sent[1]
		expect(msg and msg.prefix == "questie" and msg.channel == "PARTY", "sent to the party")
		local back = BF.Party.Deserialize(BF.Party.Unframe(msg.text, "PARTY", "x"))
		equal(back.msgId, 1, "a quest update")
		equal(back.quest.id, 7, "the quest")
		equal(back.quest.objectives[1].ful, 4, "its progress")
		local p = { ver = "12.9.0", msgVer = 5, msgId = 2, id = 7 }
		Fire("CHAT_MSG_ADDON", "questie", BF.Party.Serialize(p), "PARTY", "Stranger")
		equal(#World.errors, 0, "no errors")
	end,
}
