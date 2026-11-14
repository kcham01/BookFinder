-- Holidays: which world events are running now, and so which holiday quests exist today.
--
-- Dates come from the data (BF.Data.eventDates, lunarFestival per year; `false` = the holiday does not exist here).
-- The Darkmoon Faire has no fixed dates: it opens on the Monday after the first Friday of the month at 03:00 and
-- closes a week later at 03:00, in Elwynn Forest in odd months and Mulgore in even ones; its NPCs' rows are switched
-- to the right place (BF.Data.darkmoonNpcs).
--
-- Messages: BF_EVENTS_CHANGED()

local _, BF = ...
local L = BF.L

local Events = { active = {}, questEvent = {}, activeQuests = {} }
BF.Events = Events

-- These four "Your Fortune Awaits You..." quests can be handed in when the faire has gone.
local turnInAnytime = { [7937] = true, [7938] = true, [7944] = true, [7945] = true }

local function now()
	local t
	if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
		local c = C_DateAndTime.GetCurrentCalendarTime()
		t = { year = c.year, month = c.month, day = c.monthDay, hour = c.hour, min = c.minute }
	else
		local d = date("*t")
		t = { year = d.year, month = d.month, day = d.day, hour = d.hour, min = d.min }
	end
	return t
end

-- Minutes since the start of the year for (month, day, hour, minute): enough to compare dates within a year.
local function stamp(month, day, hour, minute)
	return (((month - 1) * 31 + (day - 1)) * 24 + (hour or 0)) * 60 + (minute or 0)
end

local function parseDate(s)
	if not s then return nil end
	local d, m = s:match("^(%d+)/(%d+)$")
	return tonumber(d), tonumber(m)
end

local function parseTime(s)
	if not s then return nil end
	local h, m = s:match("^(%d+):(%d+)$")
	return tonumber(h), tonumber(m)
end

--- Whether `t` lies between start and end (a range may run over the new year: 15/12 to 2/1).
local function within(t, sd, sm, sh, smin, ed, em, eh, emin)
	if not sd or not ed then return true end
	local cur = stamp(t.month, t.day, t.hour, t.min)
	local s = stamp(sm, sd, sh or 0, smin or 0)
	local e = stamp(em, ed, eh or 23, emin or 59)
	if s <= e then return cur >= s and cur <= e end
	return cur >= s or cur <= e
end

-- Darkmoon Faire ---------------------------------------------------------------------------------------------------

local function darkmoonPlace(t)
	-- The first Friday of the month (date("*t").wday: 1 Sunday ... 6 Friday).
	local first = date("*t", time({ year = t.year, month = t.month, day = 1, hour = 12 }))
	local firstFriday = 1 + (6 - first.wday) % 7
	local opens = firstFriday + 3 -- the Monday after
	local closes = opens + 7
	local cur = (t.day * 24 + t.hour)
	if cur < opens * 24 + 3 or cur >= closes * 24 + 3 then return nil end
	return t.month % 2 == 1 and "elwynn" or "mulgore"
end

Events.darkmoonPlaceNames = { elwynn = "Elwynn Forest", mulgore = "Mulgore" }

-- Working it out ----------------------------------------------------------------------------------------------------

local function compute()
	local Data = BF.Data
	local t = now()
	local active = {}
	for name, dates in pairs(Data.eventDates) do
		if name == "Lunar Festival" then
			dates = Data.lunarFestival[t.year % 100] or dates
		end
		if dates then
			local sd, sm = parseDate(dates.startDate)
			local ed, em = parseDate(dates.endDate)
			if within(t, sd, sm, dates.startHour, dates.startMinute, ed, em, dates.endHour, dates.endMinute) then
				active[name] = true
			end
		end
	end
	local place = darkmoonPlace(t)
	if place then active["Darkmoon Faire"] = place end
	return active, place, t
end

local function apply()
	local active, place, t = compute()
	local changed = false
	for k, v in pairs(active) do if Events.active[k] ~= v then changed = true end end
	for k in pairs(Events.active) do if active[k] == nil then changed = true end end
	Events.active = active
	Events.darkmoon = place

	wipe(Events.activeQuests)
	for _, q in ipairs(BF.Data.eventQuests) do
		local name, id = q[1], q[2]
		Events.questEvent[id] = name
		if active[name] then
			local sd, sm = parseDate(q[3])
			local ed, em = parseDate(q[4])
			local sh, smin = parseTime(q[5])
			local eh, emin = parseTime(q[6])
			if within(t, sd, sm, sh, smin, ed, em, eh, emin) then Events.activeQuests[id] = true end
		end
	end

	-- The faire's NPCs stand where the faire is this month (nowhere while it is closed: their base rows).
	BF:SetNpcRows("darkmoon", place and BF.Data.darkmoonNpcs[place] or nil)
	return changed
end

function Events:IsEventQuest(questID)
	return Events.questEvent[questID] ~= nil
end

function Events:EventName(questID)
	return Events.questEvent[questID]
end

--- An event quest exists today (its holiday runs), or it can be handed in after the holiday.
function Events:IsQuestActive(questID)
	return Events.activeQuests[questID] == true
end

function Events:CanTurnInAfter(questID)
	return turnInAnytime[questID] == true
end

local function announce()
	if not BF:Get("quests.events") then return end
	for name in pairs(Events.active) do
		if name ~= "Darkmoon Faire" then
			BF:Print(L["The \"%s\" world event is active!"], L[name])
		end
	end
	if Events.darkmoon then
		BF:Print(L["The Darkmoon Faire is up in %s!"], L[Events.darkmoonPlaceNames[Events.darkmoon]])
	end
end

BF:At("login", function()
	apply()
	announce()
	-- Holidays start and end on the hour: look again every few minutes.
	BF:Every(300, function()
		if apply() then BF:Send("BF_EVENTS_CHANGED") end
	end)
end, 5)
