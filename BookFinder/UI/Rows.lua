-- Rows: one way to lay out a list inside a page (the Journey pages): foldable gold headings with a count, plain
-- lines (white values, grey hints, DESIGN rule 3), clickable lines with a hover tooltip, and buttons in a row. A
-- list is laid out again from the top whenever what it shows changes; the frames are pooled, never thrown away.
--
--   local rows = BF.Rows:New(content, foldState)    -- foldState: a table that remembers folded headings
--   rows:Begin(width) ... rows:Heading(key, text, count) -> folded? ... rows:Line(text, opts) ... rows:Finish()

local _, BF = ...
local L = BF.L

local Rows = {}
BF.Rows = Rows

local GREY = { 0.6, 0.6, 0.6 }

local List = {}
List.__index = List

function Rows:New(content, foldState)
	return setmetatable({ content = content, folded = foldState or {}, pool = {}, used = 0, buttons = {}, buttonsUsed = 0 }, List)
end

function List:Begin(width, top)
	for i = 1, self.used do self.pool[i]:Hide() end
	for i = 1, self.buttonsUsed do self.buttons[i]:Hide() end
	self.used, self.buttonsUsed = 0, 0
	self.width, self.y = width, top or 0
end

function List:Row()
	self.used = self.used + 1
	local r = self.pool[self.used]
	if not r then
		r = CreateFrame("Button", nil, self.content)
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(true)
		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		r.right:SetPoint("RIGHT", -24, 0)
		r.toggle = r:CreateTexture(nil, "ARTWORK")
		r.toggle:SetSize(14, 14)
		r.toggle:SetPoint("RIGHT", -4, 0)
		r.highlight = r:CreateTexture(nil, "HIGHLIGHT")
		r.highlight:SetAllPoints()
		r.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		r.highlight:SetBlendMode("ADD")
		r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
		r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.pool[self.used] = r
	end
	r:Show()
	r.right:SetText("")
	r.toggle:Hide()
	r.onClick, r.onEnter, r.data = nil, nil, nil
	r.text:SetTextColor(1, 1, 1)
	return r
end

local function put(self, r, indent, minHeight)
	indent = indent or 0
	r.text:ClearAllPoints()
	r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -3)
	r.text:SetWidth(self.width - indent - 30)
	local h = math.max(minHeight or 18, r.text:GetStringHeight() + 6)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", self.content, "TOPLEFT", indent, -self.y)
	r:SetSize(self.width - indent, h)
	self.y = self.y + h
	return r
end

--- A gold heading that folds what is under it; returns true while folded.
function List:Heading(key, text, count)
	local r = self:Row()
	r.kind = "heading"
	r.text:SetFontObject("GameFontNormal")
	r.text:SetText(text)
	r.right:SetText(count or "")
	local folded = key and self.folded[key] == true
	if key then
		r.toggle:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		r.toggle:Show()
		r.onClick = function()
			self.folded[key] = not folded or nil
			if self.onFold then self.onFold() end
		end
	end
	r.highlight:SetShown(key ~= nil)
	put(self, r, 0, 22)
	return folded
end

--- A line. opts: { colour =, hint = true (grey), small = true, indent =, onClick = fn(row, button), onEnter = fn(row),
--- right = text at the right, data = anything }
function List:Line(text, opts)
	opts = opts or {}
	local r = self:Row()
	r.kind = "line"
	r.text:SetFontObject(opts.hint and "GameFontDisableSmall" or (opts.small and "GameFontHighlightSmall" or "GameFontHighlight"))
	r.text:SetText(text)
	local c = opts.colour or (opts.hint and GREY)
	if c then r.text:SetTextColor(c[1], c[2], c[3]) end
	r.right:SetText(opts.right or "")
	r.onClick, r.onEnter, r.data = opts.onClick, opts.onEnter, opts.data
	r.highlight:SetShown(opts.onClick ~= nil)
	put(self, r, opts.indent or 10)
	return r
end

--- A row of the game's buttons: { {text, fn, width?}, ... }.
function List:Buttons(list, indent)
	local x = indent or 10
	for _, spec in ipairs(list) do
		self.buttonsUsed = self.buttonsUsed + 1
		local b = self.buttons[self.buttonsUsed]
		if not b then
			b = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
			self.buttons[self.buttonsUsed] = b
		end
		b:SetSize(spec[3] or 120, 22)
		b:SetText(L[spec[1]])
		b:SetScript("OnClick", spec[2])
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -self.y - 2)
		b:Show()
		x = x + (spec[3] or 120) + 6
	end
	self.y = self.y + 28
end

function List:Gap(h) self.y = self.y + (h or 8) end

--- Ends the list: the content's height follows it. Returns the height.
function List:Finish()
	self.content:SetHeight(math.max(self.y, 1))
	return self.y
end

--- The shown rows (for tests).
function List:Shown()
	local t = {}
	for i = 1, self.used do t[#t + 1] = self.pool[i] end
	return t
end
