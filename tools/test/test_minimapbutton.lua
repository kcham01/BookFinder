-- The minimap button rides the minimap's rim, round or square or a mix (as minimap addons report the shape).

local function setup(shape)
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	GetMinimapShape = function() return shape end
	Minimap:SetSize(140, 140)
	Login()
	return BookFinderMinimapButton
end

local function offset(b)
	local p = b.points[#b.points]
	return p[4], p[5]
end

return {
	["round: on the rim, at the minimap's own size"] = function(BF)
		local b = setup("ROUND")
		local x, y = offset(b)
		expect(math.abs(math.sqrt(x * x + y * y) - 75) < 0.5, "75 from the centre (half of 140, plus 5)")
		expect(x < 0 and y < 0, "bottom-left, where it starts")
	end,

	["square: out in the corner"] = function(BF)
		local b = setup("SQUARE")
		local x, y = offset(b)
		-- (on a round minimap it would be at -53, -53; here it goes out toward the corner, a little inside it)
		expect(x < -60 and x >= -75 and y < -60 and y >= -75, "toward the corner: " .. x .. ", " .. y)
	end,

	["a mix: round where the minimap is round (top-left), square in the bottom-left"] = function(BF)
		local b = setup("CORNER-TOPLEFT")
		local x, y = offset(b)
		expect(x < -60 and y < -60, "square quarter: toward the corner")
		BF:AccountState("minimapButton").angle = 135 -- top-left
		BF.MinimapButton.Place()
		x, y = offset(b)
		expect(math.abs(math.sqrt(x * x + y * y) - 75) < 0.5, "round quarter: on the rim")
	end,
}
