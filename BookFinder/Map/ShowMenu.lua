-- The map's Show dropdown: every map item of Questie and OpenMap, each once, as one flat list in Questie's layout
-- (tick box, name, icon at the right), with only Dungeons in a section of its own (docs/NOTES.md, section 1).
--
-- It goes into the game's own map filter menu (the world map's Show button), below the game's entries, through the
-- client's menu system (Menu.ModifyMenu on the menu's tag). Advanced Search, Quests by Zone and by Faction, My Journey
-- and the settings are not in it.
--
-- The list below is the whole menu in its order. An entry shows only once its setting exists: a part of BookFinder
-- not built yet (dungeon maps, boats, people...) defines its setting when it is, and its entry appears then; nothing
-- here is a switch for something that does not exist.

local _, BF = ...
local L = BF.L

local ShowMenu = {}
BF.ShowMenu = ShowMenu

local Icons, Townsfolk = BF.Icons, BF.Townsfolk
local S = BF.Settings

local TAG = "MENU_WORLD_MAP_TRACKING"

-- Entries ---------------------------------------------------------------------------------------------------------
--   { key = setting, label =, icon = Icons kind or function }    a tick box
--   { label =, icon =, submenu = function(description) }         a submenu (▸)
--   { section = label }                                          a section heading (Dungeons only)
--   on/off/checked: for settings that are not plain true/false (the low-level quest style).

local function townsfolk(key)
	for _, k in ipairs(Townsfolk.kinds) do
		if k.key == key then return { key = "townsfolk." .. key, label = k.label, icon = k.icon, kind = k } end
	end
end

local function objectiveIcon() return Icons:ObjectiveKind("slay") end

ShowMenu.entries = {
	-- Questie's townsfolk, in Questie's order (OpenMap's same items folded in: Vendors, Repair, Innkeepers, Bankers,
	-- Mailboxes, Auctioneers, Class trainers, Profession trainers, Spirit healers, Flight masters).
	townsfolk("repair"), townsfolk("innkeeper"), townsfolk("mailbox"), townsfolk("classTrainer"),
	townsfolk("weaponMaster"), townsfolk("auctioneer"), townsfolk("banker"), townsfolk("flightMaster"),
	townsfolk("battlemaster"), townsfolk("portalTrainer"), townsfolk("barber"), townsfolk("transmogrifier"),
	townsfolk("spiritHealer"), townsfolk("moonwell"), townsfolk("meetingStone"),
	-- OpenMap's townsfolk Questie's menu lacks.
	townsfolk("stableMaster"), townsfolk("rare"),
	-- Quests.
	{ key = "quests.available", label = "Available Quest", icon = "available" },
	{ key = "quests.lowLevel", label = "Trivial Quest", icon = "availableTrivial",
		checked = function() return BF:Get("quests.lowLevel") ~= "hide" end,
		set = function(on) BF:Set("quests.lowLevel", on and "all" or "hide") end },
	{ key = "quests.objectives", label = "Objective", icon = objectiveIcon },
	{ label = "Profession Trainers", icon = "professionTrainer", submenu = "professions" },
	{ label = "Vendor", icon = "vendor", submenu = "vendors" },
	-- OpenMap's places.
	{ key = "map.boats", label = "Boats", icon = "boat" },
	{ key = "map.zeppelins", label = "Zeppelins", icon = "zeppelin" },
	{ key = "map.transportRoutes", label = "Boat and zeppelin routes", icon = "boat" },
	{ key = "map.onlyFound", label = "Only places you've found", icon = "explored" },
	{ key = "map.playerArrow", label = "Your arrow", icon = "playerArrow" },
	{ key = "map.groupMembers", label = "Party and raid members", icon = "groupMember" },
	{ key = "map.friends", label = "Friends on the map", icon = "friend" },
	{ key = "map.guild", label = "Guild members on the map", icon = "guild" },
	{ key = "map.drawings", label = "Your drawings", icon = "quill" },
	{ key = "quests.everyZone", label = "Quests from every zone", icon = "available" },
	{ key = "map.fadeWhileZooming", label = "Fade icons while zooming", icon = "fade" },
	-- Dungeons: the one section.
	{ section = "Dungeons" },
	{ key = "map.dungeons", label = "Dungeons and raids", icon = "dungeon" },
	{ key = "map.dungeonMaps", label = "Dungeon maps", icon = "dungeon" },
	{ key = "map.dungeonLevels", label = "Level ranges", icon = "dungeon" },
	{ key = "map.dungeonBosses", label = "Dungeon bosses", icon = "boss" },
	{ key = "quests.dungeon", label = "Dungeon quests", icon = "available" },
	{ key = "map.dungeonJournal", label = "Entrances open Dungeon Journal", icon = "dungeon" },
}

