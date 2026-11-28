-- Quest icons in the quest giver's window (quests.frameIcons), as Questie draws them: each quest in a gossip list shows
-- the icon it has on the map (available, low-level, repeatable, event, PvP; ready to hand in or not yet) instead of
-- the game's two.
--
-- The gossip window's quest buttons are set up by their mixins' Setup(info). Those are hooked at login, before the
-- window first opens (its buttons get the mixin when they are made); a sweep of the shown buttons on GOSSIP_SHOW covers
-- a client that sets them up some other way.

local _, BF = ...

local Look = BF.Look

local function kindFor(info, active)
	local id = info.questID
	if not id then return nil end
	if not active then
		if info.isTrivial then return "availableTrivial" end
		return Look.AvailableKind(id)
	end
	if not info.isComplete then return "incomplete" end
	return Look.CompleteKind(id)
end

local function apply(button, info, active)
	if not BF:Get("quests.frameIcons") or type(info) ~= "table" then return end
	local icon = type(button) == "table" and button.Icon
	if type(icon) ~= "table" or not icon.SetTexture then return end
	local kind = kindFor(info, active)
	if kind then BF.Icons:Apply(icon, kind) end
end

local function hook(mixinName, active)
	local mixin = rawget(_G, mixinName)
	if type(mixin) == "table" and type(mixin.Setup) == "function" then
		hooksecurefunc(mixin, "Setup", function(self, info) apply(self, info, active) end)
		return true
	end
	return false
end

BF:At("login", function()
	hook("GossipSharedAvailableQuestButtonMixin", false)
	hook("GossipSharedActiveQuestButtonMixin", true)
end, 67)

-- The sweep: every shown quest button of the gossip window, by the info the button keeps.
local function sweep()
	local gossip = rawget(_G, "GossipFrame")
	local box = type(gossip) == "table" and gossip.GreetingPanel and gossip.GreetingPanel.ScrollBox
	if type(box) ~= "table" or not box.ForEachFrame then return end
	local activeType = rawget(_G, "GOSSIP_BUTTON_TYPE_ACTIVE_QUEST")
	box:ForEachFrame(function(button)
		local data = button.GetElementData and button:GetElementData()
		local info = type(data) == "table" and data.info
		if type(info) == "table" and info.questID then
			local active
			if activeType ~= nil then active = data.buttonType == activeType else active = info.isComplete ~= nil end
			apply(button, info, active)
		end
	end)
end

-- (after the game has filled the window for this GOSSIP_SHOW)
BF:On("GOSSIP_SHOW", function()
	if BF:Get("quests.frameIcons") then BF:After(0, sweep) end
end)
