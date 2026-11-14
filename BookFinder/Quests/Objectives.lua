-- Objectives: what each objective of a quest in the log asks for, and where that is.
--
-- BF.Objectives:For(questID) pairs the quest log's objectives (text, type, progress) with the data's objective
-- groups (creatures, objects, items, reputation, kill credit, spell, trigger), in the quest's order, and gives each
-- one its sources: { {type = "npc"/"object", id =, rate = drop %?, via = item/vendor/container, name =}, ... } plus
-- trigger areas. The map turns sources into icons; tooltips and the quest list read the same pairing.

local _, BF = ...

local Objectives = {}
BF.Objectives = Objectives

local Q, OBJ, N, O, I = BF.Q, BF.OBJ, BF.N, BF.O, BF.I
local Data = BF.Data

-- The icon each objective kind draws (Map/Icons.lua resolves these to the game's art).
Objectives.SLAY, Objectives.LOOT, Objectives.OBJECT, Objectives.EVENT, Objectives.TALK, Objectives.INTERACT =
	"slay", "loot", "object", "event", "talk", "interact"

-- Data objective records in the order the quest log lists them --------------------------------------------------

local function dataObjectives(questID)
	local q = BF:Quest(questID)
	local list = {}
	if not q then return list end
	local groups = q[Q.objectives] or {}
	local function add(kind, entries)
		if not entries then return end
		for _, e in ipairs(entries) do list[#list + 1] = { kind = kind, entry = e } end
	end
	local first = Data.objectiveFirst or {}
	local function flag(name) return first[name] and first[name][questID] end
	-- The game lists creature objectives first, then objects, items, kill credit, spells. A few quests list one kind
	-- ahead of the others (the data's hints).
	local order = { "creature", "object", "item", "killCredit", "spell" }
	local function front(name)
		for i, n in ipairs(order) do
			if n == name then table.remove(order, i) break end
		end
		table.insert(order, 1, name)
	end
	if flag("spellObjectiveFirst") then front("spell") end
	if flag("killCreditObjectiveFirst") then front("killCredit") end
	if flag("objectObjectiveFirst") then front("object") end
	if flag("itemObjectiveFirst") then front("item") end
	local byName = {
		creature = groups[OBJ.creatures], object = groups[OBJ.objects], item = groups[OBJ.items],
		killCredit = groups[OBJ.killCredit], spell = groups[OBJ.spell],
	}
	for _, name in ipairs(order) do add(name, byName[name]) end
	if groups[OBJ.reputation] then list[#list + 1] = { kind = "reputation", entry = groups[OBJ.reputation] } end
	return list
end

-- Which data kinds can stand behind a log objective of each type.
local compatible = {
	monster = { creature = true, killCredit = true, spell = true },
	item = { item = true },
	object = { object = true, spell = true },
	reputation = { reputation = true },
	event = { spell = true, creature = true, object = true, killCredit = true },
	log = { creature = true, object = true, killCredit = true, spell = true },
	player = { creature = true, killCredit = true },
}

-- Sources -------------------------------------------------------------------------------------------------------

local function hiddenNpc(id) return Data.hiddenNpcs[id] end

local function npcSource(id, extra)
	if hiddenNpc(id) then return nil end
	local s = { type = "npc", id = id }
	if extra then for k, v in pairs(extra) do s[k] = v end end
	return s
end

local function itemSources(itemID, sources, depth)
	local item = BF:Item(itemID)
	if not item then return end
	local rates = Data.drops[itemID]
	for _, npc in ipairs(item[I.npcDrops] or {}) do
		local s = npcSource(npc, { via = "drop", item = itemID, rate = rates and rates[npc] })
		if s then sources[#sources + 1] = s end
	end
	for _, object in ipairs(item[I.objectDrops] or {}) do
		sources[#sources + 1] = { type = "object", id = object, via = "drop", item = itemID }
	end
	for _, npc in ipairs(item[I.vendors] or {}) do
		local s = npcSource(npc, { via = "vendor", item = itemID })
		if s then sources[#sources + 1] = s end
	end
	-- A container (a crate, a clam) that holds it: where the container comes from, one step deep.
	if depth < 1 then
		for _, container in ipairs(item[I.itemDrops] or {}) do
			itemSources(container, sources, depth + 1)
		end
	end
end

local function sourcesFor(kind, entry)
	local sources = {}
	if kind == "creature" then
		local s = npcSource(entry[1])
		if s then sources[1] = s end
	elseif kind == "killCredit" then
		for _, npc in ipairs(entry[1] or {}) do
			local s = npcSource(npc)
			if s then sources[#sources + 1] = s end
		end
	elseif kind == "object" then
		sources[1] = { type = "object", id = entry[1] }
	elseif kind == "item" then
		if not Data.hiddenItems[entry[1]] then itemSources(entry[1], sources, 0) end
	end
	return sources
end

local iconFor = {
	creature = Objectives.SLAY, killCredit = Objectives.SLAY, object = Objectives.OBJECT,
	item = Objectives.LOOT, spell = Objectives.INTERACT, reputation = nil,
}

-- The data's own icon number on an objective (third value) overrides: QuestieDB's icon types.
local iconTypes = { [1] = "slay", [2] = "loot", [3] = "event", [4] = "object", [5] = "talk", [17] = "interact" }

local function nameFor(kind, entry)
	if kind == "creature" then return BF:NpcName(entry[1]) end
	if kind == "killCredit" then return entry[3] or BF:NpcName(entry[2]) end
	if kind == "object" then return BF:ObjectName(entry[1]) end
	if kind == "item" then return BF:ItemName(entry[1]) end
	if kind == "spell" then return entry[2] end
	return nil
end

-- Pairing -------------------------------------------------------------------------------------------------------

local cache = {} -- [questID] = { stamp =, list = } rebuilt when the log changes

--- The objectives of a quest in the log, each: { index, text, type, have, need, finished, kind, name, icon,
--- sources = {...}, spawns = trigger spawn list? }. Includes the data's extra objectives (with index = nil when
--- they are not one of the log's lines) and the trigger (exploration / event) where the quest has one.
function Objectives:For(questID)
	local logQuest = BF.Log:Get(questID)
	if not logQuest then return {} end
	local cached = cache[questID]
	if cached and cached.objectives == logQuest.objectives then return cached.list end

	local q = BF:Quest(questID)
	local data = dataObjectives(questID)
	local used = {}
	local list = {}

	for index, o in ipairs(logQuest.objectives) do
		local rec = { index = index, text = o.text, type = o.type, have = o.have, need = o.need, finished = o.finished }
		local allowed = compatible[o.type or ""] or {}
		for d = 1, #data do
			if not used[d] and allowed[data[d].kind] then
				used[d] = true
				local kind, entry = data[d].kind, data[d].entry
				rec.kind = kind
				rec.name = nameFor(kind, entry)
				rec.sources = sourcesFor(kind, entry)
				local own = type(entry) == "table" and entry[kind == "killCredit" and 4 or 3]
				rec.icon = (type(own) == "number" and iconTypes[own]) or iconFor[kind]
				rec.id = type(entry) == "table" and (kind == "killCredit" and entry[2] or entry[1]) or nil
				break
			end
		end
		if not rec.kind and (o.type == "event" or o.type == "log") and q and q[Q.trigger] then
			rec.kind = "trigger"
			rec.icon = Objectives.EVENT
			rec.name = q[Q.trigger][1]
			rec.spawns = q[Q.trigger][2]
			rec.sources = {}
		end
		list[#list + 1] = rec
	end

	-- A quest with an exploration/event trigger but no matching log line still shows where to go.
	if q and q[Q.trigger] and q[Q.trigger][2] then
		local shown = false
		for _, rec in ipairs(list) do if rec.kind == "trigger" then shown = true end end
		if not shown then
			local done = BF.Log:IsComplete(questID)
			list[#list + 1] = { kind = "trigger", icon = Objectives.EVENT, name = q[Q.trigger][1], text = q[Q.trigger][1],
				spawns = q[Q.trigger][2], sources = {}, finished = done }
		end
	end

	-- Extra objectives: things the quest needs that the log does not list (use the cannon, summon the boss...).
	for _, extra in ipairs(q and q[Q.extraObjectives] or {}) do
		local spawns, iconType, text, objIndex, refs = extra[1], extra[2], extra[3], extra[4], extra[5]
		local rec = { kind = "extra", icon = iconTypes[iconType] or Objectives.EVENT, name = text, text = text,
			spawns = spawns, sources = {} }
		if objIndex and objIndex > 0 and list[objIndex] then
			rec.finished = list[objIndex].finished
			rec.of = objIndex
		end
		for _, ref in ipairs(refs or {}) do
			if ref[1] == "monster" then
				local s = npcSource(ref[2])
				if s then rec.sources[#rec.sources + 1] = s end
			elseif ref[1] == "object" then
				rec.sources[#rec.sources + 1] = { type = "object", id = ref[2] }
			elseif ref[1] == "item" then
				itemSources(ref[2], rec.sources, 0)
			end
		end
		list[#list + 1] = rec
	end

	cache[questID] = { objectives = logQuest.objectives, list = list }
	return list
end

--- A quest's objectives from the data alone (a quest in a party member's log, not in the player's): each
--- { index, kind, name, icon, id, sources }, in the order the game lists them (reputation left out).
local dataCache = {}
function Objectives:ForData(questID)
	local cached = dataCache[questID]
	if cached then return cached end
	local list = {}
	for _, d in ipairs(dataObjectives(questID)) do
		if d.kind ~= "reputation" then
			local entry = d.entry
			local own = type(entry) == "table" and entry[d.kind == "killCredit" and 4 or 3]
			list[#list + 1] = {
				index = #list + 1, kind = d.kind, name = nameFor(d.kind, entry), sources = sourcesFor(d.kind, entry),
				icon = (type(own) == "number" and iconTypes[own]) or iconFor[d.kind],
				id = type(entry) == "table" and (d.kind == "killCredit" and entry[2] or entry[1]) or nil,
			}
		end
	end
	dataCache[questID] = list
	return list
end

--- Spawns of one source: the NPC's or object's spawn list ({area = {{x, y}...}}), or nil.
function Objectives:Spawns(source)
	if source.type == "npc" then
		local n = BF:Npc(source.id)
		return n and n[N.spawns]
	elseif source.type == "object" then
		local o = BF:Object(source.id)
		return o and o[O.spawns]
	end
end

function Objectives:SourceName(source)
	if source.type == "npc" then return BF:NpcName(source.id) end
	if source.type == "object" then return BF:ObjectName(source.id) end
end

BF:Listen("BF_QUEST_REMOVED", function(_, id) cache[id] = nil end)
