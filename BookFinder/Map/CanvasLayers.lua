-- What draws on the seamless map (Map/WorldCanvas.lua): the same things as on the game's map, with the same tooltips
-- and clicks: quest icons (BF.Marks), library books, the player's map pins, friends and guild who share their place.
-- Each follows its own switches, as on the game's map.

local _, BF = ...

local Canvas, Stitch, Marks, Look = BF.WorldCanvas, BF.Stitch, BF.Marks, BF.Look

local BASE = 24

-- The maps whose marks a continent shows: the continent and its zones.
local function mapsOf(continent)
	local list = { continent }
	for _, z in ipairs(Stitch:Zones(continent)) do list[#list + 1] = z end
	return list
end

-- Quest icons.
Canvas:AddLayer("quests", function(continent, add)
	if not BF:Get("quests.map") then return end
	local gameFlights = #Canvas.FlightNodes(continent) > 0
	for _, map in ipairs(mapsOf(continent)) do
		for _, pin in ipairs(Marks:On(map)) do
			local east, north = Canvas:WorldOf(map, pin.x, pin.y)
			-- A mark that is only a flight master: the flight layer draws the game's own, learned or not.
			local onlyFlight = #pin.roles > 0
			for _, r in ipairs(pin.roles) do
				if not (r.role == "townsfolk" and r.kind and r.kind.key == "flightMaster") then onlyFlight = false end
			end
			if east and not (onlyFlight and gameFlights) then
				local kind, scaleKey = Look:Kind(pin)
				local size = scaleKey == "townsfolk" and BASE * BF:Get("icons.townsfolkMapScale")
					or BASE * BF:Get("icons.mapScale") * BF:Get("icons.scale." .. scaleKey)
				add(east, north, { kind = kind, size = size, pin = pin,
					onEnter = function(b) BF.PinTooltip:Show(b, { b.pin }, false) end,
					onLeave = function() BF.PinTooltip:Hide() end,
					onClick = function(b, button) BF.PinTooltip:Click(b.pin, button, nil, b) end })
			end
		end
	end
end)

-- Library books.
Canvas:AddLayer("books", function(continent, add)
	if not BF:Get("books.map") then return end
	for _, book in ipairs(BF.Books.list) do
		local shows = BF.BookMap:Shows(book)
		if shows then
			for _, place in ipairs(BF.Books:Places(book)) do
				local east, north = Canvas:WorldOf(place.map, place.x, place.y)
				if east then
					add(east, north, { file = BF.Books:Icon(book), size = BF:Get("books.mapSize"), book = book, place = place,
						tint = shows ~= "mine" and { 0.6, 0.6, 0.6 } or nil,
						onEnter = function(b) BF.BookMap:ShowTooltip(b, b.book, b.place) end,
						onClick = function(b, button) BF.BookMap:Click(b.book, b.place, button) end })
				end
			end
		end
	end
end)

-- The player's map pins (and shared ones), with the pin's own tooltip and clicks.
Canvas:AddLayer("userPins", function(continent, add)
	for _, p in ipairs(BF.UserPins:List()) do
		local east, north = Canvas:WorldOf(p.map, p.x, p.y)
		if east then
			local c = BF.UserPins.COLORS[p.color] or BF.UserPins.COLORS[1]
			local followed = BF.UserPins:IsFollowed(p)
			add(east, north, { kind = followed and "waypoint" or "userPin", size = followed and 30 or 24, pin = p,
				tint = p.color ~= 1 and { c[2], c[3], c[4] } or nil,
				onEnter = function(b) BookFinderUserPinMixin.OnMouseEnter(b) end,
				onClick = function(b, button) BookFinderUserPinMixin.OnMouseUp(b, button) end })
		end
	end
end)

-- Friends and guild members who share where they are.
Canvas:AddLayer("people", function(continent, add)
	if not (BF:Get("map.friends") or BF:Get("map.guild")) then return end
	for name, p in pairs(BF.People.live) do
		local r = BF.People.roster[name]
		if (p.guild and BF:Get("map.guild")) or (r and r.friend and BF:Get("map.friends")) then
			local east, north = Canvas:WorldOf(p.map, p.x, p.y)
			if east then
				local c = p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
				add(east, north, { kind = "groupMember", size = 14, name = name, place = p,
					tint = c and { c.r, c.g, c.b } or nil,
					onEnter = function(b) BookFinderPersonPinMixin.OnMouseEnter(b) end })
			end
		end
	end
end)

-- Drawn again when what they show changes.
local again = BF:Debounce(0.2, function() Canvas:Redraw() end)
BF:At("login", function()
	for _, m in ipairs({ "BF_MARKS_CHANGED", "BF_BOOKS_CHANGED", "BF_BOOKS_GROUP_CHANGED", "BF_USER_PINS_CHANGED",
		"BF_WAYPOINT_CHANGED", "BF_PEOPLE_CHANGED" }) do
		BF:Listen(m, again)
	end
	BF:Listen("BF_SETTING_CHANGED", again)
end, 79)

-- Patrol paths of the NPCs the map marks (Map/Paths.lua's choice of NPCs, colours and switches).
Canvas:AddLayer("paths", function(continent, add)
	if not BF:Get("quests.map") or not BF:Get("paths.map") then return end
	local npcs = {}
	for _, map in ipairs(mapsOf(continent)) do BF.Paths:NpcsOn(map, npcs) end
	local width = BF:Get("paths.width")
	for npc in pairs(npcs) do
		local row = BF:Npc(npc)
		local hostile = row and not BF.Player:FriendlyTo(row[BF.N.friendlyTo])
		local c = BF:Get(hostile and "paths.hostileColor" or "paths.color")
		local colour = { c[1], c[2], c[3], (c[4] or 1) * BF:Get("paths.opacity") }
		for _, poly in ipairs(BF.Paths:Of(npc)) do
			local le, ln
			for _, p in ipairs(poly.points) do
				local e, n = Canvas:WorldOf(poly.map, p[1], p[2])
				if e and le then add.line(le, ln, e, n, { thickness = width, colour = colour }) end
				le, ln = e, n
			end
		end
	end
end)

-- Flight masters, from the game's own flight data: learned ones bright, the rest greyed ("Learned" / "Not learned").
-- On the seamless map they stand in for the townsfolk flight masters (one icon for one thing): the quest layer leaves
-- out a mark whose only role is a flight master.
local function flightNodes(continent)
	if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return {} end
	local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, continent)
	return ok and type(nodes) == "table" and nodes or {}
end

Canvas.FlightNodes = flightNodes

Canvas:AddLayer("flights", function(continent, add)
	if not BF:Get("townsfolk.flightMaster") then return end
	local unreachable = Enum.FlightPathState and Enum.FlightPathState.Unreachable
	for _, node in ipairs(flightNodes(continent)) do
		local pos = node.position
		local x, y
		if pos then x, y = pos.x, pos.y end
		if x and y then
			local east, north = Canvas:WorldOf(continent, x, y)
			if east then
				local learned = node.state ~= unreachable
				add(east, north, { kind = "flightMaster", size = 18, node = node, tint = not learned and { 0.5, 0.5, 0.5 } or nil,
					onEnter = function(b)
						GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
						GameTooltip:AddLine(b.node.name or "", 1, 0.82, 0)
						GameTooltip:AddLine(learned and BF.L["Learned"] or BF.L["Not learned"], learned and 0.2 or 0.6, learned and 1 or 0.6, learned and 0.2 or 0.6)
						GameTooltip:Show()
					end })
			end
		end
	end
end)
