-- BookFinder: loaded first. One addon folder holds four addons (Questie with QuestieDB, OpenMap and Books on map
-- Forever), and the game gives every file of one addon the same private table. Each
-- component's files take their own table from it instead (tools/build.py rewrites the line that reads
-- it), so their `ns.db`, `ns.L`, `ns.RefreshMap` and the rest never meet.
--
-- A component whose standalone addon is also installed and enabled stands aside (its files return at
-- once), so the standalone copy runs alone instead of both fighting over the same frames and globals.
local ADDON, root = ...

local COMPONENTS = {
	-- key in the private table, standalone folder name, display name; `with`: stands aside together with that part
	{ key = "QuestieDB", folder = "QuestieDB", title = "QuestieDB", with = "Questie" },
	{ key = "Questie", folder = "Questie", title = "Questie", with = "QuestieDB" },
	{ key = "OpenMap", folder = "OpenMap", title = "OpenMap" },
	{ key = "Books", folder = "Books_on_map_Forever", title = "Books on map" },
}

local api = C_AddOns or {}
local getInfo = api.GetAddOnInfo or GetAddOnInfo
local enableState = api.GetAddOnEnableState or GetAddOnEnableState

-- true when the standalone addon will load this session too: installed, loadable and enabled for this
-- character
local function standaloneLoads(folder)
	if not getInfo then return false end
	local ok, name, _, _, loadable = pcall(getInfo, folder)
	if not ok or not name or not loadable then return false end
	if enableState then
		-- (the argument order changed between clients: try both, either says enabled)
		local player = UnitName and UnitName("player")
		local okA, a = pcall(enableState, folder, player)
		local okB, b = pcall(enableState, player, folder)
		local on = (okA and type(a) == "number" and a > 0) or (okB and type(b) == "number" and b > 0)
		return on and true or false
	end
	return true
end

local public = { name = ADDON, components = {}, shadowed = {} }
local folderOf = {}
for _, c in ipairs(COMPONENTS) do folderOf[c.key] = c.folder end
for _, c in ipairs(COMPONENTS) do
	local sub = {}
	root[c.key] = sub
	-- (Questie and its database are one: either standalone one running takes both)
	if standaloneLoads(c.folder) or (c.with and standaloneLoads(folderOf[c.with])) then
		sub.__skip = true
		public.shadowed[#public.shadowed + 1] = c.title
	end
	public.components[c.key] = { folder = c.folder, title = c.title, active = not sub.__skip }
end

-- Whether a part's files stand aside (the guard on each Questie and QuestieDB file's first line asks)
function public.Skip(key)
	local c = public.components[key]
	return c ~= nil and not c.active
end
root.public = public

-- Whether a component runs inside BookFinder this session (false when its standalone addon took over).
function public.Active(key)
	local c = public.components[key]
	return c and c.active or false
end

-- IsAddOnLoaded for the three folder names, answering true for a component that runs in here too:
-- the components' own checks for each other go through this.
function public.Loaded(folder)
	for _, c in pairs(public.components) do
		if c.folder == folder and c.active then return true end
	end
	local loaded = api.IsAddOnLoaded or IsAddOnLoaded
	return loaded and loaded(folder) and true or false
end

-- One settings window --------------------------------------------------------------------------------------------
-- Options > AddOns > BookFinder, the game's own settings panel: every part's settings are pages of it (OpenMap's
-- World map, the Library books, Questie's), and every way into any part's settings opens it there.
local category
local pages = {}                -- key -> the page's category, for OpenSettings(key)

-- BookFinder's category, made on first use
function public.SettingsCategory()
	if not category and Settings and Settings.RegisterVerticalLayoutCategory then
		category = Settings.RegisterVerticalLayoutCategory("BookFinder")
	end
	return category
end

-- a part's page, by a key of its own ("map", "books", "quests")
function public.RegisterPage(key, page)
	if key and page then pages[key] = page end
end

-- the settings window, at a page when one is named and known
function public.OpenSettings(key)
	local target = (key and pages[key]) or public.SettingsCategory()
	if not target then return false end
	local id = target.GetID and target:GetID() or target.ID
	if InCombatLockdown() then return false end
	if Settings and Settings.OpenToCategory then Settings.OpenToCategory(id) end
	return true
end

-- The category goes into the AddOns list once every page is in (Bridge.lua, at login)
function public.PublishSettings()
	if public.published or not category or not Settings.RegisterAddOnCategory then return end
	public.published = true
	Settings.RegisterAddOnCategory(category)
end

-- Saved file paths into a part's old folder (Interface\AddOns\Questie\Icons\slay.blp, which Questie keeps for
-- its chosen icons) point into BookFinder instead: the part's folder is inside it now, and a texture that isn't
-- found draws as a green square. Done before any part reads its settings.
local PART_FOLDERS = { "questiedb", "questie", "openmap", "books_on_map_forever" }
local SAVED = { "QuestieConfig", "QuestieConfigCharacter", "OpenMapDB", "OpenMapCharDB", "BooksOnMapForeverDB",
	"BooksOnMapForeverGlobal" }
local function repath(value)
	local low = value:lower()
	local at = low:find("interface[\\/]addons[\\/]")
	if not at then return nil end
	local rest = low:sub(at + 17)
	for _, folder in ipairs(PART_FOLDERS) do
		if rest:sub(1, #folder + 1) == folder .. "\\" or rest:sub(1, #folder + 1) == folder .. "/" then
			return value:sub(1, at - 1) .. "Interface\\AddOns\\" .. ADDON .. "\\" .. value:sub(at + 17)
		end
	end
end
local function fixPaths(t, depth, seen)
	if depth > 12 or seen[t] then return 0 end
	seen[t] = true
	local n = 0
	for k, v in pairs(t) do
		if type(v) == "string" and #v < 260 then
			local fixed = repath(v)
			if fixed then t[k] = fixed n = n + 1 end
		elseif type(v) == "table" then
			n = n + fixPaths(v, depth + 1, seen)
		end
	end
	return n
end
public.FixSavedPaths = function(t) return fixPaths(t, 0, {}) end   -- (for the offline test)

-- BookFinder's own saved settings (the minimap button), ready before any part's
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	for _, global in ipairs(SAVED) do
		local t = rawget(_G, global)
		if type(t) == "table" then pcall(fixPaths, t, 0, {}) end
	end
	BookFinderDB = type(BookFinderDB) == "table" and BookFinderDB or {}
	public.db = BookFinderDB
end)

_G.BookFinder = public
