-- The seamless continent map (phase 12, step 1; being built): the continent's own map art with every zone's art laid
-- over it at its true place (BF.Stitch), in the map window, zooming toward the cursor with the wheel, dragged to pan,
-- right-click zooming out. A zone shown in the map window opens the canvas centred on that zone.
--
-- Not yet on it (the next steps, docs/BUILD.md "Next"): quest icons, books, pins and people (they still draw on the
-- game's own map), zone borders blended, minimap detail up close, dungeons, boats, flights. Until then it is a switch on
-- Map > Look, off by default.
--
-- Canvas units: one per yard. The world frame is scaled to zoom (pixels per yard) and offset to pan.

local _, BF = ...
local L = BF.L

local Canvas = {}
BF.WorldCanvas = Canvas

local Stitch = BF.Stitch

BF.Settings:Define("map.seamless", { default = false, page = "Map/Look", group = "The map",
	label = "Seamless continent map (being built)" })

local MIN_ZOOM_FACTOR, MAX_ZOOM = 0.8, 6 -- fit the continent down to 0.8 of the view; up to 6 pixels a yard

local frame, world, continent
local zoom, minZoom = 0.05, 0.01
local centre = { east = 0, north = 0 } -- the world point at the middle of the view

local function continentOf(map)
	local seen = 0
	while map and seen < 10 do
		local info = C_Map.GetMapInfo(map)
		if not info then return nil end
		if info.mapType == Enum.UIMapType.Continent then return map end
		if info.mapType < Enum.UIMapType.Continent then return nil end
		map = info.parentMapID
		seen = seen + 1
	end
end
Canvas.ContinentOf = continentOf

-- Drawing --------------------------------------------------------------------------------------------------------------

local layers = {} -- [continent] = { frames = {...} }: made once per continent

local function drawMap(parent, map, level)
	local tiles = Stitch:Tiles(map)
	if not tiles then return nil end
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	f:SetFrameLevel(level)
	for _, t in ipairs(tiles) do
		local tex = f:CreateTexture(nil, "ARTWORK")
		tex:SetTexture(t.file)
		tex:SetPoint("TOPLEFT", parent, "TOPLEFT", t.left, t.top)
		tex:SetSize(t.right - t.left, t.top - t.bottom)
	end
	return f
end

local function build(cont)
	if layers[cont] then return layers[cont] end
	local l = { frames = {} }
	local base = world:GetFrameLevel()
	local f = drawMap(world, cont, base + 1)
	if f then l.frames[#l.frames + 1] = f end
	for i, zone in ipairs(Stitch:Zones(cont)) do
		f = drawMap(world, zone, base + 1 + i)
		if f then l.frames[#l.frames + 1] = f end
	end
	layers[cont] = l
	return l
end

-- The world frame's TOPLEFT is the world origin (east 0, north 0): a point at (east, north) is drawn at (east, north) in
-- the frame's units, its scale is the zoom. Panning puts the centre point in the middle of the view.
local function layout()
	if not world then return end
	world:SetScale(zoom)
	local w, h = frame:GetWidth(), frame:GetHeight()
	world:ClearAllPoints()
	world:SetPoint("TOPLEFT", frame, "TOPLEFT", (w / 2) / zoom - centre.east, (-h / 2) / zoom - centre.north)
	world:SetSize(1, 1)
end

--- The world point under a point of the view (pixels from the view's top left, y down).
function Canvas:WorldAt(px, py)
	local w, h = frame:GetWidth(), frame:GetHeight()
	return centre.east + (px - w / 2) / zoom, centre.north - (py - h / 2) / zoom
end

function Canvas:Zoom() return zoom end
function Canvas:Centre() return centre.east, centre.north end

--- Fits a map's rectangle in the view.
function Canvas:Fit(map)
	local _, left, top, right, bottom = Stitch.Corners(map)
	if not left then return end
	local w, h = frame:GetWidth(), frame:GetHeight()
	centre.east, centre.north = (left + right) / 2, (top + bottom) / 2
	zoom = math.min(w / math.abs(right - left), h / math.abs(top - bottom))
	layout()
end

--- Zooms by a factor, keeping the world point under (px, py) still.
function Canvas:ZoomAt(factor, px, py)
	local e, n = Canvas:WorldAt(px, py)
	local new = math.max(minZoom, math.min(MAX_ZOOM, zoom * factor))
	local w, h = frame:GetWidth(), frame:GetHeight()
	zoom = new
	centre.east = e - (px - w / 2) / zoom
	centre.north = n + (py - h / 2) / zoom
	layout()
end

function Canvas:Pan(dx, dy) -- in pixels
	centre.east = centre.east - dx / zoom
	centre.north = centre.north + dy / zoom
	layout()
end

-- The view's cursor point (pixels from its top left, y down).
local function cursor()
	local x, y = GetCursorPosition()
	local s = frame:GetEffectiveScale()
	local left, top = frame:GetLeft() or 0, frame:GetTop() or 0
	return x / s - left, top - y / s
end

-- Showing --------------------------------------------------------------------------------------------------------------

function Canvas:Show(map)
	local cont = continentOf(map)
	if not cont or not Stitch:Bounds(cont) then Canvas:Hide() return end
	for c, l in pairs(layers) do for _, f in ipairs(l.frames) do f:SetShown(c == cont) end end
	build(cont)
	local left, top, right, bottom = Stitch:Bounds(cont)
	minZoom = MIN_ZOOM_FACTOR * math.min(frame:GetWidth() / math.abs(right - left), frame:GetHeight() / math.abs(top - bottom))
	if cont ~= continent or map ~= continent then
		Canvas:Fit(map ~= cont and map or cont)
	end
	continent = cont
	frame:Show()
end

function Canvas:Hide()
	if frame then frame:Hide() end
end

local function sync()
	if not BF:Get("map.seamless") or not WorldMapFrame:IsShown() then Canvas:Hide() return end
	Canvas:Show(WorldMapFrame:GetMapID())
end

local function makeFrame()
	local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
	frame = CreateFrame("Frame", "BookFinderWorldCanvas", parent)
	frame:SetAllPoints(parent)
	frame:SetFrameLevel(parent:GetFrameLevel() + 15)
	frame:SetClipsChildren(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetColorTexture(0.12, 0.09, 0.05, 1)
	world = CreateFrame("Frame", nil, frame)
	world:SetFrameLevel(frame:GetFrameLevel() + 1)
	frame:SetScript("OnMouseWheel", function(_, delta)
		local px, py = cursor()
		Canvas:ZoomAt(delta > 0 and 1.25 or 0.8, px, py)
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			local x, y = GetCursorPosition()
			self.dragFrom = { x, y }
			self:SetScript("OnUpdate", function()
				local nx, ny = GetCursorPosition()
				local s = self:GetEffectiveScale()
				Canvas:Pan((nx - self.dragFrom[1]) / s, -(ny - self.dragFrom[2]) / s)
				self.dragFrom = { nx, ny }
			end)
		elseif button == "RightButton" then
			local px, py = cursor()
			Canvas:ZoomAt(0.5, px, py)
		end
	end)
	frame:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	frame:Hide()
	Canvas.frame = frame
end

BF:At("login", function()
	if not WorldMapFrame then return end
	makeFrame()
	hooksecurefunc(WorldMapFrame, "SetMapID", sync)
	WorldMapFrame:HookScript("OnShow", sync)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "map.seamless" then sync() end end)
end, 78)
