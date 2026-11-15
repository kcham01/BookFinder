-- BookFinder's seamless world map: one world inside the game's map window, every zone's art stitched in place, zoomed
-- smoothly from the whole world down to the street and panned freely across zones and continents.
--
-- Built from the game's own map art (the owner's rule): each map's art tiles (C_Map.GetMapArtLayerTextures) and its
-- explored pieces (C_MapExplorationInfo.GetExploredMapTextures), placed where the game lays the map on Azeroth's map
-- (C_Map.GetMapRectOnMap(map, 947)). Coordinates on the surface are Azeroth's map, 0..1.
--
-- Mouse: wheel zooms toward the cursor; drag pans; left-click glides into the zone under the cursor; right-click steps
-- out (zone -> continent -> world); middle-click centres on the player; Ctrl-click drops the map pin. Once the view
-- rests, the zone in view becomes the game's current map, so the quest log beside it follows.
--
-- Layers (bottom to top): the world's art; continents (from a little zoom); zones and their explored pieces (once a
-- zone is big enough on screen); cities (closer still); then pins, the player's arrow, the coordinates.

local _, BF = ...
local L = BF.L

local Seamless = {}
BF.Seamless = Seamless

local AZEROTH = 947
local exp, floor, max, min, abs = math.exp, math.floor, math.max, math.min, math.abs

local S = BF.Settings
S:Define("map.seamless", { default = true, page = "Map/Look", label = "Seamless world map" })
S:Define("map.deepestZoom", { default = 30, min = 10, max = 120, step = 5, page = "Map/Look", label = "Deepest zoom" })
S:Define("map.smooth", { default = true, page = "Map/Look", label = "Smooth zoom and pan" })

-- Geometry -----------------------------------------------------------------------------------------------------------

local function rectOf(map)
	if map == AZEROTH then return 0, 1, 0, 1 end
	local r = BF.Zones.RectOnMap(map, AZEROTH)
	if not r then return nil end
	return r[1], r[2], r[3], r[4]
end

local function mapType(map)
	local info = C_Map.GetMapInfo(map)
	return info and info.mapType
end

