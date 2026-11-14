-- Patrol paths on the world map and minimap.

local function quest(id, title, objectives)
	return { questID = id, title = title, level = 2, objectives = objectives or {} }
end
local function obj(text, have, need)
	return { text = text, type = "monster", numFulfilled = have, numRequired = need, finished = have >= need }
end

-- Kobold Camp Cleanup in the log, and Kobold Vermin given a walk around their camp (the data's Vermin stand still).
local WALK = { { 48.0, 36.0 }, { 49.0, 36.0 }, { 49.0, 37.0 }, { 48.0, 37.0 } }
local function setup(BF)
	World.player.level = 2
	World.completed[783] = true
	World.questLog = { quest(7, "Kobold Camp Cleanup", { obj("Kobold Vermin slain: 3/10", 3, 10) }) }
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	World.player.map, World.player.x, World.player.y = 1429, 0.485, 0.365
	Login()
	local row = {}
	for k, v in pairs(BF:Npc(6)) do row[k] = v end
	row[BF.N.waypoints] = { [12] = { WALK } }
	BF:SetNpcRows("test", { [6] = row })
	Tick(5)
end

local function pathPin()
	for _, p in ipairs(WorldMapFrame.pins) do
		if p.template == "BookFinderPathPinTemplate" then return p end
	end
end

local function shownLines(frame)
	local list = {}
	for _, l in ipairs(frame.lines or {}) do if l.shown then list[#list + 1] = l end end
	return list
end

return {
	["world map: the walk drawn, hostile colour"] = function(BF)
		setup(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local pin = pathPin()
		expect(pin, "a path pin")
		local lines = shownLines(pin)
		equal(#lines, #WALK - 1, "one line per step")
		local c = BF:Get("paths.hostileColor")
		equal(lines[1].color[1], c[1], "hostile red")
		local first = lines[1].start
		equal(first[1], "TOPLEFT", "anchored in the canvas")
		expect(math.abs(first[3] - 0.48 * 1002) < 0.01 and math.abs(first[4] + 0.36 * 668) < 0.01, "at the first point")
	end,

	["world map: the setting takes them away"] = function(BF)
		setup(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		BF:Set("paths.map", false)
		expect(not pathPin(), "no path pin")
	end,

	["hovering the NPC's pin highlights its path"] = function(BF)
		setup(BF)
		WorldMapFrame:Show()
		WorldMapFrame:SetMapID(1429)
		local target
		for _, p in ipairs(WorldMapFrame.pins) do
			if p.template == "BookFinderMapPinTemplate" then
				for _, r in ipairs(p.pin.roles) do if r.role == "objective" and r.quest == 7 then target = p end end
			end
		end
		expect(target, "the Vermin's pin")
		target:OnMouseEnter()
		local line = shownLines(pathPin())[1]
		equal(line.color[1], BF:Get("paths.highlightColor")[1], "highlighted")
		target:OnMouseLeave()
		equal(line.color[1], BF:Get("paths.hostileColor")[1], "back to hostile")
	end,

	["minimap: the walk near the player, cut at the edge"] = function(BF)
		setup(BF)
		Minimap.width, Minimap.height, Minimap.shown = 140, 140, true
		BF.MinimapPins.Update()
		local holder
		for _, child in ipairs(Minimap.children) do if child.lines then holder = child end end
		expect(holder, "the minimap's line frame")
		local lines = shownLines(holder)
		expect(#lines >= 1, "lines near the player")
		for _, l in ipairs(lines) do
			for _, p in ipairs({ l.start, l.stop }) do
				local x, y = p[3], p[4]
				expect(x * x + y * y <= 70 * 70 + 0.01, "inside the minimap's circle")
			end
		end
		World.player.x, World.player.y = 0.1, 0.9
		BF.MinimapPins.Update()
		equal(#shownLines(holder), 0, "nothing far away")
	end,

	["clipping: a segment through the circle, one outside, one through the square"] = function(BF)
		local t0, t1 = BF.Paths.clipCircle(-20, 0, 20, 0, 10)
		expect(math.abs(t0 - 0.25) < 1e-9 and math.abs(t1 - 0.75) < 1e-9, "cut to the circle")
		expect(BF.Paths.clipCircle(-20, 15, 20, 15, 10) == nil, "misses it")
		t0, t1 = BF.Paths.clipSquare(-20, 0, 20, 0, 10)
		expect(math.abs(t0 - 0.25) < 1e-9 and math.abs(t1 - 0.75) < 1e-9, "cut to the square")
		t0, t1 = BF.Paths.clipSquare(0, 0, 5, 5, 10)
		equal(t0, 0, "starts inside")
		equal(t1, 1, "ends inside")
	end,
}
