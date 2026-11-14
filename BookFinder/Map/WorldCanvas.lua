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
		-- A dungeon's (or a cave's) own map stays the game's: its floors are not part of the continent.
		if seen == 0 and info.mapType > Enum.UIMapType.Zone then return nil end
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
	-- The explored areas over the base art (a classic map leaves unexplored land blank and paints each explored
	-- area on top), in a frame of their own so they can be drawn again as the player explores.
	f.explored = CreateFrame("Frame", nil, f)
	f.explored:SetAllPoints(parent)
	f.explored:SetFrameLevel(level)
	f.map = map
	Canvas.DrawExplored(f)
	return f
end

--- (Re)draws a map's explored areas into its frame.
function Canvas.DrawExplored(f)
	f.exploredTex = f.exploredTex or {}
	for _, t in ipairs(f.exploredTex) do t:Hide() end
	local parent = f.explored:GetParent():GetParent()
	for i, piece in ipairs(Stitch:Explored(f.map)) do
		local tex = f.exploredTex[i]
		if not tex then
			tex = f.explored:CreateTexture(nil, "OVERLAY")
			f.exploredTex[i] = tex
		end
		tex:SetTexture(piece.file)
		tex:SetTexCoord(0, piece.u, 0, piece.v)
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", parent, "TOPLEFT", piece.left, piece.top)
		tex:SetSize(piece.right - piece.left, piece.top - piece.bottom)
		tex:Show()
	end
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

-- Icons -----------------------------------------------------------------------------------------------------------------
--
-- Other files draw on the canvas through layers: Canvas:AddLayer(name, fn(continent, add)), where
-- add(east, north, spec) puts an icon at a world point. spec: { kind = BF.Icons kind | file = texture, size = pixels,
-- tint = {r, g, b}?, onEnter = fn(button), onLeave = fn(button)?, onClick = fn(button, mouseButton), data fields... }.
-- Icons keep their size on screen; only those in view are drawn; they are drawn again shortly after every zoom or pan.

local layerList = {}
local overlay
local pool, used = {}, 0
local lines, linesUsed = {}, 0 -- Line regions on the overlay (patrol paths): add.line(e1, n1, e2, n2, spec)

