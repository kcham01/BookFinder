-- Quest lines in the game's tooltips (Questie's): on creatures, objects and items, what the player's quests need from
-- them with the progress (and the drop chance), the quests a creature gives and takes, IDs when chosen, and the
-- library-book line on books. While these are on, the game's own quest lines in tooltips are turned off (the
-- showQuestTrackingTooltips setting) so nothing shows twice; turned back on with ours.
--
-- WoW: Forever can hand addons secret values in tooltips (combat, instances): such a tooltip is left as the game drew it.

local _, BF = ...
local L = BF.L

local Tooltips = {}
BF.Tooltips = Tooltips

local Rules, Log, Needs, Q, N = BF.Rules, BF.Log, BF.Needs, BF.Q, BF.N

local function secret(v) return issecretvalue and issecretvalue(v) end

local function questTitle(id)
	local q = Log:Get(id)
	return Rules:ColoredTitle(id, q and q.title, BF:Get("tooltips.questLevel"))
end

-- An objective's line: its text with progress, in the quest objective colours (grey-white working, green done).
local function objectiveLine(tip, rec, rate)
	local text = rec.text or rec.name or ""
	if rate and BF:Get("tooltips.dropRates") then text = ("%s (%.1f%%)"):format(text, rate) end
	if rec.finished then tip:AddLine("   " .. text, 0.3, 1, 0.3) else tip:AddLine("   " .. text, 0.9, 0.9, 0.9) end
end

-- The quests a list of needs belongs to, each with its objective lines (one quest once).
local function addNeeds(tip, needs)
	if not needs or #needs == 0 then return false end
	local byQuest, order = {}, {}
	for _, e in ipairs(needs) do
		if not byQuest[e.quest] then
			byQuest[e.quest] = {}
			order[#order + 1] = e.quest
		end
		table.insert(byQuest[e.quest], e)
	end
	for _, quest in ipairs(order) do
		tip:AddLine(questTitle(quest))
		local seen = {}
		for _, e in ipairs(byQuest[quest]) do
			if not seen[e.objective] then
				seen[e.objective] = true
				objectiveLine(tip, e.objective, e.rate)
			end
		end
	end
	return true
end

local function addNpc(tip, npc)
	local added = false
	if BF:Get("tooltips.npcQuests") then
		local n = BF:Npc(npc)
		if n then
			-- As Questie: the quest's own icon, then its title ("! [30] Melor Sends Word").
			for _, q in ipairs(n[N.questEnds] or {}) do
				if Log:Has(q) and Log:IsComplete(q) then
					tip:AddLine(BF.Icons:Inline("complete", 14) .. " " .. questTitle(q))
					added = true
				end
			end
			for _, q in ipairs(n[N.questStarts] or {}) do
				if Rules:IsShown(q) then
					local kind = Rules:IsTrivial(q) and "availableTrivial" or "available"
					tip:AddLine(BF.Icons:Inline(kind, 14) .. " " .. Rules:ColoredTitle(q, nil, BF:Get("tooltips.questLevel")))
					added = true
				end
			end
		end
	end
	local needs = Needs:ForNpc(npc)
	if needs and #needs > 0 then
		if not added then tip:AddLine(" ") end
		addNeeds(tip, needs)
		added = true
	end
	if BF:Get("tooltips.ids.npc") then tip:AddLine("NPC ID: " .. npc, 0.5, 0.5, 0.5) added = true end
	return added
end

local function addItem(tip, item)
	local added = false
	local book = BF.Books and BF.Books.byItem[item]
	if book then
		local done = BF.Books:IsDone(book)
		tip:AddLine(L["Library book"] .. " - " .. (done and L["collected"] or L["missing"]) .. " (" .. L[BF.Books.SET_NAMES[book.set]] .. ")",
			done and 0.3 or 1, done and 1 or 0.3, 0.3)
		added = true
	end
	local needs = Needs:ForItem(item)
	if needs then addNeeds(tip, needs) added = true end
	local row = BF:Item(item)
	local starts = row and row[BF.I.startQuest]
	if starts and starts > 0 and not Log:Has(starts) and not BF.Player:HasCompleted(starts) then
		tip:AddDoubleLine(L["Starts a quest"], BF:QuestName(starts) or "", 1, 0.82, 0, 1, 1, 1)
		added = true
	end
	if BF:Get("tooltips.ids.item") then tip:AddLine("Item ID: " .. item, 0.5, 0.5, 0.5) added = true end
	return added
end

-- Hooking the tooltips ----------------------------------------------------------------------------------------------

local function onUnit(tip, data)
	if not BF:Get("tooltips.enabled") or tip ~= GameTooltip then return end
	if not data or secret(data) or secret(data.guid) then return end
	local npc = Needs:NpcFromGUID(data.guid)
	if npc and addNpc(tip, npc) then tip:Show() end
end

local function onItem(tip, data)
	if not BF:Get("tooltips.enabled") then return end
	if not data or secret(data) or secret(data.id) then return end
	local id = data.id
	if type(id) == "number" and addItem(tip, id) then tip:Show() end
end

local function onObject(tip, data)
	if not BF:Get("tooltips.enabled") or tip ~= GameTooltip then return end
	if not data or secret(data) or secret(data.id) or type(data.id) ~= "number" then return end
	local added = false
	local needs = Needs:ForObject(data.id)
	if needs then added = addNeeds(tip, needs) end
	if BF:Get("tooltips.ids.object") then tip:AddLine("Object ID: " .. data.id, 0.5, 0.5, 0.5) added = true end
	if added then tip:Show() end
end

local function onSpell(tip, data)
	if not BF:Get("tooltips.ids.spell") then return end
	if not data or secret(data) or secret(data.id) or type(data.id) ~= "number" then return end
	tip:AddLine("Spell ID: " .. data.id, 0.5, 0.5, 0.5)
	tip:Show()
end

-- The game's own quest lines in tooltips: off while ours show.
local function nativeLines()
	if not (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showQuestTrackingTooltips") ~= nil) then return end
	local want = BF:Get("tooltips.enabled") and "0" or "1"
	local state = BF:AccountState("tooltips")
	if want == "0" and state.nativeWas == nil then state.nativeWas = C_CVar.GetCVar("showQuestTrackingTooltips") end
	if want == "1" and state.nativeWas then want = state.nativeWas state.nativeWas = nil end
	if C_CVar.GetCVar("showQuestTrackingTooltips") ~= want then C_CVar.SetCVar("showQuestTrackingTooltips", want) end
end

BF:At("login", function()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
		if Enum.TooltipDataType.Spell then TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, onSpell) end
		if Enum.TooltipDataType.Object then TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, onObject) end
	end
	nativeLines()
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "tooltips.enabled" then nativeLines() end end)
end, 63)

Tooltips.AddNpc, Tooltips.AddItem = addNpc, addItem
