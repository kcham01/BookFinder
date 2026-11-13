-- BookFinder: loaded last. What makes the three parts one addon, beyond the public APIs they already talk through
-- (OpenMapAPI, ShortestPathForever.API):
--   * the one settings window (Namespaces.lua makes it): its Library books page, its front page, and adding it to
--     the game's AddOns list once every page is in
--   * one minimap button and broker launcher for everything (Books' and OpenMap's own stay off)
--   * one addon-compartment entry, and /bookfinder
--   * Shortest Path's map marks as switches in OpenMap's map menu, beside the Books switches
--   * a login note when a standalone copy took a part's place
local ADDON, root = ...
local public = root.public
local OM, SPF, BOOKS = root.OpenMap, root.SPF, root.Books

local PREFIX = "|cff33ff99BookFinder|r: "
local ICON = "Interface\\AddOns\\" .. ADDON .. "\\OpenMap\\Media\\Textures\\OpenMapIconRound"
local function say(text) print(PREFIX .. text) end
local function BL(text) return BOOKS.L and BOOKS.L[text] or text end    -- (Books' translations, where it has one)

-- What each part offers, when it runs (here, or as its standalone addon) ----------------------------------------
local function openMap()
	if InCombatLockdown() and not (WorldMapFrame and WorldMapFrame:IsShown()) then return false end
	if ToggleWorldMap then ToggleWorldMap() return true end
end
local function bookList()
	if public.OpenBooks and public.OpenBooks() then return true end
	if BOOKS.ToggleOptions then BOOKS.ToggleOptions() return true end
	if SlashCmdList.BOOKSONMAP then SlashCmdList.BOOKSONMAP("") return true end
end
local function nearby(rest)
	if SlashCmdList.SPFNEAR then SlashCmdList.SPFNEAR(rest or "") return true end
end
local function journeyActive()
	local api = ShortestPathForever and ShortestPathForever.API
	local ok, active = pcall(function() return api and api.Active and api.Active() end)
	return ok and active
end
local function stopJourney()
	if SPF.ClearJourney then SPF.ClearJourney() return true end
end

local function menu(_, rootMenu)
	rootMenu:CreateTitle("BookFinder")
	rootMenu:CreateButton(SETTINGS or "Settings", function() public.OpenSettings() end)
	rootMenu:CreateButton(WORLD_MAP or "World Map", openMap)
	if public.Active("Books") then
		rootMenu:CreateDivider()
		rootMenu:CreateButton(BL("Library books"), bookList)
		rootMenu:CreateButton((BL("Nearest:"):gsub("[:：]%s*$", "")), function() if BOOKS.GoToNearest then BOOKS.GoToNearest() end end)
		rootMenu:CreateCheckbox(BL("Optimized route"), function() return BOOKS.db and BOOKS.db.routeOn and true or false end,
			function() if BOOKS.ToggleRoute then BOOKS.ToggleRoute() end end)
	end
	if public.Active("Questie") and _G.QuestieLoader then
		rootMenu:CreateDivider()
		rootMenu:CreateButton(QUESTS_LABEL or "Quests", function()
			if not (public.OpenQuestLog and public.OpenQuestLog()) then public.OpenSettings("quests") end
		end)
		rootMenu:CreateButton("My Journey", function()
			local ok, journey = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieJourney")
			if ok and journey and journey.ToggleJourneyWindow then journey:ToggleJourneyWindow() end
		end)
	end
	if SlashCmdList.SPFNEAR or journeyActive() then
		rootMenu:CreateDivider()
		if SlashCmdList.SPFNEAR then rootMenu:CreateButton(SPF.L and SPF.L["Nearby services"] or "Nearby services", function() nearby() end) end
		if journeyActive() and SPF.ClearJourney then rootMenu:CreateButton(CANCEL .. ": " .. (SPF.L and SPF.L["Journey"] or "Journey"), stopJourney) end
	end
end

local function openMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, menu) else public.OpenSettings() end
end

