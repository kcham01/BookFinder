-- BookFinder: the world map's own Show dropdown, drawn in Questie's style.
--
-- The map's filter button (the game's MENU_WORLD_MAP_TRACKING: Quest Objectives, Show Quest Levels, Quest Difficulty
-- Color, Low-Level Quests, Tracked Items, and whatever another addon adds to it) keeps every entry and what each does.
-- Only the drawing changes: a click on the button builds the game's own menu description, as the game would, and
-- BookFinder.ContextMenu (Menu.lua) draws it with Questie's dropdown library. Each entry's click is the game's own
-- (the description's Pick), so a switch does exactly what it did in the game's menu.
--
-- The button itself is never changed: a clear button of BookFinder's lies over it and takes the click. If the game's
-- menu can't be read (another client build, an entry of a kind this doesn't know), the game's own menu opens instead.
local _, root = ...
local public = root.public
if not public then return end

local TAG = "MENU_WORLD_MAP_TRACKING"

-- The map's filter button: the overlay frame whose menu is the tracking menu
local function findButton()
	local map = WorldMapFrame
	if not map then return end
	for _, f in ipairs(map.overlayFrames or {}) do
		if type(f) == "table" and f.SetupMenu and f.OpenMenu then
			local tag = f.menuTag or (f.GetMenuTag and f:GetMenuTag())
			if tag == TAG or f.menuGenerator then return f end
		end
	end
end

local function text(element)
	local t = MenuUtil and MenuUtil.GetElementText and MenuUtil.GetElementText(element)
	if t == nil then t = element.text end
	return t ~= nil and tostring(t) or ""
end

local function children(desc)
	local list = {}
	if desc and desc.EnumerateElementDescriptions then
		for _, element in desc:EnumerateElementDescriptions() do list[#list + 1] = element end
	end
	return list
end

-- the game's menu description, built as the game builds it when the button opens its menu
local function build(button)
	if not (MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants and Menu and Menu.PopulateDescription) then return end
	local generator = button.menuGenerator
	if type(generator) ~= "function" then return end
	local rootDescription = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
	rootDescription:SetTag(TAG)
	Menu.PopulateDescription(generator, button, rootDescription)
	return rootDescription
end

-- each element into the builder calls Menu.lua draws: a divider, a title, a submenu, a tick box or a button
local function convert(desc, menu, depth)
	if depth > 3 then return 0 end
	local n = 0
	for _, element in ipairs(children(desc)) do
		local label = text(element)
		local subs = children(element)
		local okSel, selected = false, nil
		if element.IsSelected then okSel, selected = pcall(element.IsSelected, element) end
		local canPick = type(element.Pick) == "function"
		local function pick()
			element:Pick(MenuInputContext and MenuInputContext.MouseButton or 1, "LeftButton")
		end
		if label == "" then
			menu:CreateDivider()
		elseif #subs > 0 then
			n = n + convert(element, menu:CreateSubmenu(label), depth + 1)
		elseif okSel and type(selected) == "boolean" and canPick then
			menu:CreateCheckbox(label, function() local ok, v = pcall(element.IsSelected, element) return ok and v end, pick)
			n = n + 1
		elseif canPick and (element.responder or element.HasResponder and element:HasResponder()) then
			menu:CreateButton(label, pick)
			n = n + 1
		else
			menu:CreateTitle(label)
		end
	end
	return n
end

local function open(button, cover)
	local okBuild, desc = pcall(build, button)
	local entries = 0
	if okBuild and desc then
		-- (built once to see it can be drawn, then drawn: a menu with nothing to click is the game's to show)
		local probe = public.MenuTest and public.MenuTest.NewList()
		if probe then
			local okProbe, count = pcall(convert, desc, probe, 0)
			entries = okProbe and count or 0
		end
	end
	if entries == 0 then
		button:OpenMenu()
		return
	end
	public.ContextMenu(cover, function(_, menu) convert(build(button), menu, 0) end)
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
	cover:SetScript("OnClick", function(self) open(button, self) end)
	-- (the game's button still lights up under the pointer)
	cover:SetScript("OnEnter", function() if button.LockHighlight then button:LockHighlight() end
		local onEnter = button:GetScript("OnEnter") if onEnter then pcall(onEnter, button) end end)
	cover:SetScript("OnLeave", function() if button.UnlockHighlight then button:UnlockHighlight() end
		local onLeave = button:GetScript("OnLeave") if onLeave then pcall(onLeave, button) end end)
	return true
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function() install() end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() C_Timer.After(1, install) end)

-- for the self-test and the offline test
public.MapShowMenu = {
	Install = install, Find = findButton, Cover = function() return cover end,
	Count = function()
		local button = findButton()
		local desc = button and select(2, pcall(build, button))
		if type(desc) ~= "table" then return 0 end
		local probe = public.MenuTest.NewList()
		local ok, n = pcall(convert, desc, probe, 0)
		return ok and n or 0
	end,
	Convert = convert,
}
