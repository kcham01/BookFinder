-- BookFinder: every dropdown of its own (the minimap button's menu, the books tab's gear, a book's right-click) is
-- drawn in Questie's style: Questie's own dropdown library (LibUIDropDownMenuQuestie-4.0, the classic dropdown with
-- its dark tooltip border, gold titles and the faded divider), not the game's newer menu.
--
-- public.ContextMenu(owner, build) takes the same builder the game's MenuUtil.CreateContextMenu does, so a menu is
-- written once: build(owner, menu) calls menu:CreateTitle(text), menu:CreateButton(text, fn),
-- menu:CreateCheckbox(text, isChecked, toggle), menu:CreateDivider() and menu:CreateSubmenu(text) (which returns a
-- menu of its own). Without Questie's library (Questie standing aside for its standalone copy, which carries the same
-- library) the game's own menu draws it instead.
local _, root = ...
local public = root.public
if not public then return end

-- Questie's divider: the tooltip's faded line, as its own menus draw it
local DIVIDER = {
	text = "", hasArrow = false, dist = 0, isTitle = true, isUninteractable = true, notCheckable = true,
	iconOnly = true, isSeparator = true, icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
	tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tSizeX = 0, tSizeY = 8, tFitDropDownSizeX = true,
	iconInfo = { tCoordLeft = 0, tCoordRight = 1, tCoordTop = 0, tCoordBottom = 1, tSizeX = 0, tSizeY = 8, tFitDropDownSizeX = true },
}

local function lib()
	local L = LibStub and LibStub("LibUIDropDownMenuQuestie-4.0", true)
	-- (only a library that loaded whole: its EasyMenu half is a file of its own)
	if L and type(L.Create_UIDropDownMenu) == "function" and type(L.EasyMenu) == "function" then return L end
end

local function report(err) if geterrorhandler then geterrorhandler()(err) end end

-- A list that answers the modern menu's builder calls with EasyMenu entries
local function newList()
	local list = {}
	local Builder = {}
	function Builder:CreateTitle(text)
		list[#list + 1] = { text = text, isTitle = true, notCheckable = true }
	end
	function Builder:CreateButton(text, fn)
		list[#list + 1] = { text = text, notCheckable = true,
			func = function() local ok, err = pcall(fn) if not ok then report(err) end end }
	end
	function Builder:CreateCheckbox(text, isChecked, toggle)
		list[#list + 1] = { text = text, isNotRadio = true, keepShownOnClick = true,
			checked = function() local ok, v = pcall(isChecked) return ok and v and true or false end,
			func = function() local ok, err = pcall(toggle) if not ok then report(err) end end }
	end
	function Builder:CreateDivider()
		if #list > 0 and list[#list] ~= DIVIDER then list[#list + 1] = DIVIDER end
	end
	function Builder:CreateSubmenu(text)
		local sub, subList = newList()
		list[#list + 1] = { text = text, notCheckable = true, hasArrow = true, keepShownOnClick = true, menuList = subList,
			func = function() end }
		return sub
	end
	return setmetatable({}, { __index = Builder }), list
end

local frame
function public.ContextMenu(owner, build)
	local L = lib()
	if not L then
		if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, build) end
		return
	end
	local builder, list = newList()
	local ok, err = pcall(build, owner, builder)
	if not ok then report(err) return end
	if list[#list] == DIVIDER then list[#list] = nil end
	-- (Questie's menus end on a plain Cancel)
	list[#list + 1] = DIVIDER
	list[#list + 1] = { text = CANCEL or "Cancel", notCheckable = true, func = function() end }
	if not frame then frame = L:Create_UIDropDownMenu("BookFinderMenu", UIParent) end
	-- a second right-click on the same owner closes it, as Questie's map button did
	if L.getOpen and L:getOpen() and frame.owner == owner then
		L:CloseDropDownMenus()
		return
	end
	frame.owner = owner
	L:EasyMenu(list, frame, "cursor", 0, 0, "MENU", 2)
end

public.MenuTest = { NewList = newList, Divider = DIVIDER }   -- (for the offline test)
