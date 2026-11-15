-- NPC patrol paths (Questie's, kept by the owner: the only lines on the map besides OpenMap's boat routes): a creature
-- that walks a route has it drawn as a line, on the world map and the minimap, for every NPC whose quest icon is on
-- the map. Hostile creatures' paths in their own colour; hovering the NPC's icon lights its path.
--
--   paths.map / paths.minimap   on each      paths.width / paths.opacity      the line
--   paths.color / paths.hostileColor / paths.highlight / paths.highlightColor
--
-- The data: an NPC's waypoints, { [area] = { { {x, y}, ... }, ... } } (one list per path, 0..100 on the area's map).

local _, BF = ...

local Paths = {}
BF.Paths = Paths

local Marks, Zones, N = BF.Marks, BF.Zones, BF.N
local sqrt, sin, cos, abs = math.sqrt, math.sin, math.cos, math.abs

local highlighted -- the NPC whose path is lit

-- Which NPCs: those with a quest mark (not townsfolk) that walk a route. ---------------------------------------------

local walkers, walkersVersion = {}, -1

local function collect()
	if walkersVersion == Marks.version then return walkers end
	walkersVersion = Marks.version
	walkers = {}
	local seen = {}
	for map in pairs(Marks.byMap) do
		for _, pin in ipairs(Marks:On(map)) do
			local s = pin.source
			if s and s.type == "npc" and not seen[s.id] then
				local quest = false
				for _, r in ipairs(pin.roles) do if r.role ~= "townsfolk" then quest = true break end end
				if quest then
					seen[s.id] = true
					local row = BF:Npc(s.id)
					local wp = row and row[N.waypoints]
					if wp and next(wp) then
						walkers[#walkers + 1] = { npc = s.id, waypoints = wp, hostile = not BF.Player:FriendlyTo(row[N.friendlyTo]) }
					end
				end
			end
		end
	end
	return walkers
end

--- Every path as uiMap points: fn(npc, hostile, map, points) with points = { x1, y1, x2, y2, ... } (0..1).
local function eachPath(fn)
	for _, w in ipairs(collect()) do
		for area, list in pairs(w.waypoints) do
			local map = Zones:UiMapForArea(area)
			if map then
				for _, path in ipairs(list) do
					local pts = {}
					for _, p in ipairs(path) do
						if p[1] and p[1] >= 0 then pts[#pts + 1] = p[1] / 100 pts[#pts + 1] = p[2] / 100 end
					end
					if #pts >= 4 then fn(w.npc, w.hostile, map, pts) end
				end
			end
		end
	end
end
Paths.EachPath = eachPath

local function colourFor(npc, hostile)
	if BF:Get("paths.highlight") and highlighted == npc then return BF:Get("paths.highlightColor") end
	return hostile and BF:Get("paths.hostileColor") or BF:Get("paths.color")
end

-- Lines ------------------------------------------------------------------------------------------------------------

local function linePool(parent)
	local pool = { parent = parent, lines = {}, used = 0 }
	function pool:Begin() self.used = 0 end
	function pool:Line()
		self.used = self.used + 1
		local l = self.lines[self.used]
		if not l then
			l = self.parent:CreateLine(nil, "ARTWORK")
			l:SetTexture("Interface\\Buttons\\WHITE8X8")
			self.lines[self.used] = l
		end
		l:Show()
		return l
	end
	function pool:End() for i = self.used + 1, #self.lines do self.lines[i]:Hide() end end
	return pool
end

-- The world map: one frame over the whole canvas, its lines in canvas units (kept the same width on screen). ------

local mapFrame, mapLines

local function refreshMap()
	if not mapFrame then return end
	mapLines:Begin()
	local map = WorldMapFrame:GetMapID()
	if BF:Get("paths.map") and BF:Get("quests.map") and map then
		local w, h = mapFrame:GetWidth(), mapFrame:GetHeight()
		local scale = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale
			and WorldMapFrame.ScrollContainer:GetCanvasScale() or 1
		local width = BF:Get("paths.width") / math.max(0.05, scale)
		local opacity = BF:Get("paths.opacity")
		local api = rawget(_G, "OpenMapAPI")
		local stitched = api and api.IsStitched and api.IsStitched() and api.WorldFromMap and api.MapFromWorld
		-- (OpenMap's stitched art lies over the canvas: the lines go just above it, still under the icons)
		local top = stitched and api.ArtTopLevel and api.ArtTopLevel()
		local base = mapFrame:GetParent():GetFrameLevel() + 1
		mapFrame:SetFrameLevel(type(top) == "number" and math.max(base, top + 1) or base)
		local function place(from, x, y)
			if stitched then
				local u, v = api.WorldFromMap(from, x, y)
				if u then return api.MapFromWorld(map, u, v) end
				return nil
			end
			return Zones:Translate(from, x, y, map)
		end
		eachPath(function(npc, hostile, from, pts)
			local c = colourFor(npc, hostile)
			local lx, ly
			for i = 1, #pts, 2 do
				local x, y = place(from, pts[i], pts[i + 1])
				if x and lx and (x >= -0.5 and x <= 1.5) then
					local l = mapLines:Line()
					l:SetStartPoint("TOPLEFT", mapFrame, lx * w, -ly * h)
					l:SetEndPoint("TOPLEFT", mapFrame, x * w, -y * h)
					l:SetThickness(width)
					l:SetVertexColor(c[1], c[2], c[3], (c[4] or 1) * opacity)
				end
				lx, ly = x, y
			end
		end)
	end
	mapLines:End()
end
Paths.RefreshMap = refreshMap

local function installMap()
	if mapFrame or not (WorldMapFrame and WorldMapFrame.GetCanvas) then return end
	local canvas = WorldMapFrame:GetCanvas()
	mapFrame = CreateFrame("Frame", nil, canvas)
	mapFrame:SetAllPoints(canvas)
	-- Under the quest icons, over the map's art.
	mapFrame:SetFrameLevel(canvas:GetFrameLevel() + 1)
	mapLines = linePool(mapFrame)
	if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", refreshMap) end
	if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", refreshMap) end
end

-- The minimap: drawn again each update, like its pins. ---------------------------------------------------------------

local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local miniFrame, miniLines
local worldPaths, worldVersion = {}, -1   -- paths in world yards, for the player's continent

local function minimapYards()
	local zoom = Minimap:GetZoom()
	local indoors = GetCVar("minimapZoom") + 0 ~= zoom and GetCVar("minimapInsideZoom") + 0 == zoom
	return (indoors and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]
end

local function refreshMinimap()
	if not miniFrame then return end
	miniLines:Begin()
	local instance, px, py = Zones:PlayerWorld()
	if BF:Get("paths.minimap") and BF:Get("quests.minimap") and instance and Minimap:IsVisible() then
		if worldVersion ~= Marks.version or worldPaths.instance ~= instance then
			worldVersion, worldPaths = Marks.version, { instance = instance }
			eachPath(function(npc, hostile, map, pts)
				local wpts = {}
				for i = 1, #pts, 2 do
					local inst, wx, wy = Zones:ToWorld(map, pts[i], pts[i + 1])
					if inst == instance then wpts[#wpts + 1] = wx wpts[#wpts + 1] = wy end
				end
				if #wpts >= 4 then worldPaths[#worldPaths + 1] = { npc = npc, hostile = hostile, pts = wpts } end
			end)
		end
		local yards = minimapYards()
		local radius = yards / 2
		local ppy = Minimap:GetWidth() / yards
		local rotate = GetCVar("rotateMinimap") == "1"
		local facing = rotate and (GetPlayerFacing() or 0) or 0
		local cs, sn = cos(facing), sin(facing)
		local width, opacity = BF:Get("paths.width"), BF:Get("paths.opacity")
		local function project(wx, wy)
			local right, up = -(wy - py), wx - px
			if rotate then right, up = right * cs + up * sn, -right * sn + up * cs end
			return right, up
		end
		for _, p in ipairs(worldPaths) do
			local c = colourFor(p.npc, p.hostile)
			local lx, ly
			for i = 1, #p.pts, 2 do
				local x, y = project(p.pts[i], p.pts[i + 1])
				if lx then
					-- Only the part inside the minimap's circle: both ends within it.
					if sqrt(x * x + y * y) <= radius and sqrt(lx * lx + ly * ly) <= radius then
						local l = miniLines:Line()
						l:SetStartPoint("CENTER", Minimap, lx * ppy, ly * ppy)
						l:SetEndPoint("CENTER", Minimap, x * ppy, y * ppy)
						l:SetThickness(width)
						l:SetVertexColor(c[1], c[2], c[3], (c[4] or 1) * opacity)
					end
				end
				lx, ly = x, y
			end
		end
	end
	miniLines:End()
end
Paths.RefreshMinimap = refreshMinimap

--- Lights an NPC's path (its icon hovered), or none.
function Paths:Highlight(npc)
	if highlighted == npc then return end
	highlighted = npc
	refreshMap()
	refreshMinimap()
end

BF:At("login", function()
	installMap()
	miniFrame = CreateFrame("Frame", nil, Minimap)
	miniFrame:SetAllPoints(Minimap)
	miniFrame:SetFrameStrata("LOW")
	miniLines = linePool(miniFrame)
	local soon = BF:Debounce(0.2, function() refreshMap() end)
	BF:Listen("BF_MARKS_CHANGED", soon)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^paths%.") or key == "quests.map" or key == "quests.minimap" then refreshMap() refreshMinimap() end
	end)
	local api = rawget(_G, "OpenMapAPI")
	if api and api.RegisterCallback then
		pcall(api.RegisterCallback, Paths, "OpenMap_ViewChanged", soon)
		pcall(api.RegisterCallback, Paths, "OpenMap_StitchedChanged", soon)
	end
	if WorldMapFrame then WorldMapFrame:HookScript("OnShow", refreshMap) end
	local t = 0
	miniFrame:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		if t < 0.1 then return end
		t = 0
		refreshMinimap()
	end)
end, 72)
