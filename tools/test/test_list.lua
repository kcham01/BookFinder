return {
	["quest list: zones, titles with levels, objectives, complete line"] = function(BF)
		World.questLog = {
			{ questID = 7, title = "Kobold Camp Cleanup", level = 2, zone = "Elwynn Forest",
				objectives = { { text = "Kobold Vermin slain: 4/10", type = "monster", numFulfilled = 4, numRequired = 10, finished = false } } },
			{ questID = 33, title = "Wolves Across the Border", level = 2, zone = "Elwynn Forest", isComplete = 1,
				objectives = { { text = "Tough Wolf Meat: 8/8", type = "item", numFulfilled = 8, numRequired = 8, finished = true } } },
		}
		Login()
		BookFinderQuestList:Show()
		BF.QuestList:Refresh()
		local texts = {}
		for _, c in ipairs(BookFinderQuestList.children) do end
		local function collect(f) for _, c in ipairs(f.children or {}) do if c.Text and c.shown then texts[#texts + 1] = c.Text.text end collect(c) end end
		collect(BookFinderQuestList)
		local all = table.concat(texts, "\n")
		expect(all:find("Elwynn Forest", 1, true), "zone heading: " .. all)
		expect(all:find("Kobold Camp Cleanup", 1, true), "title")
		expect(all:find("4/10", 1, true), "objective")
		expect(all:find("Quest Complete!", 1, true), "complete line")
	end,
}
