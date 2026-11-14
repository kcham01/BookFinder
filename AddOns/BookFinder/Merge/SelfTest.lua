-- BookFinder: /bookfinder selftest. Goes through every feature in the game itself and writes what happened to
-- BookFinderDB.selftest: each check (passed or failed, why, how long it took) and every Lua error meanwhile. Stand
-- still out of combat; it takes under a minute and says when it's done. Then /reload and send
-- WTF/Account/<account>/SavedVariables/BookFinder.lua.
local ADDON, root = ...
local public = root.public
if not public then return end

local PREFIX = "|cff33ff99BookFinder|r: "

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

local function steps()
	local B = root.Books
	local errorsBefore = #(public.db.errors or {})

	-- The parts
	for key, c in pairs(public.components or {}) do
		check("part " .. key .. " runs here", function() return c.active, c.active and "built in" or "standalone or off" end)
	end

	-- Settings: every page opens
	-- BookFinder's settings window: every section draws its settings (Quests once Questie's options have loaded)
	local OW, O = public.OptionsWindow, public.Options
	if OW and O then
		public.OpenOptions("map")
		for _, sec in ipairs(O.SECTIONS) do
			check("settings: " .. sec.label .. " draws", function()
				OW.Select(sec.key)
				local n = OW.Rows()
				return n > 2, n .. " rows"
			end)
			wait(0.3)
		end
		check("settings: every entry reads", function()
			local bad = {}
			for _, e in ipairs(O.All()) do
				local ok = pcall(e.get or e.run and function() end)
				if not ok then bad[#bad + 1] = e.id end
			end
			return #bad == 0, #bad == 0 and (#O.All() .. " settings") or table.concat(bad, ", ")
		end)
		if BookFinderOptions then BookFinderOptions:Hide() end
	end
	wait(0.3)

	-- The map, the books tab, the quests tab, the services tab
	check("the world map opens", function()
		if not WorldMapFrame:IsShown() then ToggleWorldMap() end
		return WorldMapFrame:IsShown()
	end)
	wait(0.5)
	check("the books tab opens", function()
		public.OpenBooks()
		return public.Tabs.Selected() == "bookfinder.books"
	end)
	wait(1)
	check("the books tab draws its books", function()
		local t = public.BooksTab
		local state = t and t.State and t.State() or "no tab"
		-- (every set folded is a list too: its section headers are drawn)
		return (t and t.Rows() or 0) >= 1 or state:find("[1-9]%d* sections") ~= nil, state
	end)
	check("the books tab has distances", function()
		local t = public.BooksTab
		local n = t and t.Estimates() or 0
		return n > 0, n .. " books measured"
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
		local native = ObjectiveTrackerFrame and ObjectiveTrackerFrame:IsVisible()
		return not native, ("game tracker %s"):format(native and "visible" or "hidden")
	end)
	wait(0.5)
	check("the panel's search shows results in the books tab", function()
		public.OpenBooks()
		local t = public.BooksTab
		if not (t and t.Search) then return false, "no tab" end
		t.Search("orgrimmar")
		local n = t.Rows()
		t.Search("")
		return n > 0, n .. " results"
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

	-- OpenMap's panel: every switch on it reads, flips and comes back (BookFinder adds none to the game's Show menu)
	local wm = root.OpenMap and root.OpenMap.modules and root.OpenMap.modules.worldmap
	local panelRows = wm and wm.PanelRows and select(2, pcall(wm.PanelRows)) or {}
	if type(panelRows) ~= "table" then panelRows = {} end
	local switches = {}
	for _, r in ipairs(panelRows) do
		if type(r[2]) == "function" and type(r[3]) == "function" and r.id ~= "debug" and r.id ~= "paint" then switches[#switches + 1] = r end
	end
	check("OpenMap's panel has the map switches", function() return #switches >= 8, #switches .. " switches" end)
	for _, r in ipairs(switches) do
		check("switch " .. tostring(r[1]) .. " flips and comes back", function()
			local before = r[2]() and true or false
			r[3](not before)
			local flipped = r[2]() and true or false
			r[3](before)
			local after = r[2]() and true or false
			return flipped ~= before and after == before, ("%s -> %s -> %s"):format(tostring(before), tostring(flipped), tostring(after))
		end)
		wait(0.2)
	end

	-- The map's own Show dropdown, drawn in Questie's style
	check("the map's Show menu is drawn in Questie's style", function()
		local M = public.MapShowMenu
		if not M then return false, "no module" end
		M.Install()
		local n = M.Count()
		return M.Cover() ~= nil and n > 0, ("button %s, %d entries read"):format(M.Find() and "found" or "not found", n)
	end)

	-- The map pin: a click's waypoint is the game's own, and a spot it can't take says so
	check("a map pin goes on Orgrimmar", function()
		local ok = public.Waypoint(1454, 50, 50, "Orgrimmar")
		local wp = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
		local tracked = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()
		return ok and wp ~= nil and wp.uiMapID == 1454, ("pin %s, arrow %s"):format(wp and tostring(wp.uiMapID) or "none", tostring(tracked))
	end)
	public.ClearWaypoint()
	check("a pin with no place says why", function()
		return public.Waypoint(nil, nil, nil, "nowhere") == false
	end)

	-- The Quests tab's scrollbar is Questie's own, beside its list
	check("the quest list's scrollbar is its own", function()
		public.OpenQuestLog()
		local scroll = rawget(_G, "TrackedQuestsScrollFrame")
		if not public.Active("Questie") then return true, "Questie isn't built in" end
		if not scroll then return false, "no Questie list" end
		local range = scroll:GetVerticalScrollRange()
		local shown = scroll.ScrollBar and scroll.ScrollBar:IsShown()
		return (range > 1) == (shown and true or false), ("range %d, bar %s"):format(range, shown and "shown" or "hidden")
	end)

	-- Books' route: builds from here
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
	print(PREFIX .. "self-test started: stand still for about a minute.")
	co = coroutine.create(steps)
	local ok, err = coroutine.resume(co)
	if not ok then
		run.crashed = tostring(err)
		print(PREFIX .. "self-test stopped: " .. tostring(err))
		co = nil
	end
	return true
end
