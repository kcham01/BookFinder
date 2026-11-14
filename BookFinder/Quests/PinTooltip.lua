-- The tooltip of a quest pin (world map or minimap) and what its clicks do.
--
-- Laid out the way Questie's read (docs/study/questie.md, "Icon tooltips"): the NPC's or object's name in green, its
-- quests in white with their reward on the right, "(Hold Shift)" when more is held back; Shift shows the quest's kind,
-- the instance, reputation rewards, breadcrumbs and the next quest in the chain. Objectives: the quest's title, then
-- who or what to find (with drop chances) and the objective's progress. Several pins at one spot are listed together.

local _, BF = ...
local L = BF.L

local PinTooltip = {}
BF.PinTooltip = PinTooltip

local Rules, Reward, Log, Look, Zones, Objectives = BF.Rules, BF.Reward, BF.Log, BF.Look, BF.Zones, BF.Objectives
local Q = BF.Q

local GREEN = { 0.2, 1, 0.2 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.43, 0.43, 0.43 }
local LIGHT = { 0.86, 0.86, 0.86 }
local DETAIL = { 0.7, 0.7, 0.7 }
local YELLOW = { 1, 1, 0 }
local INDENT, INDENT2 = "   ", "      "

local tip = GameTooltip

local function line(text, c)
	c = c or WHITE
	tip:AddLine(text, c[1], c[2], c[3], true)
end

