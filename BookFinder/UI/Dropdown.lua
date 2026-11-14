-- The one dropdown: every menu BookFinder opens is this, the classic tooltip-box dropdown the owner likes in Questie
-- (docs/DESIGN.md, rule 2: one dropdown; docs/WANTS.md: "The dropdowns should look like Questie's").
--
-- A tooltip box; rows of the game's small font; a tick box at the left of a switch (the game's dropdown checks), a
-- radio dot for one-of choices; the item's icon at the right; a gold title row; a divider; a submenu opens to the right
-- of its row (▸ arrow). Clicking a switch keeps the menu open (like Questie's map menu); a plain entry closes it.
-- Escape or a click anywhere else closes it.
--
-- BF.Dropdown:Open(anchor, items) / :Toggle(anchor, items) / :Close(). An item:
--   { text =, checked = fn | bool, radio = true?, func = fn, icon = Icons kind?, disabled = fn | bool,
--     title = true?, divider = true?, submenu = { items } | fn() -> items, keepOpen = bool? }
-- items may be a function returning the list (built each time the menu opens).

local _, BF = ...

local Dropdown = {}
BF.Dropdown = Dropdown

local ROW, PAD, ICON, CHECK = 16, 12, 14, 16
local MIN_WIDTH = 120
local CHECKS = "Interface\\Common\\UI-DropDownRadioChecks"

local levels = {} -- [level] = frame

local function value(v)
	if type(v) == "function" then return v() end
	return v
end

local function backdrop(frame)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.09, 0.09, 0.09, 0.95)
	frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
end

-- Rows -------------------------------------------------------------------------------------------------------------

local function newRow(level)
	local row = CreateFrame("Button", nil, level)
	row:SetHeight(ROW)
	row.check = row:CreateTexture(nil, "ARTWORK")
	row.check:SetSize(CHECK, CHECK)
	row.check:SetPoint("LEFT", 0, 0)
	row.check:SetTexture(CHECKS)
	row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.text:SetJustifyH("LEFT")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON, ICON)
	row.icon:SetPoint("RIGHT", 0, 0)
	row.arrow = row:CreateTexture(nil, "ARTWORK")
	row.arrow:SetSize(ROW, ROW)
	row.arrow:SetPoint("RIGHT", 0, 0)
	row.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
	row.rule:SetPoint("LEFT")
	row.rule:SetPoint("RIGHT")
	row.rule:SetHeight(8)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:SetScript("OnClick", function(self) Dropdown:Click(self) end)
	row:SetScript("OnEnter", function(self) Dropdown:Hover(self) end)
	return row
end

-- Draws one item on a row; returns the width the row needs.
local function fill(row, item)
	row.item = item
	row:Show()
	row.check:Hide()
	row.icon:Hide()
	row.arrow:Hide()
	row.rule:Hide()
	row.text:Show()
	row.text:ClearAllPoints()
	if item.divider then
		row.text:Hide()
		row.rule:Show()
		row:SetHeight(ROW / 2 + 2)
		row:EnableMouse(false)
		return MIN_WIDTH
	end
	row:SetHeight(ROW)
	row:EnableMouse(not item.title)
	local isSwitch = item.checked ~= nil
	local left = isSwitch and (CHECK + 2) or 0
	row.text:SetPoint("LEFT", left, 0)
	row.text:SetText(item.text or "")
	local disabled = value(item.disabled)
	if item.title then row.text:SetFontObject("GameFontNormalSmall")
	elseif disabled then row.text:SetFontObject("GameFontDisableSmall")
	else row.text:SetFontObject("GameFontHighlightSmall") end
	if isSwitch then
		local on = value(item.checked)
		row.check:Show()
		-- The game's dropdown checks: a tick box for switches, a radio dot for one-of choices; lit or not.
		if item.radio then
			row.check:SetTexCoord(on and 0 or 0.5, on and 0.5 or 1, 0.5, 1)
		else
			row.check:SetTexCoord(on and 0 or 0.5, on and 0.5 or 1, 0, 0.5)
		end
	end
	local right = 0
	if item.submenu then
		row.arrow:Show()
		right = ROW
	end
	if item.icon and BF.Icons.kinds[item.icon] then
		row.icon:ClearAllPoints()
		row.icon:SetPoint("RIGHT", -right, 0)
		BF.Icons:Apply(row.icon, item.icon)
		row.icon:Show()
		right = right + ICON + 4
	end
	return left + row.text:GetStringWidth() + right + 16
