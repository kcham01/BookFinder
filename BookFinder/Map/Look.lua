-- How a pin looks: which icon wins when one spot has several roles, its size, its colour.
--
-- Priority, highest first: a quest to hand in, a quest to pick up, then objectives. A quest given by an item shows the
-- quest giver's "!" at the creature or object that gives the item.

local _, BF = ...

local Look = {}
BF.Look = Look

local Rules, Objectives = BF.Rules, BF.Objectives

local function availableKind(quest)
	local kind = Rules:Kind(quest)
	if kind.event then return "availableEvent" end
	if kind.pvp then return "availablePvP" end
	if kind.repeatable or kind.daily or kind.weekly then return "availableRepeatable" end
	if Rules:IsTrivial(quest) then return "availableTrivial" end
	return "available"
end

local function completeKind(quest)
	local kind = Rules:Kind(quest)
	if kind.event then return "completeEvent" end
	if kind.repeatable or kind.daily or kind.weekly then return "completeRepeatable" end
	return "complete"
end

local rank = { complete = 3, available = 2, itemStart = 2, objective = 1 }

--- The role that decides the pin's icon.
function Look:Lead(pin)
	local best, bestRank = nil, 0
	for _, r in ipairs(pin.roles) do
		local n = rank[r.role] or 0
		-- Among quests to pick up, a normal one beats a grey one.
		if n > bestRank or (n == bestRank and n == 2 and best and Rules:IsTrivial(best.quest) and not Rules:IsTrivial(r.quest)) then
			best, bestRank = r, n
		end
	end
	return best
end

--- icon kind, scale key (icons.scale.*), whether it is a quest giver/turn-in (drawn above objectives)
function Look:Kind(pin)
	local lead = Look:Lead(pin)
	if not lead then return "available", "available", true end
	if lead.role == "complete" then return completeKind(lead.quest), "available", true end
	if lead.role == "available" or lead.role == "itemStart" then return availableKind(lead.quest), "available", true end
	local icon = lead.objective and lead.objective.icon or Objectives.SLAY
	local scaleKey = (icon == "slay" or icon == "loot" or icon == "object" or icon == "event") and icon or "object"
	return BF.Icons:ObjectiveKind(icon), scaleKey, false
end

-- A colour per quest (when chosen): hues spread around the circle by the golden ratio so neighbours differ.
local colours = {}
function Look:QuestColour(quest)
	local c = colours[quest]
	if c then return c end
	local h = (quest * 0.618033988749895) % 1
	local function channel(n)
		local k = (n + h * 6) % 6
		return 1 - math.max(0, math.min(k, 4 - k, 1))
	end
	c = { 0.35 + 0.65 * channel(5), 0.35 + 0.65 * channel(3), 0.35 + 0.65 * channel(1) }
	colours[quest] = c
	return c
end

--- The pin's glow colour: the quest's own colour for objectives when chosen, else gold for givers, white else.
function Look:Glow(pin, minimap)
	local lead = Look:Lead(pin)
	local perQuest = BF:Get(minimap and "icons.colorsMinimap" or "icons.colorsMap")
	if lead and lead.role == "objective" and perQuest then return Look:QuestColour(lead.quest) end
	if lead and (lead.role == "complete" or lead.role == "available" or lead.role == "itemStart") then
		return { 1, 0.82, 0.25 }
	end
	return { 1, 1, 1 }
end
