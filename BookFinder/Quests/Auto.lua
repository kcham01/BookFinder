-- Automation (Quests > Automation): accept quests and hand them in by themselves, as Questie does
-- (docs/study/questie.md, "Automation"):
--   - talking to an NPC: a finished quest is handed in first, else the first quest offered is opened;
--   - a quest's page: accepted, unless it is low level, repeatable or PvP and those are not wanted;
--   - a finished quest's page: completed; its reward taken when there is no choice to make;
--   - holding the chosen key (Shift by default) while starting to talk skips all of it until the windows close;
--   - in battlegrounds, quests other players share can be turned down ("Automatically rejected quest shared by
--     player.");
--   - some NPCs and quests are never touched (Questie's lists, BF.Data.autoNever: commendations, war effort...).
-- And breadcrumbs: taking a quest whose breadcrumb is still to do says so, and can abandon the quest so the
-- breadcrumb can be done first ("Automatically abandoned quest %s because breadcrumb quest %s is not completed.").

local _, BF = ...
local L = BF.L

local Auto = {}
BF.Auto = Auto

local Rules, Player, Log = BF.Rules, BF.Player, BF.Log
local Q = BF.Q

local function never() return BF.Data.autoNever or { npcs = {}, accept = {}, turnIn = {} } end

local running = true -- false from a held key until every quest window has closed

function Auto:ModifierHeld()
	local key = BF:Get("auto.modifier")
	if key == "shift" then return IsShiftKeyDown() end
	if key == "ctrl" then return IsControlKeyDown() end
	if key == "alt" then return IsAltKeyDown() end
	return false
end

-- The NPC the player is talking to may be automated (not on the never list; a secret GUID: no).
local function allowedNpc(unit)
	local guid = UnitGUID(unit)
	if issecretvalue and issecretvalue(guid) then return false end
	local kind, id = BF.Tooltips:ParseGUID(guid)
	if kind == "npc" and never().npcs[id] then return false end
	return true
end

local function questID() return GetQuestID and GetQuestID() or 0 end

--- Whether a quest offered may be accepted by itself (low level, repeatable, PvP by the settings).
function Auto:Wants(id)
	if not id or id == 0 then return false end
	if never().accept[id] then return false end
	local kind = Rules:Kind(id)
	if not BF:Get("auto.trivial") and BF:Quest(id) and Rules:IsTrivial(id) then return false end
	if not BF:Get("auto.repeatable") and kind.repeatable then return false end
	if not BF:Get("auto.pvp") and kind.pvp then return false end
	return true
end

-- Events ---------------------------------------------------------------------------------------------------------------

local function onDetail()
	if not running or not BF:Get("auto.accept") or Auto:ModifierHeld() or not allowedNpc("questnpc") then return end
	local id = questID()
	if id == 0 or never().accept[id] then return end
	if BF:Get("auto.rejectInBattleground") and UnitInBattleground("player") then
		local guid = UnitGUID("questnpc")
		if guid and not (issecretvalue and issecretvalue(guid)) and strsplit("-", guid) == "Player" then
			DeclineQuest()
			BF:Print(L["Automatically rejected quest shared by player."])
			return
		end
	end
	if Auto:Wants(id) then AcceptQuest() end
end

local function onGreeting()
	if not running or Auto:ModifierHeld() or not allowedNpc("npc") then
		running = false
		return
	end
	if BF:Get("auto.complete") then
		for i = 1, GetNumActiveQuests() do
			local _, isComplete = GetActiveTitle(i)
			if isComplete then SelectActiveQuest(i) return end
		end
	end
	if BF:Get("auto.accept") and GetNumAvailableQuests() > 0 then SelectAvailableQuest(1) end
end

local function onGossip()
	if not running or Auto:ModifierHeld() or not allowedNpc("npc") then
		running = false
		return
	end
	local gossip = C_GossipInfo
	if not gossip then return end
	if BF:Get("auto.complete") then
		for _, q in ipairs(gossip.GetActiveQuests() or {}) do
			if q.isComplete then gossip.SelectActiveQuest(q.questID) return end
		end
	end
	if BF:Get("auto.accept") then
		for _, q in ipairs(gossip.GetAvailableQuests() or {}) do
			local ok = true
			if not BF:Get("auto.trivial") and q.isTrivial then ok = false end
			if not BF:Get("auto.repeatable") and q.repeatable then ok = false end
			if not BF:Get("auto.pvp") and Rules:Kind(q.questID).pvp then ok = false end
			if ok then gossip.SelectAvailableQuest(q.questID) return end
		end
	end
end

local function onProgress()
	if not running or not BF:Get("auto.complete") or Auto:ModifierHeld() or not IsQuestCompletable() then return end
	if never().turnIn[questID()] or not allowedNpc("questnpc") then return end
	CompleteQuest()
end

local function onComplete()
	if not running or not BF:Get("auto.complete") or Auto:ModifierHeld() or GetNumQuestChoices() > 1 then return end
	if never().turnIn[questID()] or not allowedNpc("questnpc") then return end
	GetQuestReward(1)
end

local function windowsClosed()
	for _, name in ipairs({ "GossipFrame", "QuestFrame", "ImmersionFrame" }) do
		local f = rawget(_G, name)
		if type(f) == "table" and f.IsVisible and f:IsVisible() then return false end
	end
	return true
end

local function stoppedTalking()
	BF:After(0.5, function()
		if not running and windowsClosed() then running = true end
	end)
end

-- Breadcrumbs ----------------------------------------------------------------------------------------------------------

local function link(id)
	return GetQuestLink and GetQuestLink(id) or ("[" .. (BF:QuestName(id) or id) .. "]")
end

--- After a quest is taken: its breadcrumbs still to do (and open to the player) are said; with the setting, the quest is
--- abandoned so the breadcrumb can be done first.
function Auto:CheckBreadcrumbs(id)
	if not (BF:Get("announce.incompleteBreadcrumb") or BF:Get("auto.abandonBreadcrumb")) then return end
	local q = BF:Quest(id)
	local skipped
	for _, b in ipairs(q and q[Q.breadcrumbs] or {}) do
		local bq = BF:Quest(b)
		if bq and not Player:HasCompleted(b) and not Log:Has(b) and Player:RaceAllowed(bq[Q.races])
			and Player:ClassAllowed(bq[Q.classes]) then
			local taken = false
			for _, other in ipairs(bq[Q.exclusiveTo] or {}) do
				if Player:HasCompleted(other) or Log:Has(other) then taken = true end
			end
			local until_ = bq[Q.availableUntilCompleted]
			if not taken and not (until_ and Player:HasCompleted(until_)) then
				if BF:Get("announce.incompleteBreadcrumb") then
					BF:Print(L["You have accepted %s without completing its breadcrumb quest %s"], link(id), link(b))
				end
				skipped = b
			end
		end
	end
	if skipped and BF:Get("auto.abandonBreadcrumb") and C_QuestLog.SetAbandonQuest then
		C_QuestLog.SetSelectedQuest(id)
		C_QuestLog.SetAbandonQuest()
		C_QuestLog.AbandonQuest()
		BF:Print(L["Automatically abandoned quest %s because breadcrumb quest %s is not completed."], link(id), link(skipped))
	end
end

BF:At("login", function()
	BF:On("QUEST_DETAIL", onDetail)
	BF:On("QUEST_GREETING", onGreeting)
	BF:On("GOSSIP_SHOW", onGossip)
	BF:On("QUEST_PROGRESS", onProgress)
	BF:On("QUEST_COMPLETE", onComplete)
	BF:On("QUEST_ACCEPT_CONFIRM", function() if BF:Get("auto.accept") then ConfirmAcceptQuest() end end)
	BF:On("GOSSIP_CLOSED", stoppedTalking)
	BF:On("QUEST_FINISHED", stoppedTalking)
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id) Auto:CheckBreadcrumbs(id) end)
end, 50)
