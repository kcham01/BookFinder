-- BookFinder: /bookfinder selftest. Goes through every feature in the game itself and writes what happened to
-- BookFinderDB.selftest: each check (passed or failed, why, how long it took), every Lua error meanwhile, and a route
-- to each of a set of places across both continents, leg by leg, as Shortest Path planned it. Stand still out of
-- combat; it takes about a minute and says when it's done. Then /reload and send
-- WTF/Account/<account>/SavedVariables/BookFinder.lua.
local ADDON, root = ...
local public = root.public
if not public then return end

local PREFIX = "|cff33ff99BookFinder|r: "

-- places to plan journeys to: { title, uiMap, x, y } (0-1), both factions' towns and the far corners
local PLACES = {
	{ "Orgrimmar", 1454, 0.50, 0.50 }, { "Thunder Bluff", 1456, 0.50, 0.50 }, { "Undercity", 1458, 0.50, 0.50 },
	{ "Stormwind City", 1453, 0.50, 0.50 }, { "Ironforge", 1455, 0.50, 0.50 },
	{ "Booty Bay", 1434, 0.27, 0.77 }, { "Gadgetzan", 1446, 0.52, 0.28 }, { "Ratchet", 1413, 0.63, 0.37 },
	{ "Everlook", 1452, 0.61, 0.38 }, { "Light's Hope Chapel", 1423, 0.81, 0.58 },
	{ "Freewind Post", 1441, 0.46, 0.51 }, { "Tarren Mill", 1424, 0.62, 0.20 },
	{ "Kargath", 1418, 0.03, 0.47 }, { "Camp Mojache", 1444, 0.75, 0.44 }, { "Splintertree Post", 1440, 0.73, 0.61 },
}

local run   -- the current run's record

local function now() return debugprofilestop and debugprofilestop() or (GetTime() * 1000) end

