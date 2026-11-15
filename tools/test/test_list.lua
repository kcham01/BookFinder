return {
	["tracker: on the screen, Questie's way (zones, [lvl] titles, '0/1 Name' objectives, complete line)"] = function(BF)
		World.questLog = {
			{ questID = 7, title = "Kobold Camp Cleanup", level = 2, zone = "Elwynn Forest",
				objectives = { { text = "Kobold Vermin slain: 4/10", type = "monster", numFulfilled = 4, numRequired = 10, finished = false } } },
			{ questID = 33, title = "Wolves Across the Border", level = 2, zone = "Elwynn Forest", isComplete = 1,
				objectives = { { text = "Tough Wolf Meat: 8/8", type = "item", numFulfilled = 8, numRequired = 8, finished = true } } },
		}
		World.watched = { [7] = true, [33] = true }
		C_QuestLog.GetQuestWatchType = function(id) return World.watched[id] and 0 or nil end
		Login()
		expect(BookFinderTracker.parent == UIParent, "on the screen")
		BookFinderTracker.width = 290
		BF.QuestList:Refresh()
		local texts = {}
		local function collect(f) for _, c in ipairs(f.children or {}) do if c.Text and c.shown then texts[#texts + 1] = c.Text.text end collect(c) end end
		collect(BookFinderTracker)
		local all = table.concat(texts, "\n")
		expect(all:find("Elwynn Forest", 1, true), "zone: " .. all)
		expect(all:find("Kobold Camp Cleanup", 1, true), "title")
		expect(all:find("4/10 Kobold Vermin slain", 1, true), "objective written Questie's way")
		expect(all:find("Quest Complete!", 1, true), "complete line")
	end,
}
