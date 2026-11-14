-- The stitched world (phase 12, step 1): where every piece of the game's own map art lies in the world, so a canvas can
-- draw a whole continent as one seamless map. Nothing is drawn here; Map/WorldCanvas.lua draws it.
--
-- Each map's art is a grid of tiles (C_Map.GetMapArtLayers: the layer's size in pixels and its tiles' size;
-- C_Map.GetMapArtLayerTextures: the tiles' file IDs, row by row). The map's 0..1 square covers the layer, and the map's
-- world rectangle (BF.Zones) puts that square in the world. So each tile gets a world rectangle.
--
-- World axes (as BF.Zones): wx grows north, wy grows west. A canvas draws east to the right and north up, so a tile's
-- left edge is -wy at its west side and its top edge is wx at its north side.
--
--   BF.Stitch:Tiles(map)      { {file, left, top, right, bottom}, ... } in world yards (east = -wy, north = wx)
--   BF.Stitch:Zones(continent) the zone maps on a continent, largest first (drawn first, so smaller ones lie on top)
--   BF.Stitch:Bounds(continent) left, top, right, bottom of the continent's own map in the same yards

local _, BF = ...

local Stitch = {}
BF.Stitch = Stitch

local Zones = BF.Zones
local cache = {}

--- The map's corners as world yards: east of its left edge, north of its top edge, east of its right, north of its bottom.
local function corners(map)
	local instance, nTop, wLeft = Zones:ToWorld(map, 0, 0)
	local _, nBottom, wRight = Zones:ToWorld(map, 1, 1)
	if not instance then return nil end
	return instance, -wLeft, nTop, -wRight, nBottom
end
Stitch.Corners = corners

--- The map's art tiles placed in the world (cached: the art never changes in a session).
function Stitch:Tiles(map)
	local c = cache[map]
	if c ~= nil then return c or nil end
	c = false
	local instance, left, top, right, bottom = corners(map)
	local layers = instance and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(map)
	local layer = layers and layers[1]
	local files = layer and C_Map.GetMapArtLayerTextures(map, 1)
	if layer and files and #files > 0 and layer.layerWidth > 0 and layer.tileWidth > 0 then
		local across = math.ceil(layer.layerWidth / layer.tileWidth)
		local w, h = right - left, bottom - top -- yards east, yards north (negative: the map's y runs south)
		c = { instance = instance }
		for i, file in ipairs(files) do
			local col, row = (i - 1) % across, math.floor((i - 1) / across)
			local x0 = col * layer.tileWidth / layer.layerWidth
			local y0 = row * layer.tileHeight / layer.layerHeight
			local x1 = (col + 1) * layer.tileWidth / layer.layerWidth
			local y1 = (row + 1) * layer.tileHeight / layer.layerHeight
			c[#c + 1] = { file = file, left = left + w * x0, top = top + h * y0, right = left + w * x1, bottom = top + h * y1 }
		end
	end
	cache[map] = c
	return c or nil
end

--- The continent's own map in world yards.
function Stitch:Bounds(continent)
	local instance, left, top, right, bottom = corners(continent)
	if not instance then return nil end
	return left, top, right, bottom, instance
end

--- The zone maps of a continent with art in the same world, largest first.
function Stitch:Zones(continent)
	local _, _, _, _, instance = Stitch:Bounds(continent)
	local list = {}
	for _, info in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone, true) or {}) do
		local i, l, t, r, b = corners(info.mapID)
		if i and i == instance then list[#list + 1] = { map = info.mapID, area = math.abs((r - l) * (t - b)) } end
	end
	table.sort(list, function(a, b) return a.area > b.area end)
	local maps = {}
	for _, z in ipairs(list) do maps[#maps + 1] = z.map end
	return maps
end

--- A world point (east, north yards) as a map's 0..1 point.
function Stitch:ToMap(map, east, north)
	local instance, left, top, right, bottom = corners(map)
	if not instance then return nil end
	return (east - left) / (right - left), (north - top) / (bottom - top)
end
