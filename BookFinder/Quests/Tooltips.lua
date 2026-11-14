-- Quest lines on the game's own tooltips: NPCs (in the world and on nameplates), objects, items, spells.
--
-- What a player reads (docs/study/questie.md, "Tooltips elsewhere"):
--   NPC     each quest that needs it, its title (with its level when chosen) and the objective's own line from the
--           quest log ("Kobold Vermin slain: 3/10"), the drop chance when it drops what a quest asks for; then the
--           quests it gives that the player can take ("!") and the finished quests it takes back ("?").
--   object  the quests that need it, the quests it starts and ends, the same way.
--   item    the quests that ask for it, with progress; other files add their own lines (a library book's state).
--   IDs     "NPC ID: 299" and the like, each switched on by itself (off by default).
--
-- The client gives the hovered thing by GUID or ID (TooltipDataProcessor). A world object's tooltip can come without
-- one; then its name (the tooltip's first line) is matched against the objects the player's quests care about, never
-- against every object in the data (thousands share names like "Crate").
--
-- WoW: Forever's secret values: a GUID or a tooltip line can be secret (in combat, in instances). Anything secret is
-- left alone: no lines are added rather than wrong ones.
--
-- Other files add lines with BF.Tooltips:Register(kind, fn(tooltip, id)), kind "npc", "object" or "item".

local _, BF = ...
local L = BF.L

local Tooltips = { providers = { npc = {}, object = {}, item = {} } }
BF.Tooltips = Tooltips

local Rules, Log, Needs, Reward, Icons = BF.Rules, BF.Log, BF.Needs, BF.Reward, BF.Icons
local N, O = BF.N, BF.O

local GREY = { 0.5, 0.5, 0.5 }
local GOLD = { 1, 0.82, 0 }
local INDENT = "   "

local function secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

--- Registers fn(tooltip, id) to add lines to every tooltip of a kind ("npc", "object", "item").
function Tooltips:Register(kind, fn)
	local list = assert(self.providers[kind], "unknown tooltip kind " .. tostring(kind))
	list[#list + 1] = fn
end

-- GUIDs ---------------------------------------------------------------------------------------------------------

--- "npc" / "object" and the ID from a GUID ("Creature-0-1-0-12-299-0000AB12CD"), or nil.
function Tooltips:ParseGUID(guid)
	if type(guid) ~= "string" or secret(guid) then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	id = tonumber(id)
	if not id then return nil end
	if kind == "Creature" or kind == "Vehicle" then return "npc", id end
	if kind == "GameObject" then return "object", id end
	return nil
end

-- Lines ---------------------------------------------------------------------------------------------------------

local function add(tip, text, c)
	c = c or { 1, 1, 1 }
	tip:AddLine(text, c[1], c[2], c[3], true)
end

local function titleOf(quest)
	local q = Log:Get(quest)
	return Rules:ColoredTitle(quest, q and q.title or nil, BF:Get("tooltips.questLevel"))
end

-- The quests in `needs` (from BF.Needs), each title once, its objectives under it.
local function addNeeds(tip, needs, withRates)
	local shownTitle = {}
	local shownLine = {}
	for _, need in ipairs(needs) do
		local quest, rec = need.quest, need.objective
		if not shownTitle[quest] then
			shownTitle[quest] = true
			add(tip, titleOf(quest))
		end
		local key = quest .. ":" .. tostring(rec.index or rec.name)
		if not shownLine[key] then
			shownLine[key] = true
			local text = rec.text ~= "" and rec.text or rec.name or ""
			local s = need.source
			if withRates and s and s.rate and BF:Get("tooltips.dropRates") then
				text = ("%s |cffbbbbbb(%s%%)|r"):format(text, (("%.1f"):format(s.rate):gsub("%.0$", "")))
			end
			if text ~= "" then add(tip, INDENT .. text, GOLD) end
		end
	end
end

-- Quests a giver offers (shown by the player's settings) and finished quests it takes back.
local function addGiver(tip, starts, ends)
	if not BF:Get("tooltips.npcQuests") then return end
	for _, quest in ipairs(ends or {}) do
		if Log:Has(quest) and Log:IsComplete(quest) and not Rules:HiddenByPlayer(quest) then
			tip:AddDoubleLine(Icons:Inline("complete", 12) .. " " .. titleOf(quest), "(" .. L["Complete"] .. ")",
				1, 1, 1, 1, 1, 0)
		end
	end
	for _, quest in ipairs(starts or {}) do
		if Rules:IsShown(quest) then
			local kind = Rules:IsTrivial(quest) and "availableTrivial" or "available"
			tip:AddDoubleLine(Icons:Inline(kind, 12) .. " " .. titleOf(quest), Reward:Text(quest), 1, 1, 1, 1, 1, 0)
			local q = BF:Quest(quest)
			if BF:Get("tooltips.nextInChain") and q and q[BF.Q.nextInChain] and q[BF.Q.nextInChain] > 0 then
				add(tip, INDENT .. L["Next in chain"] .. L[": "] .. titleOf(q[BF.Q.nextInChain]), GREY)
			end
			if BF:Get("tooltips.breadcrumbs") and q and q[BF.Q.breadcrumbFor] then
				add(tip, INDENT .. L["Breadcrumb for"] .. L[": "] .. titleOf(q[BF.Q.breadcrumbFor]), GREY)
			end
		end
	end
end

local function addID(tip, setting, label, id)
	if BF:Get(setting) then add(tip, label .. L[": "] .. id, GREY) end
end

local function runProviders(kind, tip, id)
	for _, fn in ipairs(Tooltips.providers[kind]) do BF.safecall(fn, tip, id) end
end

--- The lines for an NPC (also used by tests).
function Tooltips:AddNpc(tip, id)
	if BF:Get("tooltips.enabled") then
		addNeeds(tip, Needs:Npc(id), true)
		local row = BF:Npc(id)
		if row then addGiver(tip, row[N.questStarts], row[N.questEnds]) end
	end
	runProviders("npc", tip, id)
	addID(tip, "tooltips.ids.npc", L["NPC ID"], id)
end

function Tooltips:AddObject(tip, id)
	if BF:Get("tooltips.enabled") then
		addNeeds(tip, Needs:Object(id), true)
		local row = BF:Object(id)
		if row then addGiver(tip, row[O.questStarts], row[O.questEnds]) end
	end
	runProviders("object", tip, id)
	addID(tip, "tooltips.ids.object", L["Object ID"], id)
end

function Tooltips:AddItem(tip, id)
	if BF:Get("tooltips.enabled") then addNeeds(tip, Needs:Item(id), false) end
	runProviders("item", tip, id)
	addID(tip, "tooltips.ids.item", L["Item ID"], id)
end

function Tooltips:AddSpell(tip, id)
	addID(tip, "tooltips.ids.spell", L["Spell ID"], id)
end

-- Objects by name (a world object's tooltip without an ID) ------------------------------------------------------
--
-- Only objects the player's quests touch: what their objectives need, where finished quests are handed in, and the
-- quest-giving objects marked on the map the player is on.

local byName -- [name] = objectID, rebuilt after BF_NEEDS_CHANGED / BF_MARKS_CHANGED
local byNameMap

local function nameIndex()
	local map = BF.Zones and C_Map.GetBestMapForUnit("player")
	if byName and byNameMap == map then return byName end
	byName, byNameMap = {}, map
	local function put(id)
		local name = BF:ObjectName(id)
		if name and not byName[name] then byName[name] = id end
	end
	for quest in pairs(Log.quests) do
		for _, rec in ipairs(BF.Objectives:For(quest)) do
			for _, s in ipairs(rec.sources or {}) do if s.type == "object" then put(s.id) end end
		end
		local q = BF:Quest(quest)
		for _, id in ipairs(q and q[BF.Q.endObjects] or {}) do put(id) end
	end
	if map and BF.Marks then
		for _, pin in ipairs(BF.Marks:On(map)) do
			if pin.source and pin.source.type == "object" then put(pin.source.id) end
		end
	end
	return byName
end
BF:Listen("BF_NEEDS_CHANGED", function() byName = nil end)
BF:Listen("BF_MARKS_CHANGED", function() byName = nil end)

--- The object ID a tooltip's first line names, among the objects the player's quests touch, or nil.
function Tooltips:ObjectByName(name)
	if type(name) ~= "string" or secret(name) or name == "" then return nil end
	return nameIndex()[name]
end

-- Hooks ---------------------------------------------------------------------------------------------------------

local done = setmetatable({}, { __mode = "k" }) -- [tooltip] = true once BookFinder has added its lines this time

local function annotate(tip, kind, id)
	if done[tip] or not id then return end
	done[tip] = true
	if kind == "npc" then Tooltips:AddNpc(tip, id)
	elseif kind == "object" then Tooltips:AddObject(tip, id)
	elseif kind == "item" then Tooltips:AddItem(tip, id)
	elseif kind == "spell" then Tooltips:AddSpell(tip, id) end
end

local function cleared(tip) done[tip] = nil end

local function firstLine(tip)
	local name = tip.GetName and tip:GetName()
	local region = name and _G[name .. "TextLeft1"]
	local text = region and region:GetText()
	if secret(text) then return nil end
	return text
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookClear(tip)
	if hooked[tip] or not tip.HookScript then return end
	hooked[tip] = true
	tip:HookScript("OnTooltipCleared", cleared)
	tip:HookScript("OnHide", cleared)
end

local function onUnit(tip, data)
	hookClear(tip)
	local guid = data and data.guid
	if not guid and tip.GetUnit then
		local _, unit = tip:GetUnit()
		if unit and not secret(unit) then guid = UnitGUID(unit) end
	end
	local kind, id = Tooltips:ParseGUID(guid)
	if kind then annotate(tip, kind, id) end
end

local function onObject(tip, data)
	hookClear(tip)
	local kind, id = Tooltips:ParseGUID(data and data.guid)
	if kind == "object" then
		annotate(tip, "object", id)
	else
		local found = Tooltips:ObjectByName(firstLine(tip))
		if found then annotate(tip, "object", found) end
	end
end

local function onItem(tip, data)
	hookClear(tip)
	local id = data and data.id
	if not id and tip.GetItem then
		local _, link = tip:GetItem()
		if link and not secret(link) then id = tonumber(link:match("item:(%d+)")) end
	end
	if type(id) == "number" and not secret(id) then annotate(tip, "item", id) end
end

local function onSpell(tip, data)
	hookClear(tip)
	local id = data and data.id
	if type(id) == "number" and not secret(id) then annotate(tip, "spell", id) end
end

-- A world object's tooltip that the client gave no data for: matched by name when it shows (GameTooltip only: the
-- world cursor's tooltip).
local function onShow(tip)
	if done[tip] then return end
	if tip.GetUnit and tip:GetUnit() then return end
	if tip.GetItem and tip:GetItem() then return end
	if tip.GetSpell and tip:GetSpell() then return end
	local id = Tooltips:ObjectByName(firstLine(tip))
	if id then
		annotate(tip, "object", id)
		tip:Show() -- fit the added lines
	end
end

BF:At("login", function()
	local processor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
	local types = Enum and Enum.TooltipDataType
	if processor and types then
		if types.Unit then processor(types.Unit, onUnit) end
		if types.Item then processor(types.Item, onItem) end
		if types.Spell then processor(types.Spell, onSpell) end
		if types.Object then processor(types.Object, onObject) end
	elseif GameTooltip.HookScript then
		-- Older clients: the tooltip's own scripts.
		GameTooltip:HookScript("OnTooltipSetUnit", function(tip) onUnit(tip, nil) end)
		GameTooltip:HookScript("OnTooltipSetItem", function(tip) onItem(tip, nil) end)
		if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", function(tip) onItem(tip, nil) end) end
	end
	hookClear(GameTooltip)
	GameTooltip:HookScript("OnShow", onShow)
end, 70)
