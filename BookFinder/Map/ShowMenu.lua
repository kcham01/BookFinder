-- The map's Show dropdown: every map item of Questie and OpenMap, each once, as one flat list in Questie's layout
-- (tick box, name, icon at the right), with only Dungeons in a section of its own (docs/BUILD.md, "Decisions").
--
-- It takes over the game's own map filter menu (the world map's Show button): pressing the button opens BookFinder's
-- dropdown (UI/Dropdown.lua, the classic tooltip-box dropdown, DESIGN rule 2): the game's own entries are taken out (decided:
-- docs/BUILD.md, "Decisions") and BookFinder's are the menu. Advanced Search, Quests by Zone and by
-- Faction, My Journey and the settings are not in it.
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

-- The menu's items (BF.Dropdown's form) ------------------------------------------------------------------------

local function iconOf(entry)
	if type(entry.icon) == "function" then return entry.icon() end
	return entry.icon
end

local function switchItem(entry)
	return {
		text = entry.translated and entry.label or L[entry.label],
		icon = iconOf(entry),
		checked = function() return ShowMenu:IsChecked(entry) end,
		func = function() ShowMenu:Toggle(entry) end,
	}
end

local function submenuItems(kind)
	local list = {}
	local rows = kind == "professions" and ShowMenu:ProfessionEntries() or ShowMenu:VendorEntries()
	for _, row in ipairs(rows) do list[#list + 1] = switchItem(row) end
	return list
end

--- The whole menu: the "Show:" heading, then every entry that shows, Dungeons under its own heading.
function ShowMenu:Items()
	local items = { { text = L["Show:"], title = true } }
	local pendingSection
	for _, entry in ipairs(ShowMenu.entries) do
		if entry.section then
			pendingSection = entry.section
		elseif ShowMenu:Shows(entry) then
			if pendingSection then
				-- A section heading only over entries that show.
				items[#items + 1] = { divider = true }
				items[#items + 1] = { text = L[pendingSection], title = true }
				pendingSection = nil
			end
			if entry.submenu then
				local kind = entry.submenu
				items[#items + 1] = { text = L[entry.label], icon = iconOf(entry), submenu = function() return submenuItems(kind) end }
			else
				items[#items + 1] = switchItem(entry)
			end
		end
	end
	return items
end

-- If the game's own menu opens all the same, its rows are emptied where the client keeps them (elementDescriptions);
-- the menu is closed for BookFinder's in any case (below).
local function removeGameEntries(root)
	local rows = type(root) == "table" and type(root.elementDescriptions) == "table" and root.elementDescriptions
	if not rows then return false end
	ShowMenu.removed = #rows
	wipe(rows)
	return true
end

-- The button --------------------------------------------------------------------------------------------------
--
-- The map's Show button is the world map's tracking options button, one of the map's overlay frames. In the owner's
-- test it was not found by the one way first tried (its OnLoad), so the game's menu opened with BookFinder's rows
-- under it. Now it is known three ways: a method only its own mixin has (not the floor picker's, the same kind of
-- button), the tag of the menu it builds, or, failing both, the game's menu itself when it opens: BookFinder takes the
-- button then, closes the game's menu and opens its own.
--
-- A clear button lies over the game's and takes the click, so the game's menu is never built: BookFinder's dropdown
-- opens instead, holding only BookFinder's entries (decided: the game's entries go, and its reset badge with them).

-- A menu description that records only its tag: anything else asked of it answers itself.
local function tagRecorder()
	local rec = {}
	local stub = setmetatable({}, { __index = function() return function() return rec.stub end end })
	rec.stub = stub
	rawset(stub, "SetTag", function(_, tag) rec.tag = tag end)
	return rec
end

local function menuTag(frame)
	local generator = rawget(frame, "menuGenerator") or rawget(frame, "generator")
	if type(generator) ~= "function" then return nil end
	local rec = tagRecorder()
	pcall(generator, frame, rec.stub)
	return rec.tag
end

local function ownMethod(frame)
	local mixin = rawget(_G, "WorldMapTrackingOptionsButtonMixin")
	if type(mixin) ~= "table" then return false end
	local other = rawget(_G, "WorldMapFloorNavigationFrameMixin")
	other = type(other) == "table" and other or {}
	for key, fn in pairs(mixin) do
		if type(fn) == "function" and other[key] ~= fn and rawget(frame, key) == fn then return true end
	end
	return false
end

function ShowMenu:FindButton()
	if not WorldMapFrame then return nil end
	local frames = WorldMapFrame.overlayFrames or {}
	for _, frame in ipairs(frames) do
		if type(frame) == "table" and ownMethod(frame) then return frame end
	end
	for _, frame in ipairs(frames) do
		if type(frame) == "table" and menuTag(frame) == TAG then return frame end
	end
end

local function hideReset(button)
	local reset = button.ResetButton
	if type(reset) ~= "table" or not reset.Hide then return end
	reset:Hide()
	if reset.HookScript and not reset.bookFinderHidden then
		reset.bookFinderHidden = true
		reset:HookScript("OnShow", function(self) self:Hide() end)
	end
end

-- The quest log's gear menu --------------------------------------------------------------------------------------
--
-- Beside "Quests: n/40" the game has a second menu, a gear with one entry, "Show Quest Objectives". Decided: it goes too.
-- The gear is hidden and kept hidden; its one switch stays as it is (ticked: the quest log keeps its
-- objective lines).
--
-- Found by the names the client gives it, else among the quest log's menu buttons as the one its parent keeps under a
-- name with "Settings" in it (the Show button is the map's, not the quest log's, so it is never this one).

local function namedGear()
	local q = QuestMapFrame
	local candidates = {
		q and q.QuestsFrame and q.QuestsFrame.SettingsDropdown,
		QuestScrollFrame and QuestScrollFrame.SettingsDropdown,
		q and q.SettingsDropdown,
	}
	for _, f in pairs(candidates) do
		if type(f) == "table" and f.Hide then return f end
	end
end

local function searchGear(frame, depth)
	if depth > 5 or type(frame) ~= "table" or not frame.GetChildren then return nil end
	for _, child in ipairs({ frame:GetChildren() }) do
		if type(child) == "table" and child.SetupMenu then
			for key, value in pairs(frame) do
				if value == child and type(key) == "string" and key:find("Settings") then return child end
			end
		end
		local found = searchGear(child, depth + 1)
		if found then return found end
	end
end

function ShowMenu:FindQuestLogGear()
	return namedGear() or (QuestMapFrame and searchGear(QuestMapFrame, 0))
end

local function ditch(frame)
	frame:Hide()
	if frame.HookScript and not frame.bookFinderHidden then
		frame.bookFinderHidden = true
		frame:HookScript("OnShow", function(self) self:Hide() end)
	end
end

local function open(anchor)
	BF.Dropdown:Toggle(anchor, function() return ShowMenu:Items() end)
end

--- Lays BookFinder's clear button over the game's Show button. True once it is there.
function ShowMenu:Cover(button)
	if ShowMenu.cover then return true end
	if type(button) ~= "table" or not button.GetFrameLevel then return false end
	ShowMenu.button = button
	local cover = CreateFrame("Button", "BookFinderShowButton", button)
	cover:SetAllPoints(button)
	cover:EnableMouse(true)
	cover:SetFrameLevel(button:GetFrameLevel() + 5)
	cover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cover:SetScript("OnClick", function() open(button) end)
	-- The game's button still lights under the pointer and keeps its tooltip.
	cover:SetScript("OnEnter", function()
		if button.LockHighlight then button:LockHighlight() end
		local onEnter = button:GetScript("OnEnter")
		if onEnter then pcall(onEnter, button) end
	end)
	cover:SetScript("OnLeave", function()
		if button.UnlockHighlight then button:UnlockHighlight() end
		local onLeave = button:GetScript("OnLeave")
		if onLeave then pcall(onLeave, button) end
	end)
	ShowMenu.cover = cover
	hideReset(button)
	return true
end

local function closeGameMenus()
	local manager = Menu and Menu.GetManager and Menu.GetManager()
	if manager and manager.CloseMenus then pcall(manager.CloseMenus, manager) end
end

BF:At("login", function()
	if not ShowMenu:Cover(ShowMenu:FindButton()) and WorldMapFrame and WorldMapFrame.HookScript then
		-- The map's buttons are made with the map: looked for again each time it opens.
		WorldMapFrame:HookScript("OnShow", function()
			if not ShowMenu.cover then ShowMenu:Cover(ShowMenu:FindButton()) end
		end)
	end
	-- Last way: the game's menu opened all the same. Its rows are emptied, the button that opened it is covered, and
	-- the game's menu gives way to BookFinder's on the next frame.
	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu(TAG, function(owner, root)
			removeGameEntries(root)
			ShowMenu:Cover(owner)
			BF:After(0, function()
				closeGameMenus()
				if not BF.Dropdown:IsOpen(owner) then open(owner) end
			end)
		end)
	end
	local gear = ShowMenu:FindQuestLogGear()
	if gear then
		ShowMenu.questLogGear = gear
		ditch(gear)
	end
end, 75)
