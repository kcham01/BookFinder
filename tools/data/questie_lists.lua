-- tools/data/questie_lists.lua: BookFinder's data converter, part 3 (run by convert.py; not part of the addon).
--
-- Evaluates the lists Questie keeps as data, the way Questie does on WoW: Forever (Classic Era rules, expansion 1):
--   hidden quests, NPCs and items (its blacklists), holiday quests and holiday dates, and the Darkmoon Faire NPC
--   positions for each of the faire's two places. Prints JSON for convert.py.
--
-- Usage (from the QuestieDB folder, whose enums it reads): lua5.1 questie_lists.lua <Questie folder> <QuestieDB folder>

local root = assert(arg[1], "usage: lua5.1 questie_lists.lua <Questie folder> <QuestieDB folder>"):gsub("/$", "")
local qdb = assert(arg[2], "usage: lua5.1 questie_lists.lua <Questie folder> <QuestieDB folder>"):gsub("/$", "")
local encode = dofile((arg[0]:gsub("questie_lists%.lua$", "json.lua")))

local function module(registry, name)
	registry[name] = registry[name] or { private = {} }
	return registry[name]
end

local modules = {}
local Expansions = { Era = 1, Classic = 1, Tbc = 2, TBC = 2, Wotlk = 3, Cata = 4, MoP = 5, Current = 1 }
modules.Expansions = Expansions
modules.ContentPhases = {
	activePhases = setmetatable({}, { __index = function() return 0 end }),
}
for _, name in ipairs({ "BlacklistTbcQuestsByPhase", "BlacklistSoMQuestsByPhase", "BlacklistSoDQuestsByPhase",
	"BlacklistMoPQuestsByPhase", "BlacklistAnniversaryQuestsByPhase" }) do
	modules.ContentPhases[name] = function(_, list) return list end
end
modules.l10n = setmetatable({}, { __call = function(_, s) return s end })

-- The NPC field keys and zone IDs the Darkmoon Faire fixes are written with (QuestieDB's enums and meta).
local Enum = assert(loadfile(qdb .. "/src/corrections/enum/constants.lua"))()
modules.QuestieDB = { npcKeys = assert(loadfile(qdb .. "/src/meta/npcMeta.lua"))().keys, private = {} }
modules.ZoneDB = { zoneIDs = Enum.zoneIDs, private = {} }

-- Questie on Forever: a Classic Era client flagged Forever; every other flavour flag is false.
local Questie = setmetatable({ IsClassic = true, IsEra = true, IsForever = true }, {
	__index = function() return false end,
})

local sandbox = setmetatable({
	QuestieLoader = {
		CreateModule = function(_, name) return module(modules, name) end,
		ImportModule = function(_, name) return module(modules, name) end,
	},
	Questie = Questie,
	UnitFactionGroup = function() return "Alliance" end,
	GetCVarBool = function() return false end,
	SetCVar = function() end,
	print = function() end,
	date = os.date,
	time = os.time,
}, { __index = _G })

local function run(path)
	local chunk = assert(loadfile(root .. "/" .. path))
	setfenv(chunk, sandbox)
	return chunk("Questie", {})
end

-- Hidden quests, NPCs, items --------------------------------------------------------------------------------------

run("Database/Corrections/QuestieQuestBlacklist.lua")
run("Database/Corrections/QuestieNPCBlacklist.lua")
run("Database/Corrections/QuestieItemBlacklist.lua")

local function list(mod)
	local raw = mod:Load()
	local out = {}
	for id, flag in pairs(raw) do
		if flag == true then out[id] = true
		elseif type(flag) == "string" then out[id] = flag -- "HIDE_ON_MAP": in the quest log, never on the map
		end
	end
	return out
end

local hiddenQuests = list(modules.QuestieQuestBlacklist)
local hiddenNpcs = list(modules.QuestieNPCBlacklist)
local hiddenItems = list(modules.QuestieItemBlacklist)

-- Holidays ---------------------------------------------------------------------------------------------------------

run("Database/Corrections/Holidays/QuestieEvent.lua")
local QuestieEvent = modules.QuestieEvent
local p = io.popen('ls "' .. root .. '/Database/Corrections/Holidays/quests/"')
for file in p:lines() do run("Database/Corrections/Holidays/quests/" .. file) end
p:close()

local eventQuests = {}
for _, q in ipairs(QuestieEvent.eventQuests) do
	if not q[7] then
		-- {event, questID, startDate "d/m", endDate, startTime "h:m", endTime}
		eventQuests[#eventQuests + 1] = { q[1], q[2], q[3], q[4], q[5], q[6] }
	end
end

local eventDates = {}
for name, dates in pairs(QuestieEvent.eventDates) do eventDates[name] = dates end
for name, dates in pairs(QuestieEvent.eventDateCorrections.CLASSIC or {}) do
	if dates == false then eventDates[name] = false else eventDates[name] = dates end
end

-- Darkmoon Faire: where its NPCs stand in each of its two places (Questie's NPC fields, applied by convert.py).
run("Database/Corrections/QuestiePolicy/classicPolicyCorrections.lua")
local policy = modules.QuestieClassicPolicyCorrections
local darkmoon = {
	mulgore = policy:LoadDarkmoonFixes(true),
	elwynn = policy:LoadDarkmoonFixes(false),
}

-- Townsfolk: Questie's lists of who is who, for WoW: Forever (class trainers by class, mailboxes by faction, meeting
-- stones, weapon masters, profession trainers by profession).
local Townsfolk = module(modules, "Townsfolk")
local professionTrainers = {}
Townsfolk.SetProfessionTrainerIds = function(profession, ids) professionTrainers[profession] = ids end
modules.QuestieProfessions = { professionKeys = Enum.professionKeys, private = {} }
for _, f in ipairs({ "ClassTrainers", "Mailboxes", "MeetingStones", "WeaponTrainers" }) do
	run("Modules/QuestieMenu/" .. f .. ".lua")
end
do
	local p2 = io.popen('ls "' .. root .. '/Modules/QuestieMenu/ProfessionTrainers/"')
	for file in p2:lines() do run("Modules/QuestieMenu/ProfessionTrainers/" .. file) end
	p2:close()
end
local townsfolk = {
	classTrainers = Townsfolk.GetClassTrainers and Townsfolk.GetClassTrainers() or {},
	mailboxes = Townsfolk.GetMailboxes and Townsfolk.GetMailboxes() or {},
	meetingStones = Townsfolk.GetMeetingStones and Townsfolk.GetMeetingStones() or {},
	weaponTrainers = Townsfolk.GetWeaponTrainers and Townsfolk.GetWeaponTrainers() or {},
	professionTrainers = professionTrainers,
}

io.write(encode({
	townsfolk = townsfolk,
	hiddenQuests = hiddenQuests,
	hiddenNpcs = hiddenNpcs,
	hiddenItems = hiddenItems,
	eventQuests = eventQuests,
	eventDates = eventDates,
	lunarFestival = QuestieEvent.lunarFestival and QuestieEvent.lunarFestival.DEFAULT or {},
	darkmoon = darkmoon,
}))
