-- The quest list in the map's Quests panel.

local function quest(id, title, objectives, isComplete, zone)
	return { questID = id, title = title, level = 2, isComplete = isComplete, objectives = objectives or {}, zone = zone }
end
local function obj(text, have, need, kind)
	return { text = text, type = kind or "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

local function setup()
	World.player.level = 3
	World.completed[783] = true
	World.questLog = {
		quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }, nil, "Elwynn Forest"),
		quest(5261, "Eagan Peltskinner", {}, nil, "Elwynn Forest"),
		quest(18, "Brotherhood of Thieves", { obj("Red Burlap Bandana: 2/12", 2, 12, "item") }, nil, "Northshire"),
	}
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	Tick(5)
	WorldMapFrame:Show()
	QuestScrollFrame:Show()
	BookFinderQuestList:Show()
end

local function shownRows()
	local list = {}
	local content = BookFinderQuestList.children[#BookFinderQuestList.children]
	for _, r in ipairs(content.children) do
		if r.kind and r.shown then list[#list + 1] = r end
	end
	return list
end

local function texts()
	local t = {}
	for _, r in ipairs(shownRows()) do t[#t + 1] = r.text.text end
	return t
end

local function rowFor(fragment)
	for _, r in ipairs(shownRows()) do if r.text.text and r.text.text:find(fragment, 1, true) then return r end end
end

return {
	["zones, then each quest with its level, its objectives with progress, a finished one ready"] = function(BF)
		setup()
		BF.QuestList:Refresh()
		local t = table.concat(texts(), "\n")
		expect(t:find("Elwynn Forest", 1, true) and t:find("Northshire", 1, true), "zone headings")
		expect(t:find("[2] Kobold Camp Cleanup", 1, true), "title with level")
		expect(t:find("- Kobold Vermin slain: 3/10", 1, true), "objective")
		expect(t:find("- Ready for turn-in", 1, true), "the letter is ready to hand in")
	end,

	["the game's own list and the on-screen tracker are hidden"] = function()
		setup()
		expect(not QuestScrollFrame.Contents.shown, "the game's rows")
		expect(not ObjectiveTrackerFrame.shown, "nothing on screen")
		ObjectiveTrackerFrame:Show()
		expect(not ObjectiveTrackerFrame.shown, "and it stays away")
		expect(QuestScrollFrame.SearchBox.shown, "the search box stays")
	end,

	["a zone folds and unfolds"] = function(BF)
		setup()
		BF.QuestList:Refresh()
		local zone = rowFor("Elwynn Forest")
		zone.scripts.OnClick(zone, "LeftButton")
		expect(not rowFor("Kobold Camp Cleanup"), "folded")
		rowFor("Elwynn Forest").scripts.OnClick(rowFor("Elwynn Forest"), "LeftButton")
		expect(rowFor("Kobold Camp Cleanup"), "open again")
	end,

	["the search box narrows the list"] = function(BF)
		setup()
		local box = QuestScrollFrame.SearchBox
		box.text = "bandana"
		box.scripts.OnTextChanged(box)
		local t = table.concat(texts(), "\n")
		expect(t:find("Brotherhood of Thieves", 1, true), "the bandana quest")
		expect(not t:find("Kobold Camp Cleanup", 1, true), "not the kobolds")
	end,

	["clicks: open, map pin, untrack; right-click menu"] = function(BF)
		setup()
		BF.QuestList:Refresh()
		local r = rowFor("Kobold Camp Cleanup")
		r.scripts.OnClick(r, "LeftButton")
		equal(World.openedQuest, 7, "opened")
		World.ctrl = true
		r.scripts.OnClick(r, "LeftButton")
		World.ctrl = false
		expect(World.waypoint, "map pin set")
		World.watched[7] = true
		World.shift = true
		r.scripts.OnClick(rowFor("Kobold Camp Cleanup"), "LeftButton")
		World.shift = false
		expect(not World.watched[7], "untracked")
		r = rowFor("Kobold Camp Cleanup")
		r.scripts.OnClick(r, "RightButton")
		local items = {}
		for _, row in ipairs(BookFinderDropdown1.rows) do if row.shown then items[#items + 1] = row.item.text end end
		local menu = table.concat(items, ", ")
		expect(menu:find("Focus", 1, true) and menu:find("Show on map", 1, true) and menu:find("Set the map pin", 1, true), menu)
	end,

	["focus dims the other quests"] = function(BF)
		setup()
		BF.QuestList:ToggleFocus(7)
		equal(rowFor("Kobold Camp Cleanup").alpha, 1, "the focused quest")
		equal(rowFor("Brotherhood of Thieves").alpha, 0.5, "the others dimmed")
	end,

	["settings: hide finished quests, sort by level, objective colours"] = function(BF)
		setup()
		BF:Set("list.showComplete", false)
		Tick(1)
		expect(not rowFor("Eagan Peltskinner"), "the finished letter gone")
		BF:Set("list.sort", "byLevel")
		Tick(1)
		expect(not rowFor("Elwynn Forest"), "no zone headings when sorted by level")
		BF:Set("list.objectiveColors", "redToGreen")
		Tick(1)
		local c = rowFor("Kobold Vermin slain").text.color
		expect(c[1] == 1 and c[2] < 1, "red-ish at 3 of 10")
	end,

	["auto-track a quest when it is accepted"] = function(BF)
		setup()
		table.insert(World.questLog, quest(33, "Wolves Across the Border", { obj("Tough Wolf Meat: 0/8", 0, 8, "item") }))
		Fire("QUEST_ACCEPTED", 33)
		Tick(1)
		expect(World.watched[33], "tracked")
	end,
}
