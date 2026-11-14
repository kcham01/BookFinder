local function quest(id, title, objectives, isComplete, zone)
	return { questID = id, title = title, level = 2, zone = zone, isComplete = isComplete, objectives = objectives or {} }
end

local function obj(text, have, need, kind)
	return { text = text, type = kind or "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

return {
	["log: reads quests with their zone headings and objectives"] = function(BF)
		World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }) }
		Login()
		local q = BF.Log:Get(7)
		equal(q.title, "Kobold Camp Cleanup", "title")
		equal(q.header, "Elwynn Forest", "heading")
		equal(q.objectives[1].have, 3, "progress")
		expect(not BF.Log:IsComplete(7), "not complete")
	end,

	["log: accepted, progress, complete, turned in, abandoned"] = function(BF)
		World.questLog = {}
		Login()
		local seen = {}
		for _, m in ipairs({ "BF_QUEST_ACCEPTED", "BF_QUEST_PROGRESS", "BF_QUEST_COMPLETE_CHANGED", "BF_QUEST_REMOVED" }) do
			BF:Listen(m, function(_, id, a) seen[#seen + 1] = m:sub(10) .. ":" .. id .. (a ~= nil and (":" .. tostring(type(a) == "table" and a.have or a)) or "") end)
		end
		World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 0/10", 0, 10) }), quest(33, "Wolves Across the Border", { obj("Tough Wolf Meat: 0/8", 0, 8, "item") }) }
		Fire("QUEST_LOG_UPDATE"); Tick(0.2)
		World.questLog[1].objectives[1] = obj("Kobold Vermin slain: 10/10", 10, 10)
		World.questLog[1].isComplete = 1
		Fire("QUEST_LOG_UPDATE"); Tick(0.2)
		-- 7 is handed in; 33 is abandoned.
		World.completed[7] = true
		Fire("QUEST_TURNED_IN", 7, 170, 0)
		World.questLog = {}
		Fire("QUEST_LOG_UPDATE"); Tick(0.2)
		table.sort(seen)
		equal(table.concat(seen, " "), "ACCEPTED:33 ACCEPTED:7 COMPLETE_CHANGED:7:1 PROGRESS:7:1 REMOVED:33:false REMOVED:7:true", "messages")
	end,

	["log: a zone change's false zeroes are not believed"] = function(BF)
		World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 10/10", 10, 10) }, 1) }
		Login()
		Fire("PLAYER_ENTERING_WORLD", false, false)
		World.questLog[1].objectives[1] = obj("Kobold Vermin slain: 0/10", 0, 10)
		World.questLog[1].isComplete = nil
		Fire("QUEST_LOG_UPDATE"); Tick(0.2)
		expect(BF.Log:IsComplete(7), "still complete during the transition")
		World.questLog[1].objectives[1] = obj("Kobold Vermin slain: 10/10", 10, 10)
		World.questLog[1].isComplete = 1
		Tick(1.5)
		expect(BF.Log:IsComplete(7), "complete after")
	end,

	["log: a quest with nothing to do is ready to hand in"] = function(BF)
		World.questLog = { quest(8, "A Rogue's Deal", {}) }
		Login()
		expect(BF.Log:IsComplete(8), "letter quest complete")
	end,

	["events: holidays by date, Darkmoon Faire by week"] = function(BF)
		-- 2026-11-02 is a Monday; the first Friday of November 2026 is the 6th, so the faire opens Monday the 9th.
		World.date = { year = 2026, month = 11, monthDay = 10, hour = 12, minute = 0 }
		Login()
		equal(BF.Events.active["Darkmoon Faire"], "elwynn", "faire in Elwynn in an odd month")
		World.errors = World.errors -- (no errors expected)
	end,

	["events: a holiday crossing the new year"] = function(BF)
		World.date = { year = 2027, month = 1, monthDay = 1, hour = 12, minute = 0 }
		Login()
		expect(BF.Events.active["Winter Veil"], "Winter Veil runs on 1 January")
		World.date = { year = 2026, month = 7, monthDay = 1, hour = 12, minute = 0 }
	end,

	["rules: Northshire for a level 1 human warrior"] = function(BF)
		World.player.level = 1
		Login()
		local R = BF.Rules
		expect(R:IsAvailable(783), "A Threat Within")
		equal(R:Blocker(7), "prerequisite", "Kobold Camp Cleanup needs A Threat Within")
		expect(R:IsAvailable(33), "Wolves Across the Border")
		equal(R:Blocker(4641), "race", "a Horde quest")
		equal(R:Blocker(18), "level", "Brotherhood of Thieves needs level 2")
	end,

	["rules: prerequisites, breadcrumbs and chains follow the log"] = function(BF)
		World.player.level = 2
		World.completed[783] = true
		World.questLog = { quest(33, "Wolves Across the Border", { obj("Tough Wolf Meat: 0/8", 0, 8, "item") }) }
		Login()
		local R = BF.Rules
		expect(R:IsAvailable(7), "Kobold Camp Cleanup after A Threat Within")
		equal(R:Blocker(5261), "breadcrumb", "Eagan Peltskinner leads to a quest already taken")
		equal(R:Blocker(783), "completed", "done")
		equal(R:Blocker(33), "active", "in the log")
	end,

	["rules: low-level quests follow the setting"] = function(BF)
		World.player.level = 20
		World.greenRange = 8
		Login()
		local R = BF.Rules
		expect(R:IsTrivial(783), "a level 1 quest is grey at 20")
		expect(not R:IsShown(783), "hidden by default")
		BF:Set("quests.lowLevel", "all")
		expect(R:IsShown(783), "shown with 'all'")
		BF:Set("quests.lowLevel", "range")
		BF:Set("quests.levelMin", 1)
		BF:Set("quests.levelMax", 3)
		expect(R:IsShown(783), "shown in range 1-3")
		expect(not R:IsShown(33) or R:Level(33) <= 3, "range respected")
	end,

	["marks: a giver, a turn-in and objectives on the right map"] = function(BF)
		World.player.level = 2
		World.completed[783] = true
		World.questLog = {
			quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 0/10", 0, 10) }),
			quest(5261, "Eagan Peltskinner", {}),
		}
		Login()
		Tick(5) -- the available quests are worked out a slice per frame
		local roles = {}
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, r in ipairs(pin.roles) do
				if r.quest then roles[r.role .. ":" .. r.quest] = (roles[r.role .. ":" .. r.quest] or 0) + 1 end
			end
		end
		expect(roles["available:33"], "Wolves Across the Border offered by Eagan")
		expect(roles["complete:5261"], "Eagan Peltskinner handed in to Eagan")
		expect(roles["objective:7"] and roles["objective:7"] >= 1, "Kobold Vermin marked")
		expect(not roles["available:7"], "a quest in the log is not offered")
		-- Kobold Vermin live in a few packs: merged, far fewer pins than spawns.
		local npc = BF:Npc(6)
		local spawnCount = 0
		for _, pts in pairs(npc[BF.N.spawns]) do spawnCount = spawnCount + #pts end
		expect(roles["objective:7"] < spawnCount, ("packs merged (%d pins for %d spawns)"):format(roles["objective:7"], spawnCount))
	end,
}
