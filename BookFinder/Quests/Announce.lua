-- Announcements (Questie's, opt-in): the group hears when the player finishes an objective, picks up an item that
-- starts a quest, or accepts, abandons or hands in a quest. Written exactly as Questie writes them, marker included
-- ("{rt1} Questie: ... for ...!"), so a party member's Questie shows them with its logo and its "ShutUp" hides them.
--
--   announce.channel   party (the group's channel: raid, instance or party), yell, self (only in your own chat), disabled
--   announce.quiet     nobody's quest announcements, yours or the group's (Questie ShutUp!)

local _, BF = ...
local L = BF.L

local Announce = {}
BF.Announce = Announce

local sent = {}   -- one message once a session (Questie's guard against the log's repeats)

local function marker()
	if not (IsInGroup() or IsInRaid()) then return "" end
	local locale = GetLocale and GetLocale()
	if locale == "ruRU" then return "{звезда} Questie: " end
	if locale == "frFR" then return "{rt1} Questie : " end
	return "{rt1} Questie: "
end

local function groupChannel()
	if IsInRaid() then return "RAID" end
	if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	return "PARTY"
end

--- Sends one announcement where the setting says (nothing twice; nothing while quiet).
function Announce:Say(message)
	if not message or sent[message] or BF:Get("announce.quiet") then return false end
	local where = BF:Get("announce.channel")
	if where == "disabled" then return false end
	sent[message] = true
	if where == "self" then
		BF:Print(message)
	elseif where == "yell" then
		SendChatMessage(marker() .. message, "YELL")
	elseif IsInGroup() or IsInRaid() then
		SendChatMessage(marker() .. message, groupChannel())
	else
		return false
	end
	return true
end

local function link(questID) return BF.Links:Quest(questID) end

-- SendChatMessage refuses the |4singular:plural; escape some objective texts carry: the right form is taken.
local function plain(text)
	return (text:gsub("|4([^:;]*):([^;]*);", function(one, many) return many end))
end

local function onProgress(_, questID, _, objective, before)
	if not BF:Get("announce.objectives") then return end
	if objective.finished and not (before and before.finished) and objective.text ~= "" then
		Announce:Say(L["%s for %s!"]:format(plain(objective.text), link(questID)))
	end
end

local function onAccepted(_, questID)
	if BF:Get("announce.accepted") then Announce:Say(L["Quest %s: %s"]:format(L["Accepted"], link(questID))) end
end

local function onRemoved(_, questID, turnedIn)
	if turnedIn and BF:Get("announce.completed") then
		Announce:Say(L["Quest %s: %s"]:format(L["Completed"], link(questID)))
	elseif not turnedIn and BF:Get("announce.abandoned") then
		Announce:Say(L["Quest %s: %s"]:format(L["Abandoned"], link(questID)))
	end
end

-- An item that starts a quest, looted by the player.
local function onLoot(_, text, _, _, _, _, _, _, _, _, _, _, guid)
	if not BF:Get("announce.items") or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	if guid and not (issecretvalue and issecretvalue(guid)) and guid ~= UnitGUID("player") then return end
	local item = tonumber(text:match("|Hitem:(%d+)"))
	local row = item and BF:Item(item)
	local quest = row and row[BF.I.startQuest]
	if not quest or quest == 0 or BF.Log:Has(quest) or BF.Player:HasCompleted(quest) then return end
	local itemLink = text:match("(|c%x+|Hitem:.-|h|r)") or text:match("(|Hitem:.-|h)") or ("[" .. (BF:ItemName(item) or item) .. "]")
	BF:Print(L["You picked up %s which starts %s!"], itemLink, link(quest))
	if BF:Get("announce.channel") ~= "self" then
		Announce:Say(L["Picked up %s which starts %s!"]:format(itemLink, link(quest)))
	end
end

-- Quiet: the group's quest announcements (Questie's and ours) are hidden too.
local GROUP_EVENTS = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_YELL" }
local function quietFilter(_, _, msg)
	if not BF:Get("announce.quiet") or type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return false end
	return msg:find("^{rt1} Questie%s?:") ~= nil or msg:find("^{звезда} Questie%s?:") ~= nil
end

BF:At("login", function()
	BF:Listen("BF_QUEST_PROGRESS", onProgress)
	BF:Listen("BF_QUEST_ACCEPTED", onAccepted)
	BF:Listen("BF_QUEST_REMOVED", onRemoved)
	BF:On("CHAT_MSG_LOOT", onLoot)
	if ChatFrame_AddMessageEventFilter then
		for _, e in ipairs(GROUP_EVENTS) do ChatFrame_AddMessageEventFilter(e, quietFilter) end
	end
end, 66)
