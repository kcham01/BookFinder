-- The settings panel: sections down its right side, pages along its top, every setting once.

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	Login()
end

local function labels(tabs, field)
	local list = {}
	for _, t in ipairs(tabs) do if t.shown then list[#list + 1] = t[field].label end end
	return table.concat(list, ", ")
end

local function control(BF, key)
	for _, c in ipairs(BF.Panel:Controls()) do if c.def.key == key then return c end end
end

-- Every Lua file of the add-on (not the generated data), as one text.
local function source()
	local text = {}
	local p = io.popen("find BookFinder -name '*.lua' -not -path '*/Data/*'")
	for f in p:lines() do
		for line in io.lines(f) do
			if not line:match("^%s*def%(") and not line:match("^%s*S:Define%(") and not line:match("^local PENDING") then
				text[#text + 1] = line
			end
		end
	end
	p:close()
	return table.concat(text, "\n")
end

return {
	["/bf opens it: Map, Quests, Books, Journey down the side"] = function(BF)
		setup()
		SlashCmdList.BOOKFINDER("")
		local frame = BF.Panel.frame
		expect(frame and frame.shown, "shown")
		equal(labels(frame.sideTabs, "section"), "Map, Quests, Books, Journey", "the side tabs")
		expect(UISpecialFrames[1] == "BookFinderPanel", "Escape closes it")
		SlashCmdList.BOOKFINDER("")
		expect(not frame.shown, "toggled shut")
	end,

	["Quests' pages along the top; pages of things not built yet are left out"] = function(BF)
		setup()
		BF.Panel:Show("quests")
		equal(labels(BF.Panel.frame.topTabs, "page"), "Map, Look, Tooltips, Quest list, Automation, Advanced", "the top tabs")
		BF.Panel:Show("map")
		equal(labels(BF.Panel.frame.topTabs, "page"), "Look, More, Profiles", "the map's (On the map comes with the map)")
	end,

	["a tick box changes its setting, and follows it"] = function(BF)
		setup()
		BF.Panel:Show("quests", "map")
		local c = control(BF, "quests.repeatable")
		expect(c, "the Repeatable quests tick box")
		c.check:SetChecked(false)
		c.check.scripts.OnClick(c.check)
		equal(BF:Get("quests.repeatable"), false, "set")
		BF:Set("quests.repeatable", true)
		equal(c.check:GetChecked(), true, "follows the setting")
	end,

	["a slider sets a snapped value; numbers grey out when their style is not chosen"] = function(BF)
		setup()
		BF.Panel:Show("quests", "map")
		local c = control(BF, "quests.levelMin")
		expect(c.slider.enabled == false, "greyed until the level range style")
		BF:Set("quests.lowLevel", "range")
		expect(c.slider.enabled ~= false, "usable now")
		c.slider.scripts.OnValueChanged(c.slider, 12.4)
		equal(BF:Get("quests.levelMin"), 12, "snapped to whole levels")
	end,

	["a colour swatch opens the game's colour picker"] = function(BF)
		setup()
		BF.Panel:Show("quests", "look")
		local c = control(BF, "paths.color")
		c.swatch.scripts.OnClick(c.swatch)
		World.pickedColor = { 0, 1, 0, 0.5 }
		World.colorPicker.swatchFunc()
		equal(BF:Get("paths.color")[2], 1, "green")
		World.colorPicker.cancelFunc()
		equal(BF:Get("paths.color")[2], 0.72, "cancel puts it back")
	end,

	["Defaults puts the page's settings back"] = function(BF)
		setup()
		BF.Panel:Show("books")
		BF:Set("books.hideCollected", false)
		BF:Set("quests.repeatable", false)
		BF.Panel:ResetPage()
		equal(BF:Get("books.hideCollected"), true, "the page's own")
		equal(BF:Get("quests.repeatable"), false, "another page's untouched")
	end,

	["every setting is on exactly one page, except the Show dropdown's and those not built yet"] = function(BF)
		setup()
		local seen = {}
		for _, s in ipairs(BF.Panel.sections) do
			for _, p in ipairs(s.pages) do
				for _, def in ipairs(BF.Panel:SettingsOf(p)) do
					expect(not seen[def.key], "twice: " .. def.key)
					seen[def.key] = true
				end
			end
		end
		for _, key in ipairs(BF.Settings:Keys()) do
			local def = BF.Settings:Definition(key)
			if def.page ~= "Map/Show" and not def.pending then expect(seen[key], "on no page: " .. key) end
		end
	end,

	["pending settings are honest: none is read yet, every other one is"] = function(BF)
		setup()
		local code = source()
		for _, key in ipairs(BF.Settings:Keys()) do
			local def = BF.Settings:Definition(key)
			local read = code:find('"' .. key .. '"', 1, true)
				or (key:match("^icons%.scale%.") and code:find('"icons.scale." ..', 1, true))
				or (({ ["icons.slay"] = 1, ["icons.loot"] = 1, ["icons.object"] = 1, ["icons.event"] = 1, ["icons.talk"] = 1,
					["icons.interact"] = 1 })[key] and code:find('"icons." .. kind', 1, true))
				or (key:match("^townsfolk%.") and code:find('"townsfolk." ..', 1, true))
			if def.pending then
				expect(not read, "pending but already read: " .. key)
			else
				expect(read, "declared and shown, but nothing reads it: " .. key)
			end
		end
	end,

	["the game's AddOns settings list BookFinder, with a button that opens the panel"] = function(BF)
		setup()
		local category = World.settingsCategories[1]
		equal(category and category.name, "BookFinder", "listed")
		local button
		for _, c in ipairs(category.frame.children) do if c.kind == "Button" then button = c end end
		button.scripts.OnClick(button)
		expect(BF.Panel.frame.shown, "opened")
	end,

	["the map's BookFinder button opens it"] = function(BF)
		setup()
		BookFinderMapButton.scripts.OnClick(BookFinderMapButton)
		expect(BF.Panel.frame.shown, "opened")
	end,

	["a modern client: the stepper slider; choices in the one dropdown"] = function(BF)
		World.knownTemplates = { MinimalSliderWithSteppersTemplate = true, WowStyle1DropdownTemplate = true,
			PortraitFrameTemplate = true }
		setup()
		BF.Panel:Show("quests", "map")
		equal(BF.Panel.frame.title, "BookFinder test", "the window's title")
		local s = control(BF, "quests.lowLevelOffset")
		equal(s.slider.template, "MinimalSliderWithSteppersTemplate", "the stepper slider")
		equal(s.slider.value, 7, "at its value")
		s.slider:SetValue(9.6)
		equal(BF:Get("quests.lowLevelOffset"), 10, "moved, snapped")
		local d = control(BF, "quests.lowLevel")
		d.button.scripts.OnClick(d.button)
		local row = BookFinderDropdown1.rows[2]
		equal(row.item.text, "Show all", "its choices, in words, in BookFinder's dropdown")
		row.scripts.OnClick(row)
		expect(not BookFinderDropdown1.shown, "a choice closes it")
		equal(BF:Get("quests.lowLevel"), "all", "chosen")
	end,

	["profiles: a new one, back to Default, copy, delete"] = function(BF)
		setup()
		BF.Panel:Show("map", "profiles")
		BF:Set("quests.repeatable", false)
		BF.ProfilesPage:New("  Alts  ")
		equal(BF.Settings:ProfileName(), "Alts", "made and used, name trimmed")
		equal(BF:Get("quests.repeatable"), true, "a fresh profile has the defaults")
		BF.Settings:CopyProfile("Default")
		equal(BF:Get("quests.repeatable"), false, "copied in")
		BF.Settings:UseProfile("Default")
		expect(BF.Settings:DeleteProfile("Alts"), "deleted")
		equal(#BF.Settings:Profiles(), 1, "only Default left")
	end,
}
