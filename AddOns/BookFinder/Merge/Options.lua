-- BookFinder: every setting of the product, declared once, in BookFinder's own words.
--
-- The window that shows them is OptionsWindow.lua. Each entry here only says what the setting is called, where it
-- belongs and how to read and write it; the reading and writing are each part's own (OpenMap's menu rows and options
-- table, Questie's option definitions, Books' saved settings), so a setting does exactly what it always did.
--
-- An entry: { id, section, group, kind = "toggle" | "slider" | "choice" | "button", label, note, icon, get, set,
--   min, max, step, fmt (slider), choices (choice: a function giving { value, label } pairs), run (button) }
-- Sections, in order: map, look, quests, library, more.
local _, root = ...
local public = root.public
if not public then return end
local OM, BOOKS = root.OpenMap, root.Books

local Options = {}
public.Options = Options

Options.SECTIONS = {
	{ key = "map", label = "Map", icon = "Interface\\Icons\\INV_Misc_Map_01" },
	{ key = "look", label = "Look", icon = "Interface\\Icons\\INV_Misc_Spyglass_03" },
	{ key = "quests", label = "Quests", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
	{ key = "library", label = "Library", icon = "Interface\\Icons\\INV_Misc_Book_09" },
	{ key = "more", label = "More", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

local function BL(text) return BOOKS and BOOKS.L and BOOKS.L[text] or text end
local function worldmap()
	local wm = OM and not OM.__skip and OM.modules and OM.modules.worldmap
	return wm and wm.db and wm or nil
end

-- OpenMap's options table (its sliders and choices), as AceConfig hands it out
local function openMapOptions()
	local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if not ACR then return nil end
	local ok, opts = pcall(ACR.GetOptionsTable, ACR, "OpenMap", "dialog", "AceGUI-3.0")
	return ok and opts and opts.args or nil
end
local function fromOpenMap(list, key, section, group, label, extra)
	local args = openMapOptions()
	local o = args and args[key]
	if not o then return end
	local info = { key }
	local function resolve(v) if type(v) == "function" then local ok, r = pcall(v, info) return ok and r or nil end return v end
	local e = { id = "om." .. key, section = section, group = group, label = label or resolve(o.name) }
	if o.type == "range" then
		e.kind, e.min, e.max, e.step = "slider", o.min or o.softMin or 0, o.max or o.softMax or 1, o.bigStep or o.step or 0.05
		e.fmt = o.isPercent and "percent" or nil
	elseif o.type == "select" then
		e.kind = "choice"
		e.choices = function()
			local vals, out = resolve(o.values), {}
			for v, l in pairs(type(vals) == "table" and vals or {}) do out[#out + 1] = { value = v, label = l } end
			table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
			return out
		end
	elseif o.type == "toggle" then
		e.kind = "toggle"
	elseif o.type == "execute" then
		e.kind, e.run = "button", function() if type(o.func) == "function" then o.func(info) end end
	else
		return
	end
	e.get = function() local f = o.get return type(f) == "function" and f(info) or nil end
	e.set = function(v) local f = o.set if type(f) == "function" then f(info, v) end end
	for k, v in pairs(extra or {}) do e[k] = v end
	list[#list + 1] = e
end

-- Questie's option definitions, collected as its options load (Settings.lua's filter sees each tab)
local questie = {}
function public.CollectQuestieOptions(tab, data)
	local function walk(items)
		for key, item in pairs(type(items) == "table" and items or {}) do
			if type(item) == "table" then
				if item.type == "checkbox" or item.type == "slider" or item.type == "dropdown" then
					questie[tab .. "." .. key] = item
				end
				walk(item.items)
			end
		end
	end
	walk(data and data.items)
end
local function fromQuestie(list, ref, group, label, note)
	local item = questie[ref]
	if not item then return end
	local info = { ref:match("%.(.+)$") }
	local e = { id = "q." .. ref, section = "quests", group = group, label = label, note = note }
	if item.type == "checkbox" then
		e.kind = "toggle"
	elseif item.type == "slider" then
		e.kind, e.min, e.max, e.step = "slider", item.min or 0, item.max or 1, item.step or 0.05
	else
		e.kind = "choice"
		e.choices = function()
			local opts = type(item.options) == "function" and item.options() or item.options or {}
			local out = {}
			for v, l in pairs(opts) do out[#out + 1] = { value = v, label = l } end
			table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
			return out
		end
	end
	-- (Questie's own calling conventions: a checkbox's set(control, value), a slider's set(control, value, byHand),
	-- a dropdown's set(value))
	e.get = function() return item.get(info) end
	if item.type == "dropdown" then
		e.set = function(v) item.set(v) end
	else
		e.set = function(v) item.set(info, v, true) end
	end
	if item.enabled then e.enabled = function() local ok, v = pcall(item.enabled, info) return not ok or v ~= false end end
	list[#list + 1] = e
end

-- OpenMap's menu rows (its switches, with Questie's townsfolk and the books' switches already among them), by the
-- heading they sit under; the radio rows become choices from its options table instead
local SKIP_ROWS = { ["unexplored.dim"] = true, ["unexplored.hide"] = true, paint = true, debug = true, mapButtons = true,
	tabRail = true }
local GROUP_SECTION = { [BL("Library books")] = "library", BookFinder = "more" }
local TAB_SECTION = { show = "map", look = "look", more = "more" }

local function fromMenuRows(list)
	local wm = worldmap()
	if not (wm and wm.PanelRows) then return end
	local ok, rows = pcall(wm.PanelRows)
	if not ok or type(rows) ~= "table" then return end
	local tab, group = "show", nil
	for _, r in ipairs(rows) do
		if not r.id then
			tab = r.tab or tab
			group = r[1]
		elseif not SKIP_ROWS[r.id] and not r.id:match("^reopenView%.") then
			local section = GROUP_SECTION[group] or TAB_SECTION[tab] or "more"
			local e = { id = "row." .. r.id, section = section, group = group, label = r[1], note = r.note, icon = r.icon,
				kind = "toggle", get = r[2], set = r[3] }
			-- (Questie's trainer and vendor choosers open a menu of their own: a button, not a tick)
			if r.id == "questie.trainers" or r.id == "questie.vendors" then
				e.kind, e.run, e.note = "button", function() r[3](true) end, nil
				e.buttonText = "Choose"
			end
			list[#list + 1] = e
		end
	end
end

-- Every entry, built fresh (the parts can add rows as they load)
function Options.All()
	local list = {}
	fromMenuRows(list)
	-- Look: the map's colours, zoom and size (OpenMap's sliders and choices)
	fromOpenMap(list, "unexplored", "look", "Unexplored areas", "Unexplored areas")
	fromOpenMap(list, "darkening", "look", "Unexplored areas", "Darkening")
	fromOpenMap(list, "gapFills", "look", "Unexplored areas", "Fill the gaps between zones")
	fromOpenMap(list, "brightness", "look", "Colour", "Brightness")
	fromOpenMap(list, "colorMatch", "look", "Colour", "Colour matching")
	fromOpenMap(list, "desaturate", "look", "Colour", "Take colour out")
	fromOpenMap(list, "maxZoom", "look", "Size and zoom", "Deepest zoom")
	fromOpenMap(list, "windowScale", "look", "Size and zoom", "Map size")
	fromOpenMap(list, "iconScale", "look", "Size and zoom", "Icon size")
	fromOpenMap(list, "iconsFrom", "look", "Size and zoom", "Icons from zoom")
	fromOpenMap(list, "resetWindow", "look", "Size and zoom", "Map size and place", { buttonText = "Reset" })
	fromOpenMap(list, "minimapMix", "look", "Up close", "Minimap detail strength")
	fromOpenMap(list, "minimapFrom", "look", "Up close", "Minimap detail from zoom")
	fromOpenMap(list, "minimapDeep", "look", "Up close", "Minimap detail, most opacity")
	fromOpenMap(list, "resetSliders", "look", "Up close", "Every slider", { buttonText = "Reset" })
	-- Map: the dungeon extras and the map's own behaviour
	fromOpenMap(list, "dungeonMinimap", "map", "Dungeons", "Dungeon maps from the minimap")
	fromOpenMap(list, "questSource", "map", "Dungeons", "Dungeon quests from")
	fromOpenMap(list, "reopenView", "more", "Moving about", "When the map opens")
	fromOpenMap(list, "moveFade", "more", "Moving about", "Fade the map while moving")
	fromOpenMap(list, "mapFpsCap", "more", "Moving about", "Map frame rate cap")
	fromOpenMap(list, "padView", "more", "Moving about", "Gamepad view (test)")

	-- Quests: what a player sets, in plain words; the rest keep Questie's defaults
	local Q = function(ref, group, label, note) fromQuestie(list, ref, group, label, note) end
	Q("icons.enableMiniMapToggle", "Quest icons", "On the minimap")
	Q("icons.showObjectivesToggle", "Quest icons", "Objectives")
	Q("icons.showCompleteQuests", "Quest icons", "Quests ready to turn in")
	Q("icons.hideMapIconsForUntrackedToggle", "Quest icons", "Only tracked quests' objectives")
	Q("icons.hideUnexploredMapIconsToggle", "Quest icons", "Not in unexplored areas")
	Q("icons.hideIconsOnContinents", "Quest icons", "Not on continent maps")
	Q("map.waypointMapEnabled", "Quest icons", "Patrol paths")
	Q("icons.globalScale", "Quest icons", "Size on the map")
	Q("icons.globalMiniMapScale", "Quest icons", "Size on the minimap")
	Q("icons.globalTownsfolkScale", "Quest icons", "Townsfolk size")
	Q("icons.showNormalQuests", "Quests to pick up", "Quests")
	Q("icons.showItemQuests", "Quests to pick up", "Started by items")
	Q("icons.showRepeatableQuests", "Quests to pick up", "Repeatable")
	Q("icons.showDungeonQuests", "Quests to pick up", "Dungeon")
	Q("icons.showRaidQuests", "Quests to pick up", "Raid")
	Q("icons.showPvPQuests", "Quests to pick up", "PvP")
	Q("icons.showEventQuests", "Quests to pick up", "Event")
	Q("tracker.autoTrackQuests", "Quest list", "Track quests as you accept them")
	Q("tracker.showQuestLevels", "Quest list", "Quest levels")
	Q("tracker.collapseCompletedQuests", "Quest list", "Fold finished quests")
	Q("tracker.hideCompletedQuestObjectives", "Quest list", "Hide finished objectives")
	Q("general.enableTooltipsToggle", "Tooltips", "Quest details in tooltips")
	Q("general.showQuestLevels", "Tooltips", "Quest levels")
	Q("general.showNextInChain", "Tooltips", "Next quest in the chain")
	Q("general.showDropRates", "Tooltips", "Drop rates")
	Q("auto.autoaccept", "Automatic", "Accept quests")
	Q("auto.autocomplete", "Automatic", "Turn in quests")
	Q("auto.autoModifier", "Automatic", "Hold to skip")
	Q("nameplate.nameplateEnabled", "On units", "Objectives on nameplates")
	Q("nameplate.nameplateTargetFrameEnabled", "On units", "Objectives on the target frame")
	Q("general.questCompleteSound", "Sounds", "Quest complete")
	Q("general.objectiveCompleteSound", "Sounds", "Objective complete")
	Q("general.objectiveProgressSound", "Sounds", "Objective progress")
	Q("general.showPartyQuestObjectives", "Group", "Party members' objectives")
	Q("general.filterQuestieAnnounce", "Group", "Hide party quest messages")
	Q("general.instantQuest", "Quest text", "Instant quest text")
	Q("general.minimapCoordinatesEnabled", "Quest text", "Coordinates on the minimap")

	-- Library: the books' sizes and language (their switches came with the menu rows)
	local db = BOOKS and not BOOKS.__skip and BOOKS.db
	if db then
		local function refreshMinimap() if BOOKS.RefreshMinimapPins then BOOKS.RefreshMinimapPins() end end
		list[#list + 1] = { id = "books.pinSize", section = "library", group = "Size", kind = "slider", label = "On the map",
			min = 10, max = 40, step = 1, get = function() return db.pinSize or BOOKS.DEFAULT_PIN_SIZE or 20 end,
			set = function(v) db.pinSize = v if BOOKS.RefreshMap then BOOKS.RefreshMap() end end }
		list[#list + 1] = { id = "books.minimapPinSize", section = "library", group = "Size", kind = "slider", label = "On the minimap",
			min = 8, max = 30, step = 1, get = function() return db.minimapPinSize or BOOKS.DEFAULT_MINIMAP_PIN_SIZE or 14 end,
			set = function(v) db.minimapPinSize = v refreshMinimap() end }
		list[#list + 1] = { id = "books.lang", section = "library", group = "Language", kind = "choice", label = "Book names",
			note = "Changing it reloads the interface.",
			choices = function()
				local out = { { value = "auto", label = BL("Automatic (game language)") } }
				for _, l in ipairs(BOOKS.LANGS or {}) do out[#out + 1] = { value = l[1], label = l[3] } end
				return out
			end,
			get = function() return db.lang or "auto" end,
			set = function(value)
				if (db.lang or "auto") == value then return end
				StaticPopupDialogs.BOOKSONMAPFOREVER_RELOAD.text = BL("The interface will be reloaded to apply the language.")
				local dialog = StaticPopup_Show("BOOKSONMAPFOREVER_RELOAD")
				if dialog then dialog.data = value end
			end }
	end
	return list
end

-- The entries of one section, in their groups, in order
function Options.Section(key, all)
	local groups, order = {}, {}
	for _, e in ipairs(all or Options.All()) do
		if e.section == key then
			local g = e.group or ""
			if not groups[g] then groups[g] = {} order[#order + 1] = g end
			local list = groups[g]
			list[#list + 1] = e
		end
	end
	local out = {}
	for _, g in ipairs(order) do out[#out + 1] = { label = g, entries = groups[g] } end
	return out
end
