-- BookFinder: "take me there" is the game's own map pin and tracking arrow.
--
-- A click on a quest, a book, a search result or a book's map icon puts the client's user waypoint on that spot
-- (C_Map.SetUserWaypoint) and tracks it (C_SuperTrack), so the game draws its own pin on the map and minimap and its own
-- arrow on screen. Nothing is planned or drawn by BookFinder. When the spot can't take a pin (an instance map, a map
-- the client can't place a pin on), it says so and opens the map there instead.
local _, root = ...
local public = root.public
if not public then return end

local PREFIX = "|cff33ff99BookFinder|r: "

-- One line on screen and in chat; the same line at most once in a few seconds.
local lastText, lastAt = nil, 0
function public.Notice(text)
	local now = GetTime and GetTime() or 0
	if text == lastText and now - lastAt < 4 then return end
	lastText, lastAt = text, now
	if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) end
	print(PREFIX .. text)
end

local function openMapAt(map)
	if not WorldMapFrame then return end
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown() or not ToggleWorldMap then return end
		ToggleWorldMap()
	end
	if map then pcall(WorldMapFrame.SetMapID, WorldMapFrame, map) end
end

local current   -- { map, x, y, title } of the pin BookFinder set last

-- The pin on a zone map's point; x, y in 0-100 (Questie's and the books' own coordinates). True when it was set.
function public.Waypoint(map, x, y, title)
	if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		public.Notice(("No place is known for %s."):format(title or "that"))
		return false
	end
	local canPin = C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map)
	if not (canPin and UiMapPoint and UiMapPoint.CreateFromCoordinates and C_Map.SetUserWaypoint) then
		public.Notice(("%s can't take a map pin: the map is open there instead."):format(title or "That place"))
		openMapAt(map)
		return false
	end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
	if not ok then
		public.Notice(("%s can't take a map pin: the map is open there instead."):format(title or "That place"))
		openMapAt(map)
		return false
	end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
	current = { map = map, x = x, y = y, title = title }
	if title and title ~= "" then
		local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
		public.Notice(("Map pin: %s%s"):format(title, info and info.name and (", " .. info.name) or ""))
	end
	return true
end

-- The pin BookFinder set, while it is still the game's waypoint
function public.CurrentWaypoint()
	if not current then return nil end
	if C_Map.HasUserWaypoint and not C_Map.HasUserWaypoint() then current = nil end
	return current
end

function public.ClearWaypoint()
	current = nil
	if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end
