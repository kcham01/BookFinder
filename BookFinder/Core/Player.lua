-- The player: who they are and what they have done, as the quest rules need it.
--
-- Messages: BF_LEVEL_CHANGED(level)  BF_COMPLETED_CHANGED(questID or nil for "reload all")
--           BF_SKILLS_CHANGED()  BF_REPUTATION_CHANGED()

local _, BF = ...

local Player = {}
BF.Player = Player

local Data = BF.Data

Player.completed = {} -- [questID] = true

-- Who ---------------------------------------------------------------------------------------------------------

local function bitSet(mask, bitValue)
	return mask % (bitValue * 2) >= bitValue
end

BF:At("login", function()
	Player.faction = UnitFactionGroup("player")          -- "Alliance" / "Horde"
	Player.factionLetter = Player.faction == "Horde" and "H" or "A"
	local _, raceFile, raceID = UnitRace("player")
	Player.race, Player.raceID = raceFile, raceID
	local _, classFile, classID = UnitClass("player")
	Player.class, Player.classID = classFile, classID
	Player.level = UnitLevel("player")
	Player.raceMask = raceID and Data.raceMaskById[raceID] or 0
	Player.classMask = classID and 2 ^ (classID - 1) or 0
	local name = UnitName("player")
	Player.name = name
end, 2)

--- True when a quest's race mask (0: everyone) includes the player.
function Player:RaceAllowed(mask)
	if not mask or mask == 0 or Player.raceMask == 0 then return true end
	return bitSet(mask, Player.raceMask)
end

function Player:ClassAllowed(mask)
	if not mask or mask == 0 or Player.classMask == 0 then return true end
	return bitSet(mask, Player.classMask)
end

--- An NPC's or object's "friendly to" ("A", "H", "AH", nil) against the player.
function Player:FriendlyTo(letters)
	if not letters then return true end
	return letters:find(Player.factionLetter, 1, true) ~= nil
end

BF:On("PLAYER_LEVEL_UP", function(_, level)
	Player.level = level
	BF:Send("BF_LEVEL_CHANGED", level)
end)

-- Completed quests ---------------------------------------------------------------------------------------------

local function loadCompleted()
	local completed = Player.completed
	wipe(completed)
	if C_QuestLog.GetAllCompletedQuestIDs then
		for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do completed[id] = true end
	elseif GetQuestsCompleted then
		for id in pairs(GetQuestsCompleted() or {}) do completed[id] = true end
	end
end

BF:At("login", function()
	loadCompleted()
end, 3)

function Player:HasCompleted(id)
	if Player.completed[id] then return true end
	-- The server's list can lag a turn-in by a moment; ask directly too.
	if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) then
		Player.completed[id] = true
		return true
	end
	return false
end

BF:On("QUEST_TURNED_IN", function(_, questID)
	if questID then
		Player.completed[questID] = true
		BF:Send("BF_COMPLETED_CHANGED", questID)
	end
end)

--- Repeatable quests are never "completed" for availability; the quest engine decides that, not this list.

-- Professions --------------------------------------------------------------------------------------------------
--
-- Quests ask by skill ID. Forever answers by ID (C_SkillInfo.GetSkillLineInfoByID); older clients list skills by
-- localized name only, matched through a spell each profession teaches (its name is localized by the client).

local skillSpells = {
	[171] = 2259, -- Alchemy
	[164] = 2018, -- Blacksmithing
	[185] = 2550, -- Cooking
	[333] = 7411, -- Enchanting
	[202] = 4036, -- Engineering
	[129] = 3273, -- First Aid
	[356] = 7620, -- Fishing
	[182] = 2366, -- Herbalism
	[165] = 2108, -- Leatherworking
	[186] = 2575, -- Mining
	[393] = 8613, -- Skinning
	[197] = 3908, -- Tailoring
	[633] = 1804, -- Lockpicking
}
local skillEnglish = {
	[171] = "Alchemy", [164] = "Blacksmithing", [185] = "Cooking", [333] = "Enchanting", [202] = "Engineering",
	[129] = "First Aid", [356] = "Fishing", [182] = "Herbalism", [165] = "Leatherworking", [186] = "Mining",
	[393] = "Skinning", [197] = "Tailoring", [633] = "Lockpicking", [762] = "Riding",
}
Player.skillIdByName = {}
Player.skills = {} -- [skillID] = rank

local function skillName(id)
	local spell = skillSpells[id]
	local name = spell and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell))
		or (GetSpellInfo and GetSpellInfo(spell)))
	return name or skillEnglish[id]
end

--- The localized name of a profession (skill ID), for display.
function Player:SkillName(id)
	return skillName(id)
end

-- Forever reads a skill by its ID (C_SkillInfo); older clients only list skill lines by localized name.
local byID = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID

local function loadSkills()
	local skills = Player.skills
	wipe(skills)
	if byID then
		for id in pairs(skillEnglish) do
			local ok, info = pcall(byID, id)
			if ok and type(info) == "table" and type(info.rank) == "number" and info.rank > 0 then
				skills[id] = info.rank
			end
		end
		return
	end
	if not next(Player.skillIdByName) then
		for id in pairs(skillEnglish) do
			local name = skillName(id)
			if name then Player.skillIdByName[name] = id end
			Player.skillIdByName[skillEnglish[id]] = id
		end
	end
	for i = 1, GetNumSkillLines() do
		local name, isHeader, _, rank = GetSkillLineInfo(i)
		local id = name and not isHeader and Player.skillIdByName[name]
		if id then skills[id] = rank end
	end
end

BF:At("login", loadSkills, 3)
BF:On("SKILL_LINES_CHANGED", function()
	loadSkills()
	BF:Send("BF_SKILLS_CHANGED")
end)

--- The player's rank in a skill, or nil if not learned.
function Player:SkillRank(id)
	return Player.skills[id]
end

-- Reputation ---------------------------------------------------------------------------------------------------

--- The player's reputation with a faction, in points from the bottom of Neutral (as quests count it), or nil.
function Player:Reputation(factionID)
	local name, _, _, _, _, value = GetFactionInfoByID(factionID)
	if not name then return nil end
	return value
end

BF:On("UPDATE_FACTION", function()
	BF:Send("BF_REPUTATION_CHANGED")
end)