-- What the button's tooltip and the broker displays say: the books, the journey, what a click does
local function tooltip(tt)
	tt:AddLine("BookFinder")
	if public.Active("Books") and BOOKS.CountDone and BOOKS.BOOKS then
		tt:AddDoubleLine(BL("Books"), ("%d/%d"):format(BOOKS.CountDone(), #BOOKS.BOOKS), 1, 0.82, 0, 1, 1, 1)
		local nearest = BOOKS.NearestText and BOOKS.NearestText()
		if nearest then tt:AddDoubleLine(BL("Nearest:"), nearest, 0.36, 0.78, 1, 1, 1, 1) end
		if BOOKS.AddGroupProgressTooltip then pcall(BOOKS.AddGroupProgressTooltip, tt) end
	end
	local api = ShortestPathForever and ShortestPathForever.API
	local ok, journey = pcall(function() return api and api.Journey and api.Journey() end)
	if ok and type(journey) == "table" and journey.goal then
		local left = journey.secondsLeft and journey.secondsLeft > 0 and SecondsToTime and SecondsToTime(journey.secondsLeft, journey.secondsLeft >= 60, false, 1, true)
		tt:AddDoubleLine(journey.goal.title or "?", left or "", 0.36, 0.78, 1, 1, 1, 1)
	end
	tt:AddLine(" ")
	tt:AddLine((WORLD_MAP or "World Map") .. ": " .. (KEY_BUTTON1 or "Left Button"), 0.5, 1, 0.5)
	tt:AddLine((SETTINGS or "Settings") .. ", " .. BL("Books") .. ": " .. (KEY_BUTTON2 or "Right Button"), 0.5, 1, 0.5)
end

-- /bookfinder [settings|map|books|near ...|status] ---------------------------------------------------------------
local function status()
	for _, key in ipairs({ "OpenMap", "SPF", "Books" }) do
		local c = public.components[key]
		local where = c.active and "built in" or (public.Loaded(c.folder) and "standalone addon" or "off")
		say(("%s: %s"):format(c.title, where))
	end
	local om = OpenMapAPI
	say(("OpenMap API %s, Shortest Path API %s"):format(
		om and (om.major .. "." .. (om.version or 0)) or "-",
		ShortestPathForever and ShortestPathForever.API and tostring(ShortestPathForever.API.version) or "-"))
end

local COMMANDS = {
	settings = function() return public.OpenSettings() end,
	quests = function() return public.OpenQuestLog and public.OpenQuestLog() end,
	map = function() return public.OpenSettings("map") end,
	books = bookList,
	near = nearby,
}

SLASH_BOOKFINDER1, SLASH_BOOKFINDER2 = "/bookfinder", "/bfind"
SlashCmdList.BOOKFINDER = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "status" then status() return end
	if cmd == "" then public.OpenSettings() return end
	if COMMANDS[cmd] then
		if not COMMANDS[cmd](rest) then say(cmd .. ": not available.") end
		return
	end
	say("/bookfinder [settings | map | books | quests | near <service> | status]")
	say("Also: /openmap (the map's menu), /path, /way, /spfnear, /bom.")
end

-- The addon-compartment entry ---------------------------------------------------------------------------------
_G.BookFinder_OnAddonCompartmentClick = function(frame, button)
	if button == "RightButton" then openMenu(frame) else openMap() end
end
_G.BookFinder_OnAddonCompartmentEnter = function(_, owner)
	GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
	tooltip(GameTooltip)
	GameTooltip:Show()
end
_G.BookFinder_OnAddonCompartmentLeave = function() GameTooltip:Hide() end

-- One minimap button and broker launcher (LibDBIcon, so minimap addons and button bags handle it like any other) --
local broker
local function brokerText()
	if public.Active("Books") and BOOKS.CountDone and BOOKS.BOOKS then
		return ("%d/%d"):format(BOOKS.CountDone(), #BOOKS.BOOKS)
	end
	return "BookFinder"
end

local function minimapDB()
	local db = public.db or {}
	if not db.minimap then
		-- (Books' button's place and hidden state carry over the first time: it was the button players had)
		local old = BOOKS.db and BOOKS.db.minimapIcon
		db.minimap = { minimapPos = old and old.minimapPos or 200, hide = BOOKS.db and BOOKS.db.hideMinimap and true or nil }
	end
	return db.minimap
end

function public.SetMinimapButtonShown(on)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	local db = minimapDB()
	db.hide = not on or nil
	if icon then if on then icon:Show("BookFinder") else icon:Hide("BookFinder") end end
end

local function makeLauncher()
	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	if not ldb then return end
	broker = ldb:NewDataObject("BookFinder", {
		type = "data source",
		label = "BookFinder",
		icon = ICON,
		text = brokerText(),
		OnClick = function(frame, button) if button == "RightButton" then openMenu(frame) else openMap() end end,
		OnTooltipShow = tooltip,
	})
	-- (Books redraws its count through RefreshBroker: the launcher follows)
	if BOOKS.RefreshBroker then
		local refresh = BOOKS.RefreshBroker
		BOOKS.RefreshBroker = function(...)
			refresh(...)
			if broker then broker.text = brokerText() end
		end
	end
	local icon = LibStub("LibDBIcon-1.0", true)
	if icon then icon:Register("BookFinder", broker, minimapDB()) end
end

-- Settings: the front page and the Library books page ------------------------------------------------------------
local function proxy(page, key, varType, name, default, get, set)
	if not (Settings and Settings.RegisterProxySetting) then return end
	local ok, setting = pcall(Settings.RegisterProxySetting, page, "BookFinder_" .. key, varType, name, default, get, set)
	return ok and setting or nil
end
local function checkbox(page, key, name, default, get, set, tip)
	local setting = proxy(page, key, Settings.VarType.Boolean, name, default, get, set)
	if setting then Settings.RegisterInitializer(page, Settings.CreateCheckboxInitializer(setting, nil, tip)) end
end
local function slider(page, key, name, default, min, max, step, get, set, tip)
	local setting = proxy(page, key, Settings.VarType.Number, name, default, get, set)
	if not setting then return end
	local options = Settings.CreateSliderOptions(min, max, step)
	if MinimalSliderWithSteppersMixin then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return tostring(value) end)
	end
	Settings.RegisterInitializer(page, Settings.CreateSliderInitializer(setting, options, tip))
end
local function button(page, name, text, onClick, tip)
	if CreateSettingsButtonInitializer then
		Settings.RegisterInitializer(page, CreateSettingsButtonInitializer(name, text, onClick, tip, true))
	end
end
-- a Books label with its ": %d" left off ("Map icon size: %d" -> "Map icon size")
local function label(text) return (BL(text):gsub("%s*[:：]%s*%%d", "")) end

local function frontPage(category)
	checkbox(category, "minimapButton", BL("Show the minimap button"), true,
		function() return not minimapDB().hide end, function(on) public.SetMinimapButtonShown(on) end)
	local open = SPF.L and SPF.L["Open"] or OKAY
	if public.Active("OpenMap") then
		button(category, OM.L and OM.L["World map"] or "World map", open, function() public.OpenSettings("map") end)
	end
end

local function booksPage(category)
	if not (public.Active("Books") and BOOKS.db) then return end
	local page = Settings.RegisterVerticalLayoutSubcategory(category, BL("Books"))
	public.RegisterPage("books", page)
	local db = BOOKS.db
	local function refresh() if BOOKS.Refresh then BOOKS.Refresh() end end
	local function refreshMinimap() if BOOKS.RefreshMinimapPins then BOOKS.RefreshMinimapPins() end end

	button(page, BL("Books"), SPF.L and SPF.L["Open"] or OKAY, bookList)
	checkbox(page, "booksOnMap", BL("Show on the map"), true,
		function() return not db.hidden end, function(on) db.hidden = not on; refresh() end)
	slider(page, "booksPinSize", label("Map icon size: %d"), BOOKS.DEFAULT_PIN_SIZE or 20, 10, 40, 1,
		function() return db.pinSize or BOOKS.DEFAULT_PIN_SIZE or 20 end,
		function(v) db.pinSize = v; if BOOKS.RefreshMap then BOOKS.RefreshMap() end end)
	checkbox(page, "booksOnMinimap", BL("Show books on the minimap"), true,
		function() return not db.hideMinimapPins end, function(on) db.hideMinimapPins = not on or nil; refreshMinimap() end)
	slider(page, "booksMinimapPinSize", label("Minimap icon size: %d"), BOOKS.DEFAULT_MINIMAP_PIN_SIZE or 14, 8, 30, 1,
		function() return db.minimapPinSize or BOOKS.DEFAULT_MINIMAP_PIN_SIZE or 14 end,
		function(v) db.minimapPinSize = v; refreshMinimap() end)
	checkbox(page, "booksRoute", BL("Optimized route"), false,
		function() return db.routeOn and true or false end,
		function(on) if (db.routeOn and true or false) ~= on and BOOKS.ToggleRoute then BOOKS.ToggleRoute(on) end end)
	checkbox(page, "booksGroup", BL("Also show the books my group is missing"), true,
		function() return not db.hideGroupBooks end, function(on) db.hideGroupBooks = not on or nil; refresh() end)
	checkbox(page, "booksToasts", BL("Notify when a book is collected"), true,
		function() return not db.noToasts end, function(on) db.noToasts = not on or nil end)
	checkbox(page, "booksNearby", BL("Alert when a book is nearby"), true,
		function() return not db.noNearby end, function(on) db.noNearby = not on or nil end)

	-- the books' language (theirs only: the rest follows the game's), applied by a reload as Books always has
	local lang = proxy(page, "booksLanguage", Settings.VarType.String, BL("Language"), "auto",
		function() return db.lang or "auto" end,
		function(value)
			if (db.lang or "auto") == value then return end
			StaticPopupDialogs.BOOKSONMAPFOREVER_RELOAD.text = BL("The interface will be reloaded to apply the language.")
			local dialog = StaticPopup_Show("BOOKSONMAPFOREVER_RELOAD")
			if dialog then dialog.data = value end
		end)
	if lang and Settings.CreateControlTextContainer then
		local choices = Settings.CreateControlTextContainer()
		choices:Add("auto", BL("Automatic (game language)"))
		for _, l in ipairs(BOOKS.LANGS or {}) do choices:Add(l[1], l[3]) end
		Settings.RegisterInitializer(page, Settings.CreateDropdownInitializer(lang, function() return choices:GetData() end))
	end

	-- (and a button for it on the front page, as Shortest Path's pages have)
	button(category, BL("Books"), SPF.L and SPF.L["Open"] or OKAY, function() public.OpenSettings("books") end)
end

-- Shortest Path's map marks as switches in OpenMap's map menu --------------------------------------------------
-- Through the game's setting objects when Shortest Path's settings made them, so its page and its redraw follow;
-- then straight to its saved table if that didn't take
local MARKS = {
	{ id = "pins", label = "Show boats and zeppelins", icon = "Interface\\Icons\\INV_Misc_Spyglass_03" },
	{ id = "transit", label = "Show lifts and the tram", icon = "Interface\\Icons\\INV_Gizmo_02" },
	{ id = "portals", label = "Show portals", icon = "Interface\\Icons\\Spell_Arcane_PortalStormWind" },
	{ id = "mapFlightMasters", label = "Show flight masters", icon = "Interface\\Icons\\Ability_Mount_Gryphon_01" },
	{ id = "mapRoutes", label = "Show routes on the world map", icon = "Interface\\Icons\\INV_Misc_Map_01" },
}

-- OpenMap redraws what follows Shortest Path's boats switch (the airships to Zephras Isle, the routes)
local function refreshOpenMap()
	local m = OM.GetModule and OM:GetModule("worldmap")
	if m and m.enabled and m.Refresh then pcall(m.Refresh, m) end
end

local function registerPathToggles()
	local om = OpenMapAPI
	if not (public.Active("SPF") and SPF.db and type(om) == "table" and om.major == 1
		and type(om.RegisterMenuToggle) == "function") then return end
	local L = SPF.L or {}
	for _, m in ipairs(MARKS) do
		pcall(om.RegisterMenuToggle, ADDON, {
			id = "spf." .. m.id,
			label = L[m.label] or m.label,
			icon = m.icon,
			section = "Shortest Path",
			get = function() return SPF.db[m.id] and true or false end,
			set = function(on)
				on = on and true or false
				local setting = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_" .. m.id)
				if setting and setting.SetValue then pcall(setting.SetValue, setting, on) end
				if SPF.db[m.id] ~= on then
					SPF.db[m.id] = on
					if SPF.RefreshMap then SPF.RefreshMap() end
				end
				refreshOpenMap()
			end,
		})
	end
	-- (the boats switch on Shortest Path's own page too)
	if Settings and Settings.SetOnValueChangedCallback then
		pcall(Settings.SetOnValueChangedCallback, "ShortestPathForever_pins", refreshOpenMap)
	end
end

-- Flight points: Shortest Path learns them only at a flight master's map, so a character new to it (or whose saved
-- data didn't come along into BookFinder) plans every journey on foot. The game lists the points this character has
-- found, wherever it stands (OpenMap greys the rest out from the same list): Shortest Path learns those at login.
-- The same guard as OpenMap's (Map/Flights.lua): WoW Forever can list every point as found, learned or not, and
-- then it isn't saying, so nothing is learned from it; and nothing is ever forgotten from it.
local CONTINENT_MAPS = { 1414, 1415 }   -- Kalimdor, the Eastern Kingdoms

local function learnFlights()
	if not (public.Active("SPF") and SPF.charDB and SPF.charDB.taxi and SPF.SetTaxiKnown and SPF.TaxiNodes) then return 0 end
	if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return 0 end
	local found, undiscovered = {}, 0
	for _, mapID in ipairs(CONTINENT_MAPS) do
		local ok, list = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
		if ok and type(list) == "table" then
			for _, info in ipairs(list) do
				if type(info) == "table" and info.nodeID then
					if info.isUndiscovered == false then found[#found + 1] = info.nodeID
					elseif info.isUndiscovered == true then undiscovered = undiscovered + 1 end
				end
			end
		end
	end
	if undiscovered == 0 then return 0 end
	local learned = 0
	for _, nodeID in ipairs(found) do
		if not SPF.charDB.taxi[nodeID] and SPF.TaxiNodes[nodeID] and SPF.SetTaxiKnown(nodeID, true) then learned = learned + 1 end
	end
	return learned
end

public.LearnFlights = learnFlights   -- (the offline test drives it)

-- With none known past the first levels, journeys are long walks: say why, and how to fix it, each login until it is
local function flightHint()
	if not (public.Active("SPF") and SPF.charDB and SPF.charDB.taxi) or next(SPF.charDB.taxi) then return end
	if (UnitLevel("player") or 0) < 10 then return end
	say("Shortest Path doesn't know your flight paths yet, so it plans journeys on foot. Open any flight master's map once and it learns every one you have. Moving from the separate addons? tools/migrate_savedvariables.py brings your old settings, flights and books over.")
end

-- Load and login ---------------------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then return end
		self:UnregisterEvent("ADDON_LOADED")
		-- (every part's own load handler has run: their saved settings are in, Shortest Path's pages are made)
		local category = public.SettingsCategory()
		if category then
			pcall(frontPage, category)
			pcall(booksPage, category)
		end
		return
	end
	self:UnregisterEvent("PLAYER_LOGIN")
	-- (after every part's own login setup, which this frame's registration order already follows. Questie makes its
	-- pages later, in its startup steps, and lists the window itself once they're in; this is the fallback)
	if public.Active("Questie") then
		C_Timer.After(15, public.PublishSettings)
	else
		public.PublishSettings()
	end
	makeLauncher()
	C_Timer.After(0, registerPathToggles)
	-- (a few seconds in: the taxi lists are filled once the world has loaded)
	C_Timer.After(4, function()
		local learned = learnFlights()
		if learned > 0 then say(("Shortest Path learned the %d flight points you have."):format(learned)) end
		flightHint()
	end)
	if #public.shadowed > 0 then
		say(("%s also installed on its own: that copy runs, and BookFinder's stands aside. Disable it in the AddOns list to use BookFinder's.")
			:format(table.concat(public.shadowed, ", ")))
	end
end)
