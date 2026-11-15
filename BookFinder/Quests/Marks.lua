-- Marks: every quest icon, decided once for every map; the world map and the minimap only draw them.
--
-- A pin is one spot on one map: { map, x, y, source = {type, id}?, inside = areaID?, roles = { role, ... } }.
-- Each role says why the spot is marked:
--   { role = "available", quest = id }                  a quest to pick up (from this NPC / object)
--   { role = "itemStart", quest = id, item = id }       a quest that starts from an item this source gives
--   { role = "complete", quest = id }                   where a finished quest is handed in
--   { role = "objective", quest = id, objective = rec, source = {...} }  something an objective needs
-- One NPC at one spot is one pin, whatever roles it has. Objective spawns of the same objective close together are
-- merged into one pin (a pack of mobs); everything inside an instance shows once at its entrance.
--
-- Messages: BF_MARKS_CHANGED()

local _, BF = ...

local Marks = { byMap = {}, version = 0 }
BF.Marks = Marks

local Q = BF.Q
local Zones, Rules, Log, Objectives = BF.Zones, BF.Rules, BF.Log, BF.Objectives
local floor = math.floor

-- Building ------------------------------------------------------------------------------------------------------

local building -- the maps being built: [map] = { [key] = pin }

local function pinAt(map, x, y, key, source, inside)
	local pins = building[map]
	if not pins then
		pins = {}
		building[map] = pins
	end
	local pin = pins[key]
	if not pin then
		pin = { map = map, x = x, y = y, source = source, inside = inside, roles = {} }
		pins[key] = pin
	end
	return pin
end

local function spotKey(source, map, x, y, inside)
	if inside then return "in:" .. inside .. ":" .. floor(x * 1000) .. ":" .. floor(y * 1000) end
	return source.type .. source.id .. ":" .. floor(x * 10000) .. ":" .. floor(y * 10000)
end

