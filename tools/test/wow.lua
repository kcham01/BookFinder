-- tools/test/wow.lua: stand-ins for the parts of the WoW client API that BookFinder uses, for offline tests (lua5.1).
--
-- Not an emulator: frames record what is done to them, timers run when the test calls Tick(), events fire when the
-- test calls Fire(). Tests set the world up through the `World` table (player, quest log, map positions). When a
-- BookFinder file calls something missing here, the test fails with the name, so the stand-ins grow with the addon.

World = {
	time = 0,
	player = {
		name = "Ada Lovelace", realm = "Forever", faction = "Alliance", race = "Human", raceID = 1,
		class = "WARRIOR", classID = 1, level = 10, guid = "Player-1-00000001",
		map = 1429, x = 0.5, y = 0.5, facing = 0,
	},
	completed = {},          -- [questID] = true
	questLog = {},           -- { {questID=, title=, level=, isComplete=, objectives={ {text=, type=, numFulfilled=, numRequired=, finished=} } } }
	bags = {},               -- [itemID] = count
	skills = {},             -- { {name=, rank=, max=} }
	reputations = {},        -- [factionID] = standing value
	sentMessages = {},       -- addon messages sent: { prefix, text, channel, target }
	printed = {},            -- chat lines
	cvars = {},
}

local unpack = unpack

-- Missing API: fail loudly with the name -------------------------------------------------------------------------

-- BookFinder's saved variables read as nil until the test (or the add-on) sets them, as on a first login.
local savedVariables = { BookFinderDB = true, BookFinderCharDB = true }
setmetatable(_G, {
	__index = function(_, k)
		if savedVariables[k] then return nil end
		error("WoW API stand-in missing: " .. tostring(k), 2)
	end,
})

local function strict(name, t)
	return setmetatable(t, {
		__index = function(_, k) error("WoW API stand-in missing: " .. name .. "." .. tostring(k), 2) end,
	})
end

-- Lua extensions the client has ----------------------------------------------------------------------------------

-- The client's xpcall passes extra arguments to the function (plain Lua 5.1's does not).
do
	local plain = xpcall
	xpcall = function(fn, handler, ...)
		local n, args = select("#", ...), { ... }
		return plain(function() return fn(unpack(args, 1, n)) end, handler)
	end
end

