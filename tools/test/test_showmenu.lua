-- The map's Show dropdown: BookFinder's entries in the game's map filter menu.

local TAG = "MENU_WORLD_MAP_TRACKING"

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	Login()
end

local function labels(rows)
	local list = {}
	for _, r in ipairs(rows) do list[#list + 1] = (r.kind == "divider" and "---") or r.text end
	return list
end

local function row(rows, text)
	for _, r in ipairs(rows) do if r.text == text then return r end end
end

return {
	["the game's own entries are gone; Questie's order, one flat list"] = function()
		setup()
		local root = World.OpenShowButton()
		local l = labels(root.rows)
		equal(l[1], "Show:", "the menu's heading")
		equal(l[2], "Repair", "Questie's first, nothing of the game's above it")
		equal(l[3], "Innkeeper", "then Innkeeper")
		for _, game in ipairs({ "Quest Objectives", "Show Quest Levels", "Quest Difficulty Color", "Low-Level Quests", "Tracked Items" }) do
			expect(not row(root.rows, game), "the game's entry gone: " .. game)
		end
		local want = { "Repair", "Innkeeper", "Mailbox", "Class Trainer", "Weapon Master", "Auctioneer", "Banker",
			"Flight Master", "Battlemaster", "Barber", "Spirit Healer", "Moonwell", "Meeting Stones", "Stable Master",
			"Rare mobs", "Available Quest", "Trivial Quest", "Objective", "Profession Trainers", "Vendor" }
		local i = 1
		for _, text in ipairs(l) do if text == want[i] then i = i + 1 end end
		equal(i, #want + 1, "every entry in order (stopped at " .. tostring(want[i]) .. ")")
	end,

	["each item once, and only for this character"] = function()
		setup()
		local seen = {}
		for _, r in ipairs(World.OpenShowButton().rows) do
			if r.text then
				expect(not seen[r.text], "twice: " .. r.text)
				seen[r.text] = true
			end
		end
		expect(not seen["Portal Trainer"], "a warrior sees no portal trainers")
		expect(not seen["Advanced Search"] and not seen["My Journey"], "journey windows stay out")
	end,

	["nothing for what is not built yet"] = function()
		setup()
		local seen = {}
		for _, r in ipairs(World.OpenShowButton().rows) do if r.text then seen[r.text] = true end end
		expect(not seen["Boats"], "no boats yet")
		-- Dungeon quests exist already: the Dungeons section shows, with its heading.
		expect(seen["Dungeons"] and seen["Dungeon quests"], "the Dungeons section")
	end,

	["a tick box follows and changes its setting, the menu stays open"] = function(BF)
		setup()
		local root = World.OpenShowButton()
		local r = row(root.rows, "Mailbox")
		equal(r.isSelected(), true, "mailboxes on by default")
		r.setSelected()
		equal(BF:Get("townsfolk.mailbox"), false, "off")
		equal(r.response, MenuResponse.Refresh, "stays open")
	end,

	["Trivial Quest switches the low-level quests"] = function(BF)
		setup()
		local r = row(World.OpenShowButton().rows, "Trivial Quest")
		equal(r.isSelected(), false, "hidden by default")
		r.setSelected()
		equal(BF:Get("quests.lowLevel"), "all", "shown")
		r.setSelected()
		equal(BF:Get("quests.lowLevel"), "hide", "hidden again")
	end,

	["submenus: professions with Known Professions first, vendors"] = function()
		setup()
		local root = World.OpenShowButton()
		local p = row(root.rows, "Profession Trainers")
		equal(p.kind, "button", "a submenu")
		equal(p.rows[1].text, "Known Professions", "first")
		expect(#p.rows > 5, "the professions")
		local v = row(root.rows, "Vendor")
		expect(row(v.rows, "Food") and row(v.rows, "Ammo"), "food and ammo")
		expect(not row(v.rows, "Poisons"), "poisons for rogues only")
	end,

	["each row carries its icon at the right"] = function()
		setup()
		local r = row(World.OpenShowButton().rows, "Innkeeper")
		local textures = World.InitRow(r)
		equal(#textures, 1, "one icon")
		equal(textures[1].texture, "Interface\\Minimap\\Tracking\\Innkeeper", "the innkeeper's")
		equal(textures[1].points[1][1], "RIGHT", "at the right")
	end,

	["the Show button, not the floor picker; the reset badge hidden"] = function(BF)
		setup()
		equal(BF.ShowMenu.button, WorldMapFrame.overlayFrames[2], "the tracking options button")
		expect(WorldMapFrame.overlayFrames[1].generator == nil, "the floor picker untouched")
		local reset = WorldMapFrame.overlayFrames[2].ResetButton
		expect(not reset.shown, "no reset badge")
		reset:Show()
		expect(not reset.shown, "and it stays away")
	end,

	["no Show button to be found: the menu changed by its tag"] = function()
		WorldMapTrackingOptionsButtonMixin = { OnLoad = function() end } -- a client where no overlay frame is the Show button
		setup()
		local root = World.OpenMenu(TAG)
		local l = labels(root.rows)
		equal(l[1], "Repair", "the game's rows emptied, ours in")
	end,

	["the quest log's gear menu is gone, and stays gone"] = function(BF)
		setup()
		local gear = QuestMapFrame.QuestsFrame.SettingsDropdown
		expect(not gear.shown, "hidden")
		gear:Show()
		expect(not gear.shown, "stays hidden")
		expect(QuestMapFrame.QuestsFrame.SearchBox.shown, "the search box stays")
	end,

	["the gear found without its usual name"] = function(BF)
		local q = QuestMapFrame.QuestsFrame
		q.FilterSettings, q.SettingsDropdown = q.SettingsDropdown, nil
		setup()
		expect(not q.FilterSettings.shown, "found by its parent's key")
		expect(q.SearchBox.shown, "the search box stays")
	end,
}
