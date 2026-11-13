-- BookFinder: /bookfinder inspect. Writes what this client actually has into BookFinderDB.inspect, so the addon can be
-- built against the real game rather than guesses. It reads only, and changes nothing:
--   * the client's build, and which parts run here
--   * which art (atlases), fonts and frame templates exist
--   * every entry of the world map's Show menu, with the game settings (CVars) about quests, maps and tracking
--   * where the trackers and the quest log sit, and how big they are
-- Run it, open the world map's Show menu once (so it can read the entries), then /reload: the file is
-- WTF/Account/<account>/SavedVariables/BookFinder.lua.
local _, root = ...
local public = root.public
if not public then return end

local ATLASES = {
	-- quest log and its tabs
	"QuestLog-main-background", "QuestLog-frame-devider", "questlog-tab-icon-quest", "questlog-tab-icon-maplegend",
	"common-button-list-large", "common-button-list-large-hover", "common-button-list-collapseExpand",
	"questlog-icon-setting", "QuestLog-icon-setting", "Banker",
	-- book and lore glyphs
	"Campaign-QuestLog-LoreBook", "Campaign-QuestLog-LoreBook-Back", "loreobject-32x32", "Professions-Icon-Book",
	"Mobile-Archeology", "UI-HUD-MicroMenu-SpellbookAbilities-Up", "UI-HUD-MicroMenu-Questlog-Up",
	"poi-workorders", "Profession", "questlog-questtypeicon-lore",
	-- marks
	"common-icon-checkmark", "common-icon-redx", "bags-greenarrow", "Waypoint-MapPin-Tracked", "dungeon",
	"TaxiNode_Horde", "TaxiNode_Alliance", "Ships_CargoShip-Map", "vehicle-air-horde",
	-- tracker
	"ui-questtracker-header", "UI-QuestTracker-Primary-Objective-Header", "ui-questtrackerbutton-collapse",
	"ui-questtrackerbutton-expand", "Objective-Header", "ui-questtracker-tracker-header",
}
local FONTS = {
	"GameFontNormal", "GameFontNormalMed3", "GameFontNormalLarge2", "GameFontHighlight", "GameFontHighlightSmall",
	"GameFontDisable", "Game15Font_Shadow", "ObjectiveTrackerHeaderFont", "ObjectiveTrackerLineFont",
	"ObjectiveFont", "QuestFont_Large",
}
local TEMPLATES = {
	"SearchBoxTemplate", "ScrollFrameTemplate", "QuestLogBorderFrameTemplate", "CollapseButtonTemplate",
	"LargeSideTabButtonTemplate", "WowStyle1FilterDropdownTemplate", "WowStyle1DropdownTemplate",
	"UIPanelButtonTemplate", "ObjectiveTrackerContainerHeaderTemplate", "ObjectiveTrackerModuleHeaderTemplate",
}
local FRAMES = {
	"ObjectiveTrackerFrame", "Questie_BaseFrame", "ForeverTrackerHost", "QuestMapFrame", "WorldMapFrame",
	"ShortestPathForeverServicesPanel", "BookFinderBooksPanel", "BooksOnMapForeverRoute",
	"QuestieWorldMapButton", "QuestieFrameGroup",
}
local CVAR_HINTS = { "quest", "poi", "track", "map", "trivial", "lowlevel", "objective" }