strsplit = function(sep, s, limit)
	local out, start = {}, 1
	while true do
		if limit and #out == limit - 1 then out[#out + 1] = s:sub(start) break end
		local i, j = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start) break end
		out[#out + 1] = s:sub(start, i - 1)
		start = j + 1
	end
	return unpack(out)
end
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert, tremove, wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end
format = string.format
strlower, strupper, strsub, strlen, strfind, strmatch, gsub = string.lower, string.upper, string.sub, string.len,
	string.find, string.match, string.gsub
floor, ceil, abs, min, max, sqrt = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt
mod = math.fmod
bit = {
	band = function(a, b)
		local r, p = 0, 1
		while a > 0 and b > 0 do
			if a % 2 == 1 and b % 2 == 1 then r = r + p end
			a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
		end
		return r
	end,
	bor = function(a, b)
		local r, p = 0, 1
		while a > 0 or b > 0 do
			if a % 2 == 1 or b % 2 == 1 then r = r + p end
			a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
		end
		return r
	end,
	lshift = function(a, n) return a * 2 ^ n end,
	rshift = function(a, n) return math.floor(a / 2 ^ n) end,
}
debugprofilestop = function() return os.clock() * 1000 end
GetTime = function() return World.time end
time = function(t) if t then return os.time(t) end return 1700000000 + math.floor(World.time) end
date = os.date

local errors = {}
World.errors = errors
geterrorhandler = function()
	return function(err)
		errors[#errors + 1] = tostring(err) .. "\n" .. debug.traceback()
		return err
	end
end

-- Timers ---------------------------------------------------------------------------------------------------------

local timers = {}
local function newTimer(seconds, fn, iterations)
	local t = { at = World.time + seconds, every = seconds, fn = fn, left = iterations }
	function t:Cancel() self.cancelled = true end
	function t:IsCancelled() return self.cancelled end
	timers[#timers + 1] = t
	return t
end
C_Timer = strict("C_Timer", {
	After = function(seconds, fn) newTimer(seconds, fn, 1) end,
	NewTimer = function(seconds, fn) return newTimer(seconds, fn, 1) end,
	NewTicker = function(seconds, fn, n) return newTimer(seconds, fn, n or math.huge) end,
})

local onUpdateFrames = {}

--- Advances the clock by `seconds` in frames of `step`, running timers and OnUpdate scripts.
function Tick(seconds, step)
	step = step or 0.05
	local stop = World.time + (seconds or 0)
	repeat
		World.time = World.time + step
		for _, f in ipairs(onUpdateFrames) do
			local script = f.scripts.OnUpdate
			if script and f.shown ~= false then script(f, step) end
		end
		local i = 1
		while i <= #timers do
			local t = timers[i]
			if t.cancelled then
				table.remove(timers, i)
			elseif t.at <= World.time then
				t.fn(t)
				t.left = t.left - 1
				if t.left <= 0 or t.cancelled then table.remove(timers, i) else t.at = t.at + t.every; i = i + 1 end
			else
				i = i + 1
			end
		end
	until World.time >= stop
end

-- Frames ---------------------------------------------------------------------------------------------------------

local eventFrames = {}
local Region = {}
Region.__index = function(self, k)
	local v = Region[k]
	if v ~= nil then return v end
	-- Any other method is accepted and recorded, so layout code runs; tests assert on what matters.
	return function(frame, ...)
		frame.calls = frame.calls or {}
		frame.calls[#frame.calls + 1] = { k, ... }
	end
end

local function newRegion(kind, name, parent)
	local r = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, children = {}, shown = true,
		points = {}, width = 0, height = 0, alpha = 1 }, Region)
	if name then _G[name] = r end
	if parent and parent.children then parent.children[#parent.children + 1] = r end
	return r
end

function Region:SetScript(name, fn)
	self.scripts[name] = fn
	if name == "OnUpdate" and fn then
		local known = false
		for _, f in ipairs(onUpdateFrames) do if f == self then known = true end end
		if not known then onUpdateFrames[#onUpdateFrames + 1] = self end
	end
end
function Region:GetScript(name) return self.scripts[name] end
function Region:HookScript(name, fn)
	local old = self.scripts[name]
	self.scripts[name] = function(...) if old then old(...) end fn(...) end
end
function Region:RegisterEvent(e) eventFrames[self] = eventFrames[self] or {}; eventFrames[self][e] = true end
function Region:UnregisterEvent(e) if eventFrames[self] then eventFrames[self][e] = nil end end
function Region:UnregisterAllEvents() eventFrames[self] = nil end
function Region:IsEventRegistered(e) return eventFrames[self] and eventFrames[self][e] or false end
function Region:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Region:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end
function Region:IsShown() return self.shown end
function Region:IsVisible() return self.shown and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible()) end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width end
function Region:GetHeight() return self.height end
function Region:GetSize() return self.width, self.height end
function Region:SetAlpha(a) self.alpha = a end
function Region:GetAlpha() return self.alpha end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
function Region:GetStringWidth() return #(self.text or "") * 6 end
function Region:GetStringHeight() return 12 end
function Region:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:GetNumPoints() return #self.points end
function Region:GetParent() return self.parent end
function Region:SetParent(p) self.parent = p end
function Region:GetName() return self.name end
function Region:GetObjectType() return self.kind end
function Region:IsObjectType(t) return self.kind == t end
function Region:GetChildren() return unpack(self.children) end
function Region:EnableMouse(v) self.mouse = v end
function Region:IsMouseOver() return false end
function Region:GetEffectiveScale() return 1 end
function Region:GetScale() return self.scale or 1 end
function Region:SetScale(s) self.scale = s end
function Region:GetFrameLevel() return self.level or 1 end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetCenter() return 0, 0 end
function Region:GetLeft() return 0 end
function Region:GetTop() return 0 end
function Region:CreateTexture(name) return newRegion("Texture", name, self) end
function Region:CreateFontString(name) return newRegion("FontString", name, self) end
function Region:CreateAnimationGroup() return newRegion("AnimationGroup", nil, self) end
function Region:CreateAnimation(kind) return newRegion(kind or "Animation", nil, self) end
function Region:SetTexture(t) self.texture = t end
function Region:GetTexture() return self.texture end
function Region:SetAtlas(a) self.atlas = a end
function Region:GetAtlas() return self.atlas end
function Region:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetChecked(v) self.checked = v end
function Region:GetChecked() return self.checked end
function Region:SetValue(v) self.value = v end
function Region:GetValue() return self.value end
function Region:Enable() self.enabled = true end
function Region:Disable() self.enabled = false end
function Region:IsEnabled() return self.enabled ~= false end
function Region:SetEnabled(v) self.enabled = v end

CreateFrame = function(kind, name, parent, template)
	local f = newRegion(kind, name, parent)
	f.template = template
	return f
end

UIParent = newRegion("Frame", "UIParent")
WorldFrame = newRegion("Frame", "WorldFrame")
Minimap = newRegion("Minimap", "Minimap")
GameTooltip = newRegion("GameTooltip", "GameTooltip", UIParent)
GameTooltip.lines = {}
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
function GameTooltip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = tostring(a) .. " | " .. tostring(b) end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:SetOwner(o) self.owner = o; self.lines = {} end
function GameTooltip:NumLines() return #self.lines end

--- Sends `event` with its arguments to every frame registered for it.
function Fire(event, ...)
	for frame, events in pairs(eventFrames) do
		if events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
	end
end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) World.printed[#World.printed + 1] = text end }
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end io.write(table.concat(t, " "), "\n") end

-- Add-ons, player, world -----------------------------------------------------------------------------------------

World.addons = { BookFinder = { Version = "test" } }
C_AddOns = strict("C_AddOns", {
	GetAddOnMetadata = function(name, key) return World.addons[name] and World.addons[name][key] end,
	IsAddOnLoaded = function(name) return World.addons[name] ~= nil and World.addons[name].loaded ~= false end,
	GetAddOnEnableState = function(name) return World.addons[name] and 2 or 0 end,
})

UnitName = function(unit) if unit == "player" then return World.player.name, nil end return nil end
UnitFullName = function(unit) if unit == "player" then return World.player.name, World.player.realm end end
UnitGUID = function(unit) if unit == "player" then return World.player.guid end end
UnitFactionGroup = function() return World.player.faction, World.player.faction end
UnitRace = function() return World.player.race, World.player.race, World.player.raceID end
UnitClass = function() return World.player.class, World.player.class, World.player.classID end
UnitClassBase = function() return World.player.class, World.player.classID end
UnitLevel = function() return World.player.level end
UnitSex = function() return 2 end
UnitExists = function(unit) return unit == "player" end
UnitIsDeadOrGhost = function() return false end
UnitAffectingCombat = function() return false end
InCombatLockdown = function() return false end
IsInGroup = function() return false end
IsInRaid = function() return false end
IsInInstance = function() return false, "none" end
GetNumGroupMembers = function() return 0 end
GetRealmName = function() return World.player.realm end
GetLocale = function() return "enUS" end
GetPlayerFacing = function() return World.player.facing end
GetCVar = function(k) return World.cvars[k] end
SetCVar = function(k, v) World.cvars[k] = v end
GetCVarBool = function(k) return World.cvars[k] == "1" end

C_Map = strict("C_Map", {
	GetBestMapForUnit = function() return World.player.map end,
	GetPlayerMapPosition = function()
		return { x = World.player.x, y = World.player.y, GetXY = function(p) return p.x, p.y end }
	end,
	GetMapInfo = function(id) return World.maps and World.maps[id] or { mapID = id, name = "Map " .. id, mapType = 3, parentMapID = 1415 } end,
	GetWorldPosFromMapPos = function(map, pos)
		local m = World.maps and World.maps[map]
		local s = m and m.size or 1000
		return 0, { x = pos.x * s, y = pos.y * s, GetXY = function(p) return p.x, p.y end }
	end,
	GetMapPosFromWorldPos = function(continent, pos, map)
		local m = World.maps and World.maps[map]
		local s = m and m.size or 1000
		return map, { x = pos.x / s, y = pos.y / s, GetXY = function(p) return p.x, p.y end }
	end,
	GetMapChildrenInfo = function() return {} end,
	CanSetUserWaypointOnMap = function() return true end,
	SetUserWaypoint = function(point) World.waypoint = point end,
	GetUserWaypoint = function() return World.waypoint end,
	HasUserWaypoint = function() return World.waypoint ~= nil end,
	ClearUserWaypoint = function() World.waypoint = nil end,
})
C_DateAndTime = strict("C_DateAndTime", {
	GetCurrentCalendarTime = function()
		local d = World.date or { year = 2026, month = 11, monthDay = 14, hour = 12, minute = 0 }
		return d
	end,
})
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end }
CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(p) return p.x, p.y end } end

C_QuestLog = strict("C_QuestLog", {
	IsQuestFlaggedCompleted = function(id) return World.completed[id] == true end,
	GetAllCompletedQuestIDs = function() local t = {} for id in pairs(World.completed) do t[#t + 1] = id end return t end,
	GetQuestObjectives = function(id)
		for _, q in ipairs(World.questLog) do if q.questID == id then return q.objectives end end
		return {}
	end,
	IsOnQuest = function(id) for _, q in ipairs(World.questLog) do if q.questID == id then return true end end return false end,
	-- Forever's modern quest log: one header line ("Zone") before each quest's zone, as the client lists them.
	GetNumQuestLogEntries = function() return #World.QuestLogLines(), #World.questLog end,
	GetInfo = function(index) return World.QuestLogLines()[index] end,
	IsComplete = function(id)
		for _, q in ipairs(World.questLog) do if q.questID == id then return q.isComplete == 1 end end
		return false
	end,
	IsFailed = function(id)
		for _, q in ipairs(World.questLog) do if q.questID == id then return q.isComplete == -1 end end
		return false
	end,
	GetLogIndexForQuestID = function(id)
		for i, l in ipairs(World.QuestLogLines()) do if l.questID == id then return i end end
	end,
	GetQuestWatchType = function() return nil end,
	AddQuestWatch = function() end,
	RemoveQuestWatch = function() end,
	GetTimeAllowed = function() return nil end,
})

function World.QuestLogLines()
	local lines, header = {}, nil
	for _, q in ipairs(World.questLog) do
		local zone = q.zone or "Elwynn Forest"
		if zone ~= header then
			header = zone
			lines[#lines + 1] = { title = zone, isHeader = true }
		end
		lines[#lines + 1] = { title = q.title, level = q.level, questID = q.questID, isHeader = false, frequency = 1 }
	end
	return lines
end
GetQuestsCompleted = function() local t = {} for id in pairs(World.completed) do t[id] = true end return t end
GetNumQuestLogEntries = function() return #World.questLog, #World.questLog end
GetQuestLogTitle = function(i)
	local q = World.questLog[i]
	if not q then return nil end
	-- title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
	return q.title, q.level, 0, false, false, q.isComplete, 1, q.questID
end
GetNumQuestLeaderBoards = function(i) local q = World.questLog[i] return q and #q.objectives or 0 end
GetQuestLogLeaderBoard = function(o, i)
	local obj = World.questLog[i].objectives[o]
	return obj.text, obj.type, obj.finished
end
GetQuestLogSelection = function() return 0 end
SelectQuestLogEntry = function() end

GetItemCount = function(id) return World.bags[id] or 0 end
GetNumSkillLines = function() return #World.skills end
GetSkillLineInfo = function(i) local s = World.skills[i] return s.name, false, false, s.rank, 0, 0, s.max end
GetFactionInfoByID = function(id)
	local v = World.reputations[id]
	if not v then return nil end
	return "Faction " .. id, "", 4, 0, 42000, v
end
IsSpellKnown = function() return false end
C_Spell = strict("C_Spell", { GetSpellName = function(id) return World.spellNames and World.spellNames[id] or nil end })
C_SkillInfo = strict("C_SkillInfo", {
	GetSkillLineInfoByID = function(id)
		for _, s in ipairs(World.skills) do if s.id == id then return { name = s.name, rank = s.rank, max = s.max } end end
		return nil
	end,
})
GetSpellInfo = function(id) return World.spellNames and World.spellNames[id] or nil end

C_ChatInfo = strict("C_ChatInfo", {
	RegisterAddonMessagePrefix = function() return true end,
	IsAddonMessagePrefixRegistered = function() return true end,
	SendAddonMessage = function(prefix, text, channel, target)
		World.sentMessages[#World.sentMessages + 1] = { prefix, text, channel, target }
		return true
	end,
})

hooksecurefunc = function(t, name, fn)
	if type(t) == "string" then t, name, fn = _G, t, name end
	local old = rawget(t, name)
	t[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
end
SlashCmdList = {}
StaticPopupDialogs = {}
StaticPopup_Show = function() end
PlaySound = function() end
PlaySoundFile = function() end
SOUNDKIT = setmetatable({}, { __index = function(_, k) return k end })
