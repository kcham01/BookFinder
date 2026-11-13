-- The routing audit: from each capital, a journey to every flight point, library book and test place, for both
-- factions. Prints each journey that looks wrong, and a summary; fails when any has no route or raises an error.
--   python3 tools/routing/rig.py [tools/routing/audit.lua [mode [capital]]]
-- mode: "suspect" (default: every flight point known, only the suspect journeys printed), "all" (every journey
-- printed), "fresh" (no flight point known: a new character). capital: only journeys from that one.
-- The books' and places' zone coordinates are turned into world yards with Shortest Path's zone boxes, which bound a
-- zone loosely: such a goal can be a few hundred yards off, so a long last walk to one of them is a hint, not a bug.
local rig, mode, only = ...
io.stdout:setvbuf("line")
local ns = rig.ns

local books = {}
do
	local f = assert(io.open(rig.SRC .. "/../Books_on_map_Forever/Data/Books.lua", "rb"))
	local src = f:read("*a") f:close()
	assert(loadstring(src, "@Books.lua"))("Books", books)
end

local ORIGINS = {
	Horde = { { "Orgrimmar", 1454, 0.50, 0.60 }, { "Undercity", 1458, 0.66, 0.44 }, { "Thunder Bluff", 1456, 0.45, 0.60 } },
	Alliance = { { "Stormwind", 1453, 0.55, 0.65 }, { "Ironforge", 1455, 0.30, 0.60 }, { "Darnassus", 1457, 0.40, 0.45 } },
}
local PLACES = {
	{ "Booty Bay", 1434, 0.27, 0.77 }, { "Gadgetzan", 1446, 0.52, 0.28 }, { "Ratchet", 1413, 0.63, 0.37 },
	{ "Everlook", 1452, 0.61, 0.38 }, { "Light's Hope Chapel", 1423, 0.81, 0.58 }, { "Freewind Post", 1441, 0.46, 0.51 },
	{ "Tarren Mill", 1424, 0.62, 0.20 }, { "Kargath", 1418, 0.03, 0.47 }, { "Camp Mojache", 1444, 0.75, 0.44 },
	{ "Splintertree Post", 1440, 0.73, 0.61 },
}

local function destinations(faction)
	local list = {}
	for id, node in pairs(ns.TaxiNodes) do
		if not node.faction or node.faction == faction then
			list[#list + 1] = { name = "flight point " .. node.name, point = { map = node.map, x = node.x, y = node.y, z = node.z } }
		end
	end
	for _, b in ipairs(books.BOOKS) do
		if not b.faction or b.faction == faction then
			for _, loc in ipairs(b.locs) do
				if ns.Zones[loc[1]] then
					list[#list + 1] = { name = "book " .. loc[4], point = rig.World(loc[1], loc[2] / 100, loc[3] / 100) }
				else
					list[#list + 1] = { name = "book " .. loc[4], nozone = loc[1] }
				end
			end
		end
	end
	for _, p in ipairs(PLACES) do list[#list + 1] = { name = p[1], point = rig.World(p[2], p[3], p[4]) } end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local function gap(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

if mode == "" then mode = nil end
local total, flagged, counts = 0, 0, {}
local function flag(why) counts[why] = (counts[why] or 0) + 1 end
for _, faction in ipairs({ "Horde", "Alliance" }) do
	for _, o in ipairs(ORIGINS[faction]) do
	  if not only or only == o[1] then
		local from = rig.World(o[2], o[3], o[4])
		for _, d in ipairs(destinations(faction)) do
			total = total + 1
			local why = {}
			local plan
			if d.nozone then
				why[#why + 1] = "no zone data for map " .. d.nozone
			else
				local ok, result = pcall(rig.Plan, from, d.point, { faction = faction, known = mode == "fresh" and {} or "all" })
				if not ok then why[#why + 1] = "error: " .. tostring(result) else plan = result end
				if ok and not plan then why[#why + 1] = "no route" end
			end
			if plan then
				local walked = 0
				for i, leg in ipairs(plan.legs) do
					if leg.mode == "walk" then
						local secs = (leg.arrive - leg.depart) / 1000
						walked = walked + secs
						if leg.estimated then why[#why + 1] = "guessed walk (leg " .. i .. ")" end
						if secs > 480 then why[#why + 1] = ("%d min walk (leg %d)"):format(secs / 60, i) end
						local straight = gap(leg.from, leg.to)
						if (leg.yards or 0) > 300 and leg.yards > straight * 2.5 then
							why[#why + 1] = ("walk %.1fx the straight line (leg %d)"):format(leg.yards / straight, i)
						end
					end
				end
				if plan.arrive / 1000 > 1500 then why[#why + 1] = ("%d min in all"):format(plan.arrive / 60000) end
			end
			if #why > 0 or mode == "all" then
				if #why > 0 then flagged = flagged + 1 end
				for _, w in ipairs(why) do flag((w:gsub("%d+%.?%d*", "N"))) end
				print(("[%s] %s -> %s%s\n    %s"):format(faction, o[1], d.name, #why > 0 and ("   !! " .. table.concat(why, "; ")) or "", rig.Describe(plan)))
			end
		end
	  end
	end
end
print(("\n%d journeys, %d suspect"):format(total, flagged))
for why, n in pairs(counts) do print(("  %4d  %s"):format(n, why)) end
if (counts["no route"] or 0) > 0 then error("journeys with no route: " .. counts["no route"], 0) end
for why in pairs(counts) do if why:find("^error") then error("the planner raised errors", 0) end end