local function frameInfo(name)
	local f = rawget(_G, name)
	if type(f) ~= "table" or type(f.GetObjectType) ~= "function" then return nil end
	local info = { shown = f:IsShown() and true or false, visible = f:IsVisible() and true or false }
	pcall(function()
		info.width, info.height = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
		info.left, info.top = f:GetLeft() and math.floor(f:GetLeft() + 0.5), f:GetTop() and math.floor(f:GetTop() + 0.5)
		info.strata, info.level, info.scale = f:GetFrameStrata(), f:GetFrameLevel(), f:GetEffectiveScale()
		local point, rel, relPoint, x, y = f:GetPoint()
		info.anchor = ("%s %s %s %.0f %.0f"):format(tostring(point), rel and (rel.GetName and rel:GetName() or "?") or "UIParent",
			tostring(relPoint), x or 0, y or 0)
		info.alpha = f:GetAlpha()
		local kids = {}
		for _, child in ipairs({ f:GetChildren() }) do
			local n = child.GetName and child:GetName()
			if n then kids[#kids + 1] = n end
			if #kids >= 40 then break end
		end
		info.children = kids
	end)
	return info
end

local function cvars()
	local out = {}
	local list = (C_Console and C_Console.GetAllCommands and C_Console.GetAllCommands())
		or (ConsoleGetAllCommands and ConsoleGetAllCommands()) or {}
	for _, c in ipairs(list) do
		local name = c.command
		if type(name) == "string" and (c.commandType == 0 or c.commandType == nil or (Enum and Enum.ConsoleCommandType and c.commandType == Enum.ConsoleCommandType.Cvar)) then
			local low = name:lower()
			for _, hint in ipairs(CVAR_HINTS) do
				if low:find(hint, 1, true) then
					local ok, value = pcall(GetCVar, name)
					if ok and value ~= nil then out[name] = value end
					break
				end
			end
		end
	end
	return out
end

-- every element of a menu description, as text, nested
local function describe(desc, depth)
	local out = {}
	if not (desc and desc.EnumerateElementDescriptions) or depth > 3 then return out end
	for _, element in desc:EnumerateElementDescriptions() do
		local text = MenuUtil and MenuUtil.GetElementText and MenuUtil.GetElementText(element) or element.text
		local entry = { text = text and tostring(text) or "" }
		pcall(function() if element.IsSelected then entry.selected = element:IsSelected() and true or false end end)
		local sub = describe(element, depth + 1)
		if #sub > 0 then entry.sub = sub end
		out[#out + 1] = entry
	end
	return out
end

local watching = false
local function watchMenu(store)
	if watching or not (Menu and Menu.ModifyMenu) then return end
	watching = true
	-- (runs after the game's own entries and every addon's registered before it)
	Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
		local ok, entries = pcall(describe, rootDescription, 0)
		store.mapShowMenu = ok and entries or ("failed: " .. tostring(entries))
	end)
end

function public.Inspect()
	local db = public.db or BookFinderDB
	if not db then return false end
	local store = {}
	local version, build, date, toc = GetBuildInfo()
	store.client = { version = version, build = build, date = date, toc = toc, locale = GetLocale() }
	store.time = date and (time and time()) or nil
	store.parts = {}
	for key, c in pairs(public.components or {}) do store.parts[key] = c.active and "built in" or "standalone/off" end

	store.atlases = {}
	for _, name in ipairs(ATLASES) do
		local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
		store.atlases[name] = info and ("%dx%d %s"):format(info.width or 0, info.height or 0, tostring(info.file or info.filename or "")) or false
	end
	store.fonts = {}
	for _, name in ipairs(FONTS) do
		local font = rawget(_G, name)
		if type(font) == "table" and font.GetFont then
			local file, size, flags = font:GetFont()
			store.fonts[name] = ("%s %s %s"):format(tostring(file), tostring(size), tostring(flags))
		else
			store.fonts[name] = false
		end
	end
	store.templates = {}
	local parent = CreateFrame("Frame")
	parent:Hide()
	for _, name in ipairs(TEMPLATES) do
		store.templates[name] = pcall(CreateFrame, "Frame", nil, parent, name) and true or false
	end
	store.frames = {}
	for _, name in ipairs(FRAMES) do store.frames[name] = frameInfo(name) or false end
	if QuestMapFrame and QuestMapFrame.ContentsAnchor then
		local a = QuestMapFrame.ContentsAnchor
		store.frames["QuestMapFrame.ContentsAnchor"] = { width = a:GetWidth(), height = a:GetHeight() }
	end
	store.cvars = cvars()
	store.questLogTab = ForeverCore and ForeverCore.QuestLogTabs and ForeverCore.QuestLogTabs.Selected() or false
	store.mapShowMenu = "open the world map's Show menu once, then /reload"
	db.inspect = store
	watchMenu(store)
	return true
end