local function check(name, fn)
	local started = now()
	local ok, passed, detail = pcall(fn)
	local entry = { name = name, ms = math.floor(now() - started + 0.5) }
	if not ok then
		entry.ok, entry.detail = false, "error: " .. tostring(passed)
	else
		entry.ok, entry.detail = passed and true or false, detail and tostring(detail) or nil
	end
	run.checks[#run.checks + 1] = entry
	if entry.ok then run.passed = run.passed + 1 else run.failed = run.failed + 1 end
	return entry.ok
end

-- The runner: steps in a coroutine, `wait(seconds)` between them, so the game keeps drawing
local co
local function wait(seconds)
	C_Timer.After(seconds or 0, function()
		if co and coroutine.status(co) == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				run.crashed = tostring(err)
				print(PREFIX .. "self-test stopped: " .. tostring(err))
			end
		end
	end)
	coroutine.yield()
end

local function api()
	local spf = ShortestPathForever and ShortestPathForever.API
	return type(spf) == "table" and spf or nil
end

local function journeyNow()
	local spf = api()
	if not (spf and spf.Journey) then return nil end
	local ok, j = pcall(spf.Journey)
	return ok and type(j) == "table" and type(j.goal) == "table" and j or nil
end

local function legsOf(j)
	local out = {}
	for i, leg in ipairs(j and j.legs or {}) do
		if i > 40 then break end
		out[i] = { mode = leg.mode, text = leg.text, seconds = leg.seconds }
	end
	return out
end

local function steps()
	local B, SPF, OM = root.Books, root.SPF, root.OpenMap
	local errorsBefore = #(public.db.errors or {})

	-- The parts
	for key, c in pairs(public.components or {}) do
		check("part " .. key .. " runs here", function() return c.active, c.active and "built in" or "standalone or off" end)
	end

	-- Settings: every page opens
	for _, key in ipairs({ "Map", "Journeys", "Interface", "map", "books", "quests" }) do
		check("settings page " .. key .. " opens", function() return public.OpenSettings(key) end)
		wait(0.3)
	end
	if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	wait(0.3)

	-- The map, the books tab, the quests tab, the services tab
	check("the world map opens", function()
		if not WorldMapFrame:IsShown() then ToggleWorldMap() end
		return WorldMapFrame:IsShown()
	end)
	wait(0.5)
	check("the books tab opens", function()
		public.OpenBooks()
		return ForeverCore.QuestLogTabs.Selected() == "bookfinder.books"
	end)
	wait(1)
	check("the books tab draws its books", function()
		local t = public.BooksTab
		local state = t and t.State and t.State() or "no tab"
		-- (every set folded is a list too: its section headers are drawn)
		return (t and t.Rows() or 0) >= 1 or state:find("[1-9]%d* sections") ~= nil, state
	end)
	check("the books tab has travel times", function()
		local t = public.BooksTab
		local n = t and t.Estimates() or 0
		return n > 0, n .. " books timed"
	end)
	check("the quests tab shows Questie's list", function()
		public.OpenQuestLog()
		local QL = public.QuestLog
		local holder = QL and QL.Holder()
		local list = rawget(_G, "Questie_BaseFrame")
		if not public.Active("Questie") then return true, "Questie isn't built in" end
		return holder and list and list:GetParent() == holder, list and ("in " .. tostring(list:GetParent() and list:GetParent():GetName())) or "no Questie list"
	end)
	check("nothing tracks on screen", function()
		local column = rawget(_G, "ForeverTrackerCompanion")
		local native = ObjectiveTrackerFrame and ObjectiveTrackerFrame:IsVisible()
		return not (column and column:IsVisible()) and not native,
			("column %s, game tracker %s"):format(column and (column:IsVisible() and "visible" or "hidden") or "none", native and "visible" or "hidden")
	end)
	wait(0.5)
	check("the services tab opens", function()
		ForeverCore.QuestLogTabs.Select("services")
		return ForeverCore.QuestLogTabs.Selected() == "services"
	end)

	-- One search: places and books at once, then Questie's database once its index is read
	local ST = public.SearchTest
	check("search finds a place", function()
		local hits = ST and ST.Run("orgrimmar") or {}
		for _, s in ipairs(hits) do if s.key == "places" then return true end end
		return false
	end)
	check("search finds a library book", function()
		local hits = ST and ST.Run("goaz") or {}
		for _, s in ipairs(hits) do if s.key == "books" then return true end end
		return false
	end)
	if ST then
		local started = now()
		ST.Run("ab")  -- (two letters: no database yet)
		ST.Run("zzzz") -- (starts the index)
		for _ = 1, 120 do
			if ST.Index.ready then break end
			wait(0.5)
		end
		check("Questie's database index reads", function()
			local done, total, reading = 0, 0, false
			if ST.Progress then done, total, reading = ST.Progress() end
			return ST.Index.ready, ("%.1f s, %d of %d names read%s"):format((now() - started) / 1000, done or 0, total or 0,
				(not ST.Index.ready and not reading) and ", never started (Questie's database isn't up)" or "")
		end)
		for _, q in ipairs({ { "the killing fields", "quest" }, { "spirit healer", "npc" }, { "linen cloth", "item" }, { "mailbox", "object" } }) do
			check("search finds " .. q[2] .. " \"" .. q[1] .. "\"", function()
				for _, s in ipairs(ST.Run(q[1])) do if s.key == q[2] and #s.rows > 0 then return true, s.total .. " found" end end
				return false
			end)
		end
	end

	-- The map's Show menu: every switch reads, and flips and comes back
	local sections = public.MapMenuSections and public.MapMenuSections() or {}
	check("the Show menu has BookFinder's switches", function()
		local n = 0
		for _, s in ipairs(sections) do n = n + #s.rows end
		return n >= 5, n .. " switches"
	end)
	for _, s in ipairs(sections) do
		for _, r in ipairs(s.rows) do
			local label, get, set = r[1], r[2], r[3]
			if label ~= (B and B.L and B.L["Optimized route"] or "Optimized route") then
				check("switch " .. label .. " flips and comes back", function()
					local before = get() and true or false
					set()
					local flipped = get() and true or false
					set()
					local after = get() and true or false
					return flipped ~= before and after == before, ("%s -> %s -> %s"):format(tostring(before), tostring(flipped), tostring(after))
				end)
				wait(0.2)
			end
		end
	end

	-- Routing: a journey to each place, leg by leg (only when no journey of yours is under way)
	run.routes = {}
	local spf = api()
	if journeyNow() then
		check("routing (skipped: a journey of yours is under way)", function() return true end)
	elseif spf and spf.Navigate then
		local map = C_Map.GetBestMapForUnit("player")
		local pos = map and C_Map.GetPlayerMapPosition(map, "player")
		run.from = { map = map, x = pos and pos.x, y = pos and pos.y, zone = map and C_Map.GetMapInfo(map) and C_Map.GetMapInfo(map).name }
		for _, place in ipairs(PLACES) do
			local title, m, x, y = place[1], place[2], place[3], place[4]
			local route = { to = title, map = m, x = x, y = y }
			local okEst, seconds = pcall(spf.Estimate, map, pos and pos.x, pos and pos.y, m, x, y)
			route.estimate = okEst and seconds or nil
			local okNav, started = pcall(spf.Navigate, ADDON, m, x, y, title)
			route.started = okNav and started or false
			local j
			-- (until the search has its final answer: a plan with nothing still being measured, or no way there. What it
			-- shows on the way is kept too, with the second it appeared: a search offers a route to follow before it is sure)
			local state, _, stateText
			local began, seen = now(), nil
			route.timeline = {}
			for _ = 1, 150 do
				j = journeyNow()
				if public.JourneyStatus then state, _, stateText = public.JourneyStatus() end
				local pending = false
				if SPF and SPF.JourneyStatus then
					local okS, p = pcall(SPF.JourneyStatus)
					pending = okS and p and true or false
				end
				local shape = (state or "none") .. (pending and "+" or "") .. ":" .. (j and #j.legs or 0) .. ":" .. tostring(j and j.secondsLeft)
				if shape ~= seen and #route.timeline < 12 then
					seen = shape
					route.timeline[#route.timeline + 1] = { at = math.floor((now() - began) / 100 + 0.5) / 10, state = state, measuring = pending,
						seconds = j and j.secondsLeft, legs = legsOf(j) }
				end
				if state == "unreachable" or (j and #j.legs > 0 and state == "planned" and not pending) then break end
				wait(0.3)
			end
			route.state, route.stateText = state, stateText
			route.took = math.floor((now() - began) / 100 + 0.5) / 10
			route.goal = j and j.goal and { title = j.goal.title, map = j.goal.map, x = j.goal.x, y = j.goal.y } or nil
			route.owner = j and j.owner
			route.secondsLeft = j and j.secondsLeft
			route.legs = legsOf(j)
			run.routes[#run.routes + 1] = route
			check("journey to " .. title, function()
				local mine = route.goal and route.goal.title == title
				return route.started and #route.legs > 0 and mine,
					("%s, %d legs, planned in %.1f s%s"):format(route.secondsLeft and ("%d s"):format(route.secondsLeft) or "no time", #route.legs,
						route.took or 0, (route.goal and not mine) and (", but another journey took its place: " .. tostring(route.goal.title)) or "")
			end)
			if spf.Cancel then pcall(spf.Cancel, ADDON) end
			if SPF and SPF.ClearJourney and journeyNow() then pcall(SPF.ClearJourney) end
			wait(0.5)
		end
	end

	-- No journey fails in silence: one to nowhere is refused with its reason, and written down
	local J = public.Journeys
	if J and spf and spf.Navigate then
		check("a journey to nowhere says why", function()
			local before = #(public.db.attempts or {})
			local started = spf.Navigate(ADDON, 1454, 7, 7, "nowhere")   -- (7 is off the map: 0 to 1)
			local last = (public.db.attempts or {})[1]
			return not started and #(public.db.attempts or {}) == before + 1 and last and last.result == "refused" and last.why == "place",
				last and (tostring(last.result) .. ", " .. tostring(last.why)) or "nothing recorded"
		end)
	end

	-- Books' route: builds from here and Shortest Path takes it
	if B and not B.__skip and B.BuildRoute then
		check("the books route builds", function()
			local r = B.BuildRoute(true)
			return #r > 0 or #(B.BOOKS or {}) == (B.CountDone and B.CountDone() or 0), #r .. " stops"
		end)
	end

	-- The recorder's own snapshot
	check("the inspect snapshot runs", function() return public.Inspect() end)

	-- Errors while the test ran
	local errors = public.db.errors or {}
	run.newErrors = math.max(0, #errors - errorsBefore)
	check("no Lua errors during the test", function() return run.newErrors == 0, run.newErrors .. " new" end)

	if WorldMapFrame:IsShown() then ToggleWorldMap() end
	run.finished = time()
	print(PREFIX .. ("self-test done: %d passed, %d failed. /reload, then send WTF/Account/<account>/SavedVariables/BookFinder.lua."):format(run.passed, run.failed))
	for _, c in ipairs(run.checks) do
		if not c.ok then print(PREFIX .. "|cffff5555failed|r " .. c.name .. (c.detail and (": " .. c.detail) or "")) end
	end
	co = nil
end

function public.SelfTest()
	if co then print(PREFIX .. "the self-test is already running.") return true end
	if InCombatLockdown() then print(PREFIX .. "not in combat: try again once it's over.") return true end
	run = { started = time(), checks = {}, passed = 0, failed = 0,
		version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"),
		level = UnitLevel("player"), faction = UnitFactionGroup("player") }
	public.db.selftest = run
	print(PREFIX .. "self-test started: stand still and leave the map alone for two or three minutes (a click on it starts a journey of its own).")
	co = coroutine.create(steps)
	local ok, err = coroutine.resume(co)
	if not ok then
		run.crashed = tostring(err)
		print(PREFIX .. "self-test stopped: " .. tostring(err))
		co = nil
	end
	return true
end
