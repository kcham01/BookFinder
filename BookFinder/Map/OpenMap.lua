-- OpenMap, folded into BookFinder's download (BookFinder\OpenMap, tools/openmap_merge.py), is the world map. Its switches and settings live in BookFinder's own places so the
-- two read as one product (docs/NOTES.md 1 and 2):
--
--   * every map item of OpenMap's is in the map's Show dropdown, once, in the one flat list (Map/ShowMenu.lua), its
--     dungeon switches in the Dungeons section;
--   * all of OpenMap's other settings (its Look and More pages, the sliders and choices) are on the panel's OpenMap tab.
--
-- Each one is a BookFinder setting ("openmap.<key>") kept by OpenMap: read and written through OpenMap's own options
-- (the AceConfig table it registers as "OpenMap"), so whatever OpenMap does on a change (laying the map out again,
-- closing a dungeon map) still happens. The few its options table lacks are written to its saved settings, then a
-- harmless option is set to itself to have it redraw.
--
-- Nothing here runs without OpenMap.

local _, BF = ...
local L = BF.L

local OM = {}
BF.OpenMap = OM

local function present()
	return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("OpenMap")) or rawget(_G, "OpenMapAPI") ~= nil
end
OM.Present = present

-- OpenMap's options ----------------------------------------------------------------------------------------------

local cache, cachedAt = nil, -10

local function options()
	local now = GetTime()
	if cache and now - cachedAt < 5 then return cache end
	local stub = rawget(_G, "LibStub")
	local registry = stub and stub("AceConfigRegistry-3.0", true)
	if not registry or not registry.GetOptionsTable then return nil end
	local ok, t = pcall(registry.GetOptionsTable, registry, "OpenMap", "dialog", "BookFinder-1.0")
	if not ok or type(t) ~= "table" or type(t.args) ~= "table" then return nil end
	cache, cachedAt = t, now
	return t
end

local function infoFor(root, key, opt)
	local info = { key, options = root, option = opt, type = opt.type, arg = opt.arg, handler = opt.handler or root.handler,
		uiType = "dialog", uiName = "BookFinder-1.0", appName = "OpenMap" }
	info[0] = "OpenMap"
	return info
end

--- An option's field, run as AceConfig runs it (a function, a method of its handler, or a plain value).
local function field(key, name, ...)
	local root = options()
	local opt = root and root.args[key]
	if not opt then return nil end
	local f = opt[name]
	if type(f) == "string" and name ~= "name" and name ~= "desc" then
		local handler = opt.handler or root.handler
		if handler and type(handler[f]) == "function" then return handler[f](handler, infoFor(root, key, opt), ...) end
		return nil
	end
	if type(f) == "function" then return f(infoFor(root, key, opt), ...) end
	return f
end

local function has(key)
	local root = options()
	return root ~= nil and root.args[key] ~= nil
end
OM.Has = has

local function db() local t = rawget(_G, "OpenMapDB") return t and t.worldmap end
local function chardb() local t = rawget(_G, "OpenMapCharDB") return t and t.worldmap end

--- Has OpenMap redraw after a change written straight to its settings.
local function redraw()
	if has("autoSwitch") then
		local v = field("autoSwitch", "get")
		pcall(field, "autoSwitch", "set", v and true or false)
	end
end

-- The settings ------------------------------------------------------------------------------------------------------

local S = BF.Settings
OM.keys = {}   -- OpenMap key -> BookFinder key

--- A setting kept through OpenMap's option `key` (or straight in its saved settings when the option is missing).
local function define(key, spec)
	local bfKey = "openmap." .. key
	spec.page = spec.page or "OpenMap"
	spec.external = spec.external or {
		get = function()
			if has(key) then return field(key, "get") end
			local t = db()
			if t then return t[key] end
		end,
		set = function(v)
			if has(key) then field(key, "set", v) return end
			local t = db()
			if t then t[key] = v redraw() end
		end,
	}
	S:Define(bfKey, spec)
	OM.keys[key] = bfKey
	return bfKey
end

local function toggle(key, label, default) return define(key, { default = default ~= false, label = label }) end

--- Is this OpenMap setting offered (its option is there, or it is one of the few kept straight in its settings)?
function OM:Offers(key)
	if not present() then return false end
	if has(key) then return not field(key, "hidden") end
	local t = db()
	return t ~= nil and t[key] ~= nil
end

