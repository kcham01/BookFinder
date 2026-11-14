-- Coordinates on the world map and the minimap.

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.4823, 0.4211
	Login()
end

local function texts(frame, found)
	found = found or {}
	for _, c in ipairs(frame.children or {}) do
		if c.kind == "FontString" then found[#found + 1] = c end
		texts(c, found)
	end
	return found
end

return {
	["world map: the game's own player line kept, only the cursor added beside it"] = function(BF)
		setup()
		local footer = CreateFrame("Frame", nil, WorldMapFrame)
		local game = footer:CreateFontString()
		game:SetText("Player: 48.2, 42.1")
		WorldMapFrame:Show()
		Tick(1.5)
		local line
		for _, f in ipairs(texts(WorldMapFrame)) do if f ~= game then line = f end end
		equal(line.text, "", "nothing while the cursor is off the map")
		World.cursorX, World.cursorY = 0.25, 0.75
		Tick(0.5)
		equal(line.text, "Cursor: 25.0, 75.0", "the cursor only")
		local p = line.points[#line.points]
		equal(p[2], game, "beside the game's line")
	end,

	["world map: the player's coordinates, decimals as chosen"] = function(BF)
		setup()
		WorldMapFrame:Show()
		Tick(0.5)
		local line = texts(WorldMapFrame)[1]
		expect(line and line.text and line.text:find("48.2, 42.1", 1, true), "player at 48.2, 42.1: " .. tostring(line and line.text))
		BF:Set("coords.precision", 2)
		Tick(0.5)
		expect(line.text:find("48.23, 42.11", 1, true), "two decimals")
		World.cursorX, World.cursorY = 0.25, 0.75
		Tick(0.5)
		expect(line.text:find("Cursor: 25.00, 75.00", 1, true), "the cursor: " .. line.text)
		BF:Set("coords.map", false)
		Tick(0.5)
		equal(line.text, "", "off")
	end,

	["minimap: off until chosen"] = function(BF)
		setup()
		Tick(0.5)
		local line
		for _, c in ipairs(texts(Minimap)) do if c.text ~= nil then line = c end end
		equal(line and line.text, "", "off by default")
		BF:Set("coords.minimap", true)
		Tick(0.5)
		equal(line.text, "48.2, 42.1", "the player's spot")
	end,
}
