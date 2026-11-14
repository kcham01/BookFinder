-- The player's quest log, read from the client and kept as BF.Log.quests[questID]:
--   { id, title, level, header (zone heading), isComplete (nil / 1 done / -1 failed), frequency, suggestedGroup,
--     objectives = { {text, type, finished, have, need}, ... } }
--
-- Messages (every one after the change has been applied to BF.Log.quests):
--   BF_QUEST_ACCEPTED(questID)
--   BF_QUEST_REMOVED(questID, turnedIn)          turnedIn false: abandoned (or removed by the server)
--   BF_QUEST_PROGRESS(questID, index, objective, before)   one objective's count or state changed
--   BF_QUEST_COMPLETE_CHANGED(questID, isComplete)
--   BF_QUEST_LOG_CHANGED()                          once per scan in which anything changed

local _, BF = ...

local Log = { quests = {} }
BF.Log = Log

-- Reading the client ----------------------------------------------------------------------------------------------

local modern = C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries

local function entries()
	if modern then return C_QuestLog.GetNumQuestLogEntries() end
	return GetNumQuestLogEntries()
end

--- title, level, isHeader, isComplete, questID, frequency, suggestedGroup for one log line.
local function line(index)
	if modern then
		local info = C_QuestLog.GetInfo(index)
		if not info then return nil end
		local isComplete
		if not info.isHeader then
			if C_QuestLog.IsFailed and C_QuestLog.IsFailed(info.questID) then
				isComplete = -1
			elseif C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) then
				isComplete = 1
			end
		end
		return info.title, info.level, info.isHeader, isComplete, info.questID, info.frequency, info.suggestedGroup
	end
	local title, level, suggestedGroup, isHeader, _, isComplete, frequency, questID = GetQuestLogTitle(index)
	return title, level, isHeader, isComplete, questID, frequency, suggestedGroup
end

local function readObjectives(questID)
	local list = {}
	local raw = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
	if raw then
		for i, o in ipairs(raw) do
			list[i] = {
				text = o.text or "",
				type = o.type,
				finished = o.finished and true or false,
				have = o.numFulfilled or 0,
				need = o.numRequired or 0,
			}
		end
	end
	return list
end

local function read()
	local quests = {}
	local header
	for index = 1, entries() do
		local title, level, isHeader, isComplete, questID, frequency, suggestedGroup = line(index)
		if not title then break end
		if isHeader then
			header = title
		elseif questID and questID > 0 then
			quests[questID] = {
				id = questID, title = title, level = level, header = header, isComplete = isComplete,
				frequency = frequency, suggestedGroup = suggestedGroup, index = index,
				objectives = readObjectives(questID),
			}
		end
	end
	return quests
end

-- Changes ---------------------------------------------------------------------------------------------------------

local turnedIn = {}       -- [questID] = time of QUEST_TURNED_IN, to tell a turn-in from an abandon
local transitionUntil = 0 -- during zone changes the client briefly reports finished objectives as 0
local loaded = false

local function objectiveChanged(a, b)
	return a.have ~= b.have or a.need ~= b.need or a.finished ~= b.finished or a.text ~= b.text
end

-- During a zone change the client can report a complete quest as incomplete with every count at 0 for a moment.
-- Such a reading is not believed until the transition window has passed; the next scan settles it.
local function looksLikeTransitionGlitch(old, new)
	if GetTime() > transitionUntil then return false end
	if old.isComplete ~= 1 or new.isComplete == 1 then return false end
	for _, o in ipairs(new.objectives) do
		if o.have > 0 then return false end
	end
	return #new.objectives > 0
end

local rescan

local function scan()
	local old = Log.quests
	local new = read()
	local changed = false
	local retry = false

	for id, q in pairs(new) do
		local before = old[id]
		if before and looksLikeTransitionGlitch(before, q) then
			new[id] = before
			retry = true
		end
	end

	Log.quests = new

	if not loaded then
		loaded = true
		BF:Send("BF_QUEST_LOG_CHANGED")
		return
	end

	for id, q in pairs(new) do
		local before = old[id]
		if not before then
			changed = true
			BF:Send("BF_QUEST_ACCEPTED", id)
		else
			for i, o in ipairs(q.objectives) do
				local b = before.objectives[i]
				if b and objectiveChanged(b, o) then
					changed = true
					BF:Send("BF_QUEST_PROGRESS", id, i, o, b)
				elseif not b then
					changed = true
				end
			end
			if before.isComplete ~= q.isComplete then
				changed = true
				BF:Send("BF_QUEST_COMPLETE_CHANGED", id, q.isComplete)
			end
			if before.title ~= q.title or before.header ~= q.header then changed = true end
		end
	end

	for id in pairs(old) do
		if not new[id] then
			changed = true
			local done = turnedIn[id] ~= nil or BF.Player:HasCompleted(id)
			turnedIn[id] = nil
			BF:Send("BF_QUEST_REMOVED", id, done)
		end
	end

	if changed then BF:Send("BF_QUEST_LOG_CHANGED") end
	if retry then rescan() end
end

rescan = BF:Debounce(1, scan)
local soon = BF:Debounce(0.1, scan)

BF:At("login", function()
	scan()
	BF:On("QUEST_LOG_UPDATE", soon)
	BF:On("QUEST_ACCEPTED", soon)
	BF:On("QUEST_REMOVED", soon)
	BF:On("UNIT_QUEST_LOG_CHANGED", function(_, unit)
		if unit == "player" then soon() end
	end)
end, 10)

BF:On("QUEST_TURNED_IN", function(_, questID)
	if questID then turnedIn[questID] = GetTime() end
end)

BF:On("PLAYER_ENTERING_WORLD", function()
	transitionUntil = GetTime() + 3
end)

-- Questions -------------------------------------------------------------------------------------------------------

function Log:Has(questID)
	return Log.quests[questID] ~= nil
end

function Log:Get(questID)
	return Log.quests[questID]
end

--- True when every objective is done (or the client says the quest is complete): time to hand it in.
function Log:IsComplete(questID)
	local q = Log.quests[questID]
	if not q then return false end
	if q.isComplete == 1 then return true end
	if q.isComplete == -1 then return false end
	if #q.objectives == 0 then return true end -- nothing to do but hand it in (a letter, a "speak with")
	for _, o in ipairs(q.objectives) do
		if not o.finished then return false end
	end
	return true
end

function Log:IsFailed(questID)
	local q = Log.quests[questID]
	return q ~= nil and q.isComplete == -1
end

function Log:Count()
	local n = 0
	for _ in pairs(Log.quests) do n = n + 1 end
	return n
end
