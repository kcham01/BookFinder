-- Offline routing rig: Shortest Path's own data, planner and walking search, with no game client.
-- rig.py loads this; SRC is Shortest Path's folder, readfile reads a file, b64/inflate come from Python.
local SRC, readfile, b64, inflate = ...
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
C_EncodingUtil = { DecodeBase64 = b64, DecompressString = inflate }
Enum = { CompressionMethod = { Zlib = 1 } }
debugprofilestop = function() return os.clock() * 1000 end
local function run(file)
	local chunk = assert(loadstring(readfile(SRC .. "/" .. file), "@" .. file))
	chunk("ShortestPathForever", ns)
end
for _, f in ipairs({ "Data/Routes.lua", "Data/Transports.lua", "Data/Taxi.lua", "Data/Portals.lua", "Data/Teleports.lua",
	"Data/Zones.lua", "Data/Walks.lua", "Data/RoadCells.lua", "Data/RoadEdges.lua", "Data/Heights.lua",
	"Transport/Model.lua", "Routing/Planner.lua", "Routing/PathGrid.lua", "Routing/Path.lua" }) do run(f) end
for file in readfile(SRC .. "/Nav/Nav.xml"):gmatch('file="([^"]+)"') do run("Nav/" .. file) end

local rig = { ns = ns, SRC = SRC }
local Planner, Path = ns.Planner, ns.Path

-- a zone map point (0-1) in world yards
function rig.World(uiMap, x, y)
	local z = assert(ns.Zones[uiMap], "no zone " .. tostring(uiMap))
	return { map = z.map, x = z.maxX - y * (z.maxX - z.minX), y = z.maxY - x * (z.maxY - z.minY) }
end

local function mass(p) return Planner.Landmass(p, ns.Landmasses) end

-- The walks a journey measures: from the start to every place on its land, from every place to the goal.
local forward = {}   -- (one start serves many goals: its walks to the fixed places are measured once)
local function measured(from, to, places, water)
	local walks = {}
	local key = ("%d:%f:%f:%s:%d"):format(from.map, from.x, from.y, tostring(water), #places)
	for pass = 1, 3 do
		local point, reverse = pass == 2 and to or from, pass == 2
		if pass == 1 and forward[key] then
			for _, w in ipairs(forward[key]) do walks[#walks + 1] = w end
		elseif pass == 3 then
			if to.map == from.map and mass(to) == mass(from) and Path.HasData(from.map) then
				local costs = Path.FindManySync(from.map, from, { to }, water)
				walks[#walks + 1] = { from = from, to = to, cost = costs and costs[1] or false }
			end
		elseif Path.HasData(point.map) then
			local targets = {}
			for _, p in ipairs(places) do
				if p.map == point.map and mass(p) == mass(point) then targets[#targets + 1] = p end
			end
			local costs, reason = Path.FindManySync(point.map, point, targets, water, reverse)
			for i, t in ipairs(targets) do
				local cost = costs and costs[i]
				if cost == nil then cost = false end
				walks[#walks + 1] = { from = reverse and t or point, to = reverse and point or t, cost = cost }
			end
			if not costs then rig.lastReason = reason end
			if pass == 1 then
				forward[key] = {}
				for _, w in ipairs(walks) do forward[key][#forward[key] + 1] = w end
			end
		end
	end
	return walks
end

-- opts: faction, speed (yd/s), known ("all" or a set of taxi ids), anchors (false = boats' waits are half a period)
function rig.Plan(from, to, opts)
	opts = opts or {}
	local faction = opts.faction or "Horde"
	local places = Planner.Places({ docks = ns.Docks, taxiNodes = ns.TaxiNodes, portals = ns.Portals, faction = faction })
	local options = {
		from = from, to = to, now = 0, walkSpeed = opts.speed or 7, faction = faction, otherFaction = false,
		taxiKnown = opts.known ~= "all" and opts.known or nil,
		docks = ns.Docks, routes = ns.Routes, taxiNodes = ns.TaxiNodes, taxiPaths = ns.TaxiPaths,
		portals = ns.Portals, landmasses = ns.Landmasses, baked = ns.Walks,
		walks = opts.straight and nil or measured(from, to, places, opts.water),
	}
	return Planner.Plan(options)
end

function rig.Walk(from, to)
	local points, cost = Path.FindSync(from.map, from, to)
	return points and cost or nil, points
end

local function name(node)
	if node.kind == "start" then return "start" elseif node.kind == "goal" then return "goal" end
	if node.kind == "taxi" then return ns.TaxiNodes[node.id].name end
	if node.kind == "dock" then local d = ns.Docks[node.id] return (d.site and (d.site .. " " .. (d.name or "")) or d.name or ("dock " .. node.id)) end
	return node.label or (node.kind .. tostring(node.id))
end
rig.Name = name

function rig.Describe(plan)
	if not plan then return "NO ROUTE" end
	local out = {}
	for _, leg in ipairs(plan.legs) do
		local s = ("%s %s -> %s %ds"):format(leg.mode, name(leg.from), name(leg.to), (leg.arrive - leg.depart) / 1000)
		if leg.wait and leg.wait > 0 then s = s .. (" (+%ds wait)"):format(leg.wait / 1000) end
		if leg.mode == "walk" then s = s .. (" %dyd%s"):format(leg.yards or 0, leg.estimated and " EST" or "") end
		if leg.hops and #leg.hops > 1 then s = s .. (" [%d hops]"):format(#leg.hops) end
		out[#out + 1] = s
	end
	return ("%ds: "):format(plan.arrive / 1000) .. table.concat(out, " | ")
end
return rig
