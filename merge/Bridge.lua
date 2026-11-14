-- BookFinder: loaded last. What makes the parts one addon, beyond OpenMapAPI, which they already talk through:
--   * the one settings window (Namespaces.lua makes it): its Library books page, its front page, and adding it to
--     the game's AddOns list once every page is in
--   * one minimap button and broker launcher for everything (Books' and OpenMap's own stay off)
--   * one addon-compartment entry, and /bookfinder
--   * a login note when a standalone copy took a part's place
local ADDON, root = ...
local public = root.public
local OM, BOOKS = root.OpenMap, root.Books

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
		-- (Questie's own map menu: townsfolk, trainers and vendors to show, the quest icons, its windows. It opened from
		-- Questie's map button, which BookFinder leaves out)
		rootMenu:CreateButton("Townsfolk and quest icons", function()
			local ok, qm = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieMenu")
			if ok and qm and qm.Show then C_Timer.After(0, function() qm:Show() end) end
		end)
		rootMenu:CreateButton("My Journey", function()
			local ok, journey = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieJourney")
			if ok and journey and journey.ToggleJourneyWindow then journey:ToggleJourneyWindow() end
		end)
	end
end

local function openMenu(owner)
	public.ContextMenu(owner, menu)
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
	tt:AddLine(" ")
	tt:AddLine((WORLD_MAP or "World Map") .. ": " .. (KEY_BUTTON1 or "Left Button"), 0.5, 1, 0.5)
	tt:AddLine((SETTINGS or "Settings") .. ", " .. BL("Books") .. ": " .. (KEY_BUTTON2 or "Right Button"), 0.5, 1, 0.5)
end

-- /bookfinder [settings|map|books|near ...|status] ---------------------------------------------------------------
local function status()
	for _, key in ipairs({ "OpenMap", "Books", "Questie" }) do
		local c = public.components[key]
		local where = c.active and "built in" or (public.Loaded(c.folder) and "standalone addon" or "off")
		say(("%s: %s"):format(c.title, where))
	end
	local om = OpenMapAPI
	say(("OpenMap API %s"):format(om and (om.major .. "." .. (om.version or 0)) or "-"))
end

local COMMANDS = {
	settings = function() return public.OpenSettings() end,
	quests = function() return public.OpenQuestLog and public.OpenQuestLog() end,
	selftest = function() return public.SelfTest and public.SelfTest() end,
	inspect = function()
		if not (public.Inspect and public.Inspect()) then return false end
		say("Recorded. Now open the world map's Show menu once, then /reload: the details are in WTF/Account/<account>/SavedVariables/BookFinder.lua.")
		return true
	end,
	map = function() return public.OpenSettings("map") end,
	books = bookList,
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
	say("/bookfinder [settings | map | books | quests | status | inspect | selftest]")
	say("Also: /openmap (the map's menu), /bom (the books).")
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
-- a Books label with its ": %d" left off ("Map icon size: %d" -> "Map icon size")
local function label(text) return (BL(text):gsub("%s*[:：]%s*%%d", "")) end

-- the front page: what is BookFinder's own (the pages are in the tree beside it)
local function frontPage(category)
	checkbox(category, "minimapButton", BL("Show the minimap button"), true,
		function() return not minimapDB().hide end, function(on) public.SetMinimapButtonShown(on) end)
end

local function booksPage(category)
	if not (public.Active("Books") and BOOKS.db) then return end
	local page = Settings.RegisterVerticalLayoutSubcategory(category, BL("Library books"))
	public.RegisterPage("books", page)
	local db = BOOKS.db
	local function refresh() if BOOKS.Refresh then BOOKS.Refresh() end end
	local function refreshMinimap() if BOOKS.RefreshMinimapPins then BOOKS.RefreshMinimapPins() end end

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
	if #public.shadowed > 0 then
		say(("%s also installed on its own: that copy runs, and BookFinder's stands aside. Disable it in the AddOns list to use BookFinder's.")
			:format(table.concat(public.shadowed, ", ")))
	end
end)
