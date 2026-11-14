-- Townsfolk: innkeepers, mailboxes, trainers, vendors and the rest, as marks on the world map and the minimap.
--
-- Who is who comes from the data: the NPCs' flags (innkeeper, banker, flight master...), Questie's lists for WoW:
-- Forever (class trainers by class, profession trainers by profession, weapon masters, mailboxes), objects by name
-- (moonwells, meeting stones), and what vendors sell (Data/TownsfolkItems.lua). Only those friendly to the player.
-- Each kind is a switch in the map's Show dropdown (Map/ShowMenu.lua), with Questie's defaults.
--
-- A spot that is also a quest mark keeps the quest's icon; the townsfolk kind joins its tooltip.

local _, BF = ...
local L = BF.L

local Townsfolk = {}
BF.Townsfolk = Townsfolk

local Data, Marks, Zones = BF.Data, BF.Marks, BF.Zones
local N, O, I = BF.N, BF.O, BF.I

-- The kinds, in the Show dropdown's order: key, label, icon kind (Map/Icons.lua), default.
Townsfolk.kinds = {
	{ key = "repair", label = "Repair", icon = "repair", default = false },
	{ key = "innkeeper", label = "Innkeeper", icon = "innkeeper", default = true },
	{ key = "mailbox", label = "Mailbox", icon = "mailbox", default = true },
	{ key = "classTrainer", label = "Class Trainer", icon = "classTrainer", default = false },
	{ key = "weaponMaster", label = "Weapon Master", icon = "weaponMaster", default = false },
	{ key = "auctioneer", label = "Auctioneer", icon = "auctioneer", default = false },
	{ key = "banker", label = "Banker", icon = "banker", default = false },
	{ key = "flightMaster", label = "Flight Master", icon = "flightMaster", default = true },
	{ key = "battlemaster", label = "Battlemaster", icon = "battlemaster", default = false },
	{ key = "portalTrainer", label = "Portal Trainer", icon = "portalTrainer", default = false, class = "MAGE" },
	{ key = "barber", label = "Barber", icon = "barber", default = false, flag = "BARBER" },
	{ key = "transmogrifier", label = "Transmogrifier", icon = "transmogrifier", default = false, flag = "TRANSMOGRIFIER" },
	{ key = "spiritHealer", label = "Spirit Healer", icon = "spiritHealer", default = false },
	{ key = "moonwell", label = "Moonwell", icon = "moonwell", default = false },
	{ key = "meetingStone", label = "Meeting Stones", icon = "meetingStone", default = true },
	{ key = "stableMaster", label = "Stable Master", icon = "stableMaster", default = false },
	{ key = "rare", label = "Rare mobs", icon = "rare", default = false },
}

-- Vendor kinds (the "Vendor" submenu), by what they sell.
Townsfolk.vendorKinds = {
	{ key = "food", label = "Food", icon = "food", levelled = true },
	{ key = "drink", label = "Drink", icon = "food", levelled = true },
	{ key = "ammo", label = "Ammo", icon = "ammo", levelled = true },
	{ key = "bags", label = "Bags", icon = "vendor" },
	{ key = "tradeGoods", label = "Trade Goods", icon = "vendor" },
	{ key = "reagents", label = "Reagents", icon = "reagents" },
	{ key = "poisons", label = "Poisons", icon = "poisons", class = "ROGUE" },
	{ key = "potions", label = "Potions", icon = "vendor" },
}

