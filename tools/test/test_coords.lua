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
	["world map: two lines at the top left of the title bar, the player's and the cursor's"] = function(BF)
		setup()
		WorldMapFrame:Show()
		Tick(0.5)
		local player, cursor = BF.Coords.playerText, BF.Coords.cursorText
		equal(player:GetParent():GetParent(), WorldMapFrame.BorderFrame, "in the window's title bar")
		local p = player.points[#player.points]
		equal(p[1], "TOPLEFT", "at its top left")
		expect(p[4] >= 50, "beside the portrait")
		equal(cursor.points[#cursor.points][2], player, "the cursor's line under the player's")
		expect(player.text:find("Player", 1, true) and player.text:find("48.2, 42.1", 1, true), "player: " .. player.text)
		equal(cursor.text, "", "no cursor line while the cursor is off the map")
		World.cursorX, World.cursorY = 0.25, 0.75
		Tick(0.5)
		expect(cursor.text:find("Cursor", 1, true) and cursor.text:find("25.0, 75.0", 1, true), "cursor: " .. cursor.text)
	end,

	["world map: the game's own player line hidden while BookFinder's shows, back when it is off"] = function(BF)
		setup()
		local footer = CreateFrame("Frame", nil, WorldMapFrame)
		local game = footer:CreateFontString()
		game:SetText("Player: 48.2, 42.1")
		WorldMapFrame:Show()
		Tick(1.5)
		equal(game:GetAlpha(), 0, "hidden: not said twice")
		BF:Set("coords.map", false)
		Tick(0.5)
		equal(game:GetAlpha(), 1, "back")
		equal(BF.Coords.playerText.text, "", "ours off")
	end,

	["world map: decimals as chosen"] = function(BF)
		setup()
		WorldMapFrame:Show()
		BF:Set("coords.precision", 2)
		World.cursorX, World.cursorY = 0.25, 0.75
		Tick(0.5)
		expect(BF.Coords.playerText.text:find("48.23, 42.11", 1, true), "two decimals")
		expect(BF.Coords.cursorText.text:find("25.00, 75.00", 1, true), "the cursor too")
	end,

	["minimap: off until chosen"] = function(BF)
		setup()
		Tick(0.5)
		local line = BF.Coords.miniText
		equal(line and line.text, "", "off by default")
		BF:Set("coords.minimap", true)
		Tick(0.5)
		equal(line.text, "48.2, 42.1", "the player's spot")
	end,
}
