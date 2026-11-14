-- Phase 13: automation, announcements, sounds, Questie's chat links, the minimap button, the commands.

local function quest(id, title, objectives)
	return { questID = id, title = title, level = 2, objectives = objectives or {} }
end
local function obj(text, have, need)
	return { text = text, type = "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

local MCBRIDE = "Creature-0-1-0-12-197-0000AB12CD"

local function setup(level)
	World.player.level = level or 3
	World.completed[783] = true
	World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }) }
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(10)
end

local function didKind(kind)
	for _, d in ipairs(World.did) do if d[1] == kind then return d end end
end

return {
	["auto-accept: off by default; on, a quest page is accepted"] = function(BF)
		setup()
		World.talk = { questID = 33, npcGuid = MCBRIDE }
		Fire("QUEST_DETAIL")
		expect(not didKind("accept"), "nothing while off")
		BF:Set("auto.accept", true)
		Fire("QUEST_DETAIL")
		equal(didKind("accept")[2], 33, "accepted")
	end,

	["auto-accept: the held key skips it until the windows close"] = function(BF)
		setup()
		BF:Set("auto.accept", true)
		World.talk = { npcGuid = MCBRIDE, available = { { questID = 33 } } }
		World.shift = true
		Fire("GOSSIP_SHOW")
		World.shift = false
		Fire("GOSSIP_SHOW")
		expect(not didKind("available"), "skipped while still talking")
		Fire("GOSSIP_CLOSED")
		Tick(1)
		Fire("GOSSIP_SHOW")
		equal(didKind("available")[2], 33, "back once the windows closed")
	end,

	["auto-accept: low-level quests only when chosen"] = function(BF)
		setup(20)
		BF:Set("auto.accept", true)
		World.talk = { questID = 33, npcGuid = MCBRIDE }
		Fire("QUEST_DETAIL")
		expect(not didKind("accept"), "a level 2 quest at 20 is left")
		BF:Set("auto.trivial", true)
		Fire("QUEST_DETAIL")
		expect(didKind("accept"), "taken when low-level quests are wanted")
	end,

	["auto-complete: a finished quest first, then its reward when there is no choice"] = function(BF)
		setup()
		BF:Set("auto.complete", true)
		World.talk = { npcGuid = MCBRIDE, active = { { questID = 7, isComplete = false }, { questID = 783, isComplete = true } } }
		Fire("GOSSIP_SHOW")
		equal(didKind("active")[2], 783, "the finished one")
		World.talk = { questID = 783, npcGuid = MCBRIDE, completable = true, choices = 2 }
		Fire("QUEST_PROGRESS")
		expect(didKind("complete"), "completed")
		Fire("QUEST_COMPLETE")
		expect(not didKind("reward"), "a choice to make: left to the player")
		World.talk.choices = 1
		Fire("QUEST_COMPLETE")
		expect(didKind("reward"), "one reward: taken")
	end,

	["never-touched NPCs and quests are left alone"] = function(BF)
		setup()
		BF:Set("auto.accept", true)
		BF:Set("auto.complete", true)
		local npc = next(BF.Data.autoNever.npcs)
		World.talk = { questID = 33, npcGuid = "Creature-0-1-0-12-" .. npc .. "-0000AB12CD" }
		Fire("QUEST_DETAIL")
		expect(not didKind("accept"), "a commendation officer's quest is not accepted")
	end,

	["shared quests turned down in battlegrounds, when chosen"] = function(BF)
		setup()
		BF:Set("auto.accept", true)
		BF:Set("auto.rejectInBattleground", true)
		UnitInBattleground = function() return true end
		World.talk = { questID = 33, npcGuid = "Player-1-00000002" }
		Fire("QUEST_DETAIL")
		expect(didKind("decline"), "declined")
		expect(World.printed[#World.printed]:find("Automatically rejected quest shared by player.", 1, true), "said")
	end,

	["a skipped breadcrumb is said; with the setting the quest is abandoned"] = function(BF)
		setup()
		-- A quest with a breadcrumb the player has not done.
		local target
		for id in BF:AllIDs("quests") do
			local q = BF:Quest(id)
			local b = q and q[BF.Q.breadcrumbs] and q[BF.Q.breadcrumbs][1]
			local bq = b and BF:Quest(b)
			if bq and BF.Player:RaceAllowed(bq[BF.Q.races]) and BF.Player:ClassAllowed(bq[BF.Q.classes]) and not bq[BF.Q.exclusiveTo] then
				target = id
				break
			end
		end
		expect(target, "a quest with a breadcrumb in the data")
		BF:Set("auto.abandonBreadcrumb", true)
		BF.Auto:CheckBreadcrumbs(target)
		local text = table.concat(World.printed, "\n")
		expect(text:find("without completing its breadcrumb quest", 1, true), "said")
		equal(didKind("abandon")[2], target, "abandoned")
	end,

	["announcements: an objective done is said to the party with a star and BookFinder's name"] = function(BF)
		setup()
		World.group = { "Bob Builder" }
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) })
		Fire("QUEST_LOG_UPDATE")
		Tick(1)
		local said = World.said[#World.said]
		expect(said, "said")
		equal(said[2], "PARTY", "to the party")
		expect(said[1]:find("^{rt1} BookFinder: Kobold Vermin slain: 10/10 for "), said[1])
	end,

	["announcements: nobody when chosen; own chat when chosen"] = function(BF)
		setup()
		World.group = { "Bob Builder" }
		BF:Set("announce.channel", "disabled")
		BF:Set("announce.self", true)
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) })
		Fire("QUEST_LOG_UPDATE")
		Tick(1)
		equal(#World.said, 0, "nothing to the party")
		expect(World.printed[#World.printed]:find("for", 1, true), "in the player's own chat")
	end,

	["announcements: other players' are hidden when chosen"] = function(BF)
		setup()
		local f = World.chatFilters.CHAT_MSG_PARTY[1]
		equal(f(nil, "CHAT_MSG_PARTY", "{rt1} Questie: Quest Accepted: [x]"), false, "shown by default")
		BF:Set("announce.quiet", true)
		equal(f(nil, "CHAT_MSG_PARTY", "{rt1} Questie: Quest Accepted: [x]"), true, "hidden")
		equal(f(nil, "CHAT_MSG_PARTY", "hello"), false, "plain chat stays")
	end,

	["an item that starts a quest is said to the player"] = function(BF)
		setup()
		local item
		for id in BF:AllIDs("items") do
			local row = BF:Item(id)
			if row and row[BF.I.startQuest] and row[BF.I.startQuest] > 0 then item = id break end
		end
		Fire("CHAT_MSG_LOOT", "You receive loot: |Hitem:" .. item .. "::|h[x]|h.", "Ada Lovelace", "", "", "Ada Lovelace")
		expect(World.printed[#World.printed]:find("which starts", 1, true), "said")
	end,

	["sounds: objective progress, objective done, quest done, each when chosen"] = function(BF)
		setup()
		BF:Set("sounds.objectiveProgress", true)
		BF:Set("sounds.questComplete", true)
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 4/10", 4, 10) })
		Fire("QUEST_LOG_UPDATE")
		Tick(2)
		equal(World.played[1] and World.played[1][1], 567482, "the progress sound")
		equal(World.played[1][2], "Master", "on the chosen channel")
		BF:Set("sounds.questCompleteChoice", "Zug Zug")
		World.questLog[1] = quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) })
		World.questLog[1].isComplete = 1
		Fire("QUEST_LOG_UPDATE")
		Tick(2)
		local last = World.played[#World.played]
		equal(last[1], 557827, "the chosen quest-done sound")
	end,

	["a Questie link in chat: clicked, the quest's tooltip"] = function(BF)
		setup()
		local handler = World.linkHandlers.questie
		expect(handler, "handled")
		equal(handler("questie:7:Player-1-00000002"), LinkProcessorResponse.Handled, "taken")
		local t = table.concat(ItemRefTooltip.lines, "\n")
		expect(t:find("Kobold Camp Cleanup", 1, true), "the title")
		expect(t:find("You are on this quest", 1, true), "where the player stands")
		expect(t:find("Kobold Vermin slain: 3/10", 1, true), "the progress")
		expect(t:find("Marshal McBride", 1, true), "started by")
		handler("questie:7:Player-1-00000002")
		expect(not ItemRefTooltip.shown, "clicked again: closed")
	end,

	["the minimap button: where to go; the setting hides it"] = function(BF)
		setup()
		local b = BookFinderMinimapButton
		expect(b.shown, "shown")
		b.scripts.OnClick(b, "LeftButton")
		local items = {}
		for _, r in ipairs(BookFinderDropdown1.rows) do if r.shown then items[#items + 1] = r.item.text end end
		equal(table.concat(items, ", "), "BookFinder, World Map, Quest Log, Library books, Nearest book, My Journey, Settings", "the menu")
		BF:Set("minimap.button", false)
		expect(not b.shown, "hidden")
		equal(AddonCompartmentFrame.registered[1].text, "BookFinder", "in the AddOns menu too")
	end,

	["commands: help, eligible, flex, tomap"] = function(BF)
		setup()
		SlashCmdList.BOOKFINDER("help")
		expect(table.concat(World.printed, "\n"):find("/bf tomap", 1, true), "the list")
		SlashCmdList.BOOKFINDER("eligible 3905")
		expect(World.printed[#World.printed]:find("A quest before it is not done", 1, true), "why not")
		SlashCmdList.BOOKFINDER("flex")
		expect(World.printed[#World.printed]:find("completed 1 quests", 1, true), "count")
		SlashCmdList.BOOKFINDER("tomap Marshal McBride")
		expect(BF.Search:IsShown("npc", 197), "on the map")
		SlashCmdList.BOOKFINDER("tomap reset")
		expect(not BF.Search:IsShown("npc", 197), "off")
		SlashCmdList.BOOKFINDER("")
		expect(BF.Panel.frame.shown, "no word: the settings")
	end,
}
