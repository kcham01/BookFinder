-- Patrol paths: an NPC that walks has its route drawn as a line, on the world map and on the minimap, for the NPCs
-- the map marks (quest givers, turn-ins, objectives). Hostile NPCs in their own colour; hovering the NPC's pin
-- highlights its path. (Questie's patrol paths, docs/study/questie.md. The books' route trail is gone: docs/NOTES.md.)
--
-- Settings (Quests > Map / Look): paths.map, paths.minimap, paths.width, paths.opacity, paths.color,
-- paths.hostileColor, paths.highlight, paths.highlightColor.
--
-- The data gives each NPC's paths by area: {[area] = { {{x, y}, ...}, ... }} in percent of the area's map.

local _, BF = ...

local Paths = {}
BF.Paths = Paths

local Marks, Zones, Player = BF.Marks, BF.Zones, BF.Player
local N = BF.N
local TEMPLATE = "BookFinderPathPinTemplate"
local LEVEL_PATHS = "PIN_FRAME_LEVEL_BOOKFINDER_PATHS"

-- Which NPCs ----------------------------------------------------------------------------------------------------

--- NPC IDs marked on a map's pins (the pin's own NPC and every NPC an objective pack stands for).
function Paths:NpcsOn(map, into)
	into = into or {}
	for _, pin in ipairs(Marks:On(map)) do
		if pin.source and pin.source.type == "npc" then into[pin.source.id] = true end
		for _, r in ipairs(pin.roles) do
			if r.source and r.source.type == "npc" then into[r.source.id] = true end
			for _, s in ipairs(r.sources or {}) do
				if s.type == "npc" then into[s.id] = true end
			end
		end
	end
	return into
end

--- NPC IDs the pins at one spot stand for (for the highlight).
local function npcsOfPins(pins)
	local set = {}
	for _, pin in ipairs(pins or {}) do
		if pin.source and pin.source.type == "npc" then set[pin.source.id] = true end
		for _, r in ipairs(pin.roles or {}) do
			if r.source and r.source.type == "npc" then set[r.source.id] = true end
			for _, s in ipairs(r.sources or {}) do if s.type == "npc" then set[s.id] = true end end
		end
	end
	return set
end

local function isHostile(npc)
	local row = BF:Npc(npc)
	return row ~= nil and not Player:FriendlyTo(row[N.friendlyTo])
end

