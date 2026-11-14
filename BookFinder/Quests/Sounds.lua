-- Quest sounds: a sound when an objective moves on, when one is done, when a quest is done (Quests > Automation >
-- Sounds), each with its choice of the game's own sounds, on a chosen sound channel, after a short delay so a burst of
-- progress plays once. A finished quest's sound replaces the objective sounds waiting to play. (Questie's sounds.)
--
-- The choices are sounds the game ships, by their file IDs; this file loads before the settings that list them.

local _, BF = ...

local Sounds = {}
BF.Sounds = Sounds

-- Name -> the game's sound file ID. The names are what the settings show.
Sounds.files = {
	["QuestDefault"] = 558132,        -- a peon: "work complete"
	["GameDefault"] = 567439,         -- the game's quest complete chime
	["ObjectiveDefault"] = 567516,    -- the game's quest update sound
	["ObjectiveProgress"] = 567482,   -- a window opening
	["Human Male"] = 540703, ["Human Female"] = 540654,
	["Dwarf Male"] = 540042, ["Dwarf Female"] = 539981,
	["Night Elf Male"] = 541085, ["Night Elf Female"] = 541031,
	["Gnome Male"] = 540512, ["Gnome Female"] = 540432,
	["Orc Male"] = 541401, ["Orc Female"] = 541317,
	["Undead Male"] = 542775, ["Undead Female"] = 542684,
	["Tauren Male"] = 561484, ["Tauren Female"] = 542997,
	["Troll Male"] = 543307, ["Troll Female"] = 543273,
	["Zug Zug"] = 557827,
	["Map Ping"] = 567416,
	["Window Close"] = 567499,
	["Window Open"] = 567482,
	["Boat Docked"] = 566652,
	["Bell Toll Alliance"] = 566564,
	["Bell Toll Horde"] = 565853,
	["Explosion"] = 566982,
	["Shing!"] = 566240,
	["Wham!"] = 566946,
	["Simon Chime"] = 566076,
	["War Drums"] = 567275,
	["Humm"] = 569518,
	["Short Circuit"] = 568975,
}

-- The names, in the order the settings list them: the defaults first, then by name.
BF.SoundNames = { "QuestDefault", "GameDefault", "ObjectiveDefault", "ObjectiveProgress" }
do
	local rest = {}
	for name in pairs(Sounds.files) do
		local first = false
		for _, n in ipairs(BF.SoundNames) do if n == name then first = true end end
		if not first then rest[#rest + 1] = name end
	end
	table.sort(rest)
	for _, n in ipairs(rest) do BF.SoundNames[#BF.SoundNames + 1] = n end
end

local function play(choice)
	local file = Sounds.files[BF:Get(choice)]
	if file then PlaySoundFile(file, BF:Get("sounds.channel")) end
end

local waiting = { progress = false, complete = false }

local function later(kind, setting, choice)
	if not BF:Get(setting) or waiting[kind] then return end
	waiting[kind] = true
	BF:After(BF:Get("sounds.delay"), function()
		if waiting[kind] then
			waiting[kind] = false
			play(choice)
		end
	end)
end

function Sounds:ObjectiveProgress() later("progress", "sounds.objectiveProgress", "sounds.objectiveProgressChoice") end
function Sounds:ObjectiveComplete() later("complete", "sounds.objectiveComplete", "sounds.objectiveCompleteChoice") end

function Sounds:QuestComplete()
	if not BF:Get("sounds.questComplete") then return end
	waiting.progress, waiting.complete = false, false
	play("sounds.questCompleteChoice")
end

BF:At("login", function()
	BF:Listen("BF_QUEST_PROGRESS", function(_, _, _, o, before)
		if o.finished and not before.finished then Sounds:ObjectiveComplete()
		elseif o.have > before.have then Sounds:ObjectiveProgress() end
	end)
	BF:Listen("BF_QUEST_COMPLETE_CHANGED", function(_, _, isComplete)
		if isComplete == 1 then Sounds:QuestComplete() end
	end)
end, 50)