-- Every map to draw: continents, their zones, the cities and smaller maps inside those, with rects on Azeroth.
local maps -- { {id, minX, maxX, minY, maxY, type, depth}, ... } sorted by size, largest first
local function collect()
	maps = {}
	local seen = {}
	local function add(id, depth)
		if seen[id] then return end
		seen[id] = true
		local x0, x1, y0, y1 = rectOf(id)
		local t = mapType(id)
		if x0 and t and t ~= Enum.UIMapType.Dungeon then
			maps[#maps + 1] = { id = id, x0 = x0, x1 = x1, y0 = y0, y1 = y1, type = t, depth = depth, area = (x1 - x0) * (y1 - y0) }
		end
		for _, child in ipairs(C_Map.GetMapChildrenInfo(id) or {}) do
			if child.mapType ~= Enum.UIMapType.Dungeon then add(child.mapID, depth + 1) end
		end
	end
	add(AZEROTH, 0)
	table.sort(maps, function(a, b) return a.area > b.area end)
end

-- The frames ---------------------------------------------------------------------------------------------------------

local view, surface, overlay
local BASE = 1000 -- the surface's width in its own units (the whole world)
local state = { u = 0.5, v = 0.5, zoom = 1, tu = 0.5, tv = 0.5, tzoom = 1 }
local artByMap = {} -- [map id] = { textures = {}, built = bool, shown = bool, overlays = {} }

local function heightRatio()
	local info = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(AZEROTH)
	local l = info and info[1]
	if l and l.layerWidth and l.layerWidth > 0 then return l.layerHeight / l.layerWidth end
	return 2 / 3
end

local RATIO = 2 / 3

-- The scale that fits the whole world in the view, times the zoom.
local function fitScale()
	local w, h = view:GetSize()
	if w == 0 then return 1 end
	return min(w / BASE, h / (BASE * RATIO))
end

local function scaleNow() return fitScale() * state.zoom end

-- Places the surface so (u, v) is at the view's centre.
local function place()
	local s = scaleNow()
	surface:SetScale(s)
	local w, h = view:GetSize()
	-- (Points of a scaled frame are in its own units.)
	surface:ClearAllPoints()
	surface:SetPoint("TOPLEFT", view, "TOPLEFT", (w / 2) / s - state.u * BASE, -((h / 2) / s - state.v * BASE * RATIO))
end

--- The world point (u, v on Azeroth) under the cursor.
local function cursorUV()
	local x, y = GetCursorPosition()
	local es = view:GetEffectiveScale()
	x, y = x / es, y / es
	local left, top = view:GetLeft(), view:GetTop()
	local w, h = view:GetSize()
	local dx, dy = x - (left + w / 2), (top - h / 2) - y
	return state.u + dx / (scaleNow() * BASE), state.v + dy / (scaleNow() * BASE * RATIO)
end

-- Art ------------------------------------------------------------------------------------------------------------------

local function newTexture(layer, sub)
	local t = surface:CreateTexture(nil, layer, nil, sub)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
	return t
end

-- A map's base art: its tiles laid over its rect on the surface (the last row and column cut to the art's edge).
local function buildArt(entry, sub)
	local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(entry.id)
	local layer = layers and layers[1]
	if not layer then return {} end
	local files = C_Map.GetMapArtLayerTextures(entry.id, 1) or {}
	local cols = math.ceil(layer.layerWidth / layer.tileWidth)
	local rows = math.ceil(layer.layerHeight / layer.tileHeight)
	local px = (entry.x1 - entry.x0) * BASE / layer.layerWidth            -- surface units per art pixel
	local py = (entry.y1 - entry.y0) * BASE * RATIO / layer.layerHeight
	local list = {}
	for row = 1, rows do
		for col = 1, cols do
			local file = files[(row - 1) * cols + col]
			if file then
				local t = newTexture("BACKGROUND", sub)
				t:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR")
				local wPix = (col < cols) and layer.tileWidth or (layer.layerWidth - layer.tileWidth * (cols - 1))
				local hPix = (row < rows) and layer.tileHeight or (layer.layerHeight - layer.tileHeight * (rows - 1))
				t:SetTexCoord(0, wPix / layer.tileWidth, 0, hPix / layer.tileHeight)
				t:SetSize(wPix * px + px, hPix * py + py) -- one art pixel over the next tile: no seam between tiles
				t:SetPoint("TOPLEFT", surface, "TOPLEFT", entry.x0 * BASE + (col - 1) * layer.tileWidth * px,
					-(entry.y0 * BASE * RATIO + (row - 1) * layer.tileHeight * py))
				list[#list + 1] = t
			end
		end
	end
	entry.pixelX, entry.pixelY = px, py
	return list
end

-- A zone's explored pieces (the painted land the player has found), each cut from 256-pixel tiles.
local function nextPow2(n)
	local p = 16
	while p < n do p = p * 2 end
	return p
end

local function buildExplored(entry, sub)
	local list = {}
	if not (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and entry.pixelX) then return list end
	for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(entry.id) or {}) do
		local wide = math.ceil(info.textureWidth / 256)
		local tall = math.ceil(info.textureHeight / 256)
		for j = 1, tall do
			local hPix = (j < tall) and 256 or (info.textureHeight - 256 * (tall - 1))
			for k = 1, wide do
				local wPix = (k < wide) and 256 or (info.textureWidth - 256 * (wide - 1))
				local file = info.fileDataIDs[(j - 1) * wide + k]
				if file then
					local t = newTexture("BORDER", sub)
					t:SetTexture(file, "CLAMP", "CLAMP", "TRILINEAR")
					t:SetTexCoord(0, wPix / nextPow2(wPix), 0, hPix / nextPow2(hPix))
					t:SetSize(wPix * entry.pixelX + entry.pixelX, hPix * entry.pixelY + entry.pixelY)
					t:SetPoint("TOPLEFT", surface, "TOPLEFT",
						entry.x0 * BASE + (info.offsetX + 256 * (k - 1)) * entry.pixelX,
						-(entry.y0 * BASE * RATIO + (info.offsetY + 256 * (j - 1)) * entry.pixelY))
					list[#list + 1] = t
				end
			end
		end
	end
	return list
end

local function setShown(list, shown, alpha)
	for _, t in ipairs(list) do
		t:SetShown(shown)
		if shown then t:SetAlpha(alpha) end
	end
end

-- Which maps show at this zoom: a map fades in as it grows on screen (a zone once it is ~220 px wide), and only maps
-- in view are built and shown.
local function screenWidth(entry) return (entry.x1 - entry.x0) * BASE * scaleNow() end

local function inView(entry)
	local w, h = view:GetSize()
	local s = scaleNow()
	local halfU, halfV = (w / 2) / (s * BASE), (h / 2) / (s * BASE * RATIO)
	return entry.x1 >= state.u - halfU and entry.x0 <= state.u + halfU and entry.y1 >= state.v - halfV and entry.y0 <= state.v + halfV
end

-- What each map draws, so the world reads as one: the world's own picture always; a continent's picture once the
-- continent is wider than the view (its painted frame then lies off-screen); a zone only its explored land, the pieces
-- the game cuts to the land's shape (they blend into each other and into the continent, no frames, no rectangles);
-- a map with no such pieces (a city) its own picture once it fills most of the view.
local function hasPieces(entry)
	if entry.pieces == nil then
		local list = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and C_MapExplorationInfo.GetExploredMapTextures(entry.id)
		entry.pieces = (list and #list > 0) or false
	end
	return entry.pieces
end

local function alphaFor(entry)
	if entry.id == AZEROTH then return 1 end
	local w = screenWidth(entry)
	local vw = view:GetWidth()
	if entry.type == Enum.UIMapType.Continent then
		-- Only once the whole view lies inside the continent's picture: its painted frame never shows.
		local vh = view:GetHeight()
		local sc = scaleNow()
		local halfU, halfV = (vw / 2) / (sc * BASE), (vh / 2) / (sc * BASE * RATIO)
		local inside = min(state.u - halfU - entry.x0, entry.x1 - (state.u + halfU),
			state.v - halfV - entry.y0, entry.y1 - (state.v + halfV))
		-- (a margin of a twentieth of the view to fade across)
		return max(0, min(1, inside / (halfU * 0.1) + 1)) * max(0, min(1, (w - vw) / (vw * 0.3)))
	end
	if hasPieces(entry) then
		return max(0, min(1, (w - 120) / 120))
	end
	return max(0, min(1, (w - vw * 0.8) / (vw * 0.4)))
end

local function updateArt()
	for _, entry in ipairs(maps) do
		local a = artByMap[entry.id]
		local alpha = alphaFor(entry)
		local visible = alpha > 0 and inView(entry)
		if visible and not a then
			-- Sublayers keep the order: world, continents, zones, cities.
			local sub = min(7, -8 + entry.depth * 3)
			local piecesOnly = entry.type >= Enum.UIMapType.Zone and hasPieces(entry)
			a = { base = {} }
			if piecesOnly then
				-- Pieces are placed in the base picture's pixels: its size only.
				local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(entry.id)
				local layer = layers and layers[1]
				if layer then
					entry.pixelX = (entry.x1 - entry.x0) * BASE / layer.layerWidth
					entry.pixelY = (entry.y1 - entry.y0) * BASE * RATIO / layer.layerHeight
				end
			else
				a.base = buildArt(entry, sub)
			end
			a.explored = buildExplored(entry, min(7, sub + 1))
			artByMap[entry.id] = a
		end
		if a then
			setShown(a.base, visible, alpha)
			setShown(a.explored, visible, alpha)
			-- Close in, a continent's picture is the land not explored yet: greyed and dimmed, so the explored land
			-- reads in full colour against it (and its big lettering fades away).
			if entry.type == Enum.UIMapType.Continent and visible then
				local close = max(0, min(1, (screenWidth(entry) / view:GetWidth() - 2.5) / 2.5))
				local shade = 1 - 0.45 * close
				for _, t in ipairs(a.base) do
					if t.SetDesaturation then t:SetDesaturation(0.6 * close) end
					t:SetVertexColor(shade, shade * 0.97, shade * 0.92)
				end
			end
		end
	end
end

-- Exploration changes: a zone's explored pieces are made again.
BF:On("MAP_EXPLORATION_UPDATED", function()
	for id, a in pairs(artByMap) do
		for _, t in ipairs(a.explored or {}) do t:Hide() end
		local entry
		for _, e in ipairs(maps or {}) do if e.id == id then entry = e end end
		if entry then a.explored = buildExplored(entry, min(7, -8 + entry.depth * 3 + 1)) end
	end
	if view and view:IsShown() then updateArt() end
end)

-- Pins -----------------------------------------------------------------------------------------------------------------
--
-- Quest marks and books for the maps in view, kept the same size on screen whatever the zoom.

local pinPool, pinsActive = {}, {}
local PIN = 24

local function acquirePin()
	local p = table.remove(pinPool)
	if not p then
		p = CreateFrame("Button", nil, overlay)
		p:SetSize(PIN, PIN)
		p.Glow = p:CreateTexture(nil, "BACKGROUND")
		p.Glow:SetPoint("CENTER")
		p.Icon = p:CreateTexture(nil, "ARTWORK")
		p.Icon:SetAllPoints()
		p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		p:SetScript("OnEnter", function(self)
			if self.book then BF.BookMap:ShowTooltip(self, self.book, self.place)
			else BF.PinTooltip:Show(self, { self.pin }, false) end
		end)
		p:SetScript("OnLeave", function() GameTooltip:Hide() end)
		p:SetScript("OnClick", function(self, button)
			if self.book then BF.BookMap:Click(self.book, self.place, button)
			else BF.PinTooltip:Click(self.pin, button, nil, self) end
		end)
	end
	p:Show()
	pinsActive[#pinsActive + 1] = p
	return p
end

local function releasePins()
	for i = #pinsActive, 1, -1 do
		local p = pinsActive[i]
		p:Hide()
		p.pin, p.book, p.place = nil, nil, nil
		pinPool[#pinPool + 1] = p
		pinsActive[i] = nil
	end
end

-- Surface (u, v) -> point on the overlay (unscaled, in the view's own units).
local function toView(u, v)
	local w, h = view:GetSize()
	local s = scaleNow()
	return w / 2 + (u - state.u) * BASE * s, -(h / 2 + (v - state.v) * BASE * RATIO * s)
end

local function placePin(p, u, v)
	local x, y = toView(u, v)
	p:ClearAllPoints()
	p:SetPoint("CENTER", overlay, "TOPLEFT", x, y)
end

local pinsDirty = true
local function updatePins()
	releasePins()
	local w, h = view:GetSize()
	local function visible(x, y) return x >= -20 and x <= w + 20 and -y >= -20 and -y <= h + 20 end
	if BF:Get("quests.map") then
		for _, entry in ipairs(maps) do
			-- A zone's marks once it is big enough on screen to read them (or the player's own zone).
			if entry.type >= Enum.UIMapType.Zone and screenWidth(entry) > 240 and inView(entry) then
				for _, pin in ipairs(BF.Marks:On(entry.id)) do
					local u = entry.x0 + (entry.x1 - entry.x0) * pin.x
					local v = entry.y0 + (entry.y1 - entry.y0) * pin.y
					local x, y = toView(u, v)
					if visible(x, y) then
						local p = acquirePin()
						p.pin = pin
						local kind, scaleKey = BF.Look:Kind(pin)
						BF.Icons:Apply(p.Icon, kind)
						local size = scaleKey == "townsfolk" and PIN * BF:Get("icons.townsfolkMapScale")
							or PIN * BF:Get("icons.mapScale") * BF:Get("icons.scale." .. scaleKey)
						p:SetSize(size, size)
						local c = BF:Get("icons.glowMap") and BF.Look:Glow(pin, false)
						if c then
							BF.Icons:Apply(p.Glow, "glow")
							p.Glow:SetVertexColor(c[1], c[2], c[3], 1)
							p.Glow:SetSize(size * 1.4, size * 1.4)
							p.Glow:Show()
						else
							p.Glow:Hide()
						end
						p:SetFrameLevel(overlay:GetFrameLevel() + (scaleKey == "available" and 6 or 3))
						placePin(p, u, v)
					end
				end
			end
		end
	end
	if BF:Get("books.map") then
		for _, book in ipairs(BF.Books.list) do
			if BF.BookMap:Shows(book) then
				for _, place in ipairs(BF.Books:Places(book)) do
					local x0, x1, y0, y1 = rectOf(place.map)
					if x0 then
						local u, v = x0 + (x1 - x0) * place.x, y0 + (y1 - y0) * place.y
						local x, y = toView(u, v)
						if visible(x, y) then
							local p = acquirePin()
							p.book, p.place = book, place
							p.Icon:SetTexture(BF.Books:Icon(book))
							p.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
							p.Glow:Hide()
							local size = BF:Get("books.mapSize") * (state.zoom < 3 and 0.7 or 1)
							p:SetSize(size, size)
							p:SetFrameLevel(overlay:GetFrameLevel() + 8)
							placePin(p, u, v)
						end
					end
				end
			end
		end
	end
	pinsDirty = false
end

-- The player's arrow -----------------------------------------------------------------------------------------------------

local arrow
local function updateArrow()
	local map, x, y = BF.Zones:PlayerPosition()
	local x0, x1, y0, y1
	if map then x0, x1, y0, y1 = rectOf(map) end
	if not x0 then arrow:Hide() return end
	local u, v = x0 + (x1 - x0) * x, y0 + (y1 - y0) * y
	local px, py = toView(u, v)
	arrow:ClearAllPoints()
	arrow:SetPoint("CENTER", overlay, "TOPLEFT", px, py)
	local facing = GetPlayerFacing()
	if facing and not (issecretvalue and issecretvalue(facing)) then arrow.tex:SetRotation(facing) end
	arrow:Show()
end

-- Coordinates ------------------------------------------------------------------------------------------------------------

--- The deepest map (zone, city) under a world point, and the point on it.
local function mapAt(u, v)
	for i = #maps, 1, -1 do
		local e = maps[i]
		if e.type >= Enum.UIMapType.Zone and u >= e.x0 and u <= e.x1 and v >= e.y0 and v <= e.y1 then
			local x, y = (u - e.x0) / (e.x1 - e.x0), (v - e.y0) / (e.y1 - e.y0)
			-- Rects overlap at borders: the zone that really holds the spot, where the game can say.
			if C_Map.GetMapInfoAtPosition then
				local info = C_Map.GetMapInfoAtPosition(e.id, x, y)
				if not info or info.mapID == e.id then return e, x, y end
			else
				return e, x, y
			end
		end
	end
	for _, e in ipairs(maps) do
		if e.type == Enum.UIMapType.Continent and u >= e.x0 and u <= e.x1 and v >= e.y0 and v <= e.y1 then
			return e, (u - e.x0) / (e.x1 - e.x0), (v - e.y0) / (e.y1 - e.y0)
		end
	end
end
Seamless.MapAt = mapAt

local coordText
local function updateCoords()
	if not BF:Get("coords.map") then coordText:SetText("") return end
	local parts = {}
	if view:IsMouseOver() then
		local e, x, y = mapAt(cursorUV())
		if e then parts[#parts + 1] = ("%s: %s %s"):format(L["Cursor"], BF.Zones:MapName(e.id) or "", BF.Zones:FormatCoords(x, y)) end
	end
	-- (the player's own coordinates: the game shows them on this map already)
	coordText:SetText(table.concat(parts, "    "))
end

-- Moving the view ------------------------------------------------------------------------------------------------------

-- The view never leaves the world: centred while the world is smaller than the view, its edges held at the view's
-- edges once it is larger.
local function clampTargets()
	state.tzoom = max(1, min(BF:Get("map.deepestZoom"), state.tzoom))
	local w, h = view:GetSize()
	local s = fitScale() * state.tzoom
	local halfU, halfV = (w / 2) / (s * BASE), (h / 2) / (s * BASE * RATIO)
	if halfU >= 0.5 then state.tu = 0.5 else state.tu = max(halfU, min(1 - halfU, state.tu)) end
	if halfV >= 0.5 then state.tv = 0.5 else state.tv = max(halfV, min(1 - halfV, state.tv)) end
end

--- Glides to (u, v) at `zoom` (nil keeps it).
function Seamless:FlyTo(u, v, zoom, instant)
	state.tu, state.tv = u, v
	if zoom then state.tzoom = zoom end
	clampTargets()
	if instant or not BF:Get("map.smooth") then
		state.u, state.v, state.zoom = state.tu, state.tv, state.tzoom
		place()
		updateArt()
		pinsDirty = true
	end
end

--- Shows a whole map (a zone fills the view, with a margin).
function Seamless:ShowMap(map, instant)
	local x0, x1, y0, y1 = rectOf(map)
	if not x0 then return end
	local w, h = view:GetSize()
	local fit = fitScale()
	local zoomW = w / ((x1 - x0) * BASE * fit)
	local zoomH = h / ((y1 - y0) * BASE * RATIO * fit)
	Seamless:FlyTo((x0 + x1) / 2, (y0 + y1) / 2, min(zoomW, zoomH) * 0.92, instant)
end

-- The zone in view becomes the game's map once the view rests (so the quest log beside it follows).
local syncing = false
local restSince, lastSynced = 0, nil
local function syncGameMap()
	local e
	if state.zoom < 2.2 then
		e = { id = AZEROTH }
	else
		e = mapAt(state.u, state.v)
		if e and e.type > Enum.UIMapType.Zone and state.zoom < 12 then
			-- a city or cave only when it fills the view
			local parentInfo = C_Map.GetMapInfo(e.id)
			if parentInfo and parentInfo.parentMapID then e = { id = parentInfo.parentMapID } end
		end
	end
	if e and e.id ~= lastSynced and WorldMapFrame:GetMapID() ~= e.id then
		syncing = true
		WorldMapFrame:SetMapID(e.id)
		syncing = false
	end
	lastSynced = e and e.id
end

local function onUpdate(_, elapsed)
	local moving = false
	if BF:Get("map.smooth") then
		local k = 1 - exp(-elapsed * 14)
		local function step(cur, target)
			local d = target - cur
			if abs(d) < 1e-6 then return target, false end
			return cur + d * k, true
		end
		local m1, m2, m3
		state.zoom, m1 = step(state.zoom, state.tzoom)
		state.u, m2 = step(state.u, state.tu)
		state.v, m3 = step(state.v, state.tv)
		moving = m1 or m2 or m3
	end
	if moving then
		place()
		updateArt()
		pinsDirty = true
		restSince = 0
	else
		restSince = restSince + elapsed
		if restSince > 0.35 and restSince - elapsed <= 0.35 then syncGameMap() end
	end
	if pinsDirty then updatePins() end
	updateArrow()
	updateCoords()
end

-- Mouse ----------------------------------------------------------------------------------------------------------------

local drag
local function onWheel(_, delta)
	local cu, cv = cursorUV()
	local old = state.tzoom
	state.tzoom = max(1, min(BF:Get("map.deepestZoom"), old * (delta > 0 and 1.35 or 1 / 1.35)))
	-- Zoom toward the cursor: the point under it stays under it.
	local ratio = old / state.tzoom
	state.tu = cv and (cu + (state.tu - cu) * ratio) or state.tu
	state.tv = cv and (cv + (state.tv - cv) * ratio) or state.tv
	clampTargets()
	if not BF:Get("map.smooth") then Seamless:FlyTo(state.tu, state.tv, state.tzoom, true) end
end

local function onDown(_, button)
	if button == "LeftButton" then
		local x, y = GetCursorPosition()
		drag = { x = x, y = y, u = state.tu, v = state.tv, moved = false }
	end
end

local function onUp(_, button)
	if button == "LeftButton" and drag then
		local wasDrag = drag.moved
		drag = nil
		if wasDrag then return end
		local u, v = cursorUV()
		if IsControlKeyDown() and BF:Get("map.ctrlClickPin") then
			local e, x, y = mapAt(u, v)
			if e then BF.Waypoint:Set(e.id, x, y, L["Map pin"], BF.Zones:MapName(e.id)) end
			return
		end
		-- Into the zone under the cursor (a continent first from the world).
		local e = mapAt(u, v)
		if e then
			if state.zoom < 2 then
				local info = C_Map.GetMapInfo(e.id)
				local cont = info
				while cont and cont.mapType and cont.mapType > Enum.UIMapType.Continent and cont.parentMapID do
					cont = C_Map.GetMapInfo(cont.parentMapID)
				end
				Seamless:ShowMap(cont and cont.mapID or e.id)
			else
				Seamless:ShowMap(e.id)
			end
		end
	elseif button == "RightButton" then
		-- Out a step: a city or cave -> its zone -> its continent -> the world.
		local e = mapAt(state.u, state.v)
		local info = e and C_Map.GetMapInfo(e.id)
		local parent = info and info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
		local fitsNow = e and screenWidth(e) <= view:GetWidth() * 1.2
		if e and not fitsNow then
			Seamless:ShowMap(e.id)
		elseif parent and parent.mapType and parent.mapType >= Enum.UIMapType.Continent then
			Seamless:ShowMap(parent.mapID)
		else
			Seamless:FlyTo(0.5, 0.5, 1)
		end
	elseif button == "MiddleButton" then
		Seamless:FindMe()
	end
end

local function onDragUpdate()
	if not drag then return end
	local x, y = GetCursorPosition()
	local dx, dy = x - drag.x, y - drag.y
	if not drag.moved and dx * dx + dy * dy < 16 then return end
	drag.moved = true
	local es = view:GetEffectiveScale()
	local s = scaleNow()
	state.tu = drag.u - (dx / es) / (s * BASE)
	state.tv = drag.v + (dy / es) / (s * BASE * RATIO)
	state.u, state.v = state.tu, state.tv
	clampTargets()
	place()
	updateArt()
	pinsDirty = true
end

function Seamless:FindMe()
	local map, x, y = BF.Zones:PlayerPosition()
	local x0, x1, y0, y1
	if map then x0, x1, y0, y1 = rectOf(map) end
	if x0 then Seamless:FlyTo(x0 + (x1 - x0) * x, y0 + (y1 - y0) * y, max(state.tzoom, 14)) end
end

-- Building and switching ------------------------------------------------------------------------------------------------

local function build()
	local container = WorldMapFrame.ScrollContainer
	view = CreateFrame("Frame", "BookFinderSeamlessMap", container)
	view:SetAllPoints(container)
	view:SetClipsChildren(true)
	view:SetFrameLevel(container:GetFrameLevel() + 2)
	-- The map's own buttons (Show, floors, the quest log toggle) stay above the view.
	for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do
		if f.GetFrameLevel and f:GetFrameLevel() <= view:GetFrameLevel() + 12 then f:SetFrameLevel(view:GetFrameLevel() + 12) end
	end
	view:EnableMouse(true)
	view:EnableMouseWheel(true)
	view:SetScript("OnMouseWheel", onWheel)
	view:SetScript("OnMouseDown", onDown)
	view:SetScript("OnMouseUp", onUp)
	view:SetScript("OnUpdate", function(self, elapsed)
		onDragUpdate()
		onUpdate(self, elapsed)
	end)
	local bg = view:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAllPoints()
	bg:SetColorTexture(0.11, 0.09, 0.06, 1)

	surface = CreateFrame("Frame", nil, view)
	RATIO = heightRatio()
	surface:SetSize(BASE, BASE * RATIO)

	overlay = CreateFrame("Frame", nil, view)
	overlay:SetAllPoints(view)
	overlay:SetFrameLevel(view:GetFrameLevel() + 5)

	arrow = CreateFrame("Frame", nil, overlay)
	arrow:SetSize(28, 28)
	arrow:SetFrameLevel(overlay:GetFrameLevel() + 20)
	arrow.tex = arrow:CreateTexture(nil, "OVERLAY")
	arrow.tex:SetAllPoints()
	arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")

	coordText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	coordText:SetPoint("BOTTOMRIGHT", view, "BOTTOMRIGHT", -48, 10)

	collect()
	place()
	view:Hide()
end

-- OpenMap (folded into BookFinder's download) is the map when it is there: BookFinder's own steps aside.
local function openMapThere()
	-- (inside BookFinder's download, folded into BookFinder: its API global says it is there)
	return rawget(_G, "OpenMapAPI") ~= nil or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("OpenMap")) or false
end
Seamless.OpenMapThere = openMapThere

local function active() return BF:Get("map.seamless") and not openMapThere() end

-- The game's map moved (its zone menu, the quest log, another addon): the view flies there, unless it was us.
local function onGameMap()
	if syncing or not view or not view:IsShown() then return end
	local map = WorldMapFrame:GetMapID()
	if map and map ~= lastSynced then
		lastSynced = map
		if map == AZEROTH then Seamless:FlyTo(0.5, 0.5, 1) else Seamless:ShowMap(map) end
	end
end

local function show()
	if not active() then
		if view then view:Hide() end
		return
	end
	if not view then build() end
	view:Show()
	-- Open on the player's zone, the way the map opens.
	local map = WorldMapFrame:GetMapID() or C_Map.GetBestMapForUnit("player")
	lastSynced = map
	if map == AZEROTH then Seamless:FlyTo(0.5, 0.5, 1, true) else Seamless:ShowMap(map, true) end
end

BF:At("login", function()
	if not (WorldMapFrame and WorldMapFrame.ScrollContainer and C_Map.GetMapArtLayerTextures) then return end
	WorldMapFrame:HookScript("OnShow", show)
	hooksecurefunc(WorldMapFrame, "OnMapChanged", onGameMap)
	BF:Listen("BF_MARKS_CHANGED", function() pinsDirty = true end)
	BF:Listen("BF_BOOKS_CHANGED", function() pinsDirty = true end)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key == "map.seamless" and WorldMapFrame:IsShown() then show() end
		if key:find("^icons%.") or key:find("^books%.") or key:find("^quests%.") then pinsDirty = true end
	end)
end, 90)

Seamless.State = state