--- Whether an entry belongs in the menu now (its setting exists, it applies to this character).
function ShowMenu:Shows(entry)
	if entry.section then return true end
	if entry.submenu then return true end
	if not S:Definition(entry.key) then return false end
	if entry.kind and not Townsfolk:Applies(entry.kind) then return false end
	return true
end

function ShowMenu:IsChecked(entry)
	if entry.checked then return entry.checked() end
	return BF:Get(entry.key) == true
end

function ShowMenu:Toggle(entry)
	local on = not ShowMenu:IsChecked(entry)
	if entry.set then entry.set(on) else BF:Set(entry.key, on) end
end

-- Submenus ----------------------------------------------------------------------------------------------------

--- The professions submenu's rows: "Known Professions", then each profession by the client's name.
function ShowMenu:ProfessionEntries()
	local list = { { key = "townsfolk.knownProfessions", label = "Known Professions", icon = "professionTrainer" } }
	local rows = {}
	for _, skill in ipairs(Townsfolk.professions) do
		rows[#rows + 1] = { key = "townsfolk.profession." .. skill, label = BF.Player:SkillName(skill) or tostring(skill),
			icon = "professionTrainer", translated = true }
	end
	table.sort(rows, function(a, b) return a.label < b.label end)
	for _, r in ipairs(rows) do list[#list + 1] = r end
	return list
end

--- The vendor submenu's rows: the kinds that apply to this character (reagents for classes that use them...).
function ShowMenu:VendorEntries()
	local list = {}
	for _, k in ipairs(Townsfolk.vendorKinds) do
		if Townsfolk:Applies(k) then list[#list + 1] = { key = "townsfolk.vendor." .. k.key, label = k.label, icon = k.icon } end
	end
	return list
end

-- Building the menu (the client's Menu API) --------------------------------------------------------------------

local ICON_SIZE = 16

local function iconOf(entry)
	if type(entry.icon) == "function" then return entry.icon() end
	return entry.icon
end

-- The icon at the right of a row, in the game's own art.
local function withIcon(description, entry)
	local kind = iconOf(entry)
	if not kind or not Icons.kinds[kind] or not description.AddInitializer then return end
	description:AddInitializer(function(button)
		local t = button:AttachTexture()
		t:SetSize(ICON_SIZE, ICON_SIZE)
		t:SetPoint("RIGHT")
		Icons:Apply(t, kind)
		if button.fontString then
			-- Room for the icon: the row grows rather than the text running under it.
			button.fontString:SetPoint("RIGHT", t, "LEFT", -4, 0)
		end
		return ICON_SIZE + 4
	end)
end

local function keepOpen(description)
	if description.SetResponse and MenuResponse then description:SetResponse(MenuResponse.Refresh) end
end

local function addCheckbox(parent, entry)
	local label = entry.translated and entry.label or L[entry.label]
	local cb = parent:CreateCheckbox(label,
		function() return ShowMenu:IsChecked(entry) end,
		function() ShowMenu:Toggle(entry) end)
	keepOpen(cb)
	withIcon(cb, entry)
	return cb
end

local function addSubmenu(parent, entry)
	local button = parent:CreateButton(L[entry.label])
	withIcon(button, entry)
	local rows = entry.submenu == "professions" and ShowMenu:ProfessionEntries() or ShowMenu:VendorEntries()
	for _, row in ipairs(rows) do addCheckbox(button, row) end
	return button
end

--- Puts BookFinder's entries into a menu description (the game's map filter menu, below its own entries).
function ShowMenu:Fill(root)
	root:CreateDivider()
	local pendingSection
	for _, entry in ipairs(ShowMenu.entries) do
		if entry.section then
			pendingSection = entry.section
		elseif ShowMenu:Shows(entry) then
			if pendingSection then
				-- A section heading only over entries that show.
				root:CreateDivider()
				root:CreateTitle(L[pendingSection])
				pendingSection = nil
			end
			if entry.submenu then addSubmenu(root, entry) else addCheckbox(root, entry) end
		end
	end
end

BF:At("login", function()
	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu(TAG, function(_, root) ShowMenu:Fill(root) end)
	end
end, 75)
