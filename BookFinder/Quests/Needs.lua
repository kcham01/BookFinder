-- Needs: which NPCs, objects and items the quests in the log still need, looked up by ID.
--
-- Tooltips, nameplates and the target frame all ask the same question ("does a quest of mine need this?") many times a
-- second. The answer is worked out once from BF.Objectives whenever the log changes, as three indexes:
--   BF.Needs:Npc(id)    { {quest =, objective = rec, source = s}, ... }   kill it, loot it (s.rate: drop %), talk to it
--   BF.Needs:Object(id) { {quest =, objective = rec, source = s}, ... }   use it, loot it
--   BF.Needs:Item(id)   { {quest =, objective = rec}, ... }               the item itself is asked for
-- Finished objectives, failed quests and quests the player hid are left out. Each list keeps the log's order.

local _, BF = ...

local Needs = {}
BF.Needs = Needs

local Log, Objectives, Rules = BF.Log, BF.Objectives, BF.Rules

local npcs, objects, items -- nil until first asked after a change
local EMPTY = {}

local function add(index, id, entry)
	local list = index[id]
	if not list then
		list = {}
		index[id] = list
	end
	list[#list + 1] = entry
end

-- Quests in the log in the log's own order (index), so tooltips list them as the quest log does.
local function logOrder()
	local ids = {}
	for id in pairs(Log.quests) do ids[#ids + 1] = id end
	table.sort(ids, function(a, b)
		return (Log.quests[a].index or 0) < (Log.quests[b].index or 0)
	end)
	return ids
end

local function build()
	npcs, objects, items = {}, {}, {}
	for _, quest in ipairs(logOrder()) do
		if not Log:IsFailed(quest) and not Rules:HiddenByPlayer(quest) then
			for _, rec in ipairs(Objectives:For(quest)) do
				if not rec.finished then
					for _, s in ipairs(rec.sources or EMPTY) do
						local entry = { quest = quest, objective = rec, source = s }
						if s.type == "npc" then add(npcs, s.id, entry)
						elseif s.type == "object" then add(objects, s.id, entry) end
					end
					if rec.kind == "item" and rec.id then add(items, rec.id, { quest = quest, objective = rec }) end
				end
			end
		end
	end
end

local function ensure()
	if not npcs then build() end
end

function Needs:Npc(id)
	ensure()
	return npcs[id] or EMPTY
end

function Needs:Object(id)
	ensure()
	return objects[id] or EMPTY
end

function Needs:Item(id)
	ensure()
	return items[id] or EMPTY
end

--- The objective icon an NPC would carry on its nameplate (the first unfinished objective that needs it), or nil.
function Needs:NpcIcon(id)
	local first = Needs:Npc(id)[1]
	return first and first.objective.icon or nil
end

-- Any change to the log, its progress, or which quests are hidden starts the indexes again on the next question.
local function forget() npcs, objects, items = nil, nil, nil end
for _, m in ipairs({ "BF_QUEST_LOG_CHANGED", "BF_QUEST_PROGRESS", "BF_QUEST_COMPLETE_CHANGED", "BF_QUEST_HIDDEN_CHANGED" }) do
	BF:Listen(m, function()
		forget()
		BF:Send("BF_NEEDS_CHANGED")
	end)
end