-- Professions (the "Profession Trainers" submenu): skill ID, English name (the client's name is shown).
Townsfolk.professions = { 129, 164, 165, 171, 182, 185, 186, 197, 202, 333, 356, 393 }

local S = BF.Settings
for _, k in ipairs(Townsfolk.kinds) do
	S:Define("townsfolk." .. k.key, { default = k.default, page = "Map/Show", label = k.label })
end
for _, k in ipairs(Townsfolk.vendorKinds) do
	S:Define("townsfolk.vendor." .. k.key, { default = false, page = "Map/Show", label = k.label })
end
for _, id in ipairs(Townsfolk.professions) do
	S:Define("townsfolk.profession." .. id, { default = false, page = "Map/Show", label = "Profession " .. id })
end
S:Define("townsfolk.knownProfessions", { default = false, page = "Map/Show", label = "Known Professions" })

-- Who is friendly --------------------------------------------------------------------------------------------------

local function npcFriendly(npc)
	local row = BF:Npc(npc)
	if not row or Data.hiddenNpcs[npc] then return false end
	return BF.Player:FriendlyTo(row[N.friendlyTo])
end

-- An object's faction template says which groups it is hostile to (2 Alliance, 4 Horde): one hostile to the player's
-- side is left out (a mailbox in an enemy town).
local function objectFriendly(object)
	local row = BF:Object(object)
	if not row then return false end
	local template = row[O.faction]
	local enemies = template and Data.factionTemplate[template]
	if not enemies then return true end
	local mine = BF.Player.faction == "Horde" and 4 or 2
	return enemies % (mine * 2) < mine
end

local function hasFlag(npc, flagValue)
	local row = BF:Npc(npc)
	local flags = row and row[N.flags]
	return flags and flags % (flagValue * 2) >= flagValue
end

-- The sets, per character (worked out once a session, and when the level or professions change) -------------------

local sets = {} -- [kind key] = { npc = {[id] = true}, object = {[id] = true} }

local function add(kind, type, id)
	local set = sets[kind]
	if not set then
		set = { npc = {}, object = {} }
		sets[kind] = set
	end
	set[type][id] = true
end

local flagKinds = {
	repair = "REPAIR", innkeeper = "INNKEEPER", auctioneer = "AUCTIONEER", banker = "BANKER",
	flightMaster = "FLIGHT_MASTER", battlemaster = "BATTLEMASTER", barber = "BARBER",
	transmogrifier = "TRANSMOGRIFIER", spiritHealer = "SPIRIT_HEALER", stableMaster = "STABLEMASTER",
}

local function vendorsOf(items, levelled, kind)
	local level = BF.Player.level or 1
	for _, item in ipairs(items or {}) do
		local row = BF:Item(item)
		local need = row and row[I.requiredLevel]
		if row and (not levelled or not need or (need <= level and need >= level - 20)) then
			for _, npc in ipairs(row[I.vendors] or {}) do
				if npcFriendly(npc) and hasFlag(npc, Data.npcFlags.VENDOR) then add(kind, "npc", npc) end
			end
		end
	end
end

local function buildSets()
	wipe(sets)
	local class = BF.Player.class
	-- By NPC flags, rank: one pass over every NPC.
	for id in BF:AllIDs("npcs") do
		local row = BF:Npc(id)
		local flags = row and row[N.flags]
		if flags and flags > 0 and npcFriendly(id) then
			for kind, flagName in pairs(flagKinds) do
				local v = Data.npcFlags[flagName]
				if v and flags % (v * 2) >= v then add(kind, "npc", id) end
			end
		end
		if row and (row[N.rank] == 2 or row[N.rank] == 4) and not Data.hiddenNpcs[id] then add("rare", "npc", id) end
	end
	-- From the lists.
	local lists = Data.townsfolk
	for _, id in ipairs(lists.classTrainers[class] or {}) do if npcFriendly(id) then add("classTrainer", "npc", id) end end
	for _, id in ipairs(lists.weaponTrainers or {}) do if npcFriendly(id) then add("weaponMaster", "npc", id) end end
	for _, id in ipairs(lists.mailboxes or {}) do if objectFriendly(id) then add("mailbox", "object", id) end end
	for skill, ids in pairs(lists.professionTrainers or {}) do
		for _, id in ipairs(ids) do if npcFriendly(id) then add("profession." .. skill, "npc", id) end end
	end
	if class == "MAGE" then
		for _, id in ipairs(Data.townsfolkItems.portalTrainers) do if npcFriendly(id) then add("portalTrainer", "npc", id) end end
	end
	-- Objects by name.
	for id in BF:AllIDs("objects") do
		local name = BF:ObjectName(id)
		if name then
			if name == "Meeting Stone" then
				add("meetingStone", "object", id)
			elseif name:find("Moonwell$") and not name:find("^Corrupt") then
				add("moonwell", "object", id)
			end
		end
	end
	-- Vendors by what they sell.
	local items = Data.townsfolkItems
	vendorsOf(items.food, true, "vendor.food")
	vendorsOf(items.drink, true, "vendor.drink")
	vendorsOf(items.ammo, true, "vendor.ammo")
	vendorsOf(items.bags, false, "vendor.bags")
	vendorsOf(items.tradeGoods, false, "vendor.tradeGoods")
	vendorsOf(items.potions, false, "vendor.potions")
	vendorsOf(items.reagents[class], false, "vendor.reagents")
	if class == "ROGUE" then vendorsOf(items.poisons, false, "vendor.poisons") end
end

--- Whether a kind applies to this character at all (a portal trainer for a mage, reagents for classes that use them).
function Townsfolk:Applies(kind)
	if kind.class and kind.class ~= BF.Player.class then return false end
	if kind.flag and not Data.npcFlags[kind.flag] then return false end
	if kind.key == "reagents" and not Data.townsfolkItems.reagents[BF.Player.class] then return false end
	return true
end

-- The layer -------------------------------------------------------------------------------------------------------

local function wanted()
	local list = {}
	for _, k in ipairs(Townsfolk.kinds) do
		if BF:Get("townsfolk." .. k.key) and Townsfolk:Applies(k) then list[#list + 1] = { set = k.key, kind = k } end
	end
	for _, k in ipairs(Townsfolk.vendorKinds) do
		if BF:Get("townsfolk.vendor." .. k.key) and Townsfolk:Applies(k) then list[#list + 1] = { set = "vendor." .. k.key, kind = k } end
	end
	local onlyKnown = BF:Get("townsfolk.knownProfessions")
	for _, skill in ipairs(Townsfolk.professions) do
		local on = BF:Get("townsfolk.profession." .. skill)
		if onlyKnown then on = BF.Player:SkillRank(skill) ~= nil end
		if on then
			list[#list + 1] = { set = "profession." .. skill, kind = { key = "profession", label = BF.Player:SkillName(skill), icon = "professionTrainer" } }
		end
	end
	return list
end

local built = false
Marks:RegisterLayer("townsfolk", function(addRole)
	if not built then
		buildSets()
		built = true
	end
	for _, w in ipairs(wanted()) do
		local set = sets[w.set]
		if set then
			local role = { role = "townsfolk", kind = w.kind }
			for type, ids in pairs(set) do
				for id in pairs(ids) do
					local source = { type = type, id = id }
					local spawns = BF.Objectives:Spawns(source)
					Zones:EachSpawn(spawns, function(map, x, y, inside)
						if not inside then addRole(map, x, y, Marks.SpotKey(source, map, x, y), role, source) end
					end)
				end
			end
		end
	end
end)

local rebuild = BF:Debounce(0.2, function() Marks:RebuildLayer("townsfolk") end)
BF:At("login", function()
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key:find("^townsfolk%.") then rebuild() end end)
	BF:Listen("BF_LEVEL_CHANGED", function() built = false rebuild() end)
	BF:Listen("BF_SKILLS_CHANGED", function() if BF:Get("townsfolk.knownProfessions") then rebuild() end end)
end, 61)
