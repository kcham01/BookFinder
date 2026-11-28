-- The map's Show dropdown: the map's Show button opens BookFinder's dropdown, holding only BookFinder's entries.

local TAG = "MENU_WORLD_MAP_TRACKING"

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	Login()
end

-- Presses the Show button; returns the dropdown's shown rows' items.
local function press()
	local button = BookFinderShowButton
	button.scripts.OnClick(button, "LeftButton")
	local items = {}
	for _, row in ipairs(BookFinderDropdown1.rows) do if row.shown then items[#items + 1] = row.item end end
	return items, button
end

local function labels(items)
	local list = {}
	for _, it in ipairs(items) do list[#list + 1] = it.divider and "---" or it.text end
	return list
end

local function find(items, text)
	for _, it in ipairs(items) do if it.text == text then return it end end
end

local function rowOf(text)
	for _, row in ipairs(BookFinderDropdown1.rows) do if row.shown and row.item.text == text then return row end end
end

return {
	["the Show button opens BookFinder's dropdown: Questie's order, none of the game's entries"] = function()
		setup()
		local items = press()
		expect(BookFinderDropdown1.shown, "BookFinder's dropdown open")
		local l = labels(items)
		equal(l[1], "Show:", "its heading")
		equal(l[2], "Repair", "Questie's first")
		local want = { "Repair", "Innkeeper", "Mailbox", "Class Trainer", "Weapon Master", "Auctioneer", "Banker",
			"Flight Master", "Battlemaster", "Barber", "Spirit Healer", "Moonwell", "Meeting Stones", "Stable Master",
			"Rare mobs", "Available Quest", "Trivial Quest", "Objective", "Profession Trainers", "Vendor" }
		local i = 1
		for _, text in ipairs(l) do if text == want[i] then i = i + 1 end end
		equal(i, #want + 1, "every entry in order (stopped at " .. tostring(want[i]) .. ")")
		for _, game in ipairs({ "Quest Objectives", "Show Quest Levels", "Quest Difficulty Color", "Low-Level Quests", "Tracked Items" }) do
			expect(not find(items, game), "the game's entry gone: " .. game)
		end
	end,

	["each item once, only for this character, nothing for what is not built"] = function()
		setup()
		local seen = {}
		for _, it in ipairs(press()) do
			if it.text then
				expect(not seen[it.text], "twice: " .. it.text)
				seen[it.text] = true
			end
		end
		expect(not seen["Portal Trainer"], "a warrior sees no portal trainers")
		expect(not seen["Advanced Search"] and not seen["My Journey"], "journey windows stay out")
		expect(not seen["Boats"], "no boats yet")
		expect(seen["Dungeons"] and seen["Dungeon quests"], "the Dungeons section")
	end,

	["a tick box follows and changes its setting, the menu stays open"] = function(BF)
		setup()
		press()
		local row = rowOf("Mailbox")
		equal(row.check.texCoord and row.check.texCoord[1], 0, "ticked (mailboxes on by default)")
		row.scripts.OnClick(row)
		equal(BF:Get("townsfolk.mailbox"), false, "off")
		expect(BookFinderDropdown1.shown, "stays open")
		equal(row.check.texCoord[1], 0.5, "unticked")
	end,

	["Trivial Quest switches the low-level quests"] = function(BF)
		setup()
		press()
		local row = rowOf("Trivial Quest")
		row.scripts.OnClick(row)
		equal(BF:Get("quests.lowLevel"), "all", "shown")
		row.scripts.OnClick(row)
		equal(BF:Get("quests.lowLevel"), "hide", "hidden again")
	end,

	["submenus open beside their row: professions, vendors"] = function()
		setup()
		press()
		local row = rowOf("Profession Trainers")
		row.scripts.OnEnter(row)
		expect(BookFinderDropdown2.shown, "the submenu")
		equal(BookFinderDropdown2.rows[1].item.text, "Known Professions", "first")
		rowOf("Vendor").scripts.OnEnter(rowOf("Vendor"))
		local vendors = {}
		for _, r in ipairs(BookFinderDropdown2.rows) do if r.shown then vendors[r.item.text] = true end end
		expect(vendors.Food and vendors.Ammo and not vendors.Poisons, "food and ammo; poisons for rogues only")
	end,

	["each row carries its icon at the right"] = function()
		setup()
		press()
		local row = rowOf("Innkeeper")
		expect(row.icon.shown, "an icon")
		equal(row.icon.texture, "Interface\\Minimap\\Tracking\\Innkeeper", "the innkeeper's")
		equal(row.icon.points[#row.icon.points][1], "RIGHT", "at the right")
	end,

	["pressing again closes it; so does a click elsewhere"] = function()
		setup()
		local _, button = press()
		button.scripts.OnClick(button, "LeftButton")
		expect(not BookFinderDropdown1.shown, "closed by the button")
		press()
		Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
		expect(not BookFinderDropdown1.shown, "closed by a click elsewhere")
	end,

	["the Show button, not the floor picker; covered by BookFinder's; the reset badge hidden"] = function(BF)
		setup()
		local game = WorldMapFrame.overlayFrames[2]
		equal(BF.ShowMenu.button, game, "the tracking options button")
		equal(BookFinderShowButton.parent, game, "the cover lies on it")
		expect(BookFinderShowButton:GetFrameLevel() > game:GetFrameLevel(), "above it")
		expect(not WorldMapFrame.overlayFrames[1].scripts.OnMouseDown, "the floor picker untouched")
		local reset = game.ResetButton
		expect(not reset.shown, "no reset badge")
		reset:Show()
		expect(not reset.shown, "and it stays away")
	end,

	["found by its menu's tag when its mixin's methods don't match (as in the owner's test)"] = function(BF)
		WorldMapTrackingOptionsButtonMixin = { OnLoad = function() end, OnMouseDown = function() end }
		WorldMapFrame.overlayFrames[2].OnLoad = function() end
		setup()
		equal(BF.ShowMenu.button, WorldMapFrame.overlayFrames[2], "found by the tag")
		local items = press()
		expect(BookFinderDropdown1.shown and #items > 5, "BookFinder's dropdown")
	end,

	["not found at all: the game's menu, when it opens, gives way to BookFinder's"] = function(BF)
		WorldMapTrackingOptionsButtonMixin = { OnLoad = function() end }
		local game = WorldMapFrame.overlayFrames[2]
		game.OnLoad, game.generator = function() end, nil
		setup()
		expect(not BF.ShowMenu.cover, "not found at login")
		local root = World.OpenMenu(TAG, game)
		equal(#root.rows, 0, "the game's rows emptied")
		Tick(0.1)
		expect(World.menusClosed, "the game's menu closed")
		expect(BookFinderDropdown1.shown, "BookFinder's dropdown open in its place")
		equal(BF.ShowMenu.button, game, "and the button covered from now on")
	end,

	["the quest log's gear menu is gone, and stays gone"] = function()
		setup()
		local gear = QuestMapFrame.QuestsFrame.SettingsDropdown
		expect(not gear.shown, "hidden")
		gear:Show()
		expect(not gear.shown, "stays hidden")
		expect(QuestMapFrame.QuestsFrame.SearchBox.shown, "the search box stays")
	end,

	["the gear found without its usual name"] = function()
		local q = QuestMapFrame.QuestsFrame
		q.FilterSettings, q.SettingsDropdown = q.SettingsDropdown, nil
		setup()
		expect(not q.FilterSettings.shown, "found by its parent's key")
		expect(q.SearchBox.shown, "the search box stays")
	end,
}
