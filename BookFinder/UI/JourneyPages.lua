-- The Journey tab's pages (Questie's Journey window, image5, as pages of the panel): My Journey, Quests by Zone,
-- Quests by Faction, Advanced Search.

local _, BF = ...
local L = BF.L
local W = BF.Widgets
local Panel = BF.Panel
local Q, N, O, I = BF.Q, BF.N, BF.O, BF.I

-- A list: gold headings (with counts, folding) and rows, pooled. ---------------------------------------------------

local function newList(holder, width, top)
	local list = { rows = {}, heads = {}, used = 0, usedHeads = 0, folded = {} }
	local y = top or 0
	function list:Clear(newTop)
		for _, r in ipairs(self.rows) do r:Hide() end
		for _, h in ipairs(self.heads) do h:Hide() end
		self.used, self.usedHeads = 0, 0
		y = newTop or top or 0
	end
	function list:Heading(text, count, key)
		self.usedHeads = self.usedHeads + 1
		local h = self.heads[self.usedHeads]
		if not h then
			h = CreateFrame("Button", nil, holder)
			h:SetSize(width, 22)
			h.Text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			h.Text:SetPoint("LEFT", 18, 0)
			h.Toggle = h:CreateTexture(nil, "ARTWORK")
			h.Toggle:SetSize(14, 14)
			h.Toggle:SetPoint("LEFT", 0, 0)
			h.Rule = W:Rule(h)
			h.Rule:SetPoint("LEFT", h.Text, "RIGHT", 8, 0)
			h.Rule:SetPoint("RIGHT", -4, 0)
			self.heads[self.usedHeads] = h
		end
		h.Text:SetText(count and ("%s (%d)"):format(text, count) or text)
		local folded = key and self.folded[key]
		if key then
			h.Toggle:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			h.Toggle:Show()
			h:SetScript("OnClick", function()
				self.folded[key] = not self.folded[key]
				if self.onFold then self.onFold() end
			end)
		else
			h.Toggle:Hide()
			h:SetScript("OnClick", nil)
		end
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", 0, -y)
		h:Show()
		y = y + 24
		return not folded
	end
	-- opts: { left = text, right = text, color = {r,g,b}, indent = n, onEnter = fn(row), onClick = fn(row, button) }
	function list:Row(opts)
		self.used = self.used + 1
		local r = self.rows[self.used]
		if not r then
			r = CreateFrame("Button", nil, holder)
			r:SetSize(width, 18)
			r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			r.Left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			r.Left:SetJustifyH("LEFT")
			r.Right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			r.Right:SetPoint("RIGHT", -6, 0)
			local hl = r:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			hl:SetBlendMode("ADD")
			hl:SetAlpha(0.5)
			r:SetScript("OnLeave", function() GameTooltip:Hide() end)
			self.rows[self.used] = r
		end
		r.Left:ClearAllPoints()
		r.Left:SetPoint("LEFT", 6 + (opts.indent or 0) * 16, 0)
		r.Left:SetPoint("RIGHT", r.Right, "LEFT", -8, 0)
		r.Left:SetText(opts.left or "")
		local c = opts.color or { 1, 1, 1 }
		r.Left:SetTextColor(c[1], c[2], c[3])
		r.Right:SetText(opts.right or "")
		r:SetScript("OnEnter", opts.onEnter)
		r:SetScript("OnClick", opts.onClick)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 0, -y)
		r:Show()
		y = y + 18
		return r
	end
	function list:Gap(h) y = y + (h or 8) end
	function list:Height() return y end
	return list
end

local function questRow(list, id, indent, right)
	local rules = BF.Rules
	return list:Row({
		left = rules:ColoredTitle(id, nil, true), right = right, indent = indent,
		onEnter = function(row) BF.QuestTip:Show(row, id) end,
		onClick = function(_, button)
			if IsShiftKeyDown() and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and BF.Links then
				ChatEdit_InsertLink(BF.Links:Quest(id))
			else
				Panel.ShowDetails("quest", id)
			end
		end,
	})
