-- BookFinder's dropdown menus, drawn in the classic style the owner likes (Questie's map menu): a tooltip box, each row
-- a tick box at the left, its label, and the item's icon at the right; gold titles, thin dividers, submenus opening
-- to the side on hover. Every BookFinder menu uses this (the map's Show dropdown, the books' menus, the minimap
-- button's). Ticking a box leaves the menu open.
--
-- BF.Dropdown:Open(anchor, items) with items = {
--   { text = "Title", title = true },
--   { divider = true },
--   { text = "Label", checked = fn|bool, onClick = fn(item, checked), icon = iconKind or texture, radio = bool,
--     tooltip = "...", disabled = fn|bool },
--   { text = "Label", submenu = items or fn() -> items, icon = ... },
--   { text = "Label", onClick = fn(item) },   -- a plain button: the menu closes after it
-- }

local _, BF = ...

local Dropdown = {}
BF.Dropdown = Dropdown

local ROW_HEIGHT = 16
local PAD = 10
local CHECK = "Interface\\Common\\UI-DropDownRadioChecks"
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local MAX_LEVELS = 3

local lists = {}

local function value(v, item)
	if type(v) == "function" then return v(item) end
	return v
end

-- A row ------------------------------------------------------------------------------------------------------------

local function newRow(list)
	local row = CreateFrame("Button", nil, list)
	row:SetHeight(ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.Highlight = row:CreateTexture(nil, "BACKGROUND")
	row.Highlight:SetTexture(HIGHLIGHT)
	row.Highlight:SetBlendMode("ADD")
	row.Highlight:SetAllPoints()
	row.Highlight:Hide()

	row.Check = row:CreateTexture(nil, "ARTWORK")
	row.Check:SetTexture(CHECK)
	row.Check:SetSize(16, 16)
	row.Check:SetPoint("LEFT", 0, 0)

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.Text:SetPoint("LEFT", row.Check, "RIGHT", 2, 0)
	row.Text:SetJustifyH("LEFT")

	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(16, 16)
	row.Icon:SetPoint("RIGHT", 0, 0)

	row.Arrow = row:CreateTexture(nil, "ARTWORK")
	row.Arrow:SetTexture(ARROW)
	row.Arrow:SetSize(16, 16)
	row.Arrow:SetPoint("RIGHT", 0, 0)

	row.Divider = row:CreateTexture(nil, "ARTWORK")
	row.Divider:SetColorTexture(1, 1, 1, 0.15)
	row.Divider:SetHeight(1)
	row.Divider:SetPoint("LEFT", 2, 0)
	row.Divider:SetPoint("RIGHT", -2, 0)

	row:SetScript("OnEnter", function(self)
		local item = self.item
		if not item or item.divider or item.title then
			Dropdown:CloseFrom(self.level + 1)
			return
		end
		if not value(item.disabled, item) then self.Highlight:Show() end
		if item.submenu then
			local sub = value(item.submenu, item)
			Dropdown:Show(self.level + 1, self, sub)
		else
			Dropdown:CloseFrom(self.level + 1)
		end
		if item.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(item.text, 1, 1, 1)
			GameTooltip:AddLine(value(item.tooltip, item), nil, nil, nil, true)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function(self)
		self.Highlight:Hide()
		if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)
	row:SetScript("OnClick", function(self, button)
		local item = self.item
		if not item or item.divider or item.title or item.submenu or value(item.disabled, item) then return end
		local isCheck = item.checked ~= nil
		if isCheck then
			local now = not value(item.checked, item)
			if item.radio then now = true end
			if item.onClick then BF.safecall(item.onClick, item, now, button) end
			Dropdown:Refresh()
		else
			Dropdown:Close()
			if item.onClick then BF.safecall(item.onClick, item, nil, button) end
		end
	end)
	return row
end

local function paint(row, item)
	row.item = item
	row.Divider:SetShown(item.divider == true)
	row.Text:SetShown(not item.divider)
	row.Arrow:SetShown(item.submenu ~= nil)
	if item.divider then
		row.Check:Hide()
		row.Icon:Hide()
		return
	end
	row.Text:SetText(item.text or "")
	local disabled = value(item.disabled, item)
	if item.title then
		row.Text:SetFontObject("GameFontNormalSmall")
		row.Text:SetTextColor(1, 0.82, 0)
	elseif disabled then
		row.Text:SetFontObject("GameFontDisableSmall")
		row.Text:SetTextColor(0.5, 0.5, 0.5)
	else
		row.Text:SetFontObject("GameFontHighlightSmall")
		row.Text:SetTextColor(1, 1, 1)
	end
	-- The tick box: a check (or a dot for a choice among several) when on, the empty box when off.
	if item.checked ~= nil then
		local on = value(item.checked, item)
		row.Check:Show()
		if item.radio then
			if on then row.Check:SetTexCoord(0, 0.5, 0, 0.5) else row.Check:SetTexCoord(0.5, 1, 0, 0.5) end
		else
			if on then row.Check:SetTexCoord(0, 0.5, 0.5, 1) else row.Check:SetTexCoord(0.5, 1, 0.5, 1) end
		end
		row.Check:SetDesaturated(disabled and true or false)
	else
		row.Check:Hide()
	end
	-- The item's icon at the right (left of a submenu's arrow).
	local icon = item.icon
	if icon and not item.submenu then
		row.Icon:ClearAllPoints()
		row.Icon:SetPoint("RIGHT", 0, 0)
	elseif icon then
		row.Icon:ClearAllPoints()
		row.Icon:SetPoint("RIGHT", row.Arrow, "LEFT", -2, 0)
	end
	if icon then
		if BF.Icons.kinds[icon] then BF.Icons:Apply(row.Icon, icon) else row.Icon:SetTexture(icon) row.Icon:SetTexCoord(0, 1, 0, 1) end
		row.Icon:Show()
	else
		row.Icon:Hide()
	end
end

-- A list (one level) -----------------------------------------------------------------------------------------------

local function newList(level)
	local list = CreateFrame("Frame", "BookFinderDropdown" .. level, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	list:SetFrameStrata("FULLSCREEN_DIALOG")
	list:SetFrameLevel(10 + level * 5)
	list:SetClampedToScreen(true)
	list:EnableMouse(true)
	list:Hide()
	if list.SetBackdrop then
		list:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		list:SetBackdropColor(0.09, 0.09, 0.09, 0.95)
		list:SetBackdropBorderColor(1, 1, 1, 1)
	end
	list.level = level
	list.rows = {}
	-- Escape closes the menus (the game closes frames named in UISpecialFrames).
	if UISpecialFrames then table.insert(UISpecialFrames, list:GetName()) end
	return list
end

function Dropdown:Show(level, anchor, items)
	if level > MAX_LEVELS then return end
	Dropdown:CloseFrom(level + 1)
	local list = lists[level]
	if not list then
		list = newList(level)
		lists[level] = list
	end
	list.items = items
	local width = 0
	local shown = 0
	for i, item in ipairs(items) do
		local row = list.rows[i]
		if not row then
			row = newRow(list)
			list.rows[i] = row
		end
		row.level = level
		row:SetHeight(item.divider and 8 or ROW_HEIGHT)
		paint(row, item)
		local w = (item.divider and 0 or row.Text:GetStringWidth()) + 20 + ((item.icon or item.submenu) and 22 or 0)
			+ ((item.icon and item.submenu) and 18 or 0)
		if w > width then width = w end
		row:Show()
		shown = i
	end
	for i = shown + 1, #list.rows do list.rows[i]:Hide() end
	width = math.max(width, 120)
	local y = -PAD
	for i = 1, shown do
		local row = list.rows[i]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", PAD, y)
		row:SetWidth(width)
		y = y - row:GetHeight()
	end
	list:SetSize(width + PAD * 2, -y + PAD)
	list:ClearAllPoints()
	if level == 1 then
		list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	else
		list:SetPoint("TOPLEFT", anchor, "TOPRIGHT", PAD, PAD)
	end
	list.anchor = anchor
	list:Show()
end

--- Opens a menu under `anchor` (clicking the same anchor again closes it).
function Dropdown:Open(anchor, items)
	if lists[1] and lists[1]:IsShown() and lists[1].anchor == anchor then
		Dropdown:Close()
		return
	end
	PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	Dropdown:Show(1, anchor, items)
end

function Dropdown:CloseFrom(level)
	for l = level, MAX_LEVELS do
		if lists[l] then lists[l]:Hide() end
	end
end

function Dropdown:Close()
	Dropdown:CloseFrom(1)
end

function Dropdown:IsOpen()
	return lists[1] ~= nil and lists[1]:IsShown()
end

--- Repaints every open level (after a tick box changed something).
function Dropdown:Refresh()
	for l = 1, MAX_LEVELS do
		local list = lists[l]
		if list and list:IsShown() then
			for i, item in ipairs(list.items) do
				if list.rows[i] then paint(list.rows[i], item) end
			end
		end
	end
end

-- A click anywhere else closes the menus.
BF:On("GLOBAL_MOUSE_DOWN", function()
	if not Dropdown:IsOpen() then return end
	for l = 1, MAX_LEVELS do
		if lists[l] and lists[l]:IsShown() and lists[l]:IsMouseOver() then return end
	end
	if lists[1].anchor and lists[1].anchor:IsMouseOver() then return end
	Dropdown:Close()
end)
