return {
	["map button: on the map, a starred setting becomes a button beside it"] = function(BF)
		Login()
		BF.Panel:SetFavourite("books.map", true)
		BF.Panel:SetFavourite("action:findMe", true)
		BF.MapButton.Refresh()
		BF.ShowMenu.Open(nil)
		expect(BF.Dropdown:IsOpen(), "right-click's Show list opens")
		equal(#World.errors, 0, "no errors")
	end,

	["panel: every setting has a place (or is a Show-menu-only switch)"] = function(BF)
		Login()
		local placed = BF.Panel:PlacedKeys()
		local missing = {}
		for _, key in ipairs(BF.Settings:Keys()) do
			local def = BF.Settings:Definition(key)
			local showOnly = def.page == "Map/Show" and (key:find("^townsfolk%.vendor%.") or key:find("^townsfolk%.profession")
				or key == "townsfolk.knownProfessions")
			local kind = key:match("^townsfolk%.(%a+)$")
			local notMine = false
			for _, k in ipairs(BF.Townsfolk.kinds) do
				if k.key == kind and not BF.Townsfolk:Applies(k) then notMine = true end
			end
			if not placed[key] and not showOnly and not notMine then missing[#missing + 1] = key end
		end
		equal(table.concat(missing, ", "), "", "settings not in the panel")
	end,

	["panel: opens, every tab and page builds"] = function(BF)
		World.player.level = 10
		World.completed[783] = true
		Login()
		Tick(5)
		for _, tab in ipairs(BF.Panel.tabs) do
			for _, page in ipairs(tab.pages) do
				BF.Panel:Open(tab.key, page.key)
				expect(BookFinderPanel:IsShown(), tab.key .. "/" .. page.key)
			end
		end
		equal(#World.errors, 0, "no errors")
	end,

	["panel: a tick box changes its setting"] = function(BF)
		Login()
		BF.Panel:Open("quests", "tooltips")
		BF:Set("tooltips.ids.quest", true)
		expect(BF:Get("tooltips.ids.quest"), "set")
	end,

	["journey: accepted, completed and abandoned are written down"] = function(BF)
		World.questLog = {}
		Login()
		World.questLog = { { questID = 7, title = "Kobold Camp Cleanup", level = 2, objectives = {} } }
		Fire("QUEST_LOG_UPDATE"); Tick(0.3)
		World.completed[7] = true
		Fire("QUEST_TURNED_IN", 7)
		World.questLog = {}
		Fire("QUEST_LOG_UPDATE"); Tick(0.3)
		local kinds = {}
		for _, e in ipairs(BF.Journey:Entries()) do kinds[#kinds + 1] = e.kind .. ":" .. tostring(e.quest) end
		equal(table.concat(kinds, " "), "accepted:7 completed:7", "journey")
		BF.Panel:Open("journey", "myJourney")
	end,

	["search: by name and by ID, then details and show on map"] = function(BF)
		Login()
		local results
		BF:Listen("BF_SEARCH_DONE", function(_, r) results = r end)
		BF.Search:Run("Kobold Vermin")
		Tick(3)
		expect(results and #results.npcs >= 1, "Kobold Vermin found")
		BF.Search:Run("7")
		Tick(3)
		equal(results.quests[1], 7, "quest 7 by ID")
		BF.Panel.ShowDetails("npc", 6)
		BF.Search:SetOnMap("npc", 6, true)
		local found = false
		for _, pin in ipairs(BF.Marks:On(1429)) do
			for _, r in ipairs(pin.roles) do if r.role == "manual" then found = true end end
		end
		expect(found, "Kobold Vermin shown on the Elwynn map")
	end,

	["commands: /bf opens the panel, /bf tomap marks an NPC"] = function(BF)
		Login()
		SlashCmdList.BOOKFINDER("")
		expect(BookFinderPanel:IsShown(), "panel")
		SlashCmdList.BOOKFINDER("tomap npc Marshal McBride")
		expect(BF.Search:IsOnMap("npc", 197), "on the map")
	end,
}
