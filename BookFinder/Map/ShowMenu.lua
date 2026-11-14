-- The world map's own Show dropdown is the menu for what the map shows, drawn in Questie's style (UI/Dropdown.lua).
--
-- It holds the game's own entries first (Quest Objectives, Show Quest Levels, Quest Difficulty Color, Low-Level
-- Quests, Tracked Items, and anything another addon adds there), each doing exactly what the game's does; then every
-- map item of BookFinder, each once, in one flat list in Questie's order with its icon at the right (docs/NOTES.md 1).
-- Only Dungeons has its own section. Not in it: searches, journeys, options.
--
-- The game's button is never changed: a clear button lies over it and takes the click. The game's entries are read
-- from the menu that button would open (its generator, run into a menu description the way the game runs it). The
-- map has more than one such button (the floor picker is one too): the Show button is the one whose menu is tagged
-- MENU_WORLD_MAP_TRACKING. If the game's entries can't be read, the first line opens the game's own menu instead.

local _, BF = ...
local L = BF.L

local ShowMenu = {}
BF.ShowMenu = ShowMenu

local TAG = "MENU_WORLD_MAP_TRACKING"

-- The game's own entries ---------------------------------------------------------------------------------------------

local function describe(button)
	if not (MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants and Menu and Menu.PopulateDescription) then return nil end
	local generator = button.menuGenerator
	if type(generator) ~= "function" then return nil end
	local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
	local ok = pcall(Menu.PopulateDescription, generator, button, root)
	if not ok then return nil end
	return root
end

local function tagOf(desc)
	if not desc then return nil end
	if desc.GetTag then
		local ok, tag = pcall(desc.GetTag, desc)
		if ok then return tag end
	end
	return desc.tag
end

