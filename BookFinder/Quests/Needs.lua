-- What the quest log needs from each creature, object and item: one index read by tooltips, nameplates and the target
-- frame. Rebuilt when the quest log changes.
--
-- BF.Needs:ForNpc(id) / ForObject(id) / ForItem(id) -> { {quest =, objective = rec, item = id?, rate = %?}, ... }

local _, BF = ...

local Needs = {}
BF.Needs = Needs

local byNpc, byObject, byItem = {}, {}, {}

local function add(t, id, entry)
	local list = t[id]
	if not list then
		list = {}
		t[id] = list
	end
	list[#list + 1] = entry
end

local function rebuild()
	wipe(byNpc)
	wipe(byObject)
	wipe(byItem)
	for questID in pairs(BF.Log.quests) do
		for _, rec in ipairs(BF.Objectives:For(questID)) do
			if rec.kind == "item" and rec.id then
				add(byItem, rec.id, { quest = questID, objective = rec })
			end
			for _, s in ipairs(rec.sources or {}) do
				local entry = { quest = questID, objective = rec, item = s.item, rate = s.rate, via = s.via }
				if s.type == "npc" then add(byNpc, s.id, entry) elseif s.type == "object" then add(byObject, s.id, entry) end
			end
		end
	end
	BF:Send("BF_NEEDS_CHANGED")
end
local soon = BF:Debounce(0.2, rebuild)

function Needs:ForNpc(id) return byNpc[id] end
function Needs:ForObject(id) return byObject[id] end
function Needs:ForItem(id) return byItem[id] end

--- Whether anything still unfinished needs this NPC (for nameplate icons): the first such entry.
function Needs:OpenFor(npc)
	for _, e in ipairs(byNpc[npc] or {}) do
		if not e.objective.finished then return e end
	end
end

--- The NPC ID in a creature's GUID, or nil (players, pets, or a secret value).
function Needs:NpcFromGUID(guid)
	if not guid or (issecretvalue and issecretvalue(guid)) then return nil end
	local unitType, _, _, _, _, id = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" then return tonumber(id) end
end

BF:At("login", function()
	rebuild()
	BF:Listen("BF_QUEST_LOG_CHANGED", soon)
	BF:Listen("BF_QUEST_PROGRESS", soon)
end, 62)
