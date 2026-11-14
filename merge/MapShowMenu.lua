-- BookFinder: the world map's own Show dropdown is the menu for what the map shows, drawn in Questie's style.
--
-- It holds, in this order: the game's own entries (Quest Objectives, Show Quest Levels, Quest Difficulty Color,
-- Low-Level Quests, Tracked Items, and whatever another addon adds to that menu), each still doing exactly what the
-- game's did; then every BookFinder switch for what the map shows: quest icons, places, dungeons, townsfolk, people
-- and the library books (Options.lua's "map" section, in its groups). Those switches are here only, not in the
-- settings window.
--
-- The game's button is never changed: a clear button of BookFinder's lies over it and takes the click. The game's
-- entries are read from the menu the button would open (its generator, run into a description as the game runs it).
-- The map has more than one dropdown button (the floor picker is one too), so the Show button is the one whose menu
-- is the tracking menu.
local _, root = ...
local public = root.public
if not public then return end

local TAG = "MENU_WORLD_MAP_TRACKING"

local function children(desc)
	local list = {}
	if desc and desc.EnumerateElementDescriptions then
		for _, element in desc:EnumerateElementDescriptions() do list[#list + 1] = element end
	end
	return list
end

local function text(element)
	local t = MenuUtil and MenuUtil.GetElementText and MenuUtil.GetElementText(element)
	if t == nil then t = element.text end
	return t ~= nil and tostring(t) or ""
end

-- the game's menu description, as the button would build it when opened
local function build(button)
	if not (MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants and Menu and Menu.PopulateDescription) then return end
	local generator = button.menuGenerator
	if type(generator) ~= "function" then return end
	local rootDescription = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
	Menu.PopulateDescription(generator, button, rootDescription)
	return rootDescription
end

local function tagOf(desc)
	if not desc then return nil end
	local ok, tag = pcall(function() return desc.GetTag and desc:GetTag() or desc.tag end)
	return ok and tag or nil
end

-- The Show button: the game's own mixin says so, else the menu it builds carries the tracking menu's tag
local found
local function findButton()
	if found then return found end
	local map = WorldMapFrame
	if not map then return end
	local mixin = rawget(_G, "WorldMapTrackingOptionsButtonMixin")
	local candidates = {}
	for _, f in ipairs(map.overlayFrames or {}) do
		if type(f) == "table" and f.OpenMenu then
			if mixin and f.OnLoad and f.OnLoad == mixin.OnLoad then found = f return f end
			candidates[#candidates + 1] = f
		end
	end
	for _, f in ipairs(candidates) do
		local ok, desc = pcall(build, f)
		if ok and tagOf(desc) == TAG then found = f return f end
	end
end

-- An element's own click, as the game's menu would run it; nil for one that does nothing when clicked (a title: every
-- element has the Pick method, only a clickable one has something for it to run)
local function picker(element)
	local okR, has = pcall(function()
		return element.responder ~= nil or element.isSelected ~= nil or element.setSelected ~= nil
			or (element.HasResponder and element:HasResponder()) or false
	end)
	if not (okR and has) then return nil end
	if type(element.Pick) == "function" then
		return function() element:Pick(MenuInputContext and MenuInputContext.MouseButton or 1, "LeftButton") end
	end
	local responder = element.responder or element.onClick
	if type(responder) == "function" then
		return function() responder(element.data, { context = 1, buttonName = "LeftButton" }, nil) end
	end
end

-- The game's elements, into Menu.lua's builder calls; how many could be clicked
local function convert(desc, menu, depth)
	if depth > 3 then return 0 end
	local n = 0
	for _, element in ipairs(children(desc)) do
		local label = text(element)
		local subs = children(element)
		local okSel, selected = false, nil
		if element.IsSelected then okSel, selected = pcall(element.IsSelected, element) end
		local pick = picker(element)
		if label == "" then
			menu:CreateDivider()
		elseif #subs > 0 then
			n = n + convert(element, menu:CreateSubmenu(label), depth + 1)
		elseif pick and okSel and type(selected) == "boolean" then
			menu:CreateCheckbox(label, function() local ok, v = pcall(element.IsSelected, element) return ok and v end, pick)
			n = n + 1
		elseif pick then
			menu:CreateButton(label, pick)
			n = n + 1
		else
			menu:CreateTitle(label)
		end
	end
	return n
end

-- BookFinder's switches for what the map shows, in their groups; a long group is a submenu
local INLINE = 4
local function ours(menu)
	local O = public.Options
	if not O then return end
	for _, g in ipairs(O.Section("map")) do
		local target = menu
		if #g.entries > INLINE then
			target = menu:CreateSubmenu(g.label)
		else
			if g.label ~= "" then menu:CreateTitle(g.label) end
		end
		for _, e in ipairs(g.entries) do
			if e.kind == "toggle" then
				target:CreateCheckbox(e.label, function() local ok, v = pcall(e.get) return ok and v and true or false end,
					function() local ok, err = pcall(e.set, not (select(2, pcall(e.get)))) if not ok and geterrorhandler then geterrorhandler()(err) end end)
			elseif e.kind == "button" then
				target:CreateButton(e.label, function() pcall(e.run) end)
			elseif e.kind == "choice" then
				local sub = target:CreateSubmenu(e.label)
				local okC, list = pcall(e.choices)
				for _, c in ipairs(okC and list or {}) do
					sub:CreateCheckbox(tostring(c.label), function() local ok, v = pcall(e.get) return ok and v == c.value end,
						function() pcall(e.set, c.value) end)
				end
			end
		end
	end
end

local readable = nil   -- whether the game's entries could be read, the last time
local function fill(button, menu)
	local okBuild, desc = pcall(build, button)
	local n = 0
	if okBuild and desc then
		local okConv, count = pcall(convert, desc, menu, 0)
		n = okConv and count or 0
	end
	readable = n > 0
	if not readable then
		-- (the game's own entries couldn't be read here: its menu, a click away, rather than lost)
		menu:CreateButton("Game map filters…", function() C_Timer.After(0, function() button:OpenMenu() end) end)
	end
	menu:CreateDivider()
	ours(menu)
end

local cover
local function install()
	if cover then return true end
	local button = findButton()
	if not button then return false end
	cover = CreateFrame("Button", "BookFinderMapShowButton", button)
	cover:SetAllPoints(button)
	cover:SetFrameLevel(button:GetFrameLevel() + 5)
	cover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cover:SetScript("OnClick", function(self)
		public.ContextMenu(self, function(_, menu) fill(button, menu) end)
	end)
	-- (the game's button still lights up under the pointer, and keeps its own tooltip)
	cover:SetScript("OnEnter", function()
		if button.LockHighlight then button:LockHighlight() end
		local onEnter = button:GetScript("OnEnter") if onEnter then pcall(onEnter, button) end
	end)
	cover:SetScript("OnLeave", function()
		if button.UnlockHighlight then button:UnlockHighlight() end
		local onLeave = button:GetScript("OnLeave") if onLeave then pcall(onLeave, button) end
	end)
	-- (the game's reset badge, the red ×, stays clickable above the cover)
	if button.ResetButton and button.ResetButton.SetFrameLevel then button.ResetButton:SetFrameLevel(cover:GetFrameLevel() + 2) end
	return true
end

-- the overlay buttons are made with the map; tried again whenever it opens until one is found
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function()
		install()
		if WorldMapFrame then WorldMapFrame:HookScript("OnShow", function() if not cover then install() end end) end
	end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() C_Timer.After(1, install) end)

-- for the self-test and the offline test
public.MapShowMenu = {
	Install = install, Find = findButton, Cover = function() return cover end, Readable = function() return readable end,
	Count = function()
		local button = findButton()
		if not button then return 0 end
		local m = public.MenuTest.NewList()
		local ok, desc = pcall(build, button)
		if not (ok and desc) then return 0 end
		local okC, n = pcall(convert, desc, m, 0)
		return okC and n or 0
	end,
	Convert = convert, Ours = ours,
}
