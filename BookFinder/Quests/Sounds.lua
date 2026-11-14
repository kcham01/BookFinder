-- Quest sounds (Questie's): a quest complete, an objective done, an objective's progress; each on or off with a sound
-- of the game's own to choose, on a chosen channel, after a short delay (so it does not clash with the game's).

local _, BF = ...

local Sounds = {}
BF.Sounds = Sounds

-- Choices: name -> the game's sound (SOUNDKIT name, with its number for clients without that name).
local choices = {
	{ "QuestComplete", "IG_QUEST_LIST_COMPLETE", 878 },
	{ "QuestOpen", "IG_QUEST_LIST_OPEN", 875 },
	{ "QuestSelect", "IG_QUEST_LIST_SELECT", 877 },
	{ "LevelUp", "LEVELUP", 888 },
	{ "MapPing", "MAP_PING", 3175 },
	{ "ReadyCheck", "READY_CHECK", 8960 },
	{ "RaidWarning", "RAID_WARNING", 8959 },
	{ "Whisper", "TELL_MESSAGE", 3081 },
	{ "AlarmClock", "ALARM_CLOCK_WARNING_3", 12889 },
}
local byName = {}
for _, c in ipairs(choices) do byName[c[1]] = c end

function BF.SoundNames()
	local list = {}
	for _, c in ipairs(choices) do list[#list + 1] = c[1] end
	return list
end

local function play(name)
	local c = byName[name] or choices[1]
	local id = (SOUNDKIT and SOUNDKIT[c[2]]) or c[3]
	PlaySound(id, BF:Get("sounds.channel"))
end

function Sounds:Preview(name) play(name) end

local function later(name)
	BF:After(BF:Get("sounds.delay"), function() play(name) end)
end

BF:At("login", function()
	BF:Listen("BF_QUEST_PROGRESS", function(_, _, _, objective, before)
		if objective.finished and not before.finished then
			if BF:Get("sounds.objectiveComplete") then later(BF:Get("sounds.objectiveCompleteChoice")) end
		elseif objective.have > (before.have or 0) then
			if BF:Get("sounds.objectiveProgress") then later(BF:Get("sounds.objectiveProgressChoice")) end
		end
	end)
	BF:Listen("BF_QUEST_COMPLETE_CHANGED", function(_, _, isComplete)
		if isComplete == 1 and BF:Get("sounds.questComplete") then later(BF:Get("sounds.questCompleteChoice")) end
	end)
end)