--- An NPC's paths as polylines on its own maps: { {map =, points = {{x, y}, ...}}, ... } (0..1), cached.
local polylines = {}
function Paths:Of(npc)
	local cached = polylines[npc]
	if cached then return cached end
	cached = {}
	local row = BF:Npc(npc)
	for area, list in pairs(row and row[N.waypoints] or {}) do
		local map = Zones:UiMapForArea(area)
		if map then
			for _, path in ipairs(list) do
				local points = {}
				for _, p in ipairs(path) do
					if p[1] and p[1] >= 0 and p[2] and p[2] >= 0 then points[#points + 1] = { p[1] / 100, p[2] / 100 } end
				end
				if #points >= 2 then cached[#cached + 1] = { map = map, points = points } end
			end
		end
	end
	polylines[npc] = cached
	return cached
end

local function colour(npc, highlighted)
	local c
	if highlighted then c = BF:Get("paths.highlightColor")
	elseif isHostile(npc) then c = BF:Get("paths.hostileColor")
	else c = BF:Get("paths.color") end
	return c[1], c[2], c[3], (c[4] or 1) * BF:Get("paths.opacity")
end

-- The highlight (hovering an NPC's pin on either map) ------------------------------------------------------------

local highlighted = {} -- [npc] = true

--- Highlights the paths of the NPCs the hovered pins stand for (several pins at one spot: all of them).
function Paths:Highlight(pins)
	highlighted = BF:Get("paths.highlight") and npcsOfPins(pins) or {}
	Paths:Recolour()
end

function Paths:Unhighlight()
	if next(highlighted) then
		highlighted = {}
		Paths:Recolour()
	end
end

-- World map -----------------------------------------------------------------------------------------------------
--
-- One pin covering the whole map canvas holds every line; it lives in the canvas, so it pans and zooms with the map.

BookFinderPathPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BookFinderPathPinMixin:OnLoad()
	self.lines, self.used = {}, 0
	self:EnableMouse(false)
end

local function lineOf(frame)
	frame.used = frame.used + 1
	local line = frame.lines[frame.used]
	if not line then
		line = frame:CreateLine(nil, "ARTWORK")
		line:SetColorTexture(1, 1, 1, 1)
		frame.lines[frame.used] = line
	end
	line:Show()
	return line
end

local function hideUnused(frame)
	for i = frame.used + 1, #frame.lines do frame.lines[i]:Hide() end
end

function BookFinderPathPinMixin:OnAcquired(map)
	self.used = 0
	self.drawn = {} -- { {line =, npc =} }
	local canvas = self:GetMap():GetCanvas()
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	self:SetSize(w, h)
	if self.SetIgnoreGlobalPinScale then self:SetIgnoreGlobalPinScale(true) end -- canvas units: zooms with the map
	self:SetPosition(0.5, 0.5)
	self:UseFrameLevelType(LEVEL_PATHS)
	local width = BF:Get("paths.width")
	local npcs = {}
	for _, source in ipairs(BF.WorldMap.SourcesOf(map)) do Paths:NpcsOn(source, npcs) end
	for npc in pairs(npcs) do
		for _, poly in ipairs(Paths:Of(npc)) do
			local last
			for _, p in ipairs(poly.points) do
				local x, y = Zones:Translate(poly.map, p[1], p[2], map)
				local here = x and { x, y } or nil
				if last and here and (here[1] >= 0 and here[1] <= 1 or last[1] >= 0 and last[1] <= 1)
					and (here[2] >= 0 and here[2] <= 1 or last[2] >= 0 and last[2] <= 1) then
					local line = lineOf(self)
					line:SetStartPoint("TOPLEFT", self, last[1] * w, -last[2] * h)
					line:SetEndPoint("TOPLEFT", self, here[1] * w, -here[2] * h)
					line:SetThickness(width)
					line:SetVertexColor(colour(npc, highlighted[npc]))
					self.drawn[#self.drawn + 1] = { line = line, npc = npc }
				end
				last = here
			end
		end
	end
	hideUnused(self)
end

function BookFinderPathPinMixin:OnReleased()
	self.used = 0
	hideUnused(self)
end

function BookFinderPathPinMixin:Recolour()
	for _, d in ipairs(self.drawn or {}) do
		d.line:SetVertexColor(colour(d.npc, highlighted[d.npc]))
		d.line:SetThickness(BF:Get("paths.width") * (highlighted[d.npc] and 1.5 or 1))
	end
end

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
Paths.Provider = Provider

function Provider:OnAdded(map)
	MapCanvasDataProviderMixin.OnAdded(self, map)
	-- Lines under every quest icon: their own layer, right above the map's highlight (objectives sit above it).
	local manager = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
	if manager and manager.InsertFrameLevelAbove then
		pcall(manager.InsertFrameLevelAbove, manager, LEVEL_PATHS, "PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	end
end

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
	self.pin = nil
end

function Provider:RefreshAllData()
	self:RemoveAllData()
	if not BF:Reached("login") or not BF:Get("quests.map") or not BF:Get("paths.map") then return end
	local map = self:GetMap():GetMapID()
	if not map then return end
	self.pin = self:GetMap():AcquirePin(TEMPLATE, map)
end

-- Minimap -------------------------------------------------------------------------------------------------------
--
-- Each segment is cut to the minimap's circle (or square) so no line pokes out past its edge.

-- The part of segment a->b (minimap pixels) inside a circle of radius r around 0, as t0, t1 in 0..1, or nil.
local function clipCircle(ax, ay, bx, by, r)
	local dx, dy = bx - ax, by - ay
	local A = dx * dx + dy * dy
	if A == 0 then return nil end
	local B = 2 * (ax * dx + ay * dy)
	local C = ax * ax + ay * ay - r * r
	local disc = B * B - 4 * A * C
	if disc <= 0 then return nil end
	local s = math.sqrt(disc)
	local t0, t1 = (-B - s) / (2 * A), (-B + s) / (2 * A)
	if t0 < 0 then t0 = 0 end
	if t1 > 1 then t1 = 1 end
	if t0 >= t1 then return nil end
	return t0, t1
end

-- The same for a square of half-width r (Liang-Barsky).
local function clipSquare(ax, ay, bx, by, r)
	local t0, t1 = 0, 1
	local dx, dy = bx - ax, by - ay
	local checks = { { -dx, ax + r }, { dx, r - ax }, { -dy, ay + r }, { dy, r - ay } }
	for _, c in ipairs(checks) do
		local p, q = c[1], c[2]
		if p == 0 then
			if q < 0 then return nil end
		else
			local t = q / p
			if p < 0 then
				if t > t1 then return nil end
				if t > t0 then t0 = t end
			else
				if t < t0 then return nil end
				if t < t1 then t1 = t end
			end
		end
	end
	if t0 >= t1 then return nil end
	return t0, t1
end
Paths.clipCircle, Paths.clipSquare = clipCircle, clipSquare

local mini -- the frame on the minimap holding its lines
local miniNpcs, miniMap, miniVersion -- the NPCs marked on the player's map, kept until the marks change
local worldPaths = {} -- [npc] = { { instance, {wx, wy}, ... }, ... }

local function worldOf(npc)
	local cached = worldPaths[npc]
	if cached then return cached end
	cached = {}
	for _, poly in ipairs(Paths:Of(npc)) do
		local list = {}
		for _, p in ipairs(poly.points) do
			local instance, wx, wy = Zones:ToWorld(poly.map, p[1], p[2])
			if instance then
				list.instance = instance
				list[#list + 1] = { wx, wy }
			end
		end
		if #list >= 2 then cached[#cached + 1] = list end
	end
	worldPaths[npc] = cached
	return cached
end

local function drawMinimap(view)
	if not mini then
		mini = CreateFrame("Frame", nil, Minimap)
		mini:SetAllPoints(Minimap)
		mini:SetFrameLevel(Minimap:GetFrameLevel() + 2)
		mini.lines, mini.used, mini.drawn = {}, 0, {}
	end
	mini.used, mini.drawn = 0, {}
	if not view or not BF:Get("paths.minimap") then
		hideUnused(mini)
		return
	end
	local map = C_Map.GetBestMapForUnit("player")
	if map ~= miniMap or miniVersion ~= Marks.version then
		miniMap, miniVersion = map, Marks.version
		miniNpcs = map and Paths:NpcsOn(map) or {}
	end
	local r = view.radius * view.pixelsPerYard
	local width = BF:Get("paths.width")
	local Pins = BF.MinimapPins
	for npc in pairs(miniNpcs) do
		for _, poly in ipairs(worldOf(npc)) do
			if poly.instance == view.instance then
				local lx, ly
				for i, p in ipairs(poly) do
					local x, y = Pins:Place(view, p[1] - view.px, p[2] - view.py)
					if i > 1 then
						local t0, t1
						if view.square then t0, t1 = clipSquare(lx, ly, x, y, r) else t0, t1 = clipCircle(lx, ly, x, y, r) end
						if t0 then
							local line = lineOf(mini)
							line:SetStartPoint("CENTER", Minimap, lx + (x - lx) * t0, ly + (y - ly) * t0)
							line:SetEndPoint("CENTER", Minimap, lx + (x - lx) * t1, ly + (y - ly) * t1)
							line:SetThickness(width * (highlighted[npc] and 1.5 or 1))
							line:SetVertexColor(colour(npc, highlighted[npc]))
							mini.drawn[#mini.drawn + 1] = { line = line, npc = npc }
						end
					end
					lx, ly = x, y
				end
			end
		end
	end
	hideUnused(mini)
end

--- Lines take their colours again (after a highlight or a colour setting).
function Paths:Recolour()
	if Provider.pin then Provider.pin:Recolour() end
	if mini then
		for _, d in ipairs(mini.drawn) do
			d.line:SetVertexColor(colour(d.npc, highlighted[d.npc]))
			d.line:SetThickness(BF:Get("paths.width") * (highlighted[d.npc] and 1.5 or 1))
		end
	end
end

-- Keeping it current ----------------------------------------------------------------------------------------------

local function refreshWorldMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then WorldMapFrame:AddDataProvider(Provider) end
	BF.MinimapPins:AfterUpdate(drawMinimap)
	BF:Listen("BF_MARKS_CHANGED", refreshWorldMap)
	BF:Listen("BF_PIN_ENTER", function(_, pins) Paths:Highlight(pins) end)
	BF:Listen("BF_PIN_LEAVE", function() Paths:Unhighlight() end)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key == "paths.map" or key == "paths.width" or key == "quests.map" then refreshWorldMap()
		elseif key:find("^paths%.") then Paths:Recolour() end
		if key:find("^paths%.") and BF.MinimapPins.Update then BF.MinimapPins.Update() end
	end)
end, 71)
