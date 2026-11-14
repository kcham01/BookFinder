-- Announcements (Quests > Automation): telling the party or raid about quests, as Questie does
-- (docs/study/questie.md, "Announcements"): objectives done ("<objective> for <quest>!"), items that start quests
-- ("Picked up <item> which starts <quest>!"), quests accepted, abandoned and handed in ("Quest Accepted: <quest>").
-- Each kind is its own switch; "Announce to" picks the party, the raid, either, or nobody; "Also in my own chat" shows
-- them to the player too. Group messages start with a star and BookFinder's name, as Questie's start with its own.
-- "Hide quest announcements from others" keeps other players' (Questie's and BookFinder's) out of the chat.
--
-- An item that starts a quest is always said to the player when it is not announced.

local _, BF = ...
local L = BF.L

local Announce = {}
BF.Announce = Announce

local I = BF.I

local function inGroupChannel()
	local channel = BF:Get("announce.channel")
	if channel == "both" then return IsInRaid() or IsInGroup() end
	if channel == "raid" then return IsInRaid() end
	if channel == "party" then return IsInGroup() and not IsInRaid() end
	return false
end

local function chatChannel()
	if IsInRaid() then return "RAID" end
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	return "PARTY"
end

local function link(id)
	return GetQuestLink and GetQuestLink(id) or ("[" .. (BF:QuestName(id) or id) .. "]")
end

local said = {} -- a message is said once a session

--- Says a message to the group (and to the player's own chat when chosen). fmt and its values: the message, built with
--- the quest's link.
function Announce:Say(kindSetting, fmt, ...)
	if not BF:Get(kindSetting) then return false end
	local group, self = inGroupChannel(), BF:Get("announce.self")
	if not group and not self then return false end
	local message = L[fmt]:format(...)
	if said[message] then return true end
	said[message] = true
	if self then BF:Print(message) end
	if group then SendChatMessage("{rt1} BookFinder: " .. message, chatChannel()) end
	return true
end

-- The game writes plural forms as |4one:many; in some objective texts: the right one for the count.
local function grammar(text, count)
	return (text:gsub("|4([^;]*);", function(forms)
		local list = {}
		for form in (forms .. ":"):gmatch("([^:]*):") do list[#list + 1] = form end
		return list[(count == 1 or #list < 2) and 1 or 2] or ""
	end))
end

-- Items looted that start a quest.
local function onLoot(_, text, name, _, _, looter)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	local me = UnitName("player")
	if not (looter == me or ((looter == nil or looter == "") and name == me)) then return end
	local itemID = tonumber(text:match("item:(%d+)"))
	local row = itemID and BF:Item(itemID)
	local quest = row and row[I.startQuest]
	if not quest or quest <= 0 then return end
	local itemLink = select(2, C_Item.GetItemInfo(itemID)) or ("[" .. (BF:ItemName(itemID) or itemID) .. "]")
	if not Announce:Say("announce.items", "Picked up %s which starts %s!", itemLink, link(quest)) then
		BF:Print(L["You picked up %s which starts %s!"], itemLink, link(quest))
	end
end

-- Hiding other players' announcements.
local function filter(_, _, message)
	if BF:Get("announce.quiet") and type(message) == "string" and not (issecretvalue and issecretvalue(message))
		and (message:find("^{rt1} Questie%s?:") or message:find("^{rt1} BookFinder:")) then
		return true
	end
	return false
end

local function addFilters()
	local add = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
	if not add then return end
	for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
		local ok = pcall(add, event, filter)
		if not ok then BF:After(0.1, addFilters) return end
	end
end

BF:At("login", function()
	BF:Listen("BF_QUEST_PROGRESS", function(_, id, _, o, before)
		if o.finished and not before.finished and o.text and o.text ~= "" then
			Announce:Say("announce.objectives", "%s for %s!", grammar(o.text, o.need), link(id))
		end
	end)
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id) Announce:Say("announce.accepted", "Quest %s: %s", L["Accepted"], link(id)) end)
	BF:Listen("BF_QUEST_REMOVED", function(_, id, turnedIn)
		if turnedIn then Announce:Say("announce.completed", "Quest %s: %s", L["Completed"], link(id))
		else Announce:Say("announce.abandoned", "Quest %s: %s", L["Abandoned"], link(id)) end
	end)
	BF:On("CHAT_MSG_LOOT", onLoot)
	addFilters()
end, 50)
