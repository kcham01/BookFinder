local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y, World.player.facing = 1429, 0.5, 0.5, 0
	Login()
end

return {
	["arrow and compass follow the map pin"] = function(BF)
		setup()
		-- A pin 300 yards north of the player (map y grows southwards).
		BF.Waypoint:Set(1429, 0.5, 0.4, "Marshal McBride", nil, nil)
		Tick(0.3)
		expect(BookFinderArrow:IsShown(), "arrow shown")
		expect(BookFinderCompass:IsShown(), "compass shown")
		equal(BookFinderArrow.Distance.text, "300 yd", "distance")
	end,

	["arrival: the gold pin, the game's pin taken away, gone after walking off"] = function(BF)
		setup()
		BF.Waypoint:Set(1429, 0.5, 0.4, "Marshal McBride", nil, nil)
		Tick(0.3)
		World.player.y = 0.4005 -- 1.5 yards from it
		Tick(0.3)
		expect(not BookFinderArrow.Pointer.shown and BookFinderArrow.Goal.shown, "gold pin")
		expect(World.waypoint == nil, "the game's pin cleared")
		equal(BookFinderArrow.Title.text, "Marshal McBride", "what is here")
		World.player.y = 0.45 -- 150 yards away
		Tick(0.3)
		expect(not BookFinderArrow:IsShown(), "gone after walking off")
	end,

	["metres when chosen; nothing without a pin"] = function(BF)
		setup()
		BF:Set("guide.metres", true)
		BF.Waypoint:Set(1429, 0.5, 0.4, "Marshal McBride")
		Tick(0.3)
		equal(BookFinderArrow.Distance.text, "274 m", "metres")
		BF.Waypoint:Clear()
		Tick(0.3)
		expect(not BookFinderArrow:IsShown() and not BookFinderCompass:IsShown(), "hidden")
	end,

	["the compass marks the pin to the side the player must turn"] = function(BF)
		setup()
		-- Pin due west: with the player facing north it is to the left (negative x on the strip).
		BF.Waypoint:Set(1429, 0.4, 0.5, "West")
		Tick(1)
		local x = BookFinderCompass.Goal.points[#BookFinderCompass.Goal.points][4]
		expect(x < 0, "left of centre, got " .. tostring(x))
	end,
}
