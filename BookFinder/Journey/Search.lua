-- Advanced Search: every quest, NPC, object and item in the data, found by name or ID; each result opens its details;
-- NPCs and objects (and a quest's givers and turn-ins) can be put on the map until taken off (docs/study/questie.md,
-- "Advanced Search"). The Journey tab's last page. Quests by Zone, by Faction and My Journey open their quests here.

local _, BF = ...
local L = BF.L

local Search = {}
BF.Search = Search

local Q, N, O, I = BF.Q, BF.N, BF.O, BF.I
local Rules, Zones, Player = BF.Rules, BF.Zones, BF.Player

local KINDS = {
	{ key = "quests", label = "Quests", row = function(id) return BF:Quest(id) end },
	{ key = "npcs", label = "NPCs", row = function(id) return BF:Npc(id) end },
	{ key = "objects", label = "Objects", row = function(id) return BF:Object(id) end },
	{ key = "items", label = "Items", row = function(id) return BF:Item(id) end },
}
local SHOWN_PER_KIND = 50

-- The name index: built the first time a search runs (the rows' names read from their source text, no decoding).

local names -- [kind] = { {id, name, lower}, ... }

local function buildIndex()
	names = {}
	for _, k in ipairs(KINDS) do
		local list = {}
		for id, src in BF:AllIDs(k.key) do
			local name = type(src) == "string" and src:match('^{"(.-)",') or (type(src) == "table" and src[1])
			if name then
				name = name:gsub('\\"', '"')
				list[#list + 1] = { id, name, name:lower() }
			end
		end
		table.sort(list, function(a, b) return a[2] < b[2] end)
		names[k.key] = list
	end
end

--- Results for a text: { [kind] = { {id, name}, ... }, counts = { [kind] = n } } (a number also matches IDs).
function Search:Find(text)
	if not names then buildIndex() end
	text = strtrim(text or "")
	local out, counts = {}, {}
	if text == "" then return out, counts end
	local needle, asID = text:lower(), tonumber(text)
	for _, k in ipairs(KINDS) do
		local found, n = {}, 0
		if asID and k.row(asID) then
			n = 1
			found[1] = { asID, BF[({ quests = "QuestName", npcs = "NpcName", objects = "ObjectName", items = "ItemName" })[k.key]](BF, asID) }
		end
		for _, e in ipairs(names[k.key]) do
			if e[3]:find(needle, 1, true) and e[1] ~= asID then
				n = n + 1
				if #found < SHOWN_PER_KIND then found[#found + 1] = { e[1], e[2] } end
			end
		end
		out[k.key], counts[k.key] = found, n
	end
	return out, counts
end

-- On the map (the "found" layer) -------------------------------------------------------------------------------------

local function shown() return BF:CharacterState("search") end

--- Whether a source ({type, id}) is on the map.
function Search:IsShown(type_, id)
	local s = shown()
	return s.map ~= nil and s.map[type_ .. ":" .. id] == true
end

function Search:SetShown(type_, id, on)
	local s = shown()
	s.map = s.map or {}
	s.map[type_ .. ":" .. id] = on and true or nil
	BF.Marks:RebuildLayer("found")
end

--- A quest on the map: its givers and the NPCs and objects it is handed in to.
function Search:QuestSources(id)
	local q = BF:Quest(id)
	local list = {}
	if not q then return list end
	for _, n in ipairs(q[Q.startNpcs] or {}) do list[#list + 1] = { "npc", n } end
	for _, o in ipairs(q[Q.startObjects] or {}) do list[#list + 1] = { "object", o } end
	for _, n in ipairs(q[Q.endNpcs] or {}) do list[#list + 1] = { "npc", n } end
	for _, o in ipairs(q[Q.endObjects] or {}) do list[#list + 1] = { "object", o } end
	return list
end

function Search:ClearMap()
	shown().map = nil
	BF.Marks:RebuildLayer("found")
end

BF.Marks:RegisterLayer("found", function(add)
	for key in pairs(shown().map or {}) do
		local type_, id = key:match("^(%a+):(%d+)$")
		id = tonumber(id)
		if type_ and id then
			local source = { type = type_, id = id }
			local spawns = BF.Objectives:Spawns(source)
			Zones:EachSpawn(spawns, function(map, x, y, inside)
				if not inside then add(map, x, y, BF.Marks.SpotKey(source, map, x, y), { role = "found", source = source }, source) end
			end)
		end
	end
end)

--- The map pin to the nearest spawn of an NPC or object.
function Search:Pin(type_, id)
	local best, bestD
	Zones:EachSpawn(BF.Objectives:Spawns({ type = type_, id = id }), function(map, x, y, inside)
		if inside then return end
		local d = Zones:DistanceTo(map, x, y) or math.huge
		if not bestD or d < bestD then best, bestD = { map, x, y }, d end
	end)
	if not best then
		BF:Print(L["No place on the map for %s."], BF.Objectives:SourceName({ type = type_, id = id }) or id)
		return
	end
	BF.Waypoint:Set(best[1], best[2], best[3], BF.Objectives:SourceName({ type = type_, id = id }))
end

-- The page -----------------------------------------------------------------------------------------------------------

local page -- { rows, width, box, detail = {kind, id} | nil }

local function spawnLines(rows, spawns)
	local byZone = {}
	for area, points in pairs(spawns or {}) do
		local name = Zones:AreaName(area) or ("Area " .. area)
		byZone[name] = (byZone[name] or 0) + #points
	end
	local zones = {}
	for name, n in pairs(byZone) do zones[#zones + 1] = { name, n } end
	table.sort(zones, function(a, b) return a[1] < b[1] end)
	if #zones == 0 then rows:Line(L["No spawn data available."], { hint = true }) end
	for _, z in ipairs(zones) do rows:Line(z[1], { right = z[2] > 1 and ("x" .. z[2]) or "", small = true }) end
end

local render

local function questLines(rows, label, ids)
	if not ids or #ids == 0 then return end
	rows:Line(label, { colour = { 1, 0.82, 0 } })
	for _, q in ipairs(ids) do
		rows:Line(Rules:ColoredTitle(q, nil, true) .. "  |cff888888(" .. q .. ")|r", { indent = 20, small = true,
			onClick = function() Search:ShowQuest(q) end })
	end
end

local function sourceLines(rows, label, list, type_)
	if not list or #list == 0 then return end
	rows:Line(label, { colour = { 1, 0.82, 0 } })
	for _, id in ipairs(list) do
		local name = BF.Objectives:SourceName({ type = type_, id = id }) or "?"
		rows:Line(name .. "  |cff888888(" .. id .. ")|r", { indent = 20, small = true,
			onClick = function() Search:Show(type_ == "npc" and "npcs" or "objects", id) end })
	end
end

local function mapButtons(rows, sources)
	local any = false
	for _, s in ipairs(sources) do if Search:IsShown(s[1], s[2]) then any = true end end
	rows:Buttons({
		{ any and "Remove from Map" or "Show on Map", function()
			for _, s in ipairs(sources) do Search:SetShown(s[1], s[2], not any) end
			render()
		end, 140 },
		{ "Set the map pin", function() if sources[1] then Search:Pin(sources[1][1], sources[1][2]) end end, 140 },
	})
end

-- Why a quest cannot be taken now, in the player's words (Rules:Blocker's keys).
Search.REASONS = {
	unknown = "Not in the data", active = "In your quest log", completed = "Already done", event = "Its holiday is not on",
	hidden = "Not available on this realm", race = "Not for your race", class = "Not for your class",
	level = "Your level is too low", maxLevel = "Your level is too high", prerequisite = "A quest before it is not done",
	parent = "Needs its main quest in your log", expired = "No longer available", disabled = "Another quest in your log stops it",
	breadcrumb = "Its quest is already taken", chain = "A later quest of its chain is taken", exclusive = "You took another quest instead",
	skill = "Needs a profession", reputation = "Needs reputation", spell = "Needs a spell", specialization = "Needs a specialization",
}

local function questDetail(rows, id)
	local q = BF:Quest(id)
	rows:Heading(nil, Rules:ColoredTitle(id, nil, true))
	if not q then rows:Line(L["Not in the data."], { hint = true }) return end
	rows:Line(L["Quest ID"] .. L[": "] .. id, { small = true })
	rows:Line(L["Level"] .. L[": "] .. Rules:Level(id) .. "    " .. L["Required level"] .. L[": "] .. (q[Q.requiredLevel] or 1), { small = true })
	local k = Rules:Kind(id)
	local kinds = {}
	for _, w in ipairs({ "repeatable", "daily", "weekly", "monthly", "event", "pvp", "dungeon", "raid", "breadcrumb" }) do
		if k[w] then kinds[#kinds + 1] = L[w:sub(1, 1):upper() .. w:sub(2)] end
	end
	if #kinds > 0 then rows:Line(table.concat(kinds, ", "), { small = true }) end
	if q[Q.requiredSkill] then
		rows:Line(L["Profession"] .. L[": "] .. (Player:SkillName(q[Q.requiredSkill][1]) or "?") .. " " .. (q[Q.requiredSkill][2] or ""), { small = true })
	end
	for _, rep in ipairs(BF.Reward:ReputationLines(id)) do rows:Line(rep, { small = true, colour = { 0.4, 0.6, 1 } }) end
	local blocker = Rules:Blocker(id)
	if Player:HasCompleted(id) then rows:Line(L["You have completed this quest"], { colour = { 0.2, 1, 0.2 } })
	elseif BF.Log:Has(id) then rows:Line(L["You are on this quest"], { colour = { 1, 0.82, 0 } })
	elseif blocker == nil then rows:Line(L["Doable"], { colour = { 0.2, 1, 0.2 } })
	else rows:Line(L["Not doable now"] .. L[": "] .. L[Search.REASONS[blocker] or blocker], { hint = true }) end
	if q[Q.objectivesText] then
		for _, t in ipairs(q[Q.objectivesText]) do rows:Line(t, { small = true, hint = true }) end
	end
	questLines(rows, L["Requires all of these quests to be finished"], q[Q.preGroup])
	questLines(rows, L["Requires one of these quests to be finished"], q[Q.preSingle])
	sourceLines(rows, L["Started by"], q[Q.startNpcs], "npc")
	sourceLines(rows, L["Started by"], q[Q.startObjects], "object")
	sourceLines(rows, L["Ended by"], q[Q.endNpcs], "npc")
	sourceLines(rows, L["Ended by"], q[Q.endObjects], "object")
	rows:Gap()
	local hidden = Rules:HiddenByPlayer(id)
	if hidden then rows:Line(L["Hidden by you"], { hint = true }) end
	mapButtons(rows, Search:QuestSources(id))
	rows:Buttons({ { hidden and "Show this quest" or "Hide this quest", function()
		Rules:SetHidden(id, not hidden)
		render()
	end, 140 } })
end

local function npcDetail(rows, id)
	local n = BF:Npc(id)
	rows:Heading(nil, BF:NpcName(id) or ("NPC " .. id))
	if not n then rows:Line(L["Not in the data."], { hint = true }) return end
	rows:Line(L["NPC ID"] .. L[": "] .. id, { small = true })
	if n[N.subName] then rows:Line("<" .. n[N.subName] .. ">", { small = true }) end
	local lv = n[N.minLevel] == n[N.maxLevel] and tostring(n[N.minLevel]) or ((n[N.minLevel] or "?") .. "-" .. (n[N.maxLevel] or "?"))
	rows:Line(L["Level"] .. L[": "] .. lv, { small = true })
	local friendly = n[N.friendlyTo]
	rows:Line(L["Friendly to"] .. L[": "] .. (friendly == "AH" and L["Alliance and Horde"] or friendly == "A" and L["Alliance"]
		or friendly == "H" and L["Horde"] or L["Nobody"]), { small = true })
	questLines(rows, L["Starts"], n[N.questStarts])
	questLines(rows, L["Ends"], n[N.questEnds])
	rows:Line(L["Where"], { colour = { 1, 0.82, 0 } })
	spawnLines(rows, n[N.spawns])
	rows:Gap()
	mapButtons(rows, { { "npc", id } })
end

local function objectDetail(rows, id)
	local o = BF:Object(id)
	rows:Heading(nil, BF:ObjectName(id) or ("Object " .. id))
	if not o then rows:Line(L["Not in the data."], { hint = true }) return end
	rows:Line(L["Object ID"] .. L[": "] .. id, { small = true })
	questLines(rows, L["Starts"], o[O.questStarts])
	questLines(rows, L["Ends"], o[O.questEnds])
	rows:Line(L["Where"], { colour = { 1, 0.82, 0 } })
	spawnLines(rows, o[O.spawns])
	rows:Gap()
	mapButtons(rows, { { "object", id } })
end

local function itemDetail(rows, id)
	local it = BF:Item(id)
	rows:Heading(nil, BF:ItemName(id) or ("Item " .. id))
	if not it then rows:Line(L["Not in the data."], { hint = true }) return end
	rows:Line(L["Item ID"] .. L[": "] .. id, { small = true, onEnter = function(row)
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(id)
		GameTooltip:Show()
	end })
	local function list(label, ids, type_)
		if not ids or #ids == 0 then return end
		sourceLines(rows, label:format(#ids), ids, type_)
	end
	list(L["%d NPCs drop this item"], it[I.npcDrops], "npc")
	list(L["%d Objects drop this item"], it[I.objectDrops], "object")
	list(L["%d Vendors sell this item"], it[I.vendors], "npc")
	if it[I.startQuest] then questLines(rows, L["Starts"], { it[I.startQuest] }) end
end

local DETAILS = { quests = questDetail, npcs = npcDetail, objects = objectDetail, items = itemDetail }

render = function()
	if not page then return 0 end
	local rows = page.rows
	rows:Begin(page.width, 34)
	if page.detail then
		rows:Buttons({ { "Back to the results", function() page.detail = nil render() end, 160 } }, 0)
		DETAILS[page.detail[1]](rows, page.detail[2])
		return rows:Finish()
	end
	local text = page.box:GetText()
	if strtrim(text or "") == "" then
		rows:Line(L["Search quests, NPCs, objects and items by name or ID."], { hint = true })
		local any = next(shown().map or {}) ~= nil
		if any then rows:Buttons({ { "Clear the map", function() Search:ClearMap() render() end, 140 } }) end
		return rows:Finish()
	end
	local results, counts = Search:Find(text)
	for _, k in ipairs(KINDS) do
		local list = results[k.key]
		if #list > 0 and not rows:Heading(k.key, L[k.label], counts[k.key]) then
			for _, e in ipairs(list) do
				local label = k.key == "quests" and Rules:ColoredTitle(e[1], nil, true) or (e[2] or "?")
				rows:Line(label .. "  |cff888888(" .. e[1] .. ")|r", { small = true,
					onClick = function() Search:Show(k.key, e[1]) end })
			end
			if counts[k.key] > #list then rows:Line(L["... and %d more"]:format(counts[k.key] - #list), { hint = true }) end
		end
	end
	if not next(results) or (counts.quests + counts.npcs + counts.objects + counts.items) == 0 then
		rows:Line(L["Nothing found."], { hint = true })
	end
	return rows:Finish()
end

--- Shows a quest, NPC, object or item's details on the Advanced Search page (and opens the panel there).
function Search:Show(kind, id)
	if page then page.detail = { kind, id } end
	Search.pending = { kind, id }
	BF.Panel:Show("journey", "search")
	if page then
		page.detail = { kind, id }
		render()
	end
end

function Search:ShowQuest(id) Search:Show("quests", id) end

--- Opens Advanced Search with words in its box (/bf search).
function Search:Query(text)
	BF.Panel:Show("journey", "search")
	if page then
		page.detail = nil
		page.box:SetText(text or "")
		render()
	end
end

BF:At("login", function()
	BF.Panel:AddPage("journey", { key = "search", label = "Advanced Search", build = function(content, width)
		local box = CreateFrame("EditBox", nil, content, BF.Widgets:Template({ "SearchBoxTemplate", "InputBoxTemplate" }))
		box:SetSize(260, 20)
		box:SetPoint("TOPLEFT", 6, -4)
		box:SetAutoFocus(false)
		page = { rows = BF.Rows:New(content, BF:CharacterState("searchFolded")), width = width, box = box }
		page.rows.onFold = render
		local soon = BF:Debounce(0.25, function()
			page.detail = nil
			render()
		end)
		box:HookScript("OnTextChanged", soon)
		if Search.pending then page.detail = Search.pending end
		return render()
	end })
	BF:Listen("BF_QUEST_HIDDEN_CHANGED", function() if page and page.detail then render() end end)
end, 92)