if present() then
	-- What the map shows (the Show dropdown).
	toggle("icons", "Dungeons and raids")
	toggle("boats", "Boats")
	toggle("zeppelins", "Zeppelins")
	toggle("flight", "Flight masters")
	toggle("foundOnly", "Only places you've found", false)
	toggle("routes", "Boat and zeppelin routes", false)
	toggle("playerArrow", "Your arrow")
	toggle("group", "Party and raid members")
	toggle("friends", "Friends on the map")
	toggle("guild", "Guild members on the map")
	toggle("sketchShown", "Your drawings")
	toggle("allQuests", "Quests from every zone")
	toggle("hideWorldPinsInInstances", "Hide world markers in instances", false)
	toggle("zoomHidePins", "Fade icons while zooming", false)
	toggle("dungeonMaps", "Dungeon maps")
	toggle("dungeonLevels", "Level ranges")
	toggle("dungeonBosses", "Dungeon bosses")
	toggle("dungeonQuests", "Dungeon quests")
	toggle("dungeonMinimap", "Dungeon maps on the minimap")
	-- (a choice in OpenMap's options, a tick box here as in its menu)
	define("entranceClick", { default = false, label = "Entrances open Dungeon Journal", external = {
		get = function() return field("entranceClick", "get") == "journal" end,
		set = function(v) field("entranceClick", "set", v and "journal" or "map") end,
	} })
	define("questSource", { default = "auto", label = "Dungeon quests from", choices = {}, choiceLabels = {} })

	-- The look.
	define("unexplored", { default = "show", label = "Unexplored areas", choices = { "show", "dim", "hide" },
		choiceLabels = { show = "Show", dim = "Darken", hide = "Hide" } })
	define("unexploredOwn", { default = false, label = "Only for this character", external = {
		get = function() local c = chardb() return c and c.unexploredOwn or false end,
		set = function(v)
			local c, t = chardb(), db()
			if not c or not t then return end
			if v and not c.unexploredOwn then c.unexplored = t.unexplored end
			c.unexploredOwn = v and true or nil
			redraw()
		end,
	} })
	define("darkenColor", { default = { 0.05, 0.06, 0.08, 1 }, label = "Darkening colour", external = {
		get = function()
			local r, g, b = field("darkenColor", "get")
			if r then return { r, g, b, 1 } end
		end,
		set = function(c) field("darkenColor", "set", c[1], c[2], c[3]) end,
	} })
	toggle("chart", "Responsive ocean & border", false)
	toggle("gapFills", "Filled gaps")
	toggle("hoverHighlight", "Zone highlight on hover", false)
	toggle("zoneLevels", "Zone levels")
	toggle("coords", "Coordinates")
	toggle("tabRail", "Buttons as edge tabs", false)
	toggle("mapButtons", "OpenMap button on the map")
	toggle("minimapButton", "OpenMap minimap button")
	toggle("fullWidth", "Full-screen map fills the width", false)
	toggle("chatOverMap", "Chat over the full-screen map", false)
	toggle("padView", "OpenMap's map with the Gamepad UI (test)", false)
	toggle("minimap", "Minimap detail")
	toggle("cityMinimap", "Minimap detail in major cities")
	toggle("gapMinimap", "Minimap in the gaps")
	toggle("soften", "Soften and paper grain")
	toggle("underground", "Caves underground")
	-- (the sliders: their ranges are OpenMap's, read once it has registered its options, below)
	for _, s in ipairs({
		{ "brightness", "Map brightness", 1 }, { "colorMatch", "Colour matching", 1 }, { "desaturate", "Take colour out", 0.1 },
		{ "darkening", "Darkening", 1 }, { "maxZoom", "Deepest zoom", 48 }, { "iconsFrom", "Icons from zoom", 0 },
		{ "iconScale", "Icon size", 1 }, { "windowScale", "Map window size", 1 }, { "minimapMix", "Minimap detail strength", 1 },
		{ "minimapFrom", "Minimap detail from zoom", 1 }, { "minimapDeep", "Minimap detail deepest", 1 },
		{ "mapFpsCap", "Map frame rate cap", 0 }, { "moveFade", "Fade the map while moving", 0 },
	}) do
		define(s[1], { default = s[3], label = s[2], min = 0, max = s[3] * 2 + 1, step = 0.05 })
	end

	-- Moving about, sharing.
	toggle("autoSwitch", "Load the zone in view")
	toggle("ctrlClickPin", "Ctrl-click drops a pin")
	toggle("pinsFollowNew", "Follow new pins")
	define("reopenView", { default = "player", label = "Reopen map", choices = { "player", "zoom", "inzone", "always", "visible" },
		choiceLabels = { player = "Center on player", zoom = "Center on player, keep zoom", inzone = "Center on your zone",
			always = "Always remember", visible = "Remember while visible" } })
	toggle("pinsShared", "Pins others share with you")
	toggle("pinsShareGroup", "Send new pins to group", false)
	toggle("pinsGroupAdd", "Auto-add group's pins", false)
	toggle("friendsShare", "Share where you are", false)
end

--- The BookFinder key of OpenMap's setting `key`, when OpenMap is here and offers it; else nil.
function OM:Key(key)
	local bfKey = OM.keys[key]
	if bfKey and OM:Offers(key) then return bfKey end
end

--- Only the keys OpenMap offers, for the panel's layout.
function OM:Keys(list)
	local out = {}
	for _, key in ipairs(list) do
		local k = OM:Key(key)
		if k then out[#out + 1] = k end
	end
	return out
end

-- Once OpenMap has registered its options: the sliders' ranges and the choices' values are its own.
local function adopt()
	local root = options()
	if not root then return false end
	for key, bfKey in pairs(OM.keys) do
		local opt = root.args[key]
		local def = S:Definition(bfKey)
		if opt and def then
			if opt.type == "range" then
				def.min, def.max, def.step = opt.min or def.min, opt.max or def.max, opt.step or opt.bigStep or def.step
				if type(opt.name) == "string" then def.label = opt.name end
				def.percent = opt.isPercent or nil
			elseif opt.type == "select" and def.choices then
				local values = field(key, "values")
				if type(values) == "table" then
					local list = {}
					local order = type(opt.sorting) == "table" and opt.sorting or nil
					if order then
						for _, v in ipairs(order) do if values[v] then list[#list + 1] = v end end
					else
						for v in pairs(values) do list[#list + 1] = v end
						table.sort(list)
					end
					def.choices = list
					def.choiceLabels = def.choiceLabels or {}
					for v, text in pairs(values) do def.choiceLabels[v] = def.choiceLabels[v] or text end
					if #list > 0 then
						local known = false
						for _, v in ipairs(list) do if v == def.default then known = true end end
						if not known then def.default = list[1] end
					end
				end
			end
		end
	end
	-- Entrances open the Dungeon Journal only where one is there to open.
	local values = has("entranceClick") and field("entranceClick", "values")
	OM.journal = type(values) == "table" and values.journal ~= nil
	return true
end

-- Actions of OpenMap's that BookFinder's panel offers as buttons (its own menu's tiles).
local function slash(word)
	local run = rawget(_G, "SlashCmdList") and SlashCmdList.OPENMAP
	if run then run(word) end
end
OM.actions = {
	{ id = "omPins", label = "Pins", icon = "Interface\\Icons\\INV_Misc_Map_01", run = function() slash("pins") end },
	{ id = "omQuill", label = "Quill", icon = "Interface\\Icons\\INV_Feather_04", run = function() slash("draw") end },
	{ id = "omNotes", label = "Map notes", icon = "Interface\\Icons\\INV_Misc_Note_02", run = function() slash("notes") end },
	{ id = "omNews", label = "What's new in OpenMap", icon = "Interface\\Icons\\INV_Scroll_03", run = function() slash("news") end },
}
OM.buttons = {
	{ label = "Default colour", run = function() pcall(field, "darkenColorReset", "func") BF.Panel:Refresh() end },
	{ label = "Reset the map window", run = function() slash("reset") end },
	{ label = "Reset sliders to defaults", run = function() pcall(field, "resetSliders", "func") BF.Panel:Refresh() end },
	{ label = "Debug overlay (FPS)", run = function() slash("debug") end },
}

-- Two icons for one thing never show: OpenMap's flight masters and BookFinder's are one switch (Map/ShowMenu.lua),
-- and while OpenMap draws its own on the world map, BookFinder's stay on the minimap only.
function OM:DrawsFlightMasters()
	return OM:Key("flight") ~= nil and BF:Get("openmap.flight")
end

BF:At("login", function()
	if not present() then return end
	if not adopt() then BF:After(1, adopt) end
	-- OpenMap's own button on the map would be a second menu: BookFinder's map button is the one (UI/MapButton.lua).
	-- Turned off once; the panel's Look page turns it back on.
	-- Its first-run "how should the map start" card is OpenMap's own welcome: BookFinder starts it as OpenMap comes.
	local t = db()
	if t and t.presetAsked == false then t.presetAsked = true end
	local state = BF:AccountState("openmap")
	if not state.buttonHidden then
		state.buttonHidden = true
		if OM:Key("mapButtons") then BF:Set("openmap.mapButtons", false) end
		if OM:Key("minimapButton") then BF:Set("openmap.minimapButton", false) end
	end
end, 79)
