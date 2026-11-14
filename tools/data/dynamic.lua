-- tools/data/dynamic.lua: BookFinder's data converter, part 2 (run by convert.py; not part of the addon).
--
-- QuestieDB keeps a few corrections that depend on the player (faction, class): its "dynamic" corrections. They are
-- data written as Lua. This script evaluates them once for every faction and class, in QuestieDB's own order (legacy
-- Era fixes first, Forever fixes after: later wins, field by field), and prints the result as JSON for convert.py.
-- It also evaluates the support files (zones, dungeons, quest XP, drop rates, faction templates) the same way.
--
-- Usage: lua5.1 dynamic.lua <QuestieDB folder>   (prints one JSON document)

local root = assert(arg[1], "usage: lua5.1 dynamic.lua <QuestieDB folder>")
root = root:gsub("/$", "")

local encode = dofile((arg[0]:gsub("dynamic%.lua$", "json.lua")))

-- QuestieDB's enums (loaded through its own standalone entry point, which reads only data files) -------------------

local savedPath = package.path
local enumsChunk = assert(loadfile(root .. "/src/corrections/enum/constants.lua"))
-- constants.lua reads "src/config.lua" relative to the working directory: convert.py runs us from the QuestieDB folder.
local Enum = enumsChunk()
package.path = savedPath

local function metaKeys(name)
	local chunk = assert(loadfile(root .. "/src/meta/" .. name .. "Meta.lua"))
	return chunk().keys
end

local questKeys, npcKeys, objectKeys, itemKeys =
	metaKeys("quest"), metaKeys("npc"), metaKeys("object"), metaKeys("item")

-- Forever's flavour has no class list of its own; QuestieDB uses Classic's rules for it.
local forever = Enum.byExpansion.Forever
local classic = Enum.byExpansion.Classic

-- Stand-ins for the modules the correction files import ------------------------------------------------------------

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local FACTIONS = { "Alliance", "Horde" }

local current = { faction = "Alliance", class = "WARRIOR" }

local flags = { itemObjectiveFirst = {}, killCreditObjectiveFirst = {}, objectObjectiveFirst = {} }

local modules = {
	QuestieDB = {
		questKeys = questKeys, npcKeys = npcKeys, objectKeys = objectKeys, itemKeys = itemKeys,
		raceKeys = forever.raceKeys or classic.raceKeys,
		classKeys = forever.classKeys or classic.classKeys,
		npcFlags = forever.npcFlags or classic.npcFlags,
		sortKeys = Enum.sortKeys, specialFlags = Enum.specialFlags, questFlags = Enum.questFlags,
		factionIDs = Enum.factionIDs, waypointPresets = Enum.waypointPresets, itemClasses = Enum.itemClasses,
		private = {},
	},
	ZoneDB = { zoneIDs = Enum.zoneIDs, private = {} },
	QuestieProfessions = {
		professionKeys = Enum.professionKeys, specializationKeys = Enum.specializationKeys, rankNames = Enum.rankNames,
	},
	QuestieCorrections = flags,
	Phasing = { phases = Enum.phases },
	-- Forever is built on Classic Era: the support files' later-expansion branches must not apply.
	Expansions = { Current = 1, Era = 1, Classic = 1, Tbc = 2, TBC = 2, Wotlk = 3, Cata = 4, MoP = 5 },
	QuestXP = { db = {} },
	DropDB = { correctionKeys = Enum.dropCorrectionKeys },
}
local l10n = setmetatable({}, { __call = function(_, s) return s end })
modules.l10n = l10n

local function module(name)
	modules[name] = modules[name] or {}
	return modules[name]
end

local sandbox = {
	QuestieLoader = {
		CreateModule = function(_, name) return module(name) end,
		ImportModule = function(_, name) return module(name) end,
	},
	UnitFactionGroup = function() return current.faction end,
	UnitClassBase = function() return current.class end,
	UnitClass = function() return current.class, current.class end,
	UnitRace = function() return "Human", "Human" end,
	Questie = { IsClassic = true, IsEra = true, IsSoD = false, IsTBC = false, IsWotlk = false, IsCata = false },
	print = function() end,
}
setmetatable(sandbox, { __index = _G })

local function run(path)
	local chunk = assert(loadfile(root .. "/" .. path))
	setfenv(chunk, sandbox)
	return chunk("QuestieDB", {})
end

-- Dynamic corrections ----------------------------------------------------------------------------------------------

