-- BookFinder: every journey goes through one door, and none fails in silence.
--
-- The search, the books tab, Questie's quests (through Shortest Path's TomTom stand-in), Nearby services and any guide
-- all ask Shortest Path for a journey with API.NavigateRoute. On its own it answers false without a word when you are
-- in combat, when journeys are off, when it can't tell where you are or when the place is on no map; and once it has
-- started, "still searching" and "no way there" were only ever said in its tracker, which BookFinder keeps off the
-- screen. Here:
--   * a journey asked for in combat is kept and starts the moment combat ends;
--   * every other refusal says why, on screen (the game's own message line) and in chat;
--   * a journey that started and then found no way there says so too;
--   * every request and what became of it is written to BookFinderDB.attempts, for the file you send.
local ADDON, root = ...
local public = root.public
if not public then return end

local PREFIX = "|cff33ff99BookFinder|r: "
local MAX_ATTEMPTS = 60

-- One line on screen and in chat; the same line is not repeated within a few seconds (guides resend their stop).
local lastText, lastAt = nil, 0
local function notice(text)
	local now = GetTime and GetTime() or 0
	if text == lastText and now - lastAt < 4 then return end
	lastText, lastAt = text, now
	if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) end
	print(PREFIX .. text)
end
public.Notice = notice

local function record(entry)
	local db = public.db
	if not db then return entry end
	db.attempts = type(db.attempts) == "table" and db.attempts or {}
	entry.time = time and time() or nil
	local map = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	entry.from = type(info) == "table" and info.name or map
	table.insert(db.attempts, 1, entry)
	while #db.attempts > MAX_ATTEMPTS do table.remove(db.attempts) end
	return entry
end

local function spf()
	local SPF = root.SPF
	return SPF and not SPF.__skip and SPF or nil
end

local function titleOf(stops)
	local last = type(stops) == "table" and stops[#stops]
	local title = type(last) == "table" and type(last.title) == "string" and last.title or nil
	return title and title ~= "" and title or "that place"
end

local function onMap(stop)
	if type(stop) ~= "table" or type(stop.map) ~= "number" or type(stop.x) ~= "number" or type(stop.y) ~= "number" then return false end
	if stop.x < 0 or stop.x > 1 or stop.y < 0 or stop.y > 1 then return false end
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return true end
	local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, stop.map, CreateVector2D(stop.x, stop.y))
	return ok and continent ~= nil and world ~= nil
end

-- Why Shortest Path said no: a code for the record, and the words for you
local function whyNot(stops)
	local SPF = spf()
	local title = titleOf(stops)
	if InCombatLockdown() then
		return "combat", ("In combat: the journey to %s starts when the fight ends."):format(title)
	end
	local db = SPF and SPF.db or rawget(_G, "ShortestPathForeverDB")
	if type(db) == "table" and db.journey == false then
		return "off", "Journeys are turned off: turn them on in Options > AddOns > BookFinder > Journeys."
	end
	if SPF and SPF.JourneyPosition and not SPF.JourneyPosition() then
		return "position", "No journey from here: the game doesn't say where you are (inside an instance?)."
	end
	if type(stops) == "table" then
		for _, stop in ipairs(stops) do
			if not onMap(stop) then return "place", ("No journey to %s: it isn't on a map of the world."):format(title) end
		end
	end
	return "refused", ("Shortest Path couldn't start the journey to %s."):format(title)
end

local function copyStops(stops)
	local function copy(value, depth)
		if type(value) ~= "table" or depth > 4 then return value end
		local out = {}
		for k, v in pairs(value) do out[k] = copy(v, depth + 1) end
		return out
	end
	return copy(stops, 0)
end

-- After a start: whether the search found a way. Shortest Path's own words for it, the ones its tracker would show.
local watching
local function status()
	local SPF = spf()
	if not (SPF and SPF.JourneyInfo) then return nil end
	local ok, title, rows = pcall(SPF.JourneyInfo)
	if not ok or not title or type(rows) ~= "table" or not rows[1] then return nil end
	local key = rows[1].key
	if key == "searching" or key == "unreachable" then return key, title, rows[1].text end
	return "planned", title
end
public.JourneyStatus = status

