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
local BASE_SIZE = 24

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
WorldMap.SourcesOf = sourcesOf

local function mapType(map)
	local info = C_Map.GetMapInfo(map)
	return info and info.mapType
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

-- The provider ---------------------------------------------------------------------------------------------------

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
WorldMap.Provider = Provider

local LEVEL_OBJECTIVES = "PIN_FRAME_LEVEL_BOOKFINDER_OBJECTIVES"
local LEVEL_GIVERS = "PIN_FRAME_LEVEL_BOOKFINDER_GIVERS"
local levelsReady = false

function Provider:OnAdded(map)
	MapCanvasDataProviderMixin.OnAdded(self, map)
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
	local hideUnexplored = BF:Get("icons.hideUnexplored")
	local limit = BF:Get("icons.limitEnabled") and BF:Get("icons.limit") or math.huge
	local placed = 0
	for _, source in ipairs(sourcesOf(map)) do
		for _, pin in ipairs(Marks:On(source)) do
			local x, y = Zones:Translate(source, pin.x, pin.y, map)
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
	self:SetSize(size, size)
	if levelsReady then self:UseFrameLevelType(giver and LEVEL_GIVERS or LEVEL_OBJECTIVES) end
	local c = BF:Get("icons.glowMap") and Look:Glow(pin, false)
	if c then
		Icons:Apply(self.Glow, "glow")
		self.Glow:SetVertexColor(c[1], c[2], c[3], 1)
		self.Glow:SetSize(size * 1.4, size * 1.4)
		self.Glow:Show()
	else
		self.Glow:Hide()
	end
	self:SetPosition(x, y)
end

function BookFinderMapPinMixin:OnReleased()
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

function BookFinderMapPinMixin:OnMouseEnter()
	BF.PinTooltip:Show(self, pinsUnderCursor(self), false)
end

function BookFinderMapPinMixin:OnMouseLeave()
	BF.PinTooltip:Hide()
end

function BookFinderMapPinMixin:OnMouseUp(button)
	BF.PinTooltip:Click(self.pin, button, self.sourceMap, self)
end

-- Keeping it current ----------------------------------------------------------------------------------------------

local function refresh()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end
WorldMap.Refresh = refresh

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then
		WorldMapFrame:AddDataProvider(Provider)
	end
	BF:Listen("BF_MARKS_CHANGED", refresh)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^icons%.") or key == "quests.map" then refresh() end
	end)
end, 70)
