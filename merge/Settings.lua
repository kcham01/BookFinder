-- BookFinder: where every setting lives, with each one in one place.
--
--   The map's menu (OpenMap's panel, the OpenMap button on the map): every on/off switch. What the map shows (places,
--   dungeons, townsfolk, people, quest icons, the library books), how it looks, and the rest.
--   The settings window (Options > AddOns > BookFinder): only what a switch can't be (sliders, choices, sounds,
--   fonts, profiles), and Questie's own quest options.
--
-- This file does the parts of that no single part could:
--   * Questie's townsfolk as switches in the map's menu (OpenMap's own townsfolk step aside: Townsfolk.lua)
--   * the switches of Books and BookFinder in the map's menu
--   * which of Questie's options are left out: those that do nothing in BookFinder (its tracker's window, its own
--     map, minimap and compartment buttons) and those the map's menu already holds
--   * old settings carried over once: OpenMap's townsfolk choices to Questie's
local _, root = ...
local public = root.public
if not public then return end
local BOOKS, OM = root.Books, root.OpenMap

local function questieModule(name)
	local loader = rawget(_G, "QuestieLoader")
	if not (loader and loader.ImportModule) then return end
	local ok, mod = pcall(loader.ImportModule, loader, name)
	return ok and mod or nil
end
local function BL(text) return BOOKS and BOOKS.L and BOOKS.L[text] or text end

-- Questie's townsfolk, for the map's menu (Panel.lua asks) ----------------------------------------------------------
function public.TownsfolkRows()
	if not public.Active("Questie") then return nil end
	local qm = questieModule("QuestieMenu")
	if not (qm and qm.BookFinderTownsfolk) then return nil end
	local ok, rows = pcall(qm.BookFinderTownsfolk)
	if not ok or type(rows) ~= "table" or #rows == 0 then return nil end
	-- every kind of profession trainer, and of vendor: one row each, opening Questie's chooser
	local function chooser(label, key, icon, open, shown)
		rows[#rows + 1] = { key = key, label = label, icon = icon, note = "Choose which",
			get = function() local okS, v = pcall(shown) return okS and v and true or false end,
			set = function() C_Timer.After(0, function() pcall(open, qm, 1) end) end }
	end
	if qm.ShowProfessions then
		chooser("Profession trainers…", "trainers", "Interface\\Minimap\\tracking\\profession", qm.ShowProfessions,
			function() return qm.BookFinderTrainersShown and qm.BookFinderTrainersShown() end)
	end
	if qm.ShowVendors then
		chooser("Vendors…", "vendors", "Interface\\Minimap\\tracking\\food", qm.ShowVendors,
			function() return qm.BookFinderVendorsShown and qm.BookFinderVendorsShown() end)
	end
	return rows
end

