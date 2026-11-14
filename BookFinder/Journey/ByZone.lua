-- Quests by Zone and Quests by Faction: every quest of a zone (or a dungeon, battleground, class, profession or
-- holiday), or of a reputation, sorted into Available, Breadcrumb, Repeatable, Completed, Missing Requirement,
-- Unobtainable and Hidden (docs/study/questie.md, "Journey window"). Each quest opens its details (Advanced Search).

local _, BF = ...
local L = BF.L

local ByZone = {}
BF.QuestsByZone = ByZone

local Q = BF.Q
local Rules, Zones, Player, Log = BF.Rules, BF.Zones, BF.Player, BF.Log
local Data = BF.Data

-- The index (built the first time either page opens) -------------------------------------------------------------

ByZone.CATEGORIES = { "Zones", "Dungeons", "Battlegrounds", "Classes", "Professions", "Events", "Other" }

local CLASS_SORTS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK" }
local PROFESSION_SORTS = { "ALCHEMY", "BLACKSMITHING", "COOKING", "ENGINEERING", "FIRST_AID", "FISHING", "HERBALISM",
	"LEATHERWORKING", "TAILORING", "INSCRIPTION", "JEWELCRAFTING", "ARCHAEOLOGY", "RIDING" }
local EVENT_SORTS = { "SEASONAL", "LUNAR_FESTIVAL", "LOVE_IS_IN_THE_AIR", "NOBLEGARDEN", "CHILDRENS_WEEK", "MIDSUMMER",
	"BREWFEST", "HALLOWS_END", "HARVEST_FESTIVAL", "PILGRIMS_BOUNTY", "DAY_OF_THE_DEAD", "WINTER_VEIL", "DARKMOON_FAIRE" }

local index -- { [category] = { [key] = { name =, quests = {ids} } } }
local factions -- { [factionID] = { quests } }

