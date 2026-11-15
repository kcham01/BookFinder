-- Automation (Questie's): accept and hand in quests by themselves, unless the chosen key is held.
--
--   auto.accept     a quest's details are accepted; a quest giver's list picks its first quest the rules allow
--   auto.complete   a finished quest is handed in (not one with a choice of reward: that choice is the player's)
--   auto.trivial / auto.repeatable / auto.pvp       which kinds are taken too
--   auto.rejectInBattleground   a quest another player shares in a battleground is declined, said so in chat
--   auto.abandonBreadcrumb      a quest taken while its breadcrumb is still in the log is abandoned again, so the
--                               breadcrumb can be handed in first (Questie's rule and message)
--
-- WoW: Forever has both quest giver dialogues: the gossip one (C_GossipInfo) and the old greeting (QUEST_GREETING).

local _, BF = ...
local L = BF.L

local Auto = {}
BF.Automation = Auto

local Rules, Log, Q = BF.Rules, BF.Log, BF.Q

local function held()
	local m = BF:Get("auto.modifier")
	if m == "shift" then return IsShiftKeyDown() end
	if m == "ctrl" then return IsControlKeyDown() end
	if m == "alt" then return IsAltKeyDown() end
	return false
end

--- Whether the rules take this quest by themselves (questID may be unknown to the data: then by the game's flags).
function Auto:Takes(questID, trivial, repeatable)
	if questID and questID > 0 and BF:Quest(questID) then
		local kind = Rules:Kind(questID)
		trivial = trivial or Rules:IsTrivial(questID)
		repeatable = repeatable or kind.repeatable or kind.daily or kind.weekly
		if kind.pvp and not BF:Get("auto.pvp") then return false end
	end
	if trivial and not BF:Get("auto.trivial") then return false end
	if repeatable and not BF:Get("auto.repeatable") then return false end
	return true
end

local function inBattleground()
	local _, kind = IsInInstance()
	return kind == "pvp" or kind == "arena"
end

-- The quest's details: accept (or decline a battleground share).
local function onDetail()
	local questID = GetQuestID and GetQuestID() or 0
	local fromPlayer = UnitExists("questnpc") and UnitIsPlayer("questnpc")
	if fromPlayer and BF:Get("auto.rejectInBattleground") and inBattleground() then
		DeclineQuest()
		BF:Print(L["Automatically rejected quest shared by player."])
		return
	end
	if not BF:Get("auto.accept") or held() then return end
	if QuestGetAutoAccept and QuestGetAutoAccept() then return end -- (the game takes it already)
	if Auto:Takes(questID) then AcceptQuest() end
end

local function onAcceptConfirm()
	if BF:Get("auto.accept") and not held() and ConfirmAcceptQuest then ConfirmAcceptQuest() end
end

-- A quest giver's list: hand in a finished quest first, else take an available one.
local function onGossip()
	if held() or not C_GossipInfo then return end
	if BF:Get("auto.complete") and C_GossipInfo.GetActiveQuests then
		for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
			if q.isComplete and q.questID then C_GossipInfo.SelectActiveQuest(q.questID) return end
		end
	end
	if BF:Get("auto.accept") and C_GossipInfo.GetAvailableQuests then
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
			if q.questID and Auto:Takes(q.questID, q.isTrivial, q.repeatable or q.frequency and q.frequency > 0) then
				C_GossipInfo.SelectAvailableQuest(q.questID)
				return
			end
		end
	end
end

local function onGreeting()
	if held() then return end
	if BF:Get("auto.complete") and GetNumActiveQuests then
		for i = 1, GetNumActiveQuests() do
			local _, complete = GetActiveTitle(i)
			if complete then SelectActiveQuest(i) return end
		end
	end
	if BF:Get("auto.accept") and GetNumAvailableQuests then
		for i = 1, GetNumAvailableQuests() do
			local trivial, frequency, repeatable, _, questID
			if GetAvailableQuestInfo then trivial, frequency, repeatable, _, questID = GetAvailableQuestInfo(i) end
			if Auto:Takes(questID, trivial, repeatable or (frequency and frequency > 1)) then SelectAvailableQuest(i) return end
		end
	end
end

local function onProgress()
	if BF:Get("auto.complete") and not held() and IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end
end

local function onComplete()
	if not BF:Get("auto.complete") or held() then return end
	local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
	if choices <= 1 then GetQuestReward(choices == 1 and 1 or nil) end
end

-- A quest taken while its breadcrumb is still in the log.
local function onAccepted(_, questID)
	local q = BF:Quest(questID)
	for _, crumb in ipairs(q and q[Q.breadcrumbs] or {}) do
		if Log:Has(crumb) then
			local link, crumbLink = BF.Links:Quest(questID), BF.Links:Quest(crumb)
			if BF:Get("auto.abandonBreadcrumb") and C_QuestLog and C_QuestLog.AbandonQuest then
				C_QuestLog.SetSelectedQuest(questID)
				if C_QuestLog.SetAbandonQuest then C_QuestLog.SetAbandonQuest() end
				C_QuestLog.AbandonQuest()
				BF:Print(L["Automatically abandoned quest %s because breadcrumb quest %s is not completed."], link, crumbLink)
			elseif BF:Get("announce.incompleteBreadcrumb") then
				BF:Print(L["You have accepted %s without completing its breadcrumb quest %s"], link, crumbLink)
			end
			return
		end
	end
end

BF:At("login", function()
	BF:On("QUEST_DETAIL", onDetail)
	BF:On("QUEST_ACCEPT_CONFIRM", onAcceptConfirm)
	BF:On("GOSSIP_SHOW", onGossip)
	BF:On("QUEST_GREETING", onGreeting)
	BF:On("QUEST_PROGRESS", onProgress)
	BF:On("QUEST_COMPLETE", onComplete)
	BF:Listen("BF_QUEST_ACCEPTED", onAccepted)
end, 65)
