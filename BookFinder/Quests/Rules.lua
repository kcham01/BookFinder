-- Quest rules: can the player take this quest now, and what kind of quest is it.
--
-- BF.Rules:IsAvailable(id) answers from the data and the player's state (log, completed quests, level, race, class,
-- skills, reputation, spells, holidays, hidden lists). BF.Rules:Kind(id) gives the quest's kind for icons and lists.
-- BF.Rules:IsShown(id) adds the player's display settings (low-level style, repeatable, dungeon, PvP...).

local _, BF = ...

local Rules = {}
BF.Rules = Rules

local Q = BF.Q
local Data = BF.Data
local Log, Player, Events = BF.Log, BF.Player, BF.Events

local raidAreas = { [2717] = true, [2159] = true, [2677] = true, [1977] = true, [3429] = true, [3428] = true, [3456] = true }
local battlegroundAreas = { [2597] = true, [3277] = true, [3358] = true }

local function bitSet(mask, value)
	return mask and mask % (value * 2) >= value
end

-- The player's own hidden quests (Shift-click on a quest's icon) ------------------------------------------------------

function Rules:HiddenByPlayer(id)
	return BF:CharacterState("quests").hidden ~= nil and BF:CharacterState("quests").hidden[id] == true
end

function Rules:SetHidden(id, hidden)
	local state = BF:CharacterState("quests")
	state.hidden = state.hidden or {}
	state.hidden[id] = hidden and true or nil
	BF:Send("BF_QUEST_HIDDEN_CHANGED", id, hidden)
end

