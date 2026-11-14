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

	["quest icons, books and map pins on the canvas, with their tooltips"] = function(BF)
		setup()
		World.completed[783] = true
		World.player.level = 2
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		BF.UserPins:Add(1429, 0.5, 0.5, "Here", 1)
		Tick(2)
		local kinds = {}
		for _, b in ipairs({ BF.WorldCanvas.overlay:GetChildren() }) do
			if b.shown and b.spec then
				if b.pin and b.pin.roles then kinds.quest = b end
				if b.pin and b.pin.note then kinds.userPin = b end
			end
		end
		expect(kinds.quest, "a quest icon")
		expect(kinds.userPin, "the map pin")
		kinds.quest.scripts.OnEnter(kinds.quest)
		expect(#GameTooltip.lines > 0, "its tooltip")
	end,

	["the zone under the cursor with its levels; a click zooms into it"] = function(BF)
		setup()
		World.maps[1429].levels = { 1, 10 }
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1415)
		BookFinderWorldCanvas.IsMouseOver = function() return true end
		GetCursorPosition = function() return 500, -334 end -- the middle of the 1000 x 668 view
		local zone = BF.WorldCanvas:ZoneAt(BF.WorldCanvas:Centre())
		equal(zone, 1429, "Elwynn under the middle")
		expect(BF.WorldCanvas:HoverText():find("Elwynn Forest", 1, true), "its name")
		expect(BF.WorldCanvas:HoverText():find("1-10", 1, true), "its levels")
	end,

	["a dungeon's own map stays the game's"] = function(BF)
		setup()
		World.maps[310] = { size = 500, mapID = 310, name = "Shadowfang Keep", mapType = 4, parentMapID = 1421 }
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(310)
		expect(not BookFinderWorldCanvas.shown, "the game's own map for a dungeon")
	end,

	["the Show dropdown now has the Dungeons section's first entries"] = function(BF)
		setup()
		local seen = {}
		for _, item in ipairs(BF.ShowMenu:Items()) do if item.text then seen[item.text] = true end end
		expect(seen["Dungeons and raids"] and seen["Level ranges"], "both")
	end,

	["flight masters from the game: learned bright, the rest greyed"] = function(BF)
		setup()
		World.taxi = { [1415] = {
			{ name = "Stormwind", position = { x = 0.5, y = 0.5 }, state = 1 },
			{ name = "Far Away", position = { x = 0.52, y = 0.52 }, state = 2 },
		} }
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1415)
		Tick(1)
		local found = {}
		for _, b in ipairs({ BF.WorldCanvas.overlay:GetChildren() }) do
			if b.shown and b.node then found[b.node.name] = b end
		end
		expect(found.Stormwind and not found.Stormwind.Icon.color or found.Stormwind.Icon.color[1] == 1, "learned: bright")
		equal(found["Far Away"].Icon.color[1], 0.5, "not learned: grey")
	end,

	["explored areas: placed from the layer's pixels; a last piece uses part of its file"] = function(BF)
		setup()
		World.explored = { [1429] = { { offsetX = 100, offsetY = 50, textureWidth = 300, textureHeight = 200,
			numTexturesWide = 2, numTexturesTall = 1, fileDataIDs = { 7001, 7002 } } } }
		local pieces = BF.Stitch:Explored(1429)
		equal(#pieces, 2, "two pieces")
		local _, left, top, right, bottom = BF.Stitch.Corners(1429)
		expect(near(pieces[1].left, left + (right - left) * 100 / 1002), "from its offset")
		expect(near(pieces[2].left, left + (right - left) * 356 / 1002), "the second 256 pixels on")
		expect(near(pieces[2].u, 44 / 64), "44 pixels of a 64-pixel file")
		expect(near(pieces[1].v, 200 / 256), "200 of 256 down")
	end,

	["find a place: zones and dungeons by name; choosing one goes there"] = function(BF)
		setup()
		World.children[947] = { { mapID = 1415, name = "Eastern Kingdoms" } }
		World.children[1415] = { { mapID = 1429, name = "Elwynn Forest" } }
		BF:Set("map.seamless", true)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1415)
		local results = BF.FindPlace:Search("elwy")
		equal(results[1] and results[1].name, "Elwynn Forest", "the zone")
		equal(results[1].kind, "Zone", "as a zone")
		BF.FindPlace:Go(results[1])
		equal(WorldMapFrame:GetMapID(), 1429, "the map went there")
		equal(#BF.FindPlace:Search("e"), 0, "one letter: nothing yet")
	end,

	["the quill: a line, an arrow's head, a mark, erase, undo, clear"] = function(BF)
		setup()
		BF.Quill:Start()
		expect(BookFinderQuillBar and BookFinderQuillBar.shown, "the toolbar")
		local e, n = BF.WorldCanvas:Centre()
		BF.Quill:Add({ tool = "Arrow", ink = 2, width = 4, instance = 0, points = { { e, n }, { e + 100, n } } })
		equal(#BF.Quill.Segments(BF.Quill:Strokes()[1]), 3, "an arrow: its shaft and two strokes of head")
		BF.Quill:Add({ tool = "Mark", ink = 1, width = 2, instance = 0, mark = 8, points = { { e, n + 500 } } })
		equal(#BF.Quill:Strokes(), 2, "two strokes")
		expect(BF.Quill:EraseAt(e + 50, n + 1, 5), "erased the arrow near its shaft")
		equal(#BF.Quill:Strokes(), 1, "one left")
		BF.Quill:Undo()
		equal(#BF.Quill:Strokes(), 0, "undone")
		BF.Quill:Add({ tool = "Pen", ink = 1, width = 2, instance = 0, points = { { e, n }, { e + 1, n + 1 } } })
		BF.Quill:Clear()
		equal(#BF.Quill:Strokes(), 0, "cleared")
		BF.Quill:Stop()
		expect(not BookFinderQuillBar.shown, "done")
	end,
}
