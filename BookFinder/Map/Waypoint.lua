-- The map pin: "take me there" is always the game's own map pin (user waypoint) with its tracking, plus BookFinder's
-- arrow and compass (Map/Arrow.lua, Map/Compass.lua). The game's pin has no name, so BookFinder remembers what it
-- points at for the arrow, the compass and tooltips.
--
-- Messages: BF_WAYPOINT_CHANGED(waypoint or nil)   waypoint = { map, x, y, title, subtitle }

local _, BF = ...
local L = BF.L

local Waypoint = {}
BF.Waypoint = Waypoint

local current -- { map, x, y, title, subtitle }

local function same(a, b)
	return a and b and a.map == b.map and math.abs(a.x - b.x) < 1e-4 and math.abs(a.y - b.y) < 1e-4
end

-- A map the game can't hold a pin on (a dungeon map, the whole world): the zone the spot lies in, where there is one.
local function placeable(map, x, y)
	if C_Map.CanSetUserWaypointOnMap(map) then return map, x, y end
	if C_Map.GetMapInfoAtPosition then
		local info = C_Map.GetMapInfoAtPosition(map, x, y)
		if info and info.mapID ~= map and C_Map.CanSetUserWaypointOnMap(info.mapID) then
			local tx, ty = BF.Zones:Translate(map, x, y, info.mapID)
			if tx then return info.mapID, tx, ty end
		end
	end
	return nil
end

--- Puts the map pin on a spot (map, x, y in 0..1) and tracks it. Setting the same spot again takes it away.
function Waypoint:Set(map, x, y, title, subtitle)
	local m, px, py = placeable(map, x, y)
	if not m then
		BF:Print(L["The map pin can't go there: that map takes no pins."])
		return false
	end
	local wanted = { map = m, x = px, y = py, title = title, subtitle = subtitle }
	if same(current, wanted) and C_Map.HasUserWaypoint() then
		Waypoint:Clear()
		return false
	end
	current = wanted
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, px, py))
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	BF:Send("BF_WAYPOINT_CHANGED", current)
	return true
end

function Waypoint:Clear()
	current = nil
	if C_Map.HasUserWaypoint() then C_Map.ClearUserWaypoint() end
	BF:Send("BF_WAYPOINT_CHANGED", nil)
end

--- The pin as BookFinder knows it: { map, x, y, title, subtitle } (a pin set by the game or another addon has no title).
function Waypoint:Get()
	if not C_Map.HasUserWaypoint() then return nil end
	local point = C_Map.GetUserWaypoint()
	if not point then return nil end
	local x, y = point.position.x, point.position.y
	if current and current.map == point.uiMapID and math.abs(current.x - x) < 1e-4 and math.abs(current.y - y) < 1e-4 then
		return current
	end
	return { map = point.uiMapID, x = x, y = y }
end

-- The game's pin moved or went (the player placed one, or cleared it): forget our name for the old one.
BF:On("USER_WAYPOINT_UPDATED", function()
	local w = Waypoint:Get()
	if not w then current = nil elseif not w.title then current = nil end
	BF:Send("BF_WAYPOINT_CHANGED", Waypoint:Get())
end)
