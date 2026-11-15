-- The game's objective tracker stays off the screen: the quest list lives in the map's Quests tab (the owner's
-- decision: nothing on screen). The tracker holds secure item buttons, so it is hidden only out of combat; shown again
-- during a fight by the game, it is hidden when the fight ends. The setting brings it back.

local _, BF = ...

BF.Settings:Define("list.hideGameTracker", { default = true, page = "Quests/List", label = "Hide the game's quest tracker" })

local function tracker() return ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame end

local function apply()
	local f = tracker()
	if not f or InCombatLockdown() then return end
	if BF:Get("list.hideGameTracker") then f:Hide() else f:Show() end
end

BF:At("login", function()
	local f = tracker()
	if not f then return end
	f:HookScript("OnShow", function(self)
		if BF:Get("list.hideGameTracker") and not InCombatLockdown() then self:Hide() end
	end)
	BF:On("PLAYER_REGEN_ENABLED", apply)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "list.hideGameTracker" then apply() end end)
	apply()
end)