end

-- The seven lists of Questie's Quests by Zone / by Faction.
local CATEGORIES = {
	{ "available", "Available Quests" }, { "breadcrumb", "Breadcrumb Quests" }, { "repeatable", "Repeatable Quests" },
	{ "completed", "Completed Quests" }, { "missing", "Missing Requirement" }, { "unobtainable", "Unobtainable Quests" },
	{ "hidden", "Hidden Quests" },
}
local unobtainable = { race = true, class = true, exclusive = true, expired = true, chain = true, breadcrumb = true,
	maxLevel = true, unknown = true }

local function categorize(id)
	local rules = BF.Rules
	if rules:HiddenByPlayer(id) or rules:HiddenByData(id) == true then return "hidden" end
	local kind = rules:Kind(id)
	if BF.Player:HasCompleted(id) and not kind.repeatable then return "completed" end
	local blocker = rules:Blocker(id)
	if blocker == nil or blocker == "active" then
		if kind.breadcrumb then return "breadcrumb" end
		if kind.repeatable then return "repeatable" end
		return "available"
	end
	if unobtainable[blocker] or blocker == "completed" then return "unobtainable" end
	return "missing"
end

local function showCategories(list, ids)
	local groups = {}
	for _, id in ipairs(ids) do
		local c = categorize(id)
		groups[c] = groups[c] or {}
		table.insert(groups[c], id)
	end
	for _, cat in ipairs(CATEGORIES) do
		local g = groups[cat[1]]
		if g then
			table.sort(g, function(a, b)
				local la, lb = BF.Rules:Level(a), BF.Rules:Level(b)
				if la == lb then return (BF:QuestName(a) or "") < (BF:QuestName(b) or "") end
				return la < lb
			end)
			if list:Heading(L[cat[2]], #g, cat[1]) then
				for _, id in ipairs(g) do
					questRow(list, id, 1, BF.Log:Has(id) and L["In your quest log"] or nil)
				end
			end
			list:Gap(4)
		end
	end
	if not next(groups) then list:Row({ left = L["No quests here."], color = { 0.6, 0.6, 0.6 } }) end
end

-- My Journey -------------------------------------------------------------------------------------------------------

StaticPopupDialogs["BOOKFINDER_JOURNEY_NOTE"] = {
	text = "%s", button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel", hasEditBox = true, editBoxWidth = 260,
	timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox
		local text = box and strtrim(box:GetText() or "") or ""
		if text ~= "" then BF.Journey:AddNote(text, nil) end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		StaticPopupDialogs.BOOKFINDER_JOURNEY_NOTE.OnAccept(parent)
		parent:Hide()
	end,
}
StaticPopupDialogs["BOOKFINDER_JOURNEY_DELETE"] = {
	text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(_, entry) BF.Journey:Remove(entry) end,
}

local KIND_WORDS = {
	accepted = { "Accepted", { 1, 0.82, 0 } }, completed = { "Completed", { 0.3, 1, 0.3 } },
	abandoned = { "Abandoned", { 1, 0.35, 0.3 } }, level = { "Level", { 0.4, 0.7, 1 } }, note = { "Note", { 0.75, 0.6, 1 } },
}

Panel:RegisterPage("journey", "myJourney", function(holder, width)
	local name = UnitName("player") or ""
	local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 2, 0)
	title:SetText(L["%s's Journey"]:format(name))
	local add = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	add:SetSize(130, 22)
	add:SetPoint("TOPRIGHT", -150, 2)
	add:SetText(L["Add a note"])
	add:SetScript("OnClick", function() StaticPopup_Show("BOOKFINDER_JOURNEY_NOTE", L["Write a note for your journey:"]) end)
	local import = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	import:SetSize(140, 22)
	import:SetPoint("LEFT", add, "RIGHT", 8, 0)
	import:SetText(L["Import a journey"])
	import:SetScript("OnClick", function(self)
		local items = {}
		for _, key in ipairs(BF.Journey:Others()) do
			items[#items + 1] = { text = key, onClick = function() BF.Journey:Import(key) end }
		end
		if #items == 0 then items[1] = { text = L["No other character's journey yet"], title = true } end
		BF.Dropdown:Open(self, items)
	end)
	local list = newList(holder, width, 34)
	holder.list = list
	local function fill()
		list:Clear(34)
		local entries = BF.Journey:Entries()
		if #entries == 0 then
			list:Row({ left = L["It's about time you embark on your first Journey!"], color = { 0.7, 0.7, 0.7 } })
			return list:Height()
		end
		local byLevel, levels = {}, {}
		for i = #entries, 1, -1 do
			local e = entries[i]
			if not byLevel[e.level] then
				byLevel[e.level] = {}
				levels[#levels + 1] = e.level
			end
			table.insert(byLevel[e.level], e)
		end
		table.sort(levels, function(a, b) return a > b end)
		for _, level in ipairs(levels) do
			if list:Heading(L["Level %d"]:format(level), nil, "level" .. level) then
				for _, e in ipairs(byLevel[level]) do
					local word = KIND_WORDS[e.kind] or KIND_WORDS.note
					local text
					if e.kind == "level" then text = L["Reached level %d"]:format(e.level)
					elseif e.kind == "note" then text = e.title or ""
					else text = BF.Rules:TitleWithLevel(e.quest, BF:QuestName(e.quest)) end
					list:Row({
						left = ("|cff%02x%02x%02x%s|r  %s"):format(word[2][1] * 255, word[2][2] * 255, word[2][3] * 255, L[word[1]], text),
						right = date("%d %b %Y %H:%M", e.t), indent = 1,
						onEnter = function(row)
							if e.quest then BF.QuestTip:Show(row, e.quest)
							elseif e.kind == "note" then
								GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
								GameTooltip:AddLine(e.title or "", 1, 1, 1, true)
								GameTooltip:AddLine(L["Right-click: delete"], 0.5, 0.5, 0.5)
								GameTooltip:Show()
							end
						end,
						onClick = function(_, button)
							if e.kind == "note" and button == "RightButton" then
								StaticPopup_Show("BOOKFINDER_JOURNEY_DELETE", L["Are you sure you want to delete this note?"], nil, e)
							elseif e.quest then
								Panel.ShowDetails("quest", e.quest)
							end
						end,
					})
				end
			end
		end
		return list:Height()
	end
	list.onFold = function() holder:SetHeight(fill()) Panel:Resize(holder) end
	BF:Listen("BF_JOURNEY_CHANGED", function() if holder:IsVisible() then list.onFold() end end)
	holder.fill = fill
	return fill()
end, function(holder) return holder.fill() end)

-- Quests by Zone ----------------------------------------------------------------------------------------------------

local zoneIndex -- { continents = { name = { {area, name} } }, dungeons, battlegrounds, events, professions, class }
local function buildZoneIndex()
	zoneIndex = { byKey = {} }
	local groups = {}
	local function put(group, key, label, id)
		groups[group] = groups[group] or {}
		local g = groups[group]
		if not g[key] then g[key] = { key = key, label = label, ids = {} } end
		table.insert(g[key].ids, id)
	end
	local sortNames = {}
	for name, v in pairs(BF.Data.sortKeys) do sortNames[v] = name end
	for id in BF:AllIDs("quests") do
		local q = BF:Quest(id)
		local zone = q and q[Q.zoneOrSort]
		if zone and zone > 0 then
			local parent = BF.Data.subZoneToParent[zone] or zone
			local dungeon = BF.Zones:Dungeon(parent)
			if dungeon then
				put("Dungeons", "a" .. parent, dungeon[1], id)
			else
				local map = BF.Zones:UiMapForArea(parent)
				local info = map and C_Map.GetMapInfo(map)
				local continent = info and info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
				local cname = continent and continent.name or L["Other"]
				put(cname, "a" .. parent, BF.Zones:AreaName(parent) or ("Area " .. parent), id)
			end
		elseif zone and zone < 0 then
			local name = sortNames[zone]
			if name then
				local label = name:lower():gsub("_", " "):gsub("^%l", string.upper)
				local group = BF.Events.questEvent[id] and "Events" or (BF.Data.professionKeys[name] and "Professions") or
					(BF.Data.classKeys[name] and "Class") or "Other"
				put(group, "s" .. zone, label, id)
			end
		end
	end
	zoneIndex.groups = {}
	for group, g in pairs(groups) do
		local list = {}
		for _, z in pairs(g) do
			list[#list + 1] = z
			zoneIndex.byKey[z.key] = z
		end
		table.sort(list, function(a, b) return a.label < b.label end)
		zoneIndex.groups[#zoneIndex.groups + 1] = { name = group, zones = list }
	end
	table.sort(zoneIndex.groups, function(a, b) return a.name < b.name end)
end

Panel:RegisterPage("journey", "byZone", function(holder, width)
	if not zoneIndex then buildZoneIndex() end
	local state = BF:CharacterState("journeyPages")
	if not state.zone then
		local here = BF.Zones:AreaForUiMap(C_Map.GetBestMapForUnit("player") or 0)
		state.zone = here and ("a" .. here) or nil
	end
	local pick = W:ChoiceButton(holder, 280)
	pick:SetPoint("TOPLEFT", 0, 0)
	local list = newList(holder, width, 34)
	local function fill()
		list:Clear(34)
		local z = state.zone and zoneIndex.byKey[state.zone]
		pick:SetText(z and z.label or L["Choose a zone..."])
		if z then showCategories(list, z.ids) else list:Row({ left = L["Choose a zone above."], color = { 0.6, 0.6, 0.6 } }) end
		return list:Height()
	end
	pick:SetScript("OnClick", function(self)
		local items = {}
		for _, g in ipairs(zoneIndex.groups) do
			local sub = {}
			for _, z in ipairs(g.zones) do
				sub[#sub + 1] = { text = z.label, radio = true, checked = function() return state.zone == z.key end,
					onClick = function() state.zone = z.key holder:SetHeight(fill()) Panel:Resize(holder) end }
			end
			items[#items + 1] = { text = L[g.name], submenu = sub }
		end
		BF.Dropdown:Open(self, items)
	end)
	list.onFold = function() holder:SetHeight(fill()) Panel:Resize(holder) end
	holder.fill = fill
	return fill()
end, function(holder) return holder.fill() end)

-- Quests by Faction ------------------------------------------------------------------------------------------------

local factionIndex
local function factionName(id)
	local data = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(id)
	if data and data.name then return data.name end
	if GetFactionInfoByID then
		local name = GetFactionInfoByID(id)
		if name then return name end
	end
	return nil
end

Panel:RegisterPage("journey", "byFaction", function(holder, width)
	if not factionIndex then
		factionIndex = {}
		for id in BF:AllIDs("quests") do
			local q = BF:Quest(id)
			for _, pair in ipairs(q and q[Q.reputationReward] or {}) do
				if pair[2] > 0 then
					factionIndex[pair[1]] = factionIndex[pair[1]] or {}
					table.insert(factionIndex[pair[1]], id)
				end
			end
		end
	end
	local state = BF:CharacterState("journeyPages")
	local pick = W:ChoiceButton(holder, 280)
	pick:SetPoint("TOPLEFT", 0, 0)
	local list = newList(holder, width, 34)
	local function fill()
		list:Clear(34)
		local ids = state.faction and factionIndex[state.faction]
		pick:SetText(state.faction and (factionName(state.faction) or ("Faction " .. state.faction)) or L["Choose a faction..."])
		if ids then showCategories(list, ids) else list:Row({ left = L["Choose a faction above."], color = { 0.6, 0.6, 0.6 } }) end
		return list:Height()
	end
	pick:SetScript("OnClick", function(self)
		local factions = {}
		for id in pairs(factionIndex) do
			local name = factionName(id)
			if name then factions[#factions + 1] = { id = id, name = name } end
		end
		table.sort(factions, function(a, b) return a.name < b.name end)
		local items = {}
		for _, f in ipairs(factions) do
			items[#items + 1] = { text = f.name, radio = true, checked = function() return state.faction == f.id end,
				onClick = function() state.faction = f.id holder:SetHeight(fill()) Panel:Resize(holder) end }
		end
		BF.Dropdown:Open(self, items)
	end)
	list.onFold = function() holder:SetHeight(fill()) Panel:Resize(holder) end
	holder.fill = fill
	return fill()
end, function(holder) return holder.fill() end)

-- Advanced Search, with a details view -----------------------------------------------------------------------------

local searchHolder, searchList, searchBox, searchState = nil, nil, nil, { results = nil, details = nil, back = {} }

local function entityName(kind, id)
	if kind == "quest" then return BF:QuestName(id) end
	if kind == "npc" then return BF:NpcName(id) end
	if kind == "object" then return BF:ObjectName(id) end
	if kind == "item" then return BF:ItemName(id) end
end

local function link(list, kind, id, indent, right)
	if kind == "quest" then return questRow(list, id, indent, right) end
	return list:Row({ left = entityName(kind, id) or ("#" .. id), right = right or ("ID " .. id), indent = indent,
		color = { 0.85, 0.85, 1 }, onClick = function() Panel.ShowDetails(kind, id) end })
end

local function spawnZones(spawns)
	local seen, list = {}, {}
	BF.Zones:EachSpawn(spawns, function(map, _, _, inside)
		local name = (inside and BF.Zones:AreaName(inside)) or BF.Zones:MapName(map)
		if name and not seen[name] then seen[name] = true list[#list + 1] = name end
	end)
	table.sort(list)
	return list
end

local function firstSpawn(spawns)
	local spot
	BF.Zones:EachSpawn(spawns, function(map, x, y, inside) if not spot and not inside then spot = { map, x, y } end end)
	return spot
end

local function details(list, kind, id)
	local title = entityName(kind, id) or ("#" .. id)
	list:Heading(title .. "  |cff998866(" .. L[kind] .. " " .. id .. ")|r")
	local actions = {}
	local function line(left, right) list:Row({ left = left, right = right, indent = 1, color = { 0.9, 0.9, 0.9 } }) end
	if kind == "quest" then
		local q = BF:Quest(id) or {}
		line(L["Level"], tostring(BF.Rules:Level(id)))
		line(L["Required level"], tostring(q[Q.requiredLevel] or 1))
		local blocker = BF.Rules:Blocker(id)
		line(L["Doable"], blocker == nil and L["Yes"] or (L["No"] .. " (" .. L[blocker] .. ")"))
		for _, t in ipairs(q[Q.objectivesText] or {}) do list:Row({ left = t, indent = 1, color = { 1, 1, 1 } }) end
		if q[Q.preGroup] then
			list:Heading(L["Requires all of these quests to be finished"])
			for _, p in ipairs(q[Q.preGroup]) do link(list, "quest", p, 1) end
		end
		if q[Q.preSingle] then
			list:Heading(L["Requires one of these quests to be finished"])
			for _, p in ipairs(q[Q.preSingle]) do link(list, "quest", p, 1) end
		end
		list:Heading(L["Started by"])
		for _, n in ipairs(q[Q.startNpcs] or {}) do link(list, "npc", n, 1) end
		for _, o in ipairs(q[Q.startObjects] or {}) do link(list, "object", o, 1) end
		for _, i in ipairs(q[Q.startItems] or {}) do link(list, "item", i, 1) end
		list:Heading(L["Ended by"])
		for _, n in ipairs(q[Q.endNpcs] or {}) do link(list, "npc", n, 1) end
		for _, o in ipairs(q[Q.endObjects] or {}) do link(list, "object", o, 1) end
		for _, rep in ipairs(BF.Reward:ReputationLines(id)) do line(rep) end
		local starter = q[Q.startNpcs] and { "npc", q[Q.startNpcs][1] } or (q[Q.startObjects] and { "object", q[Q.startObjects][1] })
		actions.onMap = { "quest", id }
		if starter then actions.pin = starter end
		actions.hide = id
	elseif kind == "npc" then
		local n = BF:Npc(id) or {}
		if n[N.subName] then line("<" .. n[N.subName] .. ">") end
		line(L["Level"], n[N.minLevel] and (n[N.minLevel] == n[N.maxLevel] and tostring(n[N.minLevel]) or (n[N.minLevel] .. "-" .. n[N.maxLevel])) or "?")
		local friendly = n[N.friendlyTo]
		line(L["Friendly to"], friendly == "AH" and L["Alliance and Horde"] or friendly == "A" and FACTION_ALLIANCE or friendly == "H" and FACTION_HORDE or L["Nobody"])
		if n[N.questStarts] then
			list:Heading(L["Starts the following quests"])
			for _, q in ipairs(n[N.questStarts]) do link(list, "quest", q, 1) end
		end
		if n[N.questEnds] then
			list:Heading(L["Ends the following quests"])
			for _, q in ipairs(n[N.questEnds]) do link(list, "quest", q, 1) end
		end
		list:Heading(L["Found in"])
		local zones = spawnZones(n[N.spawns])
		if #zones == 0 then line(L["No spawn data available."]) end
		for _, z in ipairs(zones) do line(z) end
		actions.onMap = { "npc", id }
		actions.pin = { "npc", id }
	elseif kind == "object" then
		local o = BF:Object(id) or {}
		if o[O.questStarts] then
			list:Heading(L["Starts the following quests"])
			for _, q in ipairs(o[O.questStarts]) do link(list, "quest", q, 1) end
		end
		if o[O.questEnds] then
			list:Heading(L["Ends the following quests"])
			for _, q in ipairs(o[O.questEnds]) do link(list, "quest", q, 1) end
		end
		list:Heading(L["Found in"])
		local zones = spawnZones(o[O.spawns])
		if #zones == 0 then line(L["No spawn data available."]) end
		for _, z in ipairs(zones) do line(z) end
		actions.onMap = { "object", id }
		actions.pin = { "object", id }
	elseif kind == "item" then
		local it = BF:Item(id) or {}
		local drops = BF.Data.drops[id]
		local function group(field, label, kindOf)
			local ids = it[field]
			if ids and #ids > 0 then
				list:Heading(L[label]:format(#ids))
				for _, e in ipairs(ids) do
					link(list, kindOf, e, 1, drops and drops[e] and ("%.1f%%"):format(drops[e]) or nil)
				end
			end
		end
		group(I.npcDrops, "%d NPCs drop this item", "npc")
		group(I.objectDrops, "%d Objects drop this item", "object")
		group(I.vendors, "%d Vendors sell this item", "npc")
		if it[I.startQuest] then
			list:Heading(L["Starts the following quests"])
			link(list, "quest", it[I.startQuest], 1)
		end
	end
	return actions
end

local function fillSearch()
	local list = searchList
	list:Clear(40)
	for _, b in ipairs(searchHolder.actionButtons) do b:Hide() end
	if searchState.details then
		local d = searchState.details
		local actions = details(list, d[1], d[2])
		local x = 0
		local function button(i, text, run)
			local b = searchHolder.actionButtons[i]
			b:SetText(text)
			b:SetScript("OnClick", run)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", x, -(list:Height() + 8))
			b:Show()
			x = x + b:GetWidth() + 8
		end
		button(1, L["Back"], function()
			searchState.details = table.remove(searchState.back)
			searchHolder:SetHeight(fillSearch())
			Panel:Resize(searchHolder)
		end)
		if actions.onMap then
			local on = BF.Search:IsOnMap(actions.onMap[1], actions.onMap[2])
			button(2, on and L["Remove from Map"] or L["Show on Map"], function()
				BF.Search:SetOnMap(actions.onMap[1], actions.onMap[2], not on)
				searchHolder:SetHeight(fillSearch())
			end)
		end
		if actions.pin then
			button(3, L["Map pin"], function()
				local source = { type = actions.pin[1], id = actions.pin[2] }
				local spot = firstSpawn(BF.Objectives:Spawns(source))
				if spot then BF.Waypoint:Set(spot[1], spot[2], spot[3], BF.Objectives:SourceName(source), nil, actions.hide) end
			end)
		end
		if actions.hide then
			local hidden = BF.Rules:HiddenByPlayer(actions.hide)
			button(4, hidden and L["Unhide"] or L["Hide"], function()
				BF.Rules:SetHidden(actions.hide, not hidden)
				searchHolder:SetHeight(fillSearch())
			end)
		end
		return list:Height() + 40
	end
	local r = searchState.results
	if not r then
		list:Row({ left = L["Search for quests, NPCs, objects and items, by name or ID."], color = { 0.7, 0.7, 0.7 } })
		return list:Height()
	end
	local any = false
	for _, spec in ipairs({ { "quests", "Quests", "quest" }, { "npcs", "NPCs", "npc" }, { "objects", "Objects", "object" },
		{ "items", "Items", "item" } }) do
		local ids = r[spec[1]]
		if #ids > 0 then
			any = true
			if list:Heading(L[spec[2]], #ids, spec[1]) then
				for _, id in ipairs(ids) do link(list, spec[3], id, 1) end
			end
		end
	end
	if not any then list:Row({ left = L["Nothing found for \"%s\"."]:format(r.text), color = { 0.7, 0.7, 0.7 } }) end
	return list:Height()
end

--- Opens Advanced Search on an entity's details (from any list, a quest link...).
function Panel.ShowDetails(kind, id)
	if searchState.details then table.insert(searchState.back, searchState.details) end
	searchState.details = { kind, id }
	Panel:Open("journey", "search")
end

Panel:RegisterPage("journey", "search", function(holder, width)
	searchHolder = holder
	local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 2, 0)
	label:SetText(L["Advanced Search (Quests, NPCs, Objects, Items)"])
	searchBox = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
	searchBox:SetSize(width - 140, 20)
	searchBox:SetPoint("TOPLEFT", 8, -14)
	searchBox:SetAutoFocus(false)
	local go = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	go:SetSize(110, 22)
	go:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
	go:SetText(SEARCH or "Search")
	local function run()
		searchState.details, searchState.back = nil, {}
		BF.Search:Run(searchBox:GetText())
		searchBox:ClearFocus()
	end
	go:SetScript("OnClick", run)
	searchBox:SetScript("OnEnterPressed", run)
	searchBox:SetScript("OnEscapePressed", searchBox.ClearFocus)
	holder.actionButtons = {}
	for i = 1, 4 do
		local b = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
		b:SetSize(130, 22)
		b:Hide()
		holder.actionButtons[i] = b
	end
	searchList = newList(holder, width, 40)
	searchList.onFold = function() holder:SetHeight(fillSearch()) Panel:Resize(holder) end
	BF:Listen("BF_SEARCH_DONE", function(_, results)
		searchState.results = results
		holder:SetHeight(fillSearch())
		Panel:Resize(holder)
	end)
	return fillSearch()
end, function() return fillSearch() end)
