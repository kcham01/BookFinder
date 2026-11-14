-- Questie's quest links in chat (|Hquestie:<questID>:<senderGUID>|h[...]|h, docs/study/questie-protocol.md 4): a party
-- member using Questie links quests that way, and without Questie they do nothing. BookFinder answers them: clicking one
-- opens the quest's tooltip (clicking again closes it), hovering one shows it. The game's own quest links stay the
-- game's.
--
-- The tooltip (docs/study/questie.md, "Chat links"): the quest's title with its level, where the player stands with it
-- ("You are on this quest", "You have completed this quest", "This quest is repeatable", "You have not done this
-- quest"), its objectives with the player's progress, who starts and ends it, the zone it is found in, the instance.
--
-- On Forever, links are handled through the game's link handlers (LinkUtil), as Questie does there: replacing the
-- tooltip's own function taints every link click in instances.

local _, BF = ...
local L = BF.L

local Links = {}
BF.Links = Links

local Q = BF.Q
local Rules, Log, Player, Zones = BF.Rules, BF.Log, BF.Player, BF.Zones

local GOLD, WHITE, GREY, GREEN = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.6, 0.6, 0.6 }, { 0.2, 1, 0.2 }

function Links:Parse(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("^questie:(%d+)") or link:match("|Hquestie:(%d+)"))
end

--- A quest link the way Questie writes it (for chat): coloured, with the level when chosen.
function Links:Quest(id)
	local guid = UnitGUID("player") or "0"
	return ("|Hquestie:%d:%s|h%s|h"):format(id, guid, "[" .. Rules:ColoredTitle(id, nil, BF:Get("tooltips.questLevel")) .. "]")
end

local function names(list, name)
	local out = {}
	for _, id in ipairs(list or {}) do
		local n = name(id)
		if n then out[#out + 1] = n end
	end
	return table.concat(out, ", ")
end

--- Fills a tooltip with a quest.
function Links:Fill(tip, id)
	local q = BF:Quest(id)
	if not q then return false end
	tip:AddLine(Rules:ColoredTitle(id, nil, true))
	local status, colour
	if Log:Has(id) then status, colour = L["You are on this quest"], GOLD
	elseif Player:HasCompleted(id) and not Rules:Kind(id).repeatable then status, colour = L["You have completed this quest"], GREEN
	elseif Rules:Kind(id).repeatable then status, colour = L["This quest is repeatable"], WHITE
	else status, colour = L["You have not done this quest"], GREY end
	tip:AddLine(status, colour[1], colour[2], colour[3])
	for _, text in ipairs(q[Q.objectivesText] or {}) do tip:AddLine(text, 1, 1, 1, true) end
	local logQuest = Log:Get(id)
	if logQuest and #logQuest.objectives > 0 then
		tip:AddLine(" ")
		tip:AddLine(L["Your progress"] .. L[":"], GOLD[1], GOLD[2], GOLD[3])
		for _, o in ipairs(logQuest.objectives) do
			local c = o.finished and GREEN or WHITE
			tip:AddLine("   " .. o.text, c[1], c[2], c[3])
		end
	end
	local function joined(...)
		local parts = {}
		for i = 1, select("#", ...) do
			local part = select(i, ...)
			if part ~= "" then parts[#parts + 1] = part end
		end
		return table.concat(parts, ", ")
	end
	local by = joined(names(q[Q.startNpcs], function(n) return BF:NpcName(n) end),
		names(q[Q.startObjects], function(o) return BF:ObjectName(o) end),
		names(q[Q.startItems], function(i) return BF:ItemName(i) end))
	if by ~= "" then tip:AddDoubleLine(L["Started by"] .. L[":"], by, GREY[1], GREY[2], GREY[3], 1, 1, 1) end
	local ends = joined(names(q[Q.endNpcs], function(n) return BF:NpcName(n) end),
		names(q[Q.endObjects], function(o) return BF:ObjectName(o) end))
	if ends ~= "" then tip:AddDoubleLine(L["Ended by"] .. L[":"], ends, GREY[1], GREY[2], GREY[3], 1, 1, 1) end
	local zone = q[Q.zoneOrSort]
	if zone and zone > 0 then
		local dungeon = Zones:Dungeon(zone)
		if dungeon then tip:AddDoubleLine(L["Instance"] .. L[":"], dungeon[1], GREY[1], GREY[2], GREY[3], 1, 1, 1)
		else
			local name = Zones:AreaName(zone)
			if name then tip:AddDoubleLine(L["Found in"] .. L[":"], name, GREY[1], GREY[2], GREY[3], 1, 1, 1) end
		end
	end
	if BF:Get("tooltips.ids.quest") then tip:AddLine("ID: " .. id, GREY[1], GREY[2], GREY[3]) end
	return true
end

-- Clicking: the quest's tooltip in the game's link tooltip (again: closed).
local lastShown

function Links:Click(link)
	local id = Links:Parse(link)
	if not id or not BF:Quest(id) then return false end
	local tip = ItemRefTooltip
	if tip:IsShown() and lastShown == id then
		tip:Hide()
		lastShown = nil
		return true
	end
	ShowUIPanel(tip)
	tip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	tip:ClearLines()
	Links:Fill(tip, id)
	tip:Show()
	lastShown = id
	return true
end

-- Hovering a link in a chat window.
local function onEnter(frame, link)
	local id = Links:Parse(link)
	if not id or not BF:Quest(id) then return end
	GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
	Links:Fill(GameTooltip, id)
	GameTooltip:Show()
end

local function onLeave() GameTooltip:Hide() end

BF:At("login", function()
	if LinkUtil and LinkUtil.RegisterLinkHandler then
		LinkUtil.RegisterLinkHandler("questie", function(link)
			if IsModifiedClick and IsModifiedClick() then return LinkProcessorResponse.Unhandled end
			return Links:Click(link) and LinkProcessorResponse.Handled or LinkProcessorResponse.Unhandled
		end)
	end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local frame = _G["ChatFrame" .. i]
		if type(frame) == "table" and frame.HookScript then
			frame:HookScript("OnHyperlinkEnter", onEnter)
			frame:HookScript("OnHyperlinkLeave", onLeave)
		end
	end
end, 50)