local function double(left, right, lc, rc)
	lc, rc = lc or WHITE, rc or YELLOW
	tip:AddDoubleLine(left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
end

local function title(quest)
	local q = Log:Get(quest)
	return Rules:TitleWithLevel(quest, q and q.title or nil)
end

local function plainTitle(quest)
	if BF:Get("tooltips.questLevel") then return title(quest) end
	local q = Log:Get(quest)
	return (q and q.title) or BF:QuestName(quest) or ("Quest " .. quest)
end

--- "Repeatable", "Daily", "Event", "PvP", "Raid"... the kind words Questie shows.
local function kindWords(quest)
	local k = Rules:Kind(quest)
	local words = {}
	if k.event then words[#words + 1] = L["Event"] end
	if k.pvp then words[#words + 1] = (k.daily and L["Daily PvP"]) or L["PvP"] end
	if k.raid then words[#words + 1] = L["Raid"] end
	if k.weekly then words[#words + 1] = L["Weekly"]
	elseif k.monthly then words[#words + 1] = L["Monthly"]
	elseif k.daily and not k.pvp then words[#words + 1] = L["Daily"]
	elseif k.repeatable then words[#words + 1] = L["Repeatable"]
	end
	return table.concat(words, ", ")
end

local function instanceName(quest)
	local q = BF:Quest(quest)
	local zone = q and q[Q.zoneOrSort]
	if zone and zone > 0 then
		local dungeon = Zones:Dungeon(zone)
		if dungeon then return dungeon[1] end
	end
end

local function questDetail(quest, shift)
	if not shift then return end
	local words = kindWords(quest)
	if words ~= "" then line(INDENT .. words, DETAIL) end
	local instance = instanceName(quest)
	if instance then line(INDENT .. L["Instance"] .. L[": "] .. instance, DETAIL) end
	for _, rep in ipairs(Reward:ReputationLines(quest)) do line(INDENT .. rep, { 0.4, 0.6, 1 }) end
	local q = BF:Quest(quest)
	if BF:Get("tooltips.breadcrumbs") and q and q[Q.breadcrumbs] then
		line(INDENT .. L["Breadcrumb Quests"] .. L[": "], LIGHT)
		for _, b in ipairs(q[Q.breadcrumbs]) do double(INDENT2 .. title(b), Reward:Text(b)) end
	end
	if BF:Get("tooltips.nextInChain") and q and q[Q.nextInChain] and q[Q.nextInChain] > 0 then
		line(INDENT .. L["Next in chain"] .. L[": "], LIGHT)
		local nextQuest = q[Q.nextInChain]
		double(INDENT2 .. title(nextQuest), Reward:Text(nextQuest))
	end
	if BF:Get("tooltips.ids.quest") then line(INDENT .. "ID: " .. quest, GREY) end
end

local function sourceName(pin)
	if pin.source then return Objectives:SourceName(pin.source) end
	if pin.inside then
		local dungeon = Zones:Dungeon(pin.inside)
		return dungeon and dungeon[1]
	end
end

-- One pin's lines. `seen` stops a quest repeating when several pins at a spot list it.
local function addPin(pin, shift, seen)
	local hasDetail = false
	local givers, objectives, folk = {}, {}, {}
	for _, r in ipairs(pin.roles) do
		if r.role == "objective" then objectives[#objectives + 1] = r
		elseif r.role == "townsfolk" or r.role == "found" then folk[#folk + 1] = r
		else givers[#givers + 1] = r end
		if r.role ~= "objective" and r.role ~= "townsfolk" and r.role ~= "found" then hasDetail = true end
	end

	-- Townsfolk: the NPC (or object), what they are.
	if #folk > 0 and #givers == 0 then
		local name = sourceName(pin) or ""
		line(name, GREEN)
		local row = pin.source and pin.source.type == "npc" and BF:Npc(pin.source.id)
		local sub = row and row[BF.N.subName]
		local kinds = {}
		for _, r in ipairs(folk) do
			local label = r.role == "found" and L["Shown by Advanced Search"] or L[r.kind.label]
			if not seen["f" .. label] then
				seen["f" .. label] = true
				kinds[#kinds + 1] = label
			end
		end
		if sub and sub ~= "" then line("<" .. sub .. ">", LIGHT) end
		if #kinds > 0 and not (sub and #kinds == 1 and sub:find(kinds[1], 1, true)) then line(table.concat(kinds, ", "), DETAIL) end
		if BF:Get("tooltips.ids.npc") and row then line("ID: " .. pin.source.id, GREY) end
	end

	if #givers > 0 then
		local name = sourceName(pin) or ""
		if pin.inside then name = L["Instance"] .. L[": "] .. name end
		if hasDetail and not shift then double(name, "(" .. L["Hold Shift"] .. ")", GREEN, GREY) else line(name, GREEN) end
		for _, r in ipairs(givers) do
			local key = r.role .. r.quest
			if not seen[key] then
				seen[key] = true
				local right = Reward:Text(r.quest)
				if r.role == "complete" then
					right = (right ~= "" and right .. " " or "") .. "(" .. L["Complete"] .. ")"
				elseif r.role == "itemStart" then
					local item = BF:ItemName(r.item)
					if item then line(INDENT .. item, LIGHT) end
				end
				double(plainTitle(r.quest), right)
				questDetail(r.quest, shift)
			end
		end
	end

	for _, r in ipairs(objectives) do
		local key = "o" .. r.quest .. tostring(r.objective and (r.objective.index or r.objective.name))
		if not seen[key] then
			seen[key] = true
			if not seen["t" .. r.quest] then
				seen["t" .. r.quest] = true
				line(" ")
				-- A party member's objective names them instead of "(Active)".
				double(plainTitle(r.quest), "(" .. (r.party or L["Active"]) .. ")", WHITE, YELLOW)
			end
			local rec = r.objective or {}
			local names = {}
			for _, s in ipairs(r.sources or (r.source and { r.source }) or {}) do
				local n = Objectives:SourceName(s)
				if n then
					if s.rate and BF:Get("tooltips.dropRates") then n = ("%s (%.1f%%)"):format(n, s.rate) end
					names[#names + 1] = n
				end
			end
			if pin.inside then
				local dungeon = Zones:Dungeon(pin.inside)
				if dungeon then line(INDENT .. L["Instance"] .. L[": "] .. dungeon[1], DETAIL) end
			end
			for i = 1, math.min(#names, shift and 12 or 3) do line(INDENT .. "|cffdddddd" .. names[i] .. "|r") end
			if #names > (shift and 12 or 3) then line(INDENT .. "|cffdddddd...|r") end
			local text = rec.text or rec.name
			if text and text ~= "" then
				local c = r.quest and BF:Get("icons.colorsMap") and Look:QuestColour(r.quest) or { 1, 0.82, 0 }
				line(INDENT2 .. text, c)
			end
		end
	end
end

--- Shows the tooltip for the pins at one spot. owner: the pin frame.
function PinTooltip:Show(owner, pins, minimap)
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	local shift = IsShiftKeyDown()
	local seen = {}
	local canHide = false
	for i, pin in ipairs(pins) do
		if i > 1 and #pin.roles > 0 then line(" ") end
		addPin(pin, shift, seen)
		for _, r in ipairs(pin.roles) do if r.role == "available" then canHide = true end end
	end
	if canHide then
		line(" ")
		line(L["Shift-click to hide"], GREY)
	end
	tip:Show()
	self.owner, self.pins, self.minimap = owner, pins, minimap
	BF:Send("BF_PIN_ENTER", pins) -- patrol paths highlight the hovered NPCs'
end

function PinTooltip:Hide()
	if tip:GetOwner() == self.owner then tip:Hide() end
	self.owner = nil
	BF:Send("BF_PIN_LEAVE")
end

-- Holding or letting go of Shift while hovering changes the tooltip at once.
BF:On("MODIFIER_STATE_CHANGED", function(_, key)
	if PinTooltip.owner and (key == "LSHIFT" or key == "RSHIFT") and tip:IsShown() then
		PinTooltip:Show(PinTooltip.owner, PinTooltip.pins, PinTooltip.minimap)
	end
end)

-- Clicks ---------------------------------------------------------------------------------------------------------

StaticPopupDialogs["BOOKFINDER_HIDE_QUEST"] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, quests)
		for _, quest in ipairs(quests) do Rules:SetHidden(quest, true) end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function leadQuest(pin)
	local lead = Look:Lead(pin)
	return lead and lead.quest, lead
end

function PinTooltip:Click(pin, button, sourceMap, frame)
	if not pin then return end
	local quest, lead = leadQuest(pin)
	if button ~= "LeftButton" then return end

	-- A chat box open: link the quest.
	local edit = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if edit and quest and BF.Links then
		ChatEdit_InsertLink(BF.Links:Quest(quest))
		return
	end

	if IsShiftKeyDown() then
		-- Every quest offered at this spot (one pin can offer several: each was an icon of its own in Questie).
		local offered, names = {}, {}
		for _, r in ipairs(pin.roles) do
			if r.role == "available" and not offered[r.quest] then
				offered[r.quest] = true
				offered[#offered + 1] = r.quest
				names[#names + 1] = Rules:ColoredTitle(r.quest, nil, true)
			end
		end
		if #offered > 0 then
			local text = L["Are you sure you want to hide the quest '%s'?\nIf this quest isn't actually available, please report it to us!"]
			StaticPopup_Show("BOOKFINDER_HIDE_QUEST", text:format(table.concat(names, "', '")), nil, offered)
			return
		end
	end

	if IsControlKeyDown() then
		local name = sourceName(pin) or (quest and BF:QuestName(quest)) or ""
		BF.Waypoint:Set(pin.map, pin.x, pin.y, name, quest and BF:QuestName(quest), quest)
		return
	end

	-- On the world map, a pin that belongs to another map opens that map.
	if not self.minimap and WorldMapFrame and WorldMapFrame:IsShown() and sourceMap and sourceMap ~= WorldMapFrame:GetMapID() then
		WorldMapFrame:SetMapID(sourceMap)
	end
end