local function watch(entry)
	watching = entry
	if not (C_Timer and C_Timer.After) then return end
	local ticks, dead = 0, 0
	local function tick()
		if watching ~= entry then return end
		ticks = ticks + 1
		local state, title, text = status()
		entry.outcome = state or entry.outcome
		if state == "planned" or not state then
			-- (the recorder keeps the plan: its own subscription missed them in 1.8.0)
			if state and public.RecordJourney then pcall(public.RecordJourney) end
			if state or ticks > 2 then watching = nil return end
		elseif state == "unreachable" then
			dead = dead + 1
			-- (twice running: a search between two rounds reads the same for an instant)
			if dead >= 2 then
				entry.reason = text
				notice(("No way to %s from here%s"):format(entry.title or title or "there", text and text ~= "" and (": " .. text) or "."))
				watching = nil
				return
			end
		else
			dead = 0
		end
		if ticks < 45 then C_Timer.After(1, tick) else watching = nil end
	end
	C_Timer.After(1, tick)
end

-- A first plan, sooner. Shortest Path gives its walking search 2 ms of each frame, so that a search behind a journey
-- you are already following never shows. But a journey to another continent needs a second or more of searching
-- before it has anything to follow: 15 to 30 s at 2 ms a frame (your 1.8.0 self-test: Light's Hope Chapel had no plan
-- after 18 s). While there is no plan at all, the search gets FIRST_PLAN_MS of each frame; with a plan to follow it
-- goes back to Shortest Path's own figure.
local FIRST_PLAN_MS = 8
local ownBudget
local function pace()
	local SPF = spf()
	local Path = SPF and SPF.Path
	if not (Path and type(Path.budget) == "number") then return end
	ownBudget = ownBudget or Path.budget
	local want = status() == "searching" and math.max(ownBudget, FIRST_PLAN_MS) or ownBudget
	if Path.budget ~= want then Path.budget = want end
end

local queued   -- the journey asked for in combat
local original

local function navigateRoute(owner, stops, ...)
	local started = original(owner, stops, ...)
	local first = type(stops) == "table" and stops[1]
	local entry = { owner = type(owner) == "string" and owner or nil, title = titleOf(stops), stops = type(stops) == "table" and #stops or 0,
		map = type(first) == "table" and first.map or nil, x = type(first) == "table" and first.x or nil, y = type(first) == "table" and first.y or nil }
	if started then
		queued = nil
		entry.result = "started"
		pace()
		watch(record(entry))
		return true
	end
	local code, text = whyNot(stops)
	entry.why = code
	if code == "combat" and type(stops) == "table" and #stops > 0 then
		queued = { owner = owner, stops = copyStops(stops) }
		entry.result = "queued"
		record(entry)
		notice(text)
		return true
	end
	entry.result = "refused"
	record(entry)
	notice(text)
	return false
end

local function install()
	local api = ShortestPathForever and ShortestPathForever.API
	if type(api) ~= "table" or type(api.NavigateRoute) ~= "function" or original then return false end
	original = api.NavigateRoute
	api.NavigateRoute = navigateRoute
	api.Navigate = function(owner, map, x, y, title, kind)
		return navigateRoute(owner, { { map = map, x = x, y = y, title = title, kind = kind } })
	end
	-- cancelling forgets the journey that was waiting for combat to end
	local cancel = api.Cancel
	if type(cancel) == "function" then
		api.Cancel = function(owner, ...)
			if queued and queued.owner == owner then queued = nil end
			return cancel(owner, ...)
		end
	end
	return true
end

-- A journey to a point of a zone map (x, y in 0-100, as Questie and the books have them); true when it started or
-- waits for combat to end. Whatever else happens is said on screen.
function public.Journey(map, x, y, title)
	install()
	local api = ShortestPathForever and ShortestPathForever.API
	if type(api) ~= "table" or type(api.Navigate) ~= "function" then
		notice("Shortest Path isn't running, so there are no journeys.")
		return false
	end
	if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		notice(("No journey to %s: no place is known for it."):format(title or "that"))
		return false
	end
	return api.Navigate(ADDON, map, x / 100, y / 100, title) and true or false
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		install()
		if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.2, pace) end
	elseif queued then
		local q = queued
		queued = nil
		local function go() navigateRoute(q.owner, q.stops) end
		if C_Timer and C_Timer.After then C_Timer.After(0.2, go) else go() end
	end
end)

-- for the self-test and the offline test
public.Journeys = {
	Install = install,
	WhyNot = whyNot,
	Queued = function() return queued end,
	Pace = pace,
	Original = function(fn) local was = original original = fn or original return was end,
	Flush = function() if queued then local q = queued queued = nil return navigateRoute(q.owner, q.stops) end end,
}