end

-- Levels -------------------------------------------------------------------------------------------------------

local function level(n)
	local f = levels[n]
	if f then return f end
	f = CreateFrame("Frame", "BookFinderDropdown" .. n, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f.rows = {}
	f.level = n
	backdrop(f)
	f:Hide()
	levels[n] = f
	tinsert(UISpecialFrames, f:GetName()) -- Escape closes it
	return f
end

local function closeFrom(n)
	for i = n, #levels do
		if levels[i] then levels[i]:Hide() end
	end
end

--- Shows `items` as menu level n at `anchor` (level 1: under the anchor; deeper: right of the row).
local function show(n, anchor, items)
	items = value(items) or {}
	local f = level(n)
	closeFrom(n)
	local width = MIN_WIDTH
	local y = -PAD + 4
	for i, item in ipairs(items) do
		local row = f.rows[i] or newRow(f)
		f.rows[i] = row
		row.levelIndex = n
		width = math.max(width, fill(row, item))
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
		y = y - row:GetHeight()
	end
	for i = #items + 1, #f.rows do f.rows[i]:Hide() end
	for i = 1, #items do f.rows[i]:SetWidth(width) end
	f:SetSize(width + 2 * PAD, -y + PAD - 4)
	f:ClearAllPoints()
	if n == 1 then
		f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	else
		f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", PAD, PAD - 4)
	end
	f.anchor, f.items = anchor, items
	f:Show()
	return f
end

-- Behaviour ------------------------------------------------------------------------------------------------------

function Dropdown:Open(anchor, items)
	Dropdown.owner = anchor
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	return show(1, anchor, items)
end

function Dropdown:IsOpen(anchor)
	return levels[1] ~= nil and levels[1]:IsShown() and (anchor == nil or Dropdown.owner == anchor)
end

function Dropdown:Toggle(anchor, items)
	if Dropdown:IsOpen(anchor) then Dropdown:Close() else Dropdown:Open(anchor, items) end
end

function Dropdown:Close()
	closeFrom(1)
	Dropdown.owner = nil
end

--- Redraws every open level (a switch changed: its tick and anything that depends on it).
function Dropdown:Refresh()
	for n = 1, #levels do
		local f = levels[n]
		if f and f:IsShown() then
			for _, row in ipairs(f.rows) do
				if row:IsShown() and row.item then fill(row, row.item) end
			end
		end
	end
end

function Dropdown:Hover(row)
	local item = row.item
	local n = row.levelIndex
	if item and item.submenu and not value(item.disabled) then
		show(n + 1, row, item.submenu)
	else
		closeFrom(n + 1)
	end
end

function Dropdown:Click(row)
	local item = row.item
	if not item or item.title or item.divider or value(item.disabled) then return end
	if item.submenu then
		show(row.levelIndex + 1, row, item.submenu)
		return
	end
	if item.func then BF.safecall(item.func, item) end
	local keep = item.keepOpen
	if keep == nil then keep = item.checked ~= nil and not item.radio end
	PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	if keep then Dropdown:Refresh() else Dropdown:Close() end
end

-- A click anywhere outside the open levels (and their owner) closes the menu.
BF:On("GLOBAL_MOUSE_DOWN", function()
	if not Dropdown:IsOpen() then return end
	for n = 1, #levels do
		if levels[n] and levels[n]:IsShown() and levels[n]:IsMouseOver() then return end
	end
	if Dropdown.owner and Dropdown.owner.IsMouseOver and Dropdown.owner:IsMouseOver() then return end
	Dropdown:Close()
end)