-- In QuestieDB's order: the legacy (Era) file's function, then the Forever file's.
local providers = {
	Quest = {
		{ "src/corrections/Forever/legacy/classicQuestFixes.lua", "QuestieQuestFixes", "LoadFactionFixes" },
		{ "src/corrections/Forever/foreverQuestFixes.lua", "ForeverQuestFixes", "LoadDynamic" },
	},
	Npc = {
		{ "src/corrections/Forever/legacy/classicNPCFixes.lua", "QuestieNPCFixes", "LoadFactionFixes" },
		{ "src/corrections/Forever/foreverNPCFixes.lua", "ForeverNpcFixes", "LoadDynamic" },
	},
	Item = {
		{ "src/corrections/Forever/legacy/classicItemFixes.lua", "QuestieItemFixes", "LoadFactionFixes" },
		{ "src/corrections/Forever/foreverItemFixes.lua", "ForeverItemFixes", "LoadDynamic" },
	},
	Object = {
		{ "src/corrections/Forever/legacy/classicObjectFixes.lua", "QuestieObjectFixes", "LoadFactionFixes" },
		{ "src/corrections/Forever/foreverObjectFixes.lua", "ForeverObjectFixes", "LoadDynamic" },
	},
}

-- Load every correction file once (they define their modules' functions and set the objective-first flags).
for _, list in pairs(providers) do
	for _, p in ipairs(list) do run(p[1]) end
end

local dynamic = {}
for _, faction in ipairs(FACTIONS) do
	for _, class in ipairs(CLASSES) do
		current.faction, current.class = faction, class
		local key = faction .. "/" .. class
		local byType = {}
		for datatype, list in pairs(providers) do
			local merged = {}
			for _, p in ipairs(list) do
				local mod = modules[p[2]]
				local fn = mod and mod[p[3]]
				if fn then
					local rows = fn(mod) or {}
					for id, fields in pairs(rows) do
						merged[id] = merged[id] or {}
						for field, value in pairs(fields) do merged[id][field] = value end
					end
				end
			end
			byType[datatype] = merged
		end
		dynamic[key] = byType
	end
end

-- Support files ----------------------------------------------------------------------------------------------------

local support = {}

local function evalReturnString(s)
	local chunk = assert(loadstring(s))
	setfenv(chunk, sandbox)
	return chunk()
end

local supportFiles = {
	"support/Forever/Zones/dungeons.lua",
	"support/Forever/Zones/subZoneToParentZone.lua",
	"support/Forever/Zones/instanceIdToAreaId.lua",
	"support/Forever/Zones/areaIdToUiMapId.lua",
	"support/Forever/Zones/uiMapIdToAreaId.lua",
	"support/Forever/QuestXP/xpDB-classic.lua",
	"support/Forever/QuestXP/xpDB-traces.lua",
	"support/Forever/FactionTemplates/factionTemplateClassic.lua",
	"support/Forever/DropTables/classicItemDrops.lua",
	"support/Forever/DropTables/itemDropCorrections.lua",
}
for _, faction in ipairs({ "Alliance" }) do
	current.faction = faction
	for _, f in ipairs(supportFiles) do run(f) end
end

-- Many support tables are stored as "return {...}" strings to keep the client's parser fast; evaluate them.
local function materialize(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "string" and v:match("^%s*return") then
			out[k] = evalReturnString(v)
		elseif type(v) ~= "function" then
			out[k] = v
		end
	end
	return out
end

support.ZoneDB = materialize(modules.ZoneDB)
support.ZoneDB.private = materialize(modules.ZoneDB.private)
support.ZoneDB.zoneIDs = nil
support.QuestXP = modules.QuestXP.db
support.factionTemplate = modules.QuestieDB.factionTemplate
support.drops = materialize(modules.QuestieClassicItemDrops or {})
support.dropCorrections = {}
local dropMod = modules.QuestieItemDropCorrections
if dropMod then
	for name, fn in pairs(dropMod) do
		if type(fn) == "function" then
			local ok, result = pcall(fn, dropMod)
			if ok and type(result) == "table" then support.dropCorrections[name] = result end
		end
	end
end

io.write(encode({
	dynamic = dynamic,
	flags = flags,
	support = support,
	enums = {
		zoneIDs = Enum.zoneIDs, sortKeys = Enum.sortKeys, factionIDs = Enum.factionIDs,
		professionKeys = Enum.professionKeys, specializationKeys = Enum.specializationKeys,
		raceKeys = modules.QuestieDB.raceKeys, classKeys = modules.QuestieDB.classKeys,
		npcFlags = modules.QuestieDB.npcFlags, questFlags = Enum.questFlags, specialFlags = Enum.specialFlags,
		raceMaskById = Enum.raceMaskById,
	},
}))
