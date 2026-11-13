---@class SPFNamespace
local ns = select(2, ...).SPF; if ns.__skip then return end

if ns.broken then
	return
end

-- OpenMap (the seamless world map addon) offers other addons a small read-only API, OpenMapAPI: major 1, version 2
-- and up. It says where a point in the game's world sits on the stitched map's canvas (CanvasFromWorldPos, in
-- canvas fractions that run past 0..1 wherever the stitched view does), how high its stitched art reaches
-- (ArtTopLevel, so a frame of ours can be drawn above it), and whether the map on screen is the stitched one
-- (IsStitched). Only those are used here: UI/Canvas.lua already watches the canvas every frame the map is
-- shown, so it notices stitching start and stop without subscribing to OpenMap's callbacks.
--
-- Every call is a read: nothing here writes to OpenMap, to its settings or to Blizzard's map. An OpenMap that is
-- absent, older than version 2, or of another major version leaves every caller on its own map fractions, exactly
-- as before, and the same applies whenever OpenMap is loaded but not stitching (dungeons and battlegrounds, or the
-- player turned stitching off).

local OpenMap = {}
ns.OpenMapAddon = OpenMap

-- The API version CanvasFromWorldPos and ArtTopLevel arrived in.
local CANVAS_VERSION = 2

-- OpenMapAPI when it is loaded and new enough for the stitched canvas; nil otherwise.
---@return OpenMapAPI?
function OpenMap.API()
	local api = OpenMapAPI
	if type(api) ~= "table" or api.major ~= 1 or (api.version or 0) < CANVAS_VERSION then
		return nil
	end
	return api
end

-- Whether the world map is showing OpenMap's stitched map now.
---@return boolean
function OpenMap.Stitched()
	local api = OpenMap.API()
	return api ~= nil and api.IsStitched ~= nil and api.IsStitched() == true
end

-- The frame level OpenMap's stitched art reaches, or nil when it is not stitching (or not built yet): a frame of
-- ours at a fixed level shows over the art only above this.
---@return number?
function OpenMap.TopLevel()
	local api = OpenMap.API()
	if not (api and api.ArtTopLevel and OpenMap.Stitched()) then
		return nil
	end
	return api.ArtTopLevel()
end

-- A point in the game's world on the stitched map's canvas: `point` is a table with `map`, the uiMap whose yards
-- `x` and `y` are in, as Journey's points are. The result is in canvas fractions, where 0..1 is the map the map
-- frame is on and the stitched view carries on past it into the neighbouring zones. nil when OpenMap is not
-- stitching, or cannot place the point.
---@param point SPFPoint
---@return number?, number?
function OpenMap.Canvas(point)
	local api = OpenMap.API()
	if not (api and api.IsStitched and api.IsStitched()) or type(point) ~= "table" then
		return nil
	end
	local map, x, y = point.map, point.x, point.y
	if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	-- A journey's points are a continent's yards (ns.WorldPoint): OpenMap places those straight away, one Lua call and
	-- no vector per point, at the same spot as its own art and icons. (Read as a uiMap, a continent's number named no
	-- map, so every point fell through to the slower projection below, on every redraw of the route.)
	local direct, directX, directY = pcall(api.CanvasFromWorldPos, map, x, y)
	if direct and type(directX) == "number" and type(directY) == "number" then
		return directX, directY
	end
	local continent, world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
	if not (continent and world) then
		return nil
	end
	x, y = world:GetXY()
	-- The API is another addon's code: a failure there leaves this addon on its own map fractions.
	local placed, canvasX, canvasY = pcall(api.CanvasFromWorldPos, continent, x, y)
	if placed and type(canvasX) == "number" and type(canvasY) == "number" then
		return canvasX, canvasY
	end
	return nil
end

-- The API version CursorPosition arrived in.
local CURSOR_VERSION = 3

-- The zone (or city) under the cursor on the stitched map, with the cursor's place on it (0..1): the map underneath
-- is only the zone the view is on, so its own cursor position names the wrong zone, and that zone's underground
-- flag, wherever the cursor is over a neighbour. nil when OpenMap is not stitching or cannot say.
---@return number?, number?, number?
function OpenMap.CursorMapPoint()
	local api = OpenMap.API()
	if not (api and (api.version or 0) >= CURSOR_VERSION and OpenMap.Stitched()) then
		return nil
	end
	local ok, u, v = pcall(api.CursorPosition)
	if not (ok and type(u) == "number" and type(v) == "number") then
		return nil
	end
	local found, map = pcall(api.MapAt, u, v)
	if not (found and type(map) == "number") then
		return nil
	end
	local placed, x, y = pcall(api.MapFromWorld, map, u, v)
	if placed and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		return map, x, y
	end
	return nil
end