local function elements(desc)
	local list = {}
	if desc and desc.EnumerateElementDescriptions then
		for _, element in desc:EnumerateElementDescriptions() do list[#list + 1] = element end
	end
	return list
end

local function textOf(element)
	local ok, t = pcall(function() return MenuUtil.GetElementText and MenuUtil.GetElementText(element) end)
	return ok and t or ""
end

-- The element's own click, as the game's menu runs it.
local function picker(element)
	if type(element.Pick) == "function" then
		return function() element:Pick(MenuInputContext and MenuInputContext.MouseButton or 1, "LeftButton") end
	end
end

local function convert(desc, depth)
	local items = {}
	if depth > 3 then return items end
	for _, element in ipairs(elements(desc)) do
		local text = textOf(element)
		local subs = elements(element)
		local okSel, selected = false, nil
		if element.IsSelected then okSel, selected = pcall(element.IsSelected, element) end
		local pick = picker(element)
		if text == "" then
			items[#items + 1] = { divider = true }
		elseif #subs > 0 then
			items[#items + 1] = { text = text, submenu = convert(element, depth + 1) }
		elseif pick and okSel and type(selected) == "boolean" then
			items[#items + 1] = {
				text = text,
				checked = function() local ok, v = pcall(element.IsSelected, element) return ok and v end,
				onClick = pick,
			}
		elseif pick then
			items[#items + 1] = { text = text, onClick = pick }
		else
			items[#items + 1] = { text = text, title = true }
		end
	end
	return items
end

-- BookFinder's map items ---------------------------------------------------------------------------------------------

local function switch(text, key, icon, extra)
	local item = {
		text = L[text], icon = icon,
		checked = function() return BF:Get(key) end,
		onClick = function(_, on) BF:Set(key, on) end,
	}
	if extra then for k, v in pairs(extra) do item[k] = v end end
	return item
end

local function townsfolkKind(kind)
	return switch(kind.label, "townsfolk." .. kind.key, kind.icon)
end

local function professionItems()
	local items = {
		{
			text = L["Known Professions"],
			checked = function() return BF:Get("townsfolk.knownProfessions") end,
			onClick = function(_, on) BF:Set("townsfolk.knownProfessions", on) end,
		},
		{ divider = true },
	}
	local list = {}
	for _, skill in ipairs(BF.Townsfolk.professions) do
		list[#list + 1] = { skill = skill, name = BF.Player:SkillName(skill) or tostring(skill) }
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	for _, p in ipairs(list) do
		items[#items + 1] = {
			text = p.name, icon = "professionTrainer",
			checked = function() return BF:Get("townsfolk.profession." .. p.skill) end,
			onClick = function(_, on) BF:Set("townsfolk.profession." .. p.skill, on) end,
			disabled = function() return BF:Get("townsfolk.knownProfessions") end,
		}
	end
	return items
end

local function vendorItems()
	local items = {}
	for _, kind in ipairs(BF.Townsfolk.vendorKinds) do
		if BF.Townsfolk:Applies(kind) then
			items[#items + 1] = switch(kind.label, "townsfolk.vendor." .. kind.key, kind.icon)
		end
	end
	return items
end

--- BookFinder's items for the Show dropdown, in order. Other parts add theirs with ShowMenu:Add (dungeons, places,
--- people): each map item exists once.
local extraItems = {}   -- { order =, item = } or { order =, section = "Dungeons", items = fn }
function ShowMenu:Add(order, item)
	extraItems[#extraItems + 1] = { order = order, item = item }
	table.sort(extraItems, function(a, b) return a.order < b.order end)
end

function ShowMenu:Items()
	local items = {}
	local function add(i) items[#items + 1] = i end
	-- Townsfolk, in Questie's order (those that apply to this character).
	for _, kind in ipairs(BF.Townsfolk.kinds) do
		if BF.Townsfolk:Applies(kind) and kind.key ~= "stableMaster" and kind.key ~= "rare" then add(townsfolkKind(kind)) end
	end
	-- The quest icons.
	add(switch("Available Quest", "quests.available", "available"))
	add({
		text = L["Trivial Quest"], icon = "availableTrivial",
		checked = function() return BF:Get("quests.lowLevel") ~= "hide" end,
		onClick = function(_, on) BF:Set("quests.lowLevel", on and "all" or "hide") end,
	})
	add(switch("Objective", "quests.objectives", "slay"))
	add({ text = L["Profession Trainers"], icon = "professionTrainer", submenu = professionItems })
	add({ text = L["Vendor"], icon = "vendor", submenu = vendorItems })
	-- OpenMap's map items that Questie's list lacks, then the books.
	for _, kind in ipairs(BF.Townsfolk.kinds) do
		if kind.key == "stableMaster" or kind.key == "rare" then add(townsfolkKind(kind)) end
	end
	add(switch("Library books", "books.map", "book"))
	for _, e in ipairs(extraItems) do
		local item = type(e.item) == "function" and e.item() or e.item
		if item then
			if item.section then
				add({ divider = true })
				add({ text = L[item.section], title = true })
				for _, i in ipairs(type(item.items) == "function" and item.items() or item.items) do add(i) end
			else
				add(item)
			end
		end
	end
	return items
end

-- The button -------------------------------------------------------------------------------------------------------

local cover, gameButton

--- The game's Show button: its own mixin says so, else the menu it builds carries the tracking menu's tag.
local function findButton()
	local map = WorldMapFrame
	if not map then return nil end
	local mixin = rawget(_G, "WorldMapTrackingOptionsButtonMixin")
	for _, f in ipairs(map.overlayFrames or {}) do
		if mixin and f.OnMouseDown and f.OnMouseDown == mixin.OnMouseDown then return f end
	end
	for _, f in ipairs(map.overlayFrames or {}) do
		if f.menuGenerator and tagOf(describe(f)) == TAG then return f end
	end
	return nil
end

local function open()
	local items = {}
	local game = convert(describe(gameButton), 1)
	if #game > 0 then
		for _, i in ipairs(game) do items[#items + 1] = i end
	else
		-- The game's entries couldn't be read: its own menu, a click away, rather than lost.
		items[1] = { text = L["Game map filters..."], onClick = function()
			BF:After(0, function() if gameButton.OpenMenu then gameButton:OpenMenu() end end)
		end }
	end
	items[#items + 1] = { divider = true }
	for _, i in ipairs(ShowMenu:Items()) do items[#items + 1] = i end
	BF.Dropdown:Open(cover, items)
end

local function install()
	if cover then return true end
	gameButton = findButton()
	if not gameButton then return false end
	cover = CreateFrame("Button", "BookFinderMapShowButton", gameButton)
	cover:SetAllPoints(gameButton)
	cover:EnableMouse(true) -- the click (and the press that would open the game's menu) is ours
	cover:SetFrameLevel(gameButton:GetFrameLevel() + 5)
	cover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cover:SetScript("OnClick", open)
	-- The game's button still lights up under the pointer, and keeps its own tooltip.
	cover:SetScript("OnEnter", function()
		if gameButton.LockHighlight then gameButton:LockHighlight() end
		local onEnter = gameButton:GetScript("OnEnter")
		if onEnter then pcall(onEnter, gameButton) end
	end)
	cover:SetScript("OnLeave", function()
		if gameButton.UnlockHighlight then gameButton:UnlockHighlight() end
		local onLeave = gameButton:GetScript("OnLeave")
		if onLeave then pcall(onLeave, gameButton) end
	end)
	-- The game's reset badge (the red cross) stays clickable above the cover.
	if gameButton.ResetButton and gameButton.ResetButton.SetFrameLevel then
		gameButton.ResetButton:SetFrameLevel(cover:GetFrameLevel() + 2)
	end
	return true
end

ShowMenu.Install, ShowMenu.FindButton = install, findButton

BF:At("login", function()
	if not install() and WorldMapFrame then
		-- The map's buttons are made with the map: tried again each time it opens until found.
		WorldMapFrame:HookScript("OnShow", function() if not cover then install() end end)
	end
end, 80)
