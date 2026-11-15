local function stubs()
	World.calls = {}
	AcceptQuest = function() table.insert(World.calls, "accept") end
	DeclineQuest = function() table.insert(World.calls, "decline") end
	CompleteQuest = function() table.insert(World.calls, "complete") end
	GetQuestReward = function(i) table.insert(World.calls, "reward:" .. tostring(i)) end
	IsQuestCompletable = function() return true end
	GetNumQuestChoices = function() return World.choices or 0 end
	GetQuestID = function() return World.detailQuest or 7 end
	QuestGetAutoAccept = function() return false end
	LE_PARTY_CATEGORY_INSTANCE = 2
	UnitIsPlayer = function() return false end
	ConfirmAcceptQuest = function() table.insert(World.calls, "confirm") end
	IsControlKeyDown = function() return false end
	IsAltKeyDown = function() return false end
	SendChatMessage = function(msg, channel) table.insert(World.calls, (channel or "?") .. ">" .. msg) end
	C_GossipInfo = {
		GetActiveQuests = function() return World.gossipActive or {} end,
		GetAvailableQuests = function() return World.gossipAvailable or {} end,
		SelectActiveQuest = function(id) table.insert(World.calls, "turnin:" .. id) end,
		SelectAvailableQuest = function(id) table.insert(World.calls, "take:" .. id) end,
	}
end

return {
	before = stubs,

	["automation: off by default, then accepts and hands in, the key held stops it"] = function(BF)
		World.player.level = 2
		Login()
		Fire("QUEST_DETAIL")
		equal(#World.calls, 0, "nothing while off")
		BF:Set("auto.accept", true)
		BF:Set("auto.complete", true)
		Fire("QUEST_DETAIL")
		equal(World.calls[1], "accept", "accepted")
		World.shift = true
		Fire("QUEST_DETAIL")
		equal(#World.calls, 1, "Shift held: left to the player")
		World.shift = false
		Fire("QUEST_PROGRESS")
		Fire("QUEST_COMPLETE")
		equal(World.calls[2], "complete", "completed")
		equal(World.calls[3], "reward:nil", "no choice: handed in")
		World.choices = 3
		Fire("QUEST_COMPLETE")
		equal(#World.calls, 3, "a choice of reward is the player's")
		World.gossipActive = { { questID = 33, isComplete = true } }
		Fire("GOSSIP_SHOW")
		equal(World.calls[4], "turnin:33", "a finished quest handed in from the list first")
		World.gossipActive = {}
		World.gossipAvailable = { { questID = 7, isTrivial = true }, { questID = 33 } }
		Fire("GOSSIP_SHOW")
		equal(World.calls[5], "take:33", "a low-level quest skipped while those are off")
	end,

	["announce: an objective done is said to the group in Questie's words"] = function(BF)
		IsInGroup = function(category) return category ~= 2 end
		World.questLog = { { questID = 7, title = "Kobold Camp Cleanup", level = 2,
			objectives = { { text = "Kobold Vermin slain: 9/10", type = "monster", numFulfilled = 9, numRequired = 10, finished = false } } } }
		Login()
		Fire("QUEST_LOG_UPDATE"); Tick(0.3)
		World.questLog[1].objectives[1] = { text = "Kobold Vermin slain: 10/10", type = "monster", numFulfilled = 10, numRequired = 10, finished = true }
		Fire("QUEST_LOG_UPDATE"); Tick(0.3)
		local said
		for _, c in ipairs(World.calls) do if c:find("^PARTY>") then said = c end end
		expect(said and said:find("{rt1} Questie: Kobold Vermin slain: 10/10 for ", 1, true), "said: " .. tostring(said))
		BF:Set("announce.quiet", true)
		expect(not BF.Announce:Say("again"), "quiet says nothing")
	end,
}