--- Adds a role at every spawn of a source (an NPC or object), up to `limit` spots.
local function markSource(source, role, limit)
	local spawns = Objectives:Spawns(source)
	if not spawns then return end
	local count = 0
	-- Spawns of the same creature or object closer than icons.clusterSpawns yards show as one icon.
	local merge = BF:Get("icons.clusterSpawns")
	local placed = {}
	Zones:EachSpawn(spawns, function(map, x, y, inside)
		if limit and count >= limit then return end
		if merge > 0 and not inside then
			local w, h = Zones:MapSize(map)
			if w and h and w > 0 then
				for _, p in ipairs(placed) do
					if p[1] == map then
						local dx, dy = (p[2] - x) * w, (p[3] - y) * h
						if dx * dx + dy * dy <= merge * merge then return end
					end
				end
			end
			placed[#placed + 1] = { map, x, y }
		end
		count = count + 1
		local pin = pinAt(map, x, y, spotKey(source, map, x, y, inside), not inside and source or nil, inside)
		pin.roles[#pin.roles + 1] = role
	end)
end

local ITEM_START_MIN_RATE = 5    -- percent: creatures that drop the item less often are not marked
local ITEM_START_PACK = 0.08      -- a pack: droppers within this share of the map
local ITEM_START_MAX_PACKS = 3    -- packs per quest per map

local function markGivers(id)
	local q = BF:Quest(id)
	if not q then return end
	local limit = BF:Get("icons.availableLimit")
	local role = { role = "available", quest = id }
	for _, npc in ipairs(q[Q.startNpcs] or {}) do
		if not BF.Data.hiddenNpcs[npc] then markSource({ type = "npc", id = npc }, role, limit) end
	end
	for _, object in ipairs(q[Q.startObjects] or {}) do
		markSource({ type = "object", id = object }, role, limit)
	end
	if BF:Get("quests.itemStarts") then
		-- A quest started by an item: where the item comes from. Objects that hold it are marked where they stand;
		-- creatures that drop it are merged into packs (one "!" per area, at most a few per map), leaving out those
		-- that rarely drop it, so a commonly dropped item doesn't cover a zone in quest givers.
		for _, item in ipairs(q[Q.startItems] or {}) do
			local itemRow = BF:Item(item)
			local itemRole = { role = "itemStart", quest = id, item = item }
			if itemRow then
				for _, object in ipairs(itemRow[BF.I.objectDrops] or {}) do
					markSource({ type = "object", id = object }, itemRole, limit)
				end
				local rates = BF.Data.drops[item]
				local packs = {} -- [map] = { {x, y, n, sx, sy}, ... }
				for _, npc in ipairs(itemRow[BF.I.npcDrops] or {}) do
					local rate = rates and rates[npc]
					if not BF.Data.hiddenNpcs[npc] and (not rate or rate >= ITEM_START_MIN_RATE) then
						local spawns = Objectives:Spawns({ type = "npc", id = npc })
						Zones:EachSpawn(spawns, function(map, x, y, inside)
							if inside then return end
							local list = packs[map]
							if not list then list = {} packs[map] = list end
							for _, c in ipairs(list) do
								if (c.x - x) ^ 2 + (c.y - y) ^ 2 <= ITEM_START_PACK ^ 2 then
									c.sx, c.sy, c.n = c.sx + x, c.sy + y, c.n + 1
									c.x, c.y = c.sx / c.n, c.sy / c.n
									return
								end
							end
							list[#list + 1] = { x = x, y = y, sx = x, sy = y, n = 1 }
						end)
					end
				end
				for map, list in pairs(packs) do
					table.sort(list, function(a, b2) return a.n > b2.n end)
					for n = 1, math.min(#list, ITEM_START_MAX_PACKS) do
						local c = list[n]
						local pin = pinAt(map, c.x, c.y, "is:" .. id .. ":" .. item .. ":" .. n, nil, nil)
						pin.roles[#pin.roles + 1] = itemRole
					end
				end
			end
		end
	end
end

local function markTurnIn(id)
	local q = BF:Quest(id)
	if not q then return end
	local role = { role = "complete", quest = id }
	for _, npc in ipairs(q[Q.endNpcs] or {}) do markSource({ type = "npc", id = npc }, role) end
	for _, object in ipairs(q[Q.endObjects] or {}) do markSource({ type = "object", id = object }, role) end
end

-- Objective spawns of one objective on one map, merged into packs within `radius` (fraction of the map).
local function markObjective(id, rec)
	local radius = BF:Get("icons.clusterObjectives") / 100
	local clusters = {} -- [map] = { {x, y, n, sources = {}}, ... }
	local function add(map, x, y, inside, source)
		if inside then
			local pin = pinAt(map, x, y, "in:" .. inside .. ":" .. floor(x * 1000) .. ":" .. floor(y * 1000), nil, inside)
			pin.roles[#pin.roles + 1] = { role = "objective", quest = id, objective = rec, source = source }
			return
		end
		local list = clusters[map]
		if not list then
			list = {}
			clusters[map] = list
		end
		for _, c in ipairs(list) do
			local dx, dy = c.x - x, c.y - y
			if dx * dx + dy * dy <= radius * radius then
				c.sx, c.sy, c.n = c.sx + x, c.sy + y, c.n + 1
				c.x, c.y = c.sx / c.n, c.sy / c.n
				if source and not c.seen[source.type .. source.id] then
					c.seen[source.type .. source.id] = true
					c.sources[#c.sources + 1] = source
				end
				return
			end
		end
		local c = { x = x, y = y, sx = x, sy = y, n = 1, sources = {}, seen = {} }
		if source then
			c.sources[1] = source
			c.seen[source.type .. source.id] = true
		end
		list[#list + 1] = c
	end
	for _, source in ipairs(rec.sources or {}) do
		local spawns = Objectives:Spawns(source)
		if spawns then
			Zones:EachSpawn(spawns, function(map, x, y, inside) add(map, x, y, inside, source) end)
		end
	end
	if rec.spawns then
		Zones:EachSpawn(rec.spawns, function(map, x, y, inside) add(map, x, y, inside, nil) end)
	end
	local tag = id .. ":" .. tostring(rec.index or rec.name or "x")
	for map, list in pairs(clusters) do
		for n, c in ipairs(list) do
			local pin = pinAt(map, c.x, c.y, "o:" .. tag .. ":" .. n, nil, nil)
			pin.roles[#pin.roles + 1] = { role = "objective", quest = id, objective = rec, sources = c.sources, count = c.n }
		end
	end
end

local function tracked(id)
	if not BF:Get("icons.hideUntracked") then return true end
	return C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil
end

-- Layers --------------------------------------------------------------------------------------------------------
--
-- Three layers are kept apart so a change in one (a mob killed) does not redo the others (every available quest):
-- available (all the data, worked out a slice at a time), turn-ins and objectives (the quest log, quick).

local layers = { available = {}, log = {} }



local function merge()
	local byMap = {}
	for _, layer in pairs(layers) do
		for map, pins in pairs(layer) do
			local into = byMap[map]
			if not into then
				into = {}
				byMap[map] = into
			end
			for key, pin in pairs(pins) do
				local existing = into[key]
				if existing then
					local copy = { map = existing.map, x = existing.x, y = existing.y, source = existing.source,
						inside = existing.inside, roles = {} }
					for _, r in ipairs(existing.roles) do copy.roles[#copy.roles + 1] = r end
					for _, r in ipairs(pin.roles) do copy.roles[#copy.roles + 1] = r end
					into[key] = copy
				else
					into[key] = pin
				end
			end
		end
	end
	Marks.byMap = byMap
	Marks.version = Marks.version + 1
	BF:Send("BF_MARKS_CHANGED")
end

-- Other layers (townsfolk, party objectives...) register a builder: build(add), where
-- add(map, x, y, key, role, source, inside) puts a role on the pin at that spot (same key = same pin).
local extra = {}

function Marks:RegisterLayer(name, build)
	extra[name] = build
end

local function buildExtra(name)
	local result = {}
	building = result
	local ok, err = pcall(extra[name], function(map, x, y, key, role, source, inside)
		local pin = pinAt(map, x, y, key, source, inside)
		pin.roles[#pin.roles + 1] = role
	end)
	building = nil
	if not ok then geterrorhandler()(err) end
	layers[name] = result
end

--- Rebuilds one registered layer (when what it shows changes).
function Marks:RebuildLayer(name)
	buildExtra(name)
	merge()
end

--- The spot key for a source at a place (so other layers land on the same pin as the quest marks of that NPC).
Marks.SpotKey = function(source, map, x, y, inside) return spotKey(source, map, x, y, inside) end

local function buildLog()
	building = {}
	if BF:Get("quests.turnins") or BF:Get("quests.objectives") then
		for id in pairs(Log.quests) do
			if not Rules:HiddenByPlayer(id) and Rules:HiddenByData(id) ~= "HIDE_ON_MAP" and tracked(id) then
				local complete = Log:IsComplete(id)
				if complete then
					if BF:Get("quests.turnins") then markTurnIn(id) end
				elseif BF:Get("quests.objectives") and not Log:IsFailed(id) then
					for _, rec in ipairs(Objectives:For(id)) do
						if not rec.finished and rec.kind ~= "reputation" then markObjective(id, rec) end
					end
				end
			end
		end
	end
	layers.log = building
	building = nil
end

local availableJob
local function buildAvailable(done)
	if availableJob then availableJob:SetScript("OnUpdate", nil) end
	local result = {}
	if not BF:Get("quests.available") then
		layers.available = result
		if done then done() end
		return
	end
	local ids = {}
	for id in BF:AllIDs("quests") do ids[#ids + 1] = id end
	local i = 0
	availableJob = BF:Spread(function()
		for _ = 1, 100 do
			i = i + 1
			local id = ids[i]
			if not id then return true end
			if Rules:IsShown(id) and Rules:HiddenByData(id) ~= "HIDE_ON_MAP" then
				building = result
				markGivers(id)
				building = nil
			end
		end
		return false
	end, 4, function()
		availableJob = nil
		layers.available = result
		if done then done() end
	end)
end

--- Rebuilds now (log layers) and in slices (available); BF_MARKS_CHANGED when each is ready.
function Marks:Rebuild(withAvailable)
	buildLog()
	if withAvailable then for name in pairs(extra) do buildExtra(name) end end
	merge()
	if withAvailable then buildAvailable(merge) end
end

--- Pins on one map: an array (cached until the next rebuild).
local arrays, arraysVersion = {}, -1
function Marks:On(map)
	if arraysVersion ~= Marks.version then
		arrays, arraysVersion = {}, Marks.version
	end
	local a = arrays[map]
	if a then return a end
	a = {}
	for _, pin in pairs(Marks.byMap[map] or {}) do a[#a + 1] = pin end
	arrays[map] = a
	return a
end

-- When to rebuild ------------------------------------------------------------------------------------------------

local logSoon = BF:Debounce(0.2, function() Marks:Rebuild(false) end)
local allSoon = BF:Debounce(0.5, function() Marks:Rebuild(true) end)

BF:At("login", function()
	Marks:Rebuild(true)
	-- What changes only the quest log's marks:
	BF:Listen("BF_QUEST_PROGRESS", logSoon)
	BF:Listen("BF_QUEST_COMPLETE_CHANGED", logSoon)
	-- What can change which quests are available too:
	for _, m in ipairs({ "BF_QUEST_ACCEPTED", "BF_QUEST_REMOVED", "BF_COMPLETED_CHANGED", "BF_LEVEL_CHANGED",
		"BF_SKILLS_CHANGED", "BF_REPUTATION_CHANGED", "BF_EVENTS_CHANGED", "BF_QUEST_HIDDEN_CHANGED" }) do
		BF:Listen(m, allSoon)
	end
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key:find("^quests%.") or key == "icons.hideUntracked" or key == "icons.availableLimit"
			or key == "icons.clusterObjectives" or key == "icons.clusterSpawns" then
			allSoon()
		end
	end)
	BF:On("QUEST_WATCH_LIST_CHANGED", function()
		if BF:Get("icons.hideUntracked") then logSoon() end
	end)
end, 60)
