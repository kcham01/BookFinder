-- The quest marks on the world map: a data provider on the game's map canvas (WorldMapFrame), so the pins live
-- where the game's own pins live and move with its zoom and pan. BookFinder's own world map (Map/World*.lua) hosts
-- the same provider.
--
-- The map shown draws its own marks plus those of every map inside it (a city in its zone, every zone on a continent),
-- placed through the maps' world positions (BF.Zones).

local _, BF = ...

local WorldMap = {}
BF.WorldMap = WorldMap

local Marks, Look, Icons, Zones = BF.Marks, BF.Look, BF.Icons, BF.Zones
local TEMPLATE = "BookFinderMapPinTemplate"
local BASE_SIZE = 16 -- (Questie's: 16 times the icon's scale times the map's)

-- Which maps' marks a map shows --------------------------------------------------------------------------------

local sources = {}
local function sourcesOf(map)
	local list = sources[map]
	if list then return list end
	list = { map }
	if C_Map.GetMapChildrenInfo then
		for _, child in ipairs(C_Map.GetMapChildrenInfo(map, nil, true) or {}) do
			list[#list + 1] = child.mapID
		end
	end
	sources[map] = list
	return list
end

local function mapType(map)
	local info = C_Map.GetMapInfo(map)
	return info and info.mapType
end

local function isWorldOrWider(map)
	local t = mapType(map)
	return t ~= nil and Enum and Enum.UIMapType and t <= Enum.UIMapType.World
end

local function isContinentOrWider(map)
	local t = mapType(map)
	return t ~= nil and Enum and Enum.UIMapType and t <= Enum.UIMapType.Continent
end

-- Unexplored areas (icons.hideUnexplored): asked of the client once per spot.
local explored = {}
local function isExplored(map, x, y)
	if not C_MapExplorationInfo or not C_MapExplorationInfo.GetExploredAreaIDsAtPosition then return true end
	local key = map .. ":" .. math.floor(x * 200) .. ":" .. math.floor(y * 200)
	local v = explored[key]
	if v == nil then
		v = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(map, CreateVector2D(x, y)) ~= nil
		explored[key] = v
	end
	return v
end
BF:On("MAP_EXPLORATION_UPDATED", function() wipe(explored) end)

-- A pin that is only a flight master, while OpenMap draws its own flight masters on the world map: left to OpenMap
-- (one icon for one thing; BookFinder's still shows on the minimap).
local function leftToOpenMap(pin)
	if not (BF.OpenMap and BF.OpenMap:DrawsFlightMasters()) then return false end
	for _, r in ipairs(pin.roles or {}) do
		if r.role ~= "townsfolk" or not r.kind or r.kind.key ~= "flightMaster" then return false end
	end
	return true
end

-- The provider ---------------------------------------------------------------------------------------------------

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
WorldMap.Provider = Provider

local LEVEL_OBJECTIVES = "PIN_FRAME_LEVEL_BOOKFINDER_OBJECTIVES"
local LEVEL_GIVERS = "PIN_FRAME_LEVEL_BOOKFINDER_GIVERS"
local levelsReady = false

local function buildPin(pin)
	pin:SetSize(16, 16)
	pin.Glow = pin:CreateTexture(nil, "BACKGROUND")
	pin.Glow:SetPoint("CENTER")
	pin.Icon = pin:CreateTexture(nil, "ARTWORK")
	-- (as Questie: no snapping to the pixel grid, so small icons scale smoothly instead of jagged)
	for _, t in ipairs({ pin.Icon, pin.Glow }) do
		if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
		if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	end
	pin.Icon:SetAllPoints()
	BF.PinPool:Wire(pin)
end

function Provider:OnAdded(map)
	MapCanvasDataProviderMixin.OnAdded(self, map)
	BF.PinPool:Register(map, TEMPLATE, BookFinderMapPinMixin, buildPin)
	-- Our pins' own layers in the map's stack: objectives above the map's highlight, givers above them.
	local manager = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
	if manager and manager.InsertFrameLevelAbove then
		local ok1 = pcall(manager.InsertFrameLevelAbove, manager, LEVEL_OBJECTIVES, "PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
		local ok2 = ok1 and pcall(manager.InsertFrameLevelAbove, manager, LEVEL_GIVERS, LEVEL_OBJECTIVES)
		levelsReady = ok1 and ok2
	end
end

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function Provider:RefreshAllData()
	self:RemoveAllData()
	if not BF:Reached("login") or not BF:Get("quests.map") then return end
	local map = self:GetMap():GetMapID()
	if not map then return end
	if BF:Get("icons.hideOnContinents") and isContinentOrWider(map) then return end
	-- On OpenMap's stitched map: every zone's marks, placed through its API on the map underneath (past its edges too,
	-- where the stitched view shows beyond it).
	local api = rawget(_G, "OpenMapAPI")
	if api and api.IsStitched and api.IsStitched() and api.WorldFromMap and api.MapFromWorld then
		local placed = 0
		for source in pairs(Marks.byMap) do
			for _, pin in ipairs(Marks:On(source)) do
				local u, v
				if not leftToOpenMap(pin) then u, v = api.WorldFromMap(source, pin.x, pin.y) end
				local x, y
				if u then x, y = api.MapFromWorld(map, u, v) end
				if x and x > -1 and x < 2 and y > -1 and y < 2 then
					self:GetMap():AcquirePin(TEMPLATE, pin, x, y, source)
					placed = placed + 1
				end
			end
		end
		return
	end
	local hideUnexplored = BF:Get("icons.hideUnexplored")
	local limit = BF:Get("icons.limitEnabled") and BF:Get("icons.limit") or math.huge
	local placed = 0
	for _, source in ipairs(sourcesOf(map)) do
		for _, pin in ipairs(Marks:On(source)) do
			local x, y
			if not leftToOpenMap(pin) then x, y = Zones:Translate(source, pin.x, pin.y, map) end
			if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (not hideUnexplored or isExplored(map, x, y)) then
				self:GetMap():AcquirePin(TEMPLATE, pin, x, y, source)
				placed = placed + 1
				if placed >= limit then return end
			end
		end
	end
end

-- The pin --------------------------------------------------------------------------------------------------------

BookFinderMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BookFinderMapPinMixin:OnLoad()
	self:SetScalingLimits(1, 1.0, 1.15)
	-- Right-click goes through to the map (zoom out), as on the game's own pins. Not allowed in combat: tried again
	-- when the pin is next shown.
	if self.SetPassThroughButtons and not InCombatLockdown() then pcall(self.SetPassThroughButtons, self, "RightButton") end
end

function BookFinderMapPinMixin:OnAcquired(pin, x, y, sourceMap)
	self.pin, self.sourceMap = pin, sourceMap
	self.mapX, self.mapY = x, y
	local kind, scaleKey, giver = Look:Kind(pin)
	Icons:Apply(self.Icon, kind)
	local size = scaleKey == "townsfolk" and BASE_SIZE * BF:Get("icons.townsfolkMapScale")
		or BASE_SIZE * BF:Get("icons.mapScale") * BF:Get("icons.scale." .. scaleKey)
	local party = Look:PartyOnly(pin)
	if party then size = size * 0.85 end
	self:SetAlpha(party and 0.6 or 1)
	self:SetSize(size, size)
	if levelsReady then self:UseFrameLevelType(giver and LEVEL_GIVERS or LEVEL_OBJECTIVES) end
	local c = BF:Get("icons.glowMap") and Look:Glow(pin, false)
	if c then
		Icons:Apply(self.Glow, "glow")
		self.Glow:SetVertexColor(c[1], c[2], c[3], 1)
		self.Glow:SetSize(size * 1.13, size * 1.13)
		self.Glow:Show()
	else
		self.Glow:Hide()
	end
	self:SetPosition(x, y)
end

function BookFinderMapPinMixin:OnReleased()
	self.Icon:SetVertexColor(1, 1, 1, 1)
	self.pin, self.sourceMap = nil, nil
end

--- Every BookFinder pin under the cursor (several at one spot are listed together).
local function pinsUnderCursor(self)
	local list = {}
	local cx, cy = GetCursorPosition()
	for other in self:GetMap():EnumeratePinsByTemplate(TEMPLATE) do
		if other:IsVisible() then
			local scale = other:GetEffectiveScale()
			local ox, oy = other:GetCenter()
			if ox then
				local half = other:GetWidth() * 0.5
				local dx, dy = cx / scale - ox, cy / scale - oy
				if math.abs(dx) <= half and math.abs(dy) <= half then list[#list + 1] = other.pin end
			end
		end
	end
	if #list == 0 then list[1] = self.pin end
	return list
end

-- Hovering an objective lights every icon of the same quest's objectives in Questie's hover blue (givers and turn-ins
-- keep their own colour), so its spread across the map shows at a glance.
local tinted = {}
local function questOf(pin)
	local lead = Look:Lead(pin)
	return lead and lead.role == "objective" and lead.quest or nil
end

local function tintQuest(self)
	local quest = questOf(self.pin)
	if not quest then return end
	for other in self:GetMap():EnumeratePinsByTemplate(TEMPLATE) do
		if other.pin and questOf(other.pin) == quest then
			other.Icon:SetVertexColor(0.6, 1, 1, 1)
			tinted[#tinted + 1] = other
		end
	end
end

local function untint()
	for i = #tinted, 1, -1 do
		local other = tinted[i]
		if other.pin then other.Icon:SetVertexColor(1, 1, 1, 1) end
		tinted[i] = nil
	end
end

function BookFinderMapPinMixin:OnMouseEnter()
	BF.PinTooltip:Show(self, pinsUnderCursor(self), false)
	tintQuest(self)
	local s = self.pin and self.pin.source
	if BF.Paths and s and s.type == "npc" then BF.Paths:Highlight(s.id) end
end

function BookFinderMapPinMixin:OnMouseLeave()
	BF.PinTooltip:Hide()
	untint()
	if BF.Paths then BF.Paths:Highlight(nil) end
end

function BookFinderMapPinMixin:OnMouseClickAction(button)
	BF.PinTooltip:Click(self.pin, button, self.sourceMap, self)
end
-- (the canvas calls OnMouseUp, then OnMouseClickAction when released over the pin: the click is the latter)
function BookFinderMapPinMixin:OnMouseUp() end
function BookFinderMapPinMixin:OnMouseDown() end

-- Keeping it current ----------------------------------------------------------------------------------------------

local function refresh()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end
WorldMap.Refresh = refresh

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then
		WorldMapFrame:AddDataProvider(Provider)
	end
	-- OpenMap's stitched view moved: the marks of the zones now in view (a few times a second at most).
	local api = rawget(_G, "OpenMapAPI")
	if api and api.RegisterCallback then
		local soon = BF:Debounce(0.15, refresh)
		pcall(api.RegisterCallback, WorldMap, "OpenMap_ViewChanged", soon)
		pcall(api.RegisterCallback, WorldMap, "OpenMap_StitchedChanged", soon)
	end
	BF:Listen("BF_MARKS_CHANGED", refresh)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^icons%.") or key == "quests.map" or key == "openmap.flight" then refresh() end
	end)
end, 70)
