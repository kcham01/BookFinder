-- The seamless continent map, step 1: tiles placed in the world, the view's zoom and pan.

local function setup()
	-- A 3000-yard zone (as the stand-in places maps: its 0..1 square is 3000 yards each way).
	World.maps = {
		[1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 },
		[1415] = { size = 3000, mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
	}
	World.art = {
		[1429] = { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256, files = {} },
		[1415] = { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256, files = {} },
	}
	for i = 1, 12 do World.art[1429].files[i] = 1000 + i; World.art[1415].files[i] = 2000 + i end
	World.children = { [1415] = { { mapID = 1429 } } }
	World.player.map, World.player.x, World.player.y = 1429, 0.48, 0.42
	Login()
	BookFinderWorldCanvas:SetSize(1000, 668)
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

return {
	["tiles: a 4 x 3 grid of the art, each at its place in the world"] = function(BF)
		setup()
		local tiles = BF.Stitch:Tiles(1429)
		equal(#tiles, 12, "twelve tiles")
		local _, left, top, right, bottom = BF.Stitch.Corners(1429)
		local t1, t5 = tiles[1], tiles[5]
		expect(near(t1.left, left) and near(t1.top, top), "the first at the map's top left")
		expect(near(t1.right - t1.left, (right - left) * 256 / 1002), "a tile's share of the width")
		expect(near(t5.top, top + (bottom - top) * 256 / 668), "the fifth starts the second row")
		equal(t5.file, 1005, "row by row")
		expect(t1.top > t1.bottom, "north at the top")
	end,

	["off by default; on, the map window shows the continent stitched"] = function(BF)
		setup()
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1415)
		expect(not BookFinderWorldCanvas.shown, "off")
		BF:Set("map.seamless", true)
		expect(BookFinderWorldCanvas.shown, "shown")
		equal(#BF.Stitch:Zones(1415), 1, "Elwynn on Eastern Kingdoms")
	end,

	["a zone opens the canvas fitted to it; the wheel zooms about the cursor"] = function(BF)
		setup()
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local _, left, top, right, bottom = BF.Stitch.Corners(1429)
		local e, n = BF.WorldCanvas:Centre()
		expect(near(e, (left + right) / 2) and near(n, (top + bottom) / 2), "centred on Elwynn")
		local before = { BF.WorldCanvas:WorldAt(200, 100) }
		BF.WorldCanvas:ZoomAt(2, 200, 100)
		local after = { BF.WorldCanvas:WorldAt(200, 100) }
		expect(near(before[1], after[1]) and near(before[2], after[2]), "the point under the cursor stays put")
	end,

	["dragging pans the other way round"] = function(BF)
		setup()
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local e, n = BF.WorldCanvas:Centre()
		BF.WorldCanvas:Pan(100, 0)
		local e2 = BF.WorldCanvas:Centre()
		expect(e2 < e, "dragging right shows what lies west")
		BF.WorldCanvas:Pan(0, -50)
		local _, n2 = BF.WorldCanvas:Centre()
		expect(n2 < n, "dragging up shows what lies south")
	end,
}