--- Hidden from everything (the data's own list, unless its holiday is running) or only from the map.
function Rules:HiddenByData(id)
	local flag = Data.hiddenQuests[id]
	if not flag then return false end
	if Events:IsEventQuest(id) and Events:IsQuestActive(id) then return false end
	return flag
end

-- Level ---------------------------------------------------------------------------------------------------------

--- The quest's level, or the player's for quests that have none (-1).
function Rules:Level(id)
	local q = BF:Quest(id)
	local level = q and q[Q.level]
	if not level or level <= 0 then return Player.level end
	return level
end

local function greenRange()
	if UnitQuestTrivialLevelRange then return UnitQuestTrivialLevelRange("player") end
	if GetQuestGreenRange then return GetQuestGreenRange("player") end
	return 8
end

--- Grey to the player: too low to be worth much.
function Rules:IsTrivial(id)
	return (Player.level - Rules:Level(id)) > greenRange()
end

-- Kinds ---------------------------------------------------------------------------------------------------------

--- A table of what the quest is: repeatable, daily, weekly, monthly, event, pvp, dungeon, raid, elite, aqWarEffort,
--- breadcrumb, itemStart (cached; the data does not change during a session).
local kinds = {}
function Rules:Kind(id)
	local k = kinds[id]
	if k then return k end
	local q = BF:Quest(id)
	k = {}
	if q then
		local flags = q[Q.questFlags] or 0
		local special = q[Q.specialFlags] or 0
		local zone = q[Q.zoneOrSort]
		local sort = Data.sortKeys
		k.repeatable = special % 2 == 1
		k.daily = bitSet(flags, Data.questFlags.DAILY)
		k.weekly = bitSet(flags, Data.questFlags.WEEKLY)
		k.monthly = bitSet(flags, Data.questFlags.MONTHLY)
		k.event = Events:IsEventQuest(id)
		k.aqWarEffort = zone == sort.AHN_QIRAJ_WAR
		k.pvp = zone == sort.BATTLEGROUNDS or (zone and battlegroundAreas[zone]) or false
		k.raid = bitSet(flags, Data.questFlags.RAID) or (zone and raidAreas[zone]) or false
		k.dungeon = not k.raid and not k.pvp and zone and zone > 0 and BF.Zones:Dungeon(zone) ~= nil or false
		k.breadcrumb = q[Q.breadcrumbFor] ~= nil
		k.itemStart = q[Q.startItems] ~= nil and q[Q.startNpcs] == nil and q[Q.startObjects] == nil
		k.sharable = bitSet(flags, Data.questFlags.SHARABLE)
	end
	kinds[id] = k
	return k
end

-- Availability --------------------------------------------------------------------------------------------------

local function completed(id) return Player:HasCompleted(id) end
local function active(id) return Log:Has(id) end

local function allCompleted(list)
	for _, id in ipairs(list) do
		if not completed(id) then return false end
	end
	return true
end

local function anyCompleted(list)
	for _, id in ipairs(list) do
		if completed(id) then return true end
	end
	return false
end

local function noneTaken(list)
	for _, id in ipairs(list) do
		if completed(id) or active(id) then return false end
	end
	return true
end

local function spellKnown(spell)
	if IsPlayerSpell then return IsPlayerSpell(spell) end
	if IsSpellKnown then return IsSpellKnown(spell) end
	return false
end

local function reputationAtLeast(pair)
	local value = Player:Reputation(pair[1])
	return value ~= nil and value >= pair[2]
end

local function reputationBelow(pair)
	local value = Player:Reputation(pair[1])
	return value == nil or value < pair[2]
end

local function skillMet(pair)
	local rank = Player:SkillRank(pair[1])
	return rank ~= nil and rank >= (pair[2] or 0)
end

--- Why a quest cannot be taken now (a short key), or nil if it can. Levels are judged by IsShown, not here: a quest
--- whose level the player has not reached yet is "level" here so lists can say so.
function Rules:Blocker(id)
	local q = BF:Quest(id)
	if not q then return "unknown" end
	if active(id) then return "active" end
	local kind = Rules:Kind(id)
	if completed(id) and not kind.repeatable then return "completed" end
	if kind.event and not Events:IsQuestActive(id) then return "event" end
	if Rules:HiddenByData(id) == true then return "hidden" end
	if not Player:RaceAllowed(q[Q.races]) then return "race" end
	if not Player:ClassAllowed(q[Q.classes]) then return "class" end
	if (q[Q.requiredLevel] or 0) > Player.level then return "level" end
	if q[Q.requiredMaxLevel] and q[Q.requiredMaxLevel] > 0 and Player.level > q[Q.requiredMaxLevel] then return "maxLevel" end
	if q[Q.preGroup] and not allCompleted(q[Q.preGroup]) then return "prerequisite" end
	if q[Q.preSingle] and not anyCompleted(q[Q.preSingle]) then return "prerequisite" end
	if q[Q.parent] and not active(q[Q.parent]) then return "parent" end
	if q[Q.availableStartingWith] then
		local other = q[Q.availableStartingWith]
		if not (active(other) or completed(other)) then return "prerequisite" end
	end
	if q[Q.availableUntilCompleted] and completed(q[Q.availableUntilCompleted]) then return "expired" end
	if q[Q.disabledBy] and active(q[Q.disabledBy]) then return "disabled" end
	if q[Q.breadcrumbFor] then
		local target = q[Q.breadcrumbFor]
		if completed(target) or active(target) then return "breadcrumb" end
	end
	if q[Q.nextInChain] and (completed(q[Q.nextInChain]) or active(q[Q.nextInChain])) then return "chain" end
	if q[Q.exclusiveTo] and not noneTaken(q[Q.exclusiveTo]) then return "exclusive" end
	if q[Q.requiredSkill] and not skillMet(q[Q.requiredSkill]) then return "skill" end
	if q[Q.requiredRanks] then
		local any = false
		for _, pair in ipairs(q[Q.requiredRanks]) do
			if skillMet(pair) then any = true break end
		end
		if not any then return "skill" end
	end
	if q[Q.requiredMinRep] and not reputationAtLeast(q[Q.requiredMinRep]) then return "reputation" end
	if q[Q.requiredMaxRep] and not reputationBelow(q[Q.requiredMaxRep]) then return "reputation" end
	local spell = q[Q.requiredSpell]
	if spell and spell ~= 0 then
		if spell > 0 and not spellKnown(spell) then return "spell" end
		if spell < 0 and spellKnown(-spell) then return "spell" end
	end
	if q[Q.requiredSpecialization] and q[Q.requiredSpecialization] > 0 and not spellKnown(q[Q.requiredSpecialization]) then
		return "specialization"
	end
	if (kind.daily or kind.weekly or kind.monthly) and completed(id) then return "completed" end
	return nil
end

function Rules:IsAvailable(id)
	return Rules:Blocker(id) == nil
end

--- Shown as a quest to pick up, by the player's settings: available (or in the chosen level range), not hidden by them,
--- and of a kind they want to see.
function Rules:IsShown(id)
	local blocker = Rules:Blocker(id)
	local level = Rules:Level(id)
	local style = BF:Get("quests.lowLevel")
	if style == "range" then
		if blocker and blocker ~= "level" then return false end
		if level < BF:Get("quests.levelMin") or level > BF:Get("quests.levelMax") then return false end
	else
		if blocker then return false end
		if style == "hide" and Rules:IsTrivial(id) then return false end
		if style == "offset" and level < Player.level - BF:Get("quests.lowLevelOffset") then return false end
	end
	if Rules:HiddenByPlayer(id) then return false end
	local kind = Rules:Kind(id)
	if kind.repeatable and not BF:Get("quests.repeatable") then return false end
	if kind.event and not BF:Get("quests.events") then return false end
	if kind.pvp and not BF:Get("quests.pvp") then return false end
	if kind.dungeon and not BF:Get("quests.dungeon") then return false end
	if kind.raid and not BF:Get("quests.raid") then return false end
	if kind.aqWarEffort and not BF:Get("quests.aqWarEffort") then return false end
	if kind.itemStart and not BF:Get("quests.itemStarts") then return false end
	return true
end

--- Every quest shown as available, as a set { [id] = true } (worked out in slices: thousands of quests).
function Rules:EachShown(fn)
	for id in BF:AllIDs("quests") do
		if Rules:IsShown(id) then fn(id) end
	end
end

-- Display -------------------------------------------------------------------------------------------------------

--- "[33D] Hearts of Zeal": level and kind letter (D dungeon, R raid, P PvP, + elite group quest).
function Rules:TitleWithLevel(id, title)
	title = title or BF:QuestName(id) or ("Quest " .. id)
	local level = Rules:Level(id)
	local kind = Rules:Kind(id)
	local tag = ""
	if kind.raid then tag = "R"
	elseif kind.dungeon then tag = "D"
	elseif kind.pvp then tag = "P"
	elseif Log:Get(id) and (Log:Get(id).suggestedGroup or 0) > 0 then tag = "+"
	end
	return ("[%d%s] %s"):format(level, tag, title)
end

--- The quest's title coloured by difficulty, with its level when the setting asks for it.
function Rules:ColoredTitle(id, title, withLevel)
	local level = Rules:Level(id)
	local text = withLevel and Rules:TitleWithLevel(id, title) or (title or BF:QuestName(id) or ("Quest " .. id))
	local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	if color then
		return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, text)
	end
	return text
end
