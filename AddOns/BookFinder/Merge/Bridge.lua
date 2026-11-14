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
-- The minimap button's menu: where to go, then the settings window.
local function menu(_, rootMenu)
	rootMenu:CreateTitle("BookFinder")
	rootMenu:CreateButton(WORLD_MAP or "World Map", openMap)
	if public.Active("Questie") then
		rootMenu:CreateButton(QUEST_LOG or "Quest Log", function() if public.OpenQuestLog then public.OpenQuestLog() end end)
	end
	if public.Active("Books") then
		rootMenu:CreateButton(BL("Library books"), bookList)
		rootMenu:CreateButton("Nearest book", function() if BOOKS.GoToNearest then BOOKS.GoToNearest() end end)
	end
	if public.Active("Questie") and _G.QuestieLoader then
		rootMenu:CreateButton("My Journey", function()
			local ok, journey = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieJourney")
			if ok and journey and journey.ToggleJourneyWindow then journey:ToggleJourneyWindow() end
		end)
	end
	rootMenu:CreateDivider()
	rootMenu:CreateButton(SETTINGS or "Settings", function() if public.OpenOptions then public.OpenOptions("map") end end)
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
	tt:AddLine("Menu: " .. (KEY_BUTTON2 or "Right Button"), 0.5, 1, 0.5)
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

-- The game's AddOns settings list: BookFinder's entry opens BookFinder's own settings window
local function frontPage(category)
	if CreateSettingsButtonInitializer then
		local ok, init = pcall(CreateSettingsButtonInitializer, "BookFinder settings", "Open",
			function() if public.OpenOptions then public.OpenOptions("map") end end,
			"The map, its look, quests, the library books and the rest, in one window.", true)
		if ok and init then Settings.RegisterInitializer(category, init) end
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
