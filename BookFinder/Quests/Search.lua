-- Advanced Search (Questie's): quests, NPCs, objects and items by name or ID; and "Show on map": any NPC, object or
-- quest's givers marked on the map until removed (Questie's tomap).
--
-- Messages: BF_SEARCH_DONE(results)   results = { quests = {ids}, npcs = {ids}, objects = {ids}, items = {ids} }

local _, BF = ...
local L = BF.L

local Search = {}
BF.Search = Search

local KINDS = { "quests", "npcs", "objects", "items" }
local LIMIT = 200

-- The name of a row without decoding it (rows start with their name: {"Name",...}).
local function nameOf(source)
	local name = source:match('^{"(.-)"[,}]')
	return name and name:gsub('\\"', '"')
end

local job
--- Searches in slices (tens of thousands of rows); BF_SEARCH_DONE when finished.
function Search:Run(text)
	if job then job:SetScript("OnUpdate", nil) end
	text = strtrim(text or "")
	local results = { quests = {}, npcs = {}, objects = {}, items = {}, text = text }
	if text == "" then
		BF:Send("BF_SEARCH_DONE", results)
		return
	end
	local id = tonumber(text)
	local needle = text:lower()
	local lists = {}
	for _, kind in ipairs(KINDS) do
		local ids = {}
		for i, source in BF:AllIDs(kind) do ids[#ids + 1] = { i, source } end
		lists[#lists + 1] = { kind = kind, ids = ids }
	end
	local k, n = 1, 0
	job = BF:Spread(function()
		for _ = 1, 2000 do
			local list = lists[k]
			if not list then return true end
			n = n + 1
			local e = list.ids[n]
			if not e then
				k, n = k + 1, 0
			else
				local hit
				if id then hit = e[1] == id else
					local name = nameOf(e[2])
					hit = name and name:lower():find(needle, 1, true)
				end
				local out = results[list.kind]
				if hit and #out < LIMIT then out[#out + 1] = e[1] end
			end
		end
		return false
	end, 6, function()
		job = nil
		for _, kind in ipairs(KINDS) do
			table.sort(results[kind], function(a, b)
				local na, nb = nameOf(BF.Data[kind][a] or "") or "", nameOf(BF.Data[kind][b] or "") or ""
				if na == nb then return a < b end
				return na < nb
			end)
		end
		BF:Send("BF_SEARCH_DONE", results)
	end)
end

-- Show on map ---------------------------------------------------------------------------------------------------------

local function shown()
	local s = BF:CharacterState("search")
	s.onMap = s.onMap or {}
	return s.onMap -- ["npc:123"] = true, ["object:45"] = true, ["quest:7"] = true
end

function Search:IsOnMap(kind, id) return shown()[kind .. ":" .. id] == true end

function Search:SetOnMap(kind, id, on)
	shown()[kind .. ":" .. id] = on and true or nil
	BF.Marks:RebuildLayer("manual")
end

function Search:ClearMap()
	wipe(shown())
	BF.Marks:RebuildLayer("manual")
end

BF.Marks:RegisterLayer("manual", function(add)
	for key in pairs(shown()) do
		local kind, id = key:match("^(%a+):(%d+)$")
		id = tonumber(id)
		local sources = {}
		if kind == "npc" or kind == "object" then
			sources[1] = { type = kind, id = id }
		elseif kind == "quest" then
			local q = BF:Quest(id)
			for _, npc in ipairs(q and q[BF.Q.startNpcs] or {}) do sources[#sources + 1] = { type = "npc", id = npc } end
			for _, obj in ipairs(q and q[BF.Q.startObjects] or {}) do sources[#sources + 1] = { type = "object", id = obj } end
		end
		for _, source in ipairs(sources) do
			local role = { role = "manual", label = kind == "quest" and BF:QuestName(id) or nil, quest = kind == "quest" and id or nil }
			BF.Zones:EachSpawn(BF.Objectives:Spawns(source), function(map, x, y, inside)
				if not inside then add(map, x, y, BF.Marks.SpotKey(source, map, x, y), role, source) end
			end)
		end
	end
end)

-- /bf tomap <npc|object> <name or ID>; no argument: the target.
function Search:ToMap(kind, what)
	if (not what or what == "") and UnitExists("target") then
		local guid = UnitGUID("target")
		if guid and not (issecretvalue and issecretvalue(guid)) then
			local unitType, _, _, _, _, npcID = strsplit("-", guid)
			if unitType == "Creature" then
				Search:SetOnMap("npc", tonumber(npcID), true)
				BF:Print(L["%s shown on the map."], UnitName("target"))
			end
		end
		return
	end
	local id = tonumber(what)
	local dataKind = kind == "object" and "objects" or "npcs"
	if not id then
		local needle = (what or ""):lower()
		for i, source in BF:AllIDs(dataKind) do
			local name = nameOf(source)
			if name and name:lower() == needle then id = i break end
		end
	end
	if id then
		Search:SetOnMap(kind == "object" and "object" or "npc", id, true)
		BF:Print(L["%s shown on the map."], (kind == "object" and BF:ObjectName(id)) or BF:NpcName(id) or id)
	else
		BF:Print(L["Nothing found for \"%s\"."], what or "")
	end
end
