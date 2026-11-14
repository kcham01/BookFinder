-- BookFinder: the namespace, events and messages every other file builds on.
--
-- Every file receives (addonName, BF) from the client. BF is the one shared table: modules hang off it by name
-- (BF.Quests, BF.Map ...). Nothing global is created except the saved variables and the slash commands.

local ADDON, BF = ...

BF.name = ADDON
BF.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
BF.Data = BF.Data or { quests = {}, npcs = {}, objects = {}, items = {} }

local geterrorhandler = geterrorhandler
local xpcall = xpcall

-- A handler that throws must not stop the other handlers of the same event, nor leave the event half delivered.
local function safecall(fn, ...)
	return xpcall(fn, geterrorhandler(), ...)
end
BF.safecall = safecall

-- Game events -----------------------------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Handler lists are walked in place. Removing a handler while its list is being walked only blanks the slot (false);
-- the list is compacted once the walk ends, so no handler is skipped or called twice.
local walking = {}

local function compact(list)
	local j = 0
	for i = 1, #list do
		local fn = list[i]
		list[i] = nil
		if fn then
			j = j + 1
			list[j] = fn
		end
	end
end

local function remove(list, fn, key)
	for i = #list, 1, -1 do
		if list[i] == fn then
			if walking[key] then list[i] = false else table.remove(list, i) end
		end
	end
end

local function dispatch(list, key, ...)
	walking[key] = (walking[key] or 0) + 1
	local n = #list -- handlers added during the walk wait for the next one
	for i = 1, n do
		local fn = list[i]
		if fn then safecall(fn, ...) end
	end
	walking[key] = walking[key] - 1
	if walking[key] == 0 then
		walking[key] = nil
		compact(list)
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = eventHandlers[event]
	if list then dispatch(list, list, event, ...) end
end)

--- Calls fn(event, ...) on every `event`. Returns fn, for BF:Off.
function BF:On(event, fn)
	local list = eventHandlers[event]
	if not list then
		list = {}
		eventHandlers[event] = list
		eventFrame:RegisterEvent(event)
	end
	list[#list + 1] = fn
	return fn
end

function BF:Off(event, fn)
	local list = eventHandlers[event]
	if not list then return end
	remove(list, fn, list)
	if not walking[list] and #list == 0 then
		eventHandlers[event] = nil
		eventFrame:UnregisterEvent(event)
	end
end

--- Calls fn once on the next `event`, then forgets it.
function BF:Once(event, fn)
	local wrapper
	wrapper = function(...)
		BF:Off(event, wrapper)
		fn(...)
	end
	return BF:On(event, wrapper)
end

-- BookFinder's own messages (between its modules) -------------------------------------------------------------------
--
-- Messages are named like events, prefixed "BF_": BF_SETTING_CHANGED, BF_QUESTS_CHANGED, BF_WAYPOINT_CHANGED ...
-- Each is listed where it is first sent, with its arguments.

local listeners = {}

function BF:Listen(message, fn)
	local list = listeners[message]
	if not list then
		list = {}
		listeners[message] = list
	end
	list[#list + 1] = fn
	return fn
end

function BF:Unlisten(message, fn)
	local list = listeners[message]
	if list then remove(list, fn, list) end
end

function BF:Send(message, ...)
	local list = listeners[message]
	if list then dispatch(list, list, message, ...) end
end

-- Start-up ----------------------------------------------------------------------------------------------------------
--
-- Modules register what to run at each stage instead of each listening for ADDON_LOADED / PLAYER_LOGIN themselves,
-- so the order is explicit:
--   "load"   saved variables are ready (ADDON_LOADED for BookFinder): settings, data overrides.
--   "login"  the player exists (PLAYER_LOGIN): player facts, quest log, map, UI.
--   "world"  the world is shown (first PLAYER_ENTERING_WORLD): anything that needs positions or the map open once.

local stages = { load = {}, login = {}, world = {} }
local reached = {}

--- Runs fn at `stage` (in registration order, after lower `order` values: default 50). Late registrations run now.
function BF:At(stage, fn, order)
	local list = assert(stages[stage], "unknown stage " .. tostring(stage))
	if reached[stage] then
		safecall(fn)
		return
	end
	list[#list + 1] = { fn = fn, order = order or 50, index = #list + 1 }
end

local function runStage(stage)
	if reached[stage] then return end
	reached[stage] = true
	local list = stages[stage]
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.index < b.index
	end)
	for _, entry in ipairs(list) do safecall(entry.fn) end
	BF:Send("BF_STAGE", stage)
end

function BF:Reached(stage)
	return reached[stage] == true
end

BF:On("ADDON_LOADED", function(_, name)
	if name == ADDON then runStage("load") end
end)
BF:On("PLAYER_LOGIN", function()
	runStage("load") -- in case ADDON_LOADED came before this file (it cannot, but a reload under a debugger can)
	runStage("login")
end)
BF:Once("PLAYER_ENTERING_WORLD", function()
	runStage("world")
end)

-- Small shared helpers ----------------------------------------------------------------------------------------------

--- Chat line in the game's system colour, starting with BookFinder's name in gold.
function BF:Print(fmt, ...)
	local text = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100BookFinder:|r " .. text)
end

--- Runs fn after `seconds`; returns a handle with :Cancel().
function BF:After(seconds, fn)
	return C_Timer.NewTimer(seconds, function() safecall(fn) end)
end

--- Calls fn every `seconds` until the returned ticker is cancelled.
function BF:Every(seconds, fn)
	return C_Timer.NewTicker(seconds, function() safecall(fn) end)
end

--- Coalesces bursts: fn runs once, `delay` seconds after the last call (bags and quest logs fire in bursts).
function BF:Debounce(delay, fn)
	local timer
	return function()
		if timer then timer:Cancel() end
		timer = C_Timer.NewTimer(delay, function()
			timer = nil
			safecall(fn)
		end)
	end
end

--- Runs work(step) a slice at a time so long jobs never freeze a frame. work returns true when finished.
--- budget: milliseconds per frame (default 4).
function BF:Spread(work, budget, onDone)
	budget = budget or 4
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function(self)
		local start = debugprofilestop()
		repeat
			local ok, finished = xpcall(work, geterrorhandler())
			if not ok or finished then
				self:SetScript("OnUpdate", nil)
				if onDone then safecall(onDone) end
				return
			end
		until debugprofilestop() - start > budget
	end)
	return frame
end
