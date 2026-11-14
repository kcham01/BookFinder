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
		expect(line.text:find("Cursor: |cffffffff25.00, 75.00", 1, true), "the cursor: " .. line.text)
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
