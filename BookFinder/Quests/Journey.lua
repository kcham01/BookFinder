-- My Journey (Questie's): the character's history: quests accepted, completed and abandoned, levels reached, and the
-- player's own notes, each with the date and the character's level then. Kept per character.
--
-- Entry: { t = time(), kind = "accepted"/"completed"/"abandoned"/"level"/"note", quest = id?, level = n,
--          title = (note), text = (note) }
-- Messages: BF_JOURNEY_CHANGED()

local _, BF = ...

local Journey = {}
BF.Journey = Journey

local function entries()
	local s = BF:CharacterState("journey")
	s.entries = s.entries or {}
	return s.entries
end

function Journey:Entries() return entries() end

local function add(entry)
	entry.t = entry.t or time()
	entry.level = entry.level or BF.Player.level or UnitLevel("player")
	table.insert(entries(), entry)
	BF:Send("BF_JOURNEY_CHANGED")
end

function Journey:AddNote(title, text)
	add({ kind = "note", title = title, text = text })
end

function Journey:Remove(entry)
	local list = entries()
	for i = #list, 1, -1 do
		if list[i] == entry then table.remove(list, i) end
	end
	BF:Send("BF_JOURNEY_CHANGED")
end

--- Copies another character's journey (account-wide copies kept at logout) into this one.
function Journey:Import(characterKey)
	local copy = BF:AccountState("journeys")[characterKey]
	if not copy then return false end
	local list = entries()
	for _, e in ipairs(copy) do
		local c = {}
		for k, v in pairs(e) do c[k] = v end
		list[#list + 1] = c
	end
	table.sort(list, function(a, b) return a.t < b.t end)
	BF:Send("BF_JOURNEY_CHANGED")
	return true
end

--- Characters whose journey can be imported (by "Name - Realm").
function Journey:Others()
	local mine = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
	local list = {}
	for key in pairs(BF:AccountState("journeys")) do
		if key ~= mine then list[#list + 1] = key end
	end
	table.sort(list)
	return list
end

BF:At("login", function()
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id) add({ kind = "accepted", quest = id }) end)
	BF:Listen("BF_QUEST_REMOVED", function(_, id, turnedIn)
		add({ kind = turnedIn and "completed" or "abandoned", quest = id })
	end)
	BF:Listen("BF_LEVEL_CHANGED", function(_, level) add({ kind = "level", level = level }) end)
	-- A copy for the player's other characters to import.
	BF:On("PLAYER_LOGOUT", function()
		local key = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
		BF:AccountState("journeys")[key] = entries()
	end)
end, 30)
