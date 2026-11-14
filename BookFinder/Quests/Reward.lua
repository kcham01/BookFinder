-- Quest rewards as the player will get them: XP (scaled for their level and XP buffs), money, reputation.
--
-- XP follows the game's rule: the data holds a quest's full XP; a player more than five levels above the quest gets
-- 20% less for each further level, down to a tenth, and the game rounds the result (to 5 under 100, 10 under 500,
-- 25 under 1000, 50 above). XP buffs add their share on top. At the level cap quests give no XP.

local _, BF = ...
local L = BF.L

local Reward = {}
BF.Reward = Reward

local floor = math.floor
local Q = BF.Q

-- XP buffs: [spell ID] = share added (stacks multiply it where the buff stacks).
local xpBuffs = {
	[377749] = 0.5,  -- Joyous Journeys
	[46668] = 0.1,   -- Darkmoon Faire: Sayge's / the faire's buff
	[95987] = 0.1,   -- Unburdened (Hallow's End, Alliance)
	[24705] = 0.1,   -- Grim Visage (Hallow's End, Horde)
	[429959] = 0.01, -- Well-Rested (a sleeping bag on WoW: Forever), per stack
}

local function buffShare()
	-- Auras can be secret in combat and in instances on WoW: Forever: no bonus is shown then.
	if InCombatLockdown() or IsInInstance() then return 0 end
	local share = 0
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for i = 1, 40 do
			local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
			if not aura then break end
			local id = aura.spellId
			if issecretvalue and issecretvalue(id) then break end
			local per = xpBuffs[id]
			if per then share = share + per * math.max(1, aura.applications or 1) end
		end
	end
	return share
end

local function round(xp)
	if xp <= 100 then return 5 * floor((xp + 2) / 5) end
	if xp <= 500 then return 10 * floor((xp + 5) / 10) end
	if xp <= 1000 then return 25 * floor((xp + 12) / 25) end
	return 50 * floor((xp + 25) / 50)
end

local function maxLevel()
	return (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
end

--- The XP the player gets for a quest now (0 if unknown or at the level cap). atMaxLevel: as if not capped.
function Reward:XP(questID, atMaxLevel)
	local q = BF:Quest(questID)
	local data = q and q[Q.xp]
	if not data then return 0 end
	local questLevel, xp = data[1], data[2]
	if not questLevel or questLevel <= 0 or not xp or xp <= 0 then return 0 end
	local level = BF.Player.level or UnitLevel("player")
	if level >= maxLevel() and not atMaxLevel then return 0 end
	local multiplier = 2 * (questLevel - level) + 20
	if multiplier < 1 then multiplier = 1 elseif multiplier > 10 then multiplier = 10 end
	return floor(round(xp * multiplier / 10) * (1 + buffShare()))
end

--- Money in copper (from the game; 0 when the client does not know the quest yet).
function Reward:Money(questID)
	return GetQuestLogRewardMoney and GetQuestLogRewardMoney(questID) or 0
end

--- Reputation rewards: { {factionID, value}, ... } or nil.
function Reward:Reputation(questID)
	local q = BF:Quest(questID)
	return q and q[Q.reputationReward]
end

--- "1,450 xp" plus the money, for a tooltip's right side ("" when there is nothing to show).
function Reward:Text(questID)
	local parts = {}
	local atMax = BF:Get("tooltips.xpAtMaxLevel")
	local xp = Reward:XP(questID, atMax)
	if xp > 0 then parts[#parts + 1] = (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or tostring(xp)) .. " " .. L["xp"] end
	local money = Reward:Money(questID)
	if money > 0 and GetCoinTextureString then parts[#parts + 1] = "|cffffffff" .. GetCoinTextureString(money) .. "|r" end
	return table.concat(parts, " ")
end

--- Each reputation reward as "+250 Stormwind" lines (faction names from the client).
function Reward:ReputationLines(questID)
	local lines = {}
	for _, pair in ipairs(Reward:Reputation(questID) or {}) do
		local name = GetFactionInfoByID and GetFactionInfoByID(pair[1])
		if name then
			lines[#lines + 1] = ("%s%d %s"):format(pair[2] >= 0 and "+" or "", pair[2], name)
		end
	end
	return lines
end