local function title(words) -- "LUNAR_FESTIVAL" -> "Lunar Festival"
	return (words:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local function build()
	index, factions = {}, {}
	for _, c in ipairs(ByZone.CATEGORIES) do index[c] = {} end
	local sortCategory, sortName = {}, {}
	for name, value in pairs(Data.sortKeys) do sortCategory[value], sortName[value] = "Other", title(name) end
	for _, n in ipairs(CLASS_SORTS) do if Data.sortKeys[n] then sortCategory[Data.sortKeys[n]] = "Classes" end end
	for _, n in ipairs(PROFESSION_SORTS) do if Data.sortKeys[n] then sortCategory[Data.sortKeys[n]] = "Professions" end end
	for _, n in ipairs(EVENT_SORTS) do if Data.sortKeys[n] then sortCategory[Data.sortKeys[n]] = "Events" end end
	if Data.sortKeys.BATTLEGROUNDS then sortCategory[Data.sortKeys.BATTLEGROUNDS] = "Battlegrounds" end
	local function put(category, key, name, id)
		local g = index[category][key]
		if not g then
			g = { name = name, quests = {} }
			index[category][key] = g
		end
		g.quests[#g.quests + 1] = id
	end
	for id in BF:AllIDs("quests") do
		local q = BF:Quest(id)
		local zone = q and q[Q.zoneOrSort]
		if zone and zone > 0 then
			local dungeon, dungeonID = Zones:Dungeon(zone)
			if dungeon then
				put("Dungeons", dungeonID, dungeon[1], id)
			elseif Rules:Kind(id).pvp then
				put("Battlegrounds", zone, Zones:AreaName(zone) or ("Area " .. zone), id)
			else
				local map = Zones:UiMapForArea(zone)
				local key = map or ("a" .. zone)
				put("Zones", key, (map and Zones:MapName(map)) or Zones:AreaName(zone) or ("Area " .. zone), id)
			end
		elseif zone and zone < 0 then
			put(sortCategory[zone] or "Other", zone, sortName[zone] or ("Category " .. zone), id)
		end
		for _, rep in ipairs(q and q[Q.reputationReward] or {}) do
			if rep[2] and rep[2] > 0 then
				factions[rep[1]] = factions[rep[1]] or {}
				table.insert(factions[rep[1]], id)
			end
		end
	end
end

local function ensure() if not index then build() end end

--- The groups of a category, sorted by name: { {key, name, count}, ... }.
function ByZone:Groups(category)
	ensure()
	local list = {}
	for key, g in pairs(index[category] or {}) do list[#list + 1] = { key, g.name, #g.quests } end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	return list
end

function ByZone:QuestsOf(category, key)
	ensure()
	local g = index[category] and index[category][key]
	return g and g.quests or {}
end

local factionNames = {}
local function factionName(id)
	if factionNames[id] then return factionNames[id] end
	local name = GetFactionInfoByID and GetFactionInfoByID(id)
	if not name then
		for words, value in pairs(Data.factionIDs or {}) do if value == id then name = title(words) end end
	end
	factionNames[id] = name or ("Faction " .. id)
	return factionNames[id]
end

function ByZone:Factions()
	ensure()
	local list = {}
	for id, quests in pairs(factions) do list[#list + 1] = { id, factionName(id), #quests } end
	table.sort(list, function(a, b) return a[2] < b[2] end)
	return list
end

function ByZone:QuestsOfFaction(id)
	ensure()
	return factions[id] or {}
end

-- Sorting quests into the lists --------------------------------------------------------------------------------

ByZone.LISTS = { "Available Quests", "Breadcrumb Quests", "Repeatable Quests", "Completed Quests",
	"Missing Requirement", "Unobtainable Quests", "Hidden Quests" }

--- Which list a quest belongs in.
function ByZone:ListOf(id)
	if Rules:HiddenByPlayer(id) then return "Hidden Quests" end
	local kind = Rules:Kind(id)
	if Player:HasCompleted(id) and not kind.repeatable then return "Completed Quests" end
	local blocker = Rules:Blocker(id)
	if blocker == "hidden" or blocker == "race" or blocker == "class" or blocker == "unknown" or blocker == "expired" then
		return "Unobtainable Quests"
	end
	if blocker and blocker ~= "active" then return "Missing Requirement", blocker end
	if kind.breadcrumb then return "Breadcrumb Quests" end
	if kind.repeatable then return "Repeatable Quests" end
	return "Available Quests"
end

function ByZone:Sort(ids)
	local lists = {}
	for _, name in ipairs(ByZone.LISTS) do lists[name] = {} end
	for _, id in ipairs(ids) do
		local name, why = ByZone:ListOf(id)
		table.insert(lists[name], { id = id, why = why })
	end
	for _, list in pairs(lists) do
		table.sort(list, function(a, b)
			local la, lb = Rules:Level(a.id), Rules:Level(b.id)
			if la ~= lb then return la < lb end
			return a.id < b.id
		end)
	end
	return lists
end

-- Pages ------------------------------------------------------------------------------------------------------------

local function renderLists(rows, ids)
	local lists = ByZone:Sort(ids)
	local any = false
	for _, name in ipairs(ByZone.LISTS) do
		local list = lists[name]
		if #list > 0 then
			any = true
			if not rows:Heading(name, L[name], #list) then
				for _, e in ipairs(list) do
					local text = Rules:ColoredTitle(e.id, nil, true)
					if Log:Has(e.id) then text = text .. " |cffffd100(" .. L["Active"] .. ")|r" end
					rows:Line(text, { small = true, indent = 16,
						right = e.why and ("|cff888888" .. L[BF.Search.REASONS[e.why] or e.why] .. "|r") or nil,
						onClick = function() BF.Search:ShowQuest(e.id) end })
				end
			end
		end
	end
	if not any then rows:Line(L["No quests here."], { hint = true }) end
end

-- A dropdown face (a game button) that opens the one dropdown with choices.
local function chooser(content, x, w, label, items)
	local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetPoint("TOPLEFT", x, -4)
	b:SetScript("OnClick", function(self) BF.Dropdown:Toggle(self, items) end)
	function b:Show_(text) self:SetText(text or label) end
	return b
end

local function currentZoneKey()
	local map = C_Map.GetBestMapForUnit("player")
	return map
end

local zonePage
local function renderZone()
	local p = zonePage
	if not p then return 0 end
	local s = p.state
	s.category = s.category or "Zones"
	if s.key == nil and s.category == "Zones" then s.key = currentZoneKey() end
	local groups = ByZone:Groups(s.category)
	local name
	for _, g in ipairs(groups) do if g[1] == s.key then name = g[2] end end
	p.category:Show_(L[s.category])
	p.zone:Show_(name or L["Choose a zone"])
	p.rows:Begin(p.width, 34)
	if name then renderLists(p.rows, ByZone:QuestsOf(s.category, s.key)) else
		p.rows:Line(L["Choose a zone above."], { hint = true })
	end
	return p.rows:Finish()
end

local factionPage
local function renderFaction()
	local p = factionPage
	if not p then return 0 end
	local s = p.state
	local name
	for _, f in ipairs(ByZone:Factions()) do if f[1] == s.faction then name = f[2] end end
	p.faction:Show_(name or L["Choose a faction"])
	p.rows:Begin(p.width, 34)
	if name then renderLists(p.rows, ByZone:QuestsOfFaction(s.faction)) else
		p.rows:Line(L["Choose a faction above."], { hint = true })
	end
	return p.rows:Finish()
end

BF:At("login", function()
	BF.Panel:AddPage("journey", { key = "byZone", label = "Quests by Zone", build = function(content, width)
		local state = BF:CharacterState("byZone")
		zonePage = { state = state, width = width, rows = BF.Rows:New(content, BF:CharacterState("byZoneFolded")) }
		zonePage.rows.onFold = renderZone
		zonePage.category = chooser(content, 6, 150, L["Zones"], function()
			local items = {}
			for _, c in ipairs(ByZone.CATEGORIES) do
				if #ByZone:Groups(c) > 0 then
					items[#items + 1] = { text = L[c], radio = true, checked = function() return state.category == c end,
						func = function() state.category, state.key = c, nil renderZone() end }
				end
			end
			return items
		end)
		zonePage.zone = chooser(content, 162, 240, L["Choose a zone"], function()
			local items = {}
			for _, g in ipairs(ByZone:Groups(state.category or "Zones")) do
				items[#items + 1] = { text = ("%s  |cff888888(%d)|r"):format(g[2], g[3]), radio = true,
					checked = function() return state.key == g[1] end,
					func = function() state.key = g[1] renderZone() end }
			end
			return items
		end)
		return renderZone()
	end }, 2)
	BF.Panel:AddPage("journey", { key = "byFaction", label = "Quests by Faction", build = function(content, width)
		local state = BF:CharacterState("byFaction")
		factionPage = { state = state, width = width, rows = BF.Rows:New(content, BF:CharacterState("byFactionFolded")) }
		factionPage.rows.onFold = renderFaction
		factionPage.faction = chooser(content, 6, 260, L["Choose a faction"], function()
			local items = {}
			for _, f in ipairs(ByZone:Factions()) do
				items[#items + 1] = { text = ("%s  |cff888888(%d)|r"):format(f[2], f[3]), radio = true,
					checked = function() return state.faction == f[1] end,
					func = function() state.faction = f[1] renderFaction() end }
			end
			return items
		end)
		return renderFaction()
	end }, 3)
	local soon = BF:Debounce(0.3, function() renderZone() renderFaction() end)
	for _, m in ipairs({ "BF_QUEST_LOG_CHANGED", "BF_COMPLETED_CHANGED", "BF_QUEST_HIDDEN_CHANGED", "BF_LEVEL_CHANGED" }) do
		BF:Listen(m, soon)
	end
end, 91)
