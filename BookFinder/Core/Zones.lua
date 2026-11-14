-- Zones and coordinates.
--
-- The data places things by **area ID** with x, y in percent of that area's map. The client draws by **uiMapID**
-- with x, y in 0..1. This file turns one into the other, places instance spawns at their dungeon's entrance, and
-- measures distances in yards.
--
-- Each map's corners are asked of the client once (C_Map.GetWorldPosFromMapPos) and kept: after that a point moves
-- between maps (zone -> continent -> world) and distances are measured with arithmetic only, never an API call per pin.
-- World vectors from the client: .x grows northwards and .y westwards; a map's x grows eastwards, its y southwards,
-- so map x follows world -y and map y follows world -x.

local _, BF = ...

local Zones = {}
BF.Zones = Zones

local Data = BF.Data
local floor, sqrt = math.floor, math.sqrt

-- Area -> map ---------------------------------------------------------------------------------------------------

local areaMapCache = {}

--- The uiMapID an area's coordinates belong to, or nil (instances and areas the client has no map for).
function Zones:UiMapForArea(area)
	local cached = areaMapCache[area]
	if cached ~= nil then return cached or nil end
	local map = Data.areaToUiMap[area]
	if not map then
		local parent = Data.subZoneToParent[area]
		if parent then map = Data.areaToUiMap[parent] end
	end
	if map == 0 then map = nil end
	areaMapCache[area] = map or false
	return map
end

--- The area ID the client's map belongs to (for quests by zone), or nil.
function Zones:AreaForUiMap(map)
	return Data.uiMapToArea[map]
end

--- The dungeon or raid an area is (or belongs to), as its entry in BF.Data.dungeons: {name, alt areas, parent, entrances}.
local dungeonByArea
function Zones:Dungeon(area)
	if not dungeonByArea then
		dungeonByArea = {}
		for id, entry in pairs(Data.dungeons) do
			dungeonByArea[id] = id
			if entry[2] then for _, alt in ipairs(entry[2]) do dungeonByArea[alt] = id end end
		end
	end
	local id = dungeonByArea[area]
	if not id and Data.subZoneToParent[area] then id = dungeonByArea[Data.subZoneToParent[area]] end
	return id and Data.dungeons[id], id
end

--- Calls fn(uiMapID, x, y, insideAreaID) for every point of a spawn list ({area = {{x, y}, ...}}): x, y in 0..1.
--- A spawn inside a dungeon or raid is given twice: on the instance's own map (where the client has one), and at
--- each of the instance's entrances outside with insideAreaID set, so zone maps can show it at the door.
function Zones:EachSpawn(spawns, fn)
	if not spawns then return end
	for area, points in pairs(spawns) do
		local map = Zones:UiMapForArea(area)
		if map then
			for i = 1, #points do
				local p = points[i]
				if p[1] and p[1] >= 0 and p[2] and p[2] >= 0 then fn(map, p[1] / 100, p[2] / 100, nil) end
			end
		end
		local dungeon = Zones:Dungeon(area)
		if dungeon and dungeon[4] then
			for _, entrance in ipairs(dungeon[4]) do
				local outside = Zones:UiMapForArea(entrance[1])
				if outside and outside ~= map then fn(outside, entrance[2] / 100, entrance[3] / 100, area) end
			end
		end
	end
end

-- Map geometry --------------------------------------------------------------------------------------------------

local rects = {} -- [uiMapID] = { instance, ax, ay, bx, by } world corners of map (0,0) and (1,1); false if none

local function rect(map)
	local r = rects[map]
	if r ~= nil then return r or nil end
	r = false
	if map and C_Map.GetWorldPosFromMapPos then
		local instance, a = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 0))
		local _, b = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(1, 1))
		if instance and a and b then
			local ax, ay = a:GetXY()
			local bx, by = b:GetXY()
			if ax ~= bx and ay ~= by then r = { instance, ax, ay, bx, by } end
		end
	end
	rects[map] = r
	return r or nil
end

--- World position of a map point: instance (continent) ID, world x (north), world y (west). nil if unknown.
function Zones:ToWorld(map, x, y)
	local r = rect(map)
	if not r then return nil end
	return r[1], r[2] + (r[4] - r[2]) * y, r[3] + (r[5] - r[3]) * x
end

--- A world position on a map: x, y in 0..1 (may fall outside 0..1: the point is off that map). nil if another world.
function Zones:FromWorld(map, instance, wx, wy)
	local r = rect(map)
	if not r or r[1] ~= instance then return nil end
	return (wy - r[3]) / (r[5] - r[3]), (wx - r[2]) / (r[4] - r[2])
end

--- A point of one map on another (zone to continent, continent to zone...). nil if they are different worlds.
function Zones:Translate(fromMap, x, y, toMap)
	if fromMap == toMap then return x, y end
	local instance, wx, wy = Zones:ToWorld(fromMap, x, y)
	if not instance then return nil end
	return Zones:FromWorld(toMap, instance, wx, wy)
end

--- Size of a map in yards (width, height), or nil.
function Zones:MapSize(map)
	local r = rect(map)
	if not r then return nil end
	return math.abs(r[5] - r[3]), math.abs(r[4] - r[2])
end

-- The player ---------------------------------------------------------------------------------------------------

--- The player's map and position on it (0..1), or nil (in instances, or while the client has no position).
function Zones:PlayerPosition()
	local map = C_Map.GetBestMapForUnit("player")
	if not map then return nil end
	local pos = C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return nil end
	return map, x, y
end

--- Player's world position: instance, wx, wy. nil when unknown.
function Zones:PlayerWorld()
	local map, x, y = Zones:PlayerPosition()
	if not map then return nil end
	return Zones:ToWorld(map, x, y)
end

--- Yards between the player and a map point, and the bearing to it (radians, 0 = north, counter-clockwise like
--- GetPlayerFacing). nil when either is unknown or they are in different worlds.
function Zones:DistanceTo(map, x, y)
	local pi, px, py = Zones:PlayerWorld()
	if not pi then return nil end
	local ti, tx, ty = Zones:ToWorld(map, x, y)
	if not ti or ti ~= pi then return nil end
	local dx, dy = tx - px, ty - py -- dx north, dy west
	return sqrt(dx * dx + dy * dy), math.atan2(dy, dx) % (2 * math.pi)
end

--- Yards between two map points (nil if different worlds).
function Zones:Distance(mapA, xa, ya, mapB, xb, yb)
	local ia, ax, ay = Zones:ToWorld(mapA, xa, ya)
	local ib, bx, by = Zones:ToWorld(mapB, xb, yb)
	if not ia or ia ~= ib then return nil end
	local dx, dy = bx - ax, by - ay
	return sqrt(dx * dx + dy * dy)
end

-- Names ---------------------------------------------------------------------------------------------------------

function Zones:MapName(map)
	local info = map and C_Map.GetMapInfo(map)
	return info and info.name
end

--- The area's name as the client knows it, else the dungeon list's name.
function Zones:AreaName(area)
	if not area then return nil end
	local map = Zones:UiMapForArea(area)
	if map then
		local name = Zones:MapName(map)
		if name then return name end
	end
	local dungeon = Zones:Dungeon(area)
	if dungeon then return dungeon[1] end
	if C_Map.GetAreaInfo then return C_Map.GetAreaInfo(area) end
	return nil
end

--- "45.2, 67.8": one decimal, the way the game's own coordinates read.
function Zones:FormatCoords(x, y)
	return ("%.1f, %.1f"):format(floor(x * 1000 + 0.5) / 10, floor(y * 1000 + 0.5) / 10)
end
