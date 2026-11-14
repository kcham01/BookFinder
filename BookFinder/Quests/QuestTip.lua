-- A quest's tooltip, as Questie's quest links show it: the title, whether the player is on it / has done it / it is
-- repeatable / not done, its objectives (with the player's progress when on it), who starts and ends it, where.
-- Used by the Journey's lists, Advanced Search, and quest links in chat.

local _, BF = ...
local L = BF.L

local QuestTip = {}
BF.QuestTip = QuestTip

local Q = BF.Q

local function names(npcs, objects)
	local list = {}
	for _, id in ipairs(npcs or {}) do list[#list + 1] = BF:NpcName(id) end
	for _, id in ipairs(objects or {}) do list[#list + 1] = BF:ObjectName(id) end
	return table.concat(list, ", ")
end

--- Fills `tip` (a GameTooltip) for a quest.
function QuestTip:Fill(tip, id)
	local q = BF:Quest(id)
	local rules = BF.Rules
	tip:AddLine(rules:ColoredTitle(id, nil, true))
	local kind = rules:Kind(id)
	if BF.Log:Has(id) then
		tip:AddLine(L["You are on this quest"], 0.3, 1, 0.3)
	elseif BF.Player:HasCompleted(id) and not kind.repeatable then
		tip:AddLine(L["You have completed this quest"], 0.3, 1, 0.3)
	elseif kind.repeatable then
		tip:AddLine(L["This quest is repeatable"], 0.4, 0.7, 1)
	else
		tip:AddLine(L["You have not done this quest"], 1, 0.3, 0.3)
	end
	if not q then return end
	tip:AddLine(" ")
	if BF.Log:Has(id) then
		tip:AddLine(L["Your progress"] .. L[": "], 1, 0.82, 0)
		for _, o in ipairs(BF.Log:Get(id).objectives) do
			tip:AddLine("   " .. o.text, o.finished and 0.3 or 1, o.finished and 1 or 1, o.finished and 0.3 or 1, true)
		end
	else
		for _, text in ipairs(q[Q.objectivesText] or {}) do tip:AddLine(text, 1, 1, 1, true) end
	end
	tip:AddLine(" ")
	local starts = names(q[Q.startNpcs], q[Q.startObjects])
	if q[Q.startItems] then
		local items = {}
		for _, i in ipairs(q[Q.startItems]) do items[#items + 1] = BF:ItemName(i) end
		starts = (starts ~= "" and starts .. ", " or "") .. table.concat(items, ", ")
	end
	if starts ~= "" then tip:AddDoubleLine(L["Started by"], starts, 1, 0.82, 0, 1, 1, 1) end
	local ends = names(q[Q.endNpcs], q[Q.endObjects])
	if ends ~= "" then tip:AddDoubleLine(L["Ended by"], ends, 1, 0.82, 0, 1, 1, 1) end
	local zone = q[Q.zoneOrSort]
	if zone and zone > 0 then
		local name = BF.Zones:AreaName(zone)
		if name then tip:AddDoubleLine(L["Found in"], name, 1, 0.82, 0, 1, 1, 1) end
	end
	local reward = BF.Reward:Text(id)
	if reward ~= "" then tip:AddDoubleLine(L["Reward"], reward, 1, 0.82, 0, 1, 1, 1) end
	if BF:Get("tooltips.ids.quest") then tip:AddLine("ID: " .. id, 0.5, 0.5, 0.5) end
end

function QuestTip:Show(owner, id)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	QuestTip:Fill(GameTooltip, id)
	GameTooltip:Show()
end
