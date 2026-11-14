-- Find a place (OpenMap's search, docs/study/openmap.md "The OpenMap menu"): a search box at the seamless map's top
-- left. Two letters or more list the places whose names hold them, by kind (Continent, Zone, Raid, Dungeon, Flight
-- master), in the one dropdown; choosing one takes the map there.

local _, BF = ...
local L = BF.L

local Find = {}
BF.FindPlace = Find

local Canvas = BF.WorldCanvas
local RAIDS = { [2717] = true, [2159] = true, [2677] = true, [1977] = true, [3429] = true, [3428] = true, [3456] = true }
local MAX_PER_KIND = 12

-- Every place, by kind (worked out on the first search; flight masters from the continent in view each time).
local places
local function all()
	if places then return places end
	places = {}
	local world = 947
	for _, c in ipairs(C_Map.GetMapChildrenInfo(world, Enum.UIMapType.Continent, true) or {}) do
		places[#places + 1] = { kind = "Continent", name = c.name, map = c.mapID }
		for _, z in ipairs(C_Map.GetMapChildrenInfo(c.mapID, Enum.UIMapType.Zone, true) or {}) do
			places[#places + 1] = { kind = "Zone", name = z.name, map = z.mapID }
		end
	end
	for area, d in pairs(BF.Data.dungeons) do
		local e = d[4] and d[4][1]
		local outside = e and BF.Zones:UiMapForArea(e[1])
		if outside then
			places[#places + 1] = { kind = RAIDS[area] and "Raid" or "Dungeon", name = d[1], map = BF.Zones:UiMapForArea(area),
				at = { outside, e[2] / 100, e[3] / 100 } }
		end
	end
	return places
end

local ORDER = { "Continent", "Zone", "Raid", "Dungeon", "Flight master" }

--- The places matching a text, in ORDER, at most MAX_PER_KIND of each.
function Find:Search(text)
	text = strtrim(text or ""):lower()
	if #text < 2 then return {} end
	local list = {}
	for _, p in ipairs(all()) do list[#list + 1] = p end
	local cont = Canvas.ContinentOf(WorldMapFrame:GetMapID())
	for _, node in ipairs(cont and Canvas.FlightNodes(cont) or {}) do
		if node.position then
			list[#list + 1] = { kind = "Flight master", name = node.name, at = { cont, node.position.x, node.position.y } }
		end
	end
	local byKind = {}
	for _, p in ipairs(list) do
		if p.name and p.name:lower():find(text, 1, true) then
			byKind[p.kind] = byKind[p.kind] or {}
			if #byKind[p.kind] < MAX_PER_KIND then table.insert(byKind[p.kind], p) end
		end
	end
	local out = {}
	for _, kind in ipairs(ORDER) do
		local group = byKind[kind]
		if group then
			table.sort(group, function(a, b) return a.name < b.name end)
			for _, p in ipairs(group) do out[#out + 1] = p end
		end
	end
	return out
end

--- Takes the map to a place: a continent or zone opens on it; a dungeon, raid or flight master is centred, close.
function Find:Go(p)
	if p.kind == "Continent" or p.kind == "Zone" then
		WorldMapFrame:SetMapID(p.map)
		return
	end
	local map, x, y = p.at[1], p.at[2], p.at[3]
	local cont = Canvas.ContinentOf(map)
	if cont then WorldMapFrame:SetMapID(cont) end
	local east, north = Canvas:WorldOf(map, x, y)
	if east and Canvas.frame:IsShown() then
		Canvas:CentreOn(east, north, 0.4)
	elseif p.map then
		WorldMapFrame:SetMapID(p.map)
	end
end

local function items(text)
	local out = {}
	local lastKind
	for _, p in ipairs(Find:Search(text)) do
		if p.kind ~= lastKind then
			out[#out + 1] = { text = L[p.kind], title = true }
			lastKind = p.kind
		end
		out[#out + 1] = { text = p.name, func = function() Find:Go(p) end }
	end
	if #out == 0 then out[1] = { text = L["Nothing found."], title = true } end
	return out
end

BF:At("login", function()
	local canvas = Canvas.frame
	if not canvas then return end
	local box = CreateFrame("EditBox", "BookFinderFindPlace", canvas, BF.Widgets:Template({ "SearchBoxTemplate", "InputBoxTemplate" }))
	box:SetSize(180, 20)
	box:SetPoint("TOPLEFT", 12, -10)
	box:SetFrameLevel(canvas:GetFrameLevel() + 250)
	box:SetAutoFocus(false)
	if type(box.Instructions) == "table" then box.Instructions:SetText(L["Find a place"]) end
	box:HookScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		if #strtrim(text) >= 2 then BF.Dropdown:Open(self, items(text)) else BF.Dropdown:Close() end
	end)
	box:SetScript("OnEnterPressed", function(self)
		local first = Find:Search(self:GetText())[1]
		if first then Find:Go(first) end
		BF.Dropdown:Close()
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self) BF.Dropdown:Close() self:ClearFocus() end)
	Find.box = box
end, 80)
