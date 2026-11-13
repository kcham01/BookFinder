-- BookFinder: loaded first. One addon folder holds three addons (OpenMap, Shortest Path Forever and
-- Books on map Forever), and the game gives every file of one addon the same private table. Each
-- component's files take their own table from it instead (tools/build.py rewrites the line that reads
-- it), so their `ns.db`, `ns.L`, `ns.RefreshMap` and the rest never meet.
--
-- A component whose standalone addon is also installed and enabled stands aside (its files return at
-- once), so the standalone copy runs alone instead of both fighting over the same frames and globals.
local ADDON, root = ...

local COMPONENTS = {
	-- key in the private table, standalone folder name, display name
	{ key = "OpenMap", folder = "OpenMap", title = "OpenMap" },
	{ key = "SPF", folder = "ShortestPathForever", title = "Shortest Path Forever" },
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
for _, c in ipairs(COMPONENTS) do
	local sub = {}
	root[c.key] = sub
	if standaloneLoads(c.folder) then
		sub.__skip = true
		public.shadowed[#public.shadowed + 1] = c.title
	end
	public.components[c.key] = { folder = c.folder, title = c.title, active = not sub.__skip }
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
-- Options > AddOns > BookFinder, the game's own settings panel: every part's settings are pages of it (Shortest
-- Path's pages, OpenMap's World map, the Library books), and every way into any part's settings opens it there.
local category
local pages = {}                -- key -> the page's category, for OpenSettings(key)

-- BookFinder's category, made on first use (Shortest Path's settings build it at load, the others after)
function public.SettingsCategory()
	if not category and Settings and Settings.RegisterVerticalLayoutCategory then
		category = Settings.RegisterVerticalLayoutCategory("BookFinder")
	end
	return category
end

-- a part's page, by a key of its own ("map", "books", or a Shortest Path page's title)
function public.RegisterPage(key, page)
	if key and page then pages[key] = page end
end

-- the settings window, at a page when one is named and known
function public.OpenSettings(key)
	local target = (key and pages[key]) or public.SettingsCategory()
	if not target then return false end
	local id = target.GetID and target:GetID() or target.ID
	if ForeverCore and ForeverCore.OpenSettingsPanel then
		ForeverCore.OpenSettingsPanel(id)
	elseif Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(id)
	end
	return true
end

-- The category goes into the AddOns list once every page is in (Bridge.lua, at login)
function public.PublishSettings()
	if public.published or not category or not Settings.RegisterAddOnCategory then return end
	public.published = true
	Settings.RegisterAddOnCategory(category)
end

-- BookFinder's own saved settings (the minimap button), ready before any part's
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")
	BookFinderDB = type(BookFinderDB) == "table" and BookFinderDB or {}
	public.db = BookFinderDB
end)

_G.BookFinder = public
