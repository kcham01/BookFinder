-- Quest links in chat, the way Questie writes and reads them (so links pass both ways between BookFinder and Questie):
--   sent as plain text, "[[33] Hearts of Zeal (1234)]" (or "[Hearts of Zeal (1234)]" without levels); every receiver's
--   chat filter turns that into a clickable |Hquestie:<questID>:<senderGUID>|h[...]|h link; a click shows the quest's
--   tooltip (Quests/QuestTip.lua). A quest in the player's log is sent as the game's own quest link when there is one.

local _, BF = ...

local Links = {}
BF.Links = Links

--- The text to put in chat for a quest.
function Links:Quest(id)
	if GetQuestLink and BF.Log:Has(id) then
		local link = GetQuestLink(id)
		if link then return link end
	end
	local name = BF:QuestName(id) or ("Quest " .. id)
	if BF:Get("list.questLevel") then
		return ("[[%d] %s (%d)]"):format(BF.Rules:Level(id), name, id)
	end
	return ("[%s (%d)]"):format(name, id)
end

-- Incoming chat: Questie-style quest texts become links (left alone when Questie itself is loaded: it does this).
local function linkify(text, guid)
	local function make(level, name, id)
		id = tonumber(id)
		if not id or not BF:Quest(id) then return nil end
		local label = level and ("[%s] %s"):format(level, name) or name
		local colored = BF.Rules:ColoredTitle(id, label, false)
		return ("|Hquestie:%d:%s|h[%s]|h"):format(id, guid or "", colored)
	end
	text = text:gsub("%[%[(%d+)%] (.-) %((%d+)%)%]", function(level, name, id) return make(level, name, id) end)
	text = text:gsub("%[([^%[%]]-) %((%d+)%)%]", function(name, id) return make(nil, name, id) end)
	return text
end

local events = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM" }

local function filter(_, _, msg, author, ...)
	if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) or not msg:find("%(%d+%)%]") then return false end
	local guid = select(10, ...)
	return false, linkify(msg, type(guid) == "string" and guid or nil), author, ...
end

-- A click on a quest link: its tooltip.
local function onLink(link)
	local id = tonumber((link or ""):match("^questie:(%d+)"))
	if not id then return false end
	ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	ItemRefTooltip:ClearLines()
	BF.QuestTip:Fill(ItemRefTooltip, id)
	ItemRefTooltip:Show()
	return true
end

BF:At("login", function()
	local questie = C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie")
	if questie then return end
	if ChatFrame_AddMessageEventFilter then
		for _, e in ipairs(events) do ChatFrame_AddMessageEventFilter(e, filter) end
	end
	if LinkUtil and LinkUtil.RegisterLinkHandler then
		LinkUtil.RegisterLinkHandler("questie", onLink)
	end
end)

Links.Linkify = linkify