-- Questie's options left out ---------------------------------------------------------------------------------------
local QUESTIE_HIDDEN = {
	general = {
		-- (BookFinder's one map menu, minimap button and compartment entry stand for Questie's)
		mapShowHideEnabled = true, minimapButtonEnabled = true, compartmentButtonEnabled = true,
		-- (the map's own coordinates, OpenMap's, are in the map's menu)
		mapCoordinatesEnabled = true, mapCoordinatePrecision = true,
	},
	icons = {
		-- (the townsfolk are switches in the map's menu; the map's quest icons too)
		townsfolk_options = true, townsfolkOptions = true, professionOptions = true, vendorOptions = true,
		enableMapToggle = true,
	},
	tracker = {
		-- (the list is in the map's Quests tab, always on: its window, place and frame do nothing there)
		enableQuestieTracker = true, resetTrackerLocation = true,
		minimizeInCombat = true, minimizeInInstances = true, hideInCombat = true, hideInInstances = true,
		hideInPetBattles = true, hideSizer = true, lockTracker = true, stickyDurabilityFrame = true,
		stickyVoiceOverFrame = true, setTomTom = true, trackerSetpoint = true, trackerHeightRatio = true,
		trackerWidthRatio = true, group_header = true, group_background = true,
	},
}
local function hide(items, hidden)
	if type(items) ~= "table" then return end
	for key, item in pairs(items) do
		if type(item) == "table" then
			if hidden[key] then item.visible = false end
			hide(item.items, hidden)
		end
	end
end
function public.FilterQuestieOptions(tab, data)
	local hidden = QUESTIE_HIDDEN[tab]
	if hidden and type(data) == "table" then hide(data.items, hidden) end
end
public.QuestieHidden = QUESTIE_HIDDEN   -- (for the offline test)

-- The switches of Books and BookFinder in the map's menu ------------------------------------------------------------
local function registerSwitches()
	local api = OpenMapAPI
	if type(api) ~= "table" or type(api.RegisterMenuToggle) ~= "function" then return end
	local books = BL("Library books")
	local db = BOOKS and BOOKS.db
	if public.Active("Books") and db then
		local function refresh() if BOOKS.Refresh then BOOKS.Refresh() end end
		local function refreshMinimap() if BOOKS.RefreshMinimapPins then BOOKS.RefreshMinimapPins() end end
		pcall(api.RegisterMenuToggle, "BookFinder", { id = "booksMinimap", label = BL("Show books on the minimap"), section = books,
			icon = "Interface\\Icons\\INV_Misc_Book_09",
			get = function() return not db.hideMinimapPins end, set = function(on) db.hideMinimapPins = not on or nil refreshMinimap() end })
		pcall(api.RegisterMenuToggle, "BookFinder", { id = "booksGroup", label = BL("Also show the books my group is missing"), section = books,
			icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
			get = function() return not db.hideGroupBooks end, set = function(on) db.hideGroupBooks = not on or nil refresh() end })
		pcall(api.RegisterMenuToggle, "BookFinder", { id = "booksToasts", label = BL("Notify when a book is collected"), section = books,
			icon = "Interface\\Icons\\INV_Scroll_03",
			get = function() return not db.noToasts end, set = function(on) db.noToasts = not on or nil end })
		pcall(api.RegisterMenuToggle, "BookFinder", { id = "booksNearby", label = BL("Alert when a book is nearby"), section = books,
			icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
			get = function() return not db.noNearby end, set = function(on) db.noNearby = not on or nil end })
	end
	pcall(api.RegisterMenuToggle, "BookFinder", { id = "minimapButton", label = "Minimap button", section = "BookFinder", tab = "more",
		icon = "Interface\\AddOns\\BookFinder\\OpenMap\\Media\\Textures\\OpenMapIconRound",
		get = function() local m = public.db and public.db.minimap return not (m and m.hide) end,
		set = function(on) if public.SetMinimapButtonShown then public.SetMinimapButtonShown(on) end end })
end

-- The map's menu, opened from anywhere (the minimap menu, the settings window, the books tab's gear)
function public.OpenMapMenu()
	if InCombatLockdown() then return false end
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
	if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
	local wm = OM and OM.modules and OM.modules.worldmap
	if wm and wm.OpenMenu then
		local ok, opened = pcall(wm.OpenMenu, wm)
		return ok and opened ~= false
	end
	return false
end

-- Old settings carried over, once --------------------------------------------------------------------------------
-- OpenMap's townsfolk switches (which BookFinder now leaves to Questie) become Questie's, for the kinds both have
local FOLK = { repair = "Repair", innkeeper = "Innkeeper", mailbox = "Mailbox", banker = "Banker", auctioneer = "Auctioneer",
	stable = "Stable Master", classTrainer = "Class Trainer", spirit = "Spirit Healer" }
local function carryOver()
	local db = public.db
	if not db or db.settingsMoved21 then return end
	local wm = OM and OM.modules and OM.modules.worldmap
	local folk = wm and wm.db and wm.db.townsfolk
	local rows = public.TownsfolkRows()
	if not rows then return end   -- (Questie not up yet: next login)
	db.settingsMoved21 = true
	if type(folk) ~= "table" then return end
	local byKey = {}
	for _, r in ipairs(rows) do byKey[r.key] = r end
	for openMapKey, questieKey in pairs(FOLK) do
		if folk[openMapKey] then
			if byKey[questieKey] then pcall(byKey[questieKey].set, true) end
			folk[openMapKey] = false
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	registerSwitches()
	-- (Questie's database and townsfolk are ready a few seconds in)
	C_Timer.After(12, function() pcall(carryOver) end)
end)

public.SettingsTest = { Register = registerSwitches, CarryOver = carryOver }
