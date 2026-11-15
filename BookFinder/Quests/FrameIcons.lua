-- Questie's quest icons in the quest giver's window (quests.frameIcons): each quest in a gossip list shows the icon it
-- has on the map (available, low-level, repeatable, event, PvP; complete or not yet), instead of the game's two.
-- The game's gossip buttons are set up by their mixins' Setup: hooked, the icon is changed after the game's.

local _, BF = ...

local Rules, Log = BF.Rules, BF.Log

local function availableKind(id, trivial)
	local k = Rules:Kind(id)
	if k.pvp then return "availablePvP" end
	if k.event then return "availableEvent" end
	if k.repeatable or k.daily or k.weekly then return "availableRepeatable" end
	if trivial or Rules:IsTrivial(id) then return "availableTrivial" end
	return "available"
end

local function completeKind(id, done)
	if not done then return "incomplete" end
	local k = Rules:Kind(id)
	if k.pvp then return "completePvP" end
	if k.event then return "completeEvent" end
	if k.repeatable or k.daily or k.weekly then return "completeRepeatable" end
	return "complete"
end

local function apply(button, kind)
	local icon = button and button.Icon
	if not icon or not BF:Get("quests.frameIcons") then return end
	if not BF.Icons.kinds[kind] then kind = kind:find("^complete") and "complete" or "available" end
	BF.Icons:Apply(icon, kind)
end

local function hook(mixinName, fn)
	local mixin = rawget(_G, mixinName)
	if mixin and mixin.Setup then hooksecurefunc(mixin, "Setup", fn) end
end

BF:At("login", function()
	hook("GossipSharedAvailableQuestButtonMixin", function(self, info)
		if type(info) == "table" and info.questID then apply(self, availableKind(info.questID, info.isTrivial)) end
	end)
	hook("GossipSharedActiveQuestButtonMixin", function(self, info)
		if type(info) == "table" and info.questID then apply(self, completeKind(info.questID, info.isComplete)) end
	end)
end, 67)
