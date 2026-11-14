-- Data access: the rows in Data/*.lua are Lua source strings (tools/data/convert.py); a row becomes a table the first
-- time it is asked for and stays cached. Row layouts: tools/data/SCHEMA.md. Field positions are named below so no
-- other file uses a bare number.
--
-- BF.Data.quests[id] etc. hold the source strings; use BF:Quest(id), BF:Npc(id), BF:Object(id), BF:Item(id).

local _, BF = ...

local loadstring = loadstring
local Data = BF.Data

-- Field positions (tools/data/SCHEMA.md) -------------------------------------------------------------------------

BF.Q = {
	name = 1, level = 2, requiredLevel = 3, requiredMaxLevel = 4, races = 5, classes = 6,
	startNpcs = 7, startObjects = 8, startItems = 9, endNpcs = 10, endObjects = 11,
	objectivesText = 12, objectives = 13, trigger = 14, sourceItem = 15,
	preGroup = 16, preSingle = 17, children = 18, groupWith = 19, exclusiveTo = 20, zoneOrSort = 21,
	requiredSkill = 22, requiredMinRep = 23, requiredMaxRep = 24, requiredSourceItems = 25, nextInChain = 26,
	questFlags = 27, specialFlags = 28, parent = 29, reputationReward = 30, breadcrumbFor = 31, breadcrumbs = 32,
	extraObjectives = 33, requiredSpell = 34, requiredSpecialization = 35, availableUntilCompleted = 36,
	availableStartingWith = 37, requiredRanks = 38, disabledBy = 39, xp = 40,
}
-- Objective groups inside BF.Q.objectives
BF.OBJ = { creatures = 1, objects = 2, items = 3, reputation = 4, killCredit = 5, spell = 6 }

BF.N = {
	name = 1, minLevel = 2, maxLevel = 3, rank = 4, spawns = 5, waypoints = 6, zone = 7, questStarts = 8,
	questEnds = 9, faction = 10, friendlyTo = 11, subName = 12, flags = 13,
}
BF.O = { name = 1, questStarts = 2, questEnds = 3, spawns = 4, zone = 5, faction = 6, waypoints = 7 }
BF.I = {
	name = 1, npcDrops = 2, objectDrops = 3, itemDrops = 4, startQuest = 5, questRewards = 6, flags = 7,
	foodType = 8, itemLevel = 9, requiredLevel = 10, ammoType = 11, class = 12, subClass = 13, vendors = 14,
	relatedQuests = 15, teachesSpell = 16,
}

-- Rows ----------------------------------------------------------------------------------------------------------

local caches = { quests = {}, npcs = {}, objects = {}, items = {} }
local sources = {} -- [kind] = source table after overrides (set at login)

local function decode(kind, id)
	local src = (sources[kind] or Data[kind])[id]
	if not src then return nil end
	local chunk, err = loadstring("return " .. src)
	if not chunk then
		geterrorhandler()(("BookFinder: bad %s row %s: %s"):format(kind, tostring(id), tostring(err)))
		return nil
	end
	return chunk()
end

-- Rows switched in at run time, whole (tables), by a named layer: the Darkmoon Faire's NPCs where the faire is now.
local runtime = { quests = {}, npcs = {}, objects = {}, items = {} } -- [kind][layer] = { [id] = row }

local function getter(kind)
	local cache = caches[kind]
	local layers = runtime[kind]
	return function(_, id)
		if not id then return nil end
		for _, rows in pairs(layers) do
			local row = rows[id]
			if row then return row end
		end
		local row = cache[id]
		if row == nil then
			row = decode(kind, id) or false
			cache[id] = row
		end
		return row or nil
	end
end

--- Puts whole rows over the data's rows of one kind under a layer name; nil takes that layer away.
function BF:SetRuntimeRows(kind, layer, rows)
	runtime[kind][layer] = rows
end

function BF:SetNpcRows(layer, rows)
	BF:SetRuntimeRows("npcs", layer, rows)
end

BF.Quest = getter("quests")
BF.Npc = getter("npcs")
BF.Object = getter("objects")
BF.Item = getter("items")

--- Every ID of a kind ("quests", "npcs", "objects", "items"), as an iterator over (id, sourceString).
function BF:AllIDs(kind)
	return pairs(sources[kind] or Data[kind])
end

-- Faction and class rows (QuestieDB's dynamic corrections, layered by the converter) -------------------------------
--
-- At login each kind that has override rows gets its own source table: the base table's strings with the faction's
-- rows over them, then the faction-and-class rows over those. Only references to strings are copied.

local function applyOverrides()
	local override = Data.override
	if not override then return end
	local faction = UnitFactionGroup("player")
	local _, class = UnitClass("player")
	local factionRows = faction and rawget(override, faction)
	local classRows = faction and class and rawget(override, faction .. "/" .. class)
	for kind in pairs(caches) do
		local f = factionRows and rawget(factionRows, kind)
		local c = classRows and rawget(classRows, kind)
		if f or c then
			local merged = {}
			for id, s in pairs(Data[kind]) do merged[id] = s end
			if f then for id, s in pairs(f) do merged[id] = s end end
			if c then for id, s in pairs(c) do merged[id] = s end end
			sources[kind] = merged
			wipe(caches[kind])
		end
	end
end

BF:At("login", applyOverrides, 1)

-- Convenience readers ----------------------------------------------------------------------------------------------

function BF:QuestName(id)
	local q = BF:Quest(id)
	return q and q[BF.Q.name]
end

function BF:NpcName(id)
	local n = BF:Npc(id)
	return n and n[BF.N.name]
end

function BF:ObjectName(id)
	local o = BF:Object(id)
	return o and o[BF.O.name]
end

function BF:ItemName(id)
	local i = BF:Item(id)
	return i and i[BF.I.name]
end