function Canvas:AddLayer(name, fn)
	for _, l in ipairs(layerList) do if l.name == name then l.fn = fn return end end
	layerList[#layerList + 1] = { name = name, fn = fn }
end

local function iconButton()
	used = used + 1
	local b = pool[used]
	if not b then
		b = CreateFrame("Button", nil, overlay)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetAllPoints()
		b.Label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.Label:SetPoint("TOP", b, "BOTTOM", 0, -1)
		b:SetScript("OnEnter", function(self) if self.spec.onEnter then self.spec.onEnter(self) end end)
		b:SetScript("OnLeave", function(self)
			if self.spec.onLeave then self.spec.onLeave(self) else GameTooltip:Hide() end
		end)
		b:SetScript("OnClick", function(self, button) if self.spec.onClick then self.spec.onClick(self, button) end end)
		pool[used] = b
	end
	b:Show()
	return b
end

function Canvas:Redraw()
	if not frame or not frame:IsShown() or not continent then return end
	for i = 1, used do pool[i]:Hide() end
	for i = 1, linesUsed do lines[i]:Hide() end
	linesUsed = 0
	used = 0
	local w, h = frame:GetWidth(), frame:GetHeight()
	local function add(east, north, spec)
		local px = (east - centre.east) * zoom + w / 2
		local py = (centre.north - north) * zoom + h / 2
		if px < -20 or py < -20 or px > w + 20 or py > h + 20 then return end
		local b = iconButton()
		b.spec = spec
		for k, v in pairs(spec) do if k ~= "onEnter" and k ~= "onLeave" and k ~= "onClick" then b[k] = v end end
		if spec.kind then BF.Icons:Apply(b.Icon, spec.kind) else
			b.Icon:SetTexture(spec.file)
			b.Icon:SetVertexColor(1, 1, 1, 1)
		end
		if spec.tint then b.Icon:SetVertexColor(spec.tint[1], spec.tint[2], spec.tint[3], 1) end
		b:SetSize(spec.size or 20, spec.size or 20)
		b.Label:SetText(spec.label or "")
		b:ClearAllPoints()
		b:SetPoint("CENTER", frame, "TOPLEFT", px, -py)
	end
	-- A line between two world points (spec: { thickness, colour = {r, g, b, a} }), cut off where it leaves the view.
	local function line(e1, n1, e2, n2, spec)
		local x1, y1 = (e1 - centre.east) * zoom + w / 2, (centre.north - n1) * zoom + h / 2
		local x2, y2 = (e2 - centre.east) * zoom + w / 2, (centre.north - n2) * zoom + h / 2
		if (x1 < 0 and x2 < 0) or (x1 > w and x2 > w) or (y1 < 0 and y2 < 0) or (y1 > h and y2 > h) then return end
		linesUsed = linesUsed + 1
		local l = lines[linesUsed]
		if not l then
			l = overlay:CreateLine(nil, "BACKGROUND")
			l:SetColorTexture(1, 1, 1, 1)
			lines[linesUsed] = l
		end
		l:SetStartPoint("TOPLEFT", frame, x1, -y1)
		l:SetEndPoint("TOPLEFT", frame, x2, -y2)
		l:SetThickness(spec.thickness or 2)
		local c = spec.colour or { 1, 1, 1, 1 }
		l:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		l:Show()
	end
	local api = setmetatable({ line = line }, { __call = function(_, ...) return add(...) end })
	for _, l in ipairs(layerList) do BF.safecall(l.fn, continent, api) end
end

local redrawSoon = BF:Debounce(0.05, function() Canvas:Redraw() end)

--- A world point (east, north yards) from a map's point; nil if the map is in another world than the continent.
function Canvas:WorldOf(map, x, y)
	local instance, wx, wy = BF.Zones:ToWorld(map, x, y)
	if not instance then return nil end
	return -wy, wx, instance
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
	redrawSoon()
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

--- Centres the view on a world point at a zoom (pixels per yard; kept within the canvas's limits).
function Canvas:CentreOn(east, north, atZoom)
	centre.east, centre.north = east, north
	zoom = math.max(minZoom, math.min(MAX_ZOOM, atZoom or zoom))
	layout()
end

function Canvas:Pan(dx, dy) -- in pixels
	centre.east = centre.east - dx / zoom
	centre.north = centre.north + dy / zoom
	layout()
end

--- The zone under a world point: the smallest zone map of the continent whose rectangle holds it (and its 0..1 point).
function Canvas:ZoneAt(east, north)
	local best, bestArea, bx, by
	for _, z in ipairs(Stitch:Zones(continent or 0)) do
		local x, y = Stitch:ToMap(z, east, north)
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			local _, l, t, r, b = Stitch.Corners(z)
			local area = math.abs((r - l) * (t - b))
			if not bestArea or area < bestArea then best, bestArea, bx, by = z, area, x, y end
		end
	end
	return best, bx, by
end

-- The view's cursor point (pixels from its top left, y down).
local function cursor()
	local x, y = GetCursorPosition()
	local s = frame:GetEffectiveScale()
	local left, top = frame:GetLeft() or 0, frame:GetTop() or 0
	return x / s - left, top - y / s
end

--- The line at the bottom of the canvas: "Elwynn Forest (1-10)  45.2, 63.1" for the zone under the cursor.
function Canvas:HoverText()
	if not frame:IsMouseOver() then return "" end
	local zone, x, y = Canvas:ZoneAt(Canvas:WorldAt(cursor()))
	if not zone then return "" end
	local text = BF.Zones:MapName(zone) or ""
	local low, high
	if C_Map.GetMapLevels then low, high = C_Map.GetMapLevels(zone) end
	if low and high and low > 0 then
		local c = GetQuestDifficultyColor and GetQuestDifficultyColor(low)
		local levels = low == high and tostring(low) or (low .. "-" .. high)
		text = text .. (c and ("  |cff%02x%02x%02x(%s)|r"):format(c.r * 255, c.g * 255, c.b * 255, levels) or ("  (" .. levels .. ")"))
	end
	return text .. "   " .. BF.Coords:Format(x, y)
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
	overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 200) -- above every zone's art
	Canvas.overlay = overlay
	frame:SetScript("OnMouseWheel", function(_, delta)
		local px, py = cursor()
		Canvas:ZoomAt(delta > 0 and 1.25 or 0.8, px, py)
	end)
	-- The zone under the cursor: its name, its levels (coloured for the player), the cursor's place on it.
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.label:SetPoint("BOTTOMRIGHT", -8, 8)
	frame:SetScript("OnUpdate", nil)
	frame.hover = 0
	local hoverFrame = CreateFrame("Frame", nil, frame)
	hoverFrame:SetScript("OnUpdate", function(_, e)
		frame.hover = frame.hover + e
		if frame.hover < 0.1 then return end
		frame.hover = 0
		frame.label:SetText(Canvas:HoverText())
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		if Canvas.inputHook and Canvas.inputHook("down", button) then return end
		if button == "LeftButton" then
			local x, y = GetCursorPosition()
			self.dragFrom = { x, y }
			self.downAt = { x, y }
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
	frame:SetScript("OnMouseUp", function(self, button)
		self:SetScript("OnUpdate", nil)
		if Canvas.inputHook and Canvas.inputHook("up", button) then return end
		-- A click that did not drag: into the zone under the cursor.
		if button == "LeftButton" and self.downAt then
			local x, y = GetCursorPosition()
			if math.abs(x - self.downAt[1]) + math.abs(y - self.downAt[2]) < 4 then
				local zone = Canvas:ZoneAt(Canvas:WorldAt(cursor()))
				if zone then Canvas:Fit(zone) end
			end
		end
		self.downAt = nil
	end)
	frame:Hide()
	Canvas.frame = frame
end

BF:At("login", function()
	if not WorldMapFrame then return end
	makeFrame()
	hooksecurefunc(WorldMapFrame, "SetMapID", sync)
	-- New ground explored: the zones of the continents drawn so far paint it.
	BF:On("MAP_EXPLORATION_UPDATED", function()
		for _, l in pairs(layers) do for _, f in ipairs(l.frames) do Canvas.DrawExplored(f) end end
	end)
	WorldMapFrame:HookScript("OnShow", sync)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "map.seamless" then sync() end end)
end, 78)
