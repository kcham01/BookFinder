-- The Books tab beside the quest log (docs/NOTES.md 3): a book tab under the quest log's own side tabs on the map's
-- right edge. It shows the books, as Books on map's window did, in the quest log's own look:
--
--   the count and a bar with the rewards' notches (10, 20, 25, 38; hover lists the rewards, reached ones green);
--   each set a foldable heading with "n / total"; each book a row: its icon, name, place and coordinates, and a tick
--   box (ticked: collected, off the map). Click a row: the map opens on its zone; right-click: the map pin on it.
--   Hover: the book's card (every place, the group). At the foot: Show all, Hide all, Optimized route, Settings.
--
-- The quest log's tabs are the game's (QuestMapFrame's, switched by SetDisplayMode): the book tab sits under them
-- and switches the same way, the game's own lists of tabs left untouched. If this client's quest log has no such tabs, the tab sits on the map's right
-- edge and shows its page over the quest log the same way.

local _, BF = ...
local L = BF.L
local W = BF.Widgets

local Books = BF.Books
local Tab = {}
BF.BooksTab = Tab

local MODE = "BookFinderBooks"
local ROW_H, HEAD_H = 34, 24

local tab, page, scroll, content, bar, count, footer
local rows, heads = {}, {}
local folded = {}   -- [set] = true

-- The page ---------------------------------------------------------------------------------------------------------

local function zoneOf(book)
	local place = Books:Places(book)[1]
	return place
end

local function openOn(book)
	local place = zoneOf(book)
	if place and WorldMapFrame then WorldMapFrame:SetMapID(place.map) end
end

local function placeText(book)
	local place = zoneOf(book)
	local where = L[book.place or ""] ~= "" and L[book.place] or (place and BF.Zones:MapName(place.map)) or ""
	if place then where = where .. "  |cff999999" .. BF.Zones:FormatCoords(place.x, place.y) .. "|r" end
	return where
end

local function makeHead(i)
	local h = CreateFrame("Button", nil, content)
	h:SetHeight(HEAD_H)
	h.fold = h:CreateTexture(nil, "ARTWORK")
	h.fold:SetSize(14, 14)
	h.fold:SetPoint("LEFT", 2, 0)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
	h.text:SetPoint("LEFT", h.fold, "RIGHT", 4, 0)
	h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	h.count:SetPoint("RIGHT", -6, 0)
	h.rule = W:Rule(h)
	h.rule:SetPoint("BOTTOMLEFT", 0, 1)
	h.rule:SetPoint("BOTTOMRIGHT", 0, 1)
	h:SetScript("OnClick", function(self)
		folded[self.set] = not folded[self.set] or nil
		Tab:Refresh()
	end)
	heads[i] = h
	return h
end

local function makeRow(i)
	local r = CreateFrame("Button", nil, content)
	r:SetHeight(ROW_H)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 0.82, 0.45, 0.08)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(26, 26)
	r.icon:SetPoint("LEFT", 6, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.check = W:CheckBox(r)
	r.check:SetPoint("RIGHT", -4, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
	r.name:SetPoint("RIGHT", r.check, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.place = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.place:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 0)
	r.place:SetPoint("RIGHT", r.check, "LEFT", -6, 0)
	r.place:SetJustifyH("LEFT")
	r.place:SetWordWrap(false)
	r:SetScript("OnClick", function(self, button)
		local place = zoneOf(self.book)
		if button == "RightButton" then
			if place then BF.Waypoint:Set(place.map, place.x, place.y, Books:Name(self.book), L[self.book.place or ""]) end
		elseif IsShiftKeyDown() then
			Books:Tick(self.book, not Books:IsDone(self.book))
		else
			openOn(self.book)
		end
	end)
	r:SetScript("OnEnter", function(self)
		local place = zoneOf(self.book)
		if place then BF.BookMap:ShowTooltip(self, self.book, place) end
		GameTooltip:AddLine(L["Click: its zone on the map"], 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r.check:SetScript("OnClick", function(self)
		local book = self:GetParent().book
		local how = Books:How(book)
		-- A book in the bags or handed in stays collected; the box is the player's own tick.
		if how == "carried" or how == "handedIn" then self:SetChecked(true) return end
		Books:Tick(book, self:GetChecked() and true or false)
	end)
	rows[i] = r
	return r
end

function Tab:Refresh()
	if not page or not page:IsVisible() then return end
	local done, total = Books:DoneCount(), Books:Count()
	count:SetText(L["Library books"] .. "  |cffffffff" .. done .. " / " .. total .. "|r")
	bar:SetMinMaxValues(0, total)
	bar:SetValue(done)
	for _, n in ipairs(bar.notches) do
		n.label:SetTextColor(done >= n.goal and 0.3 or 0.7, done >= n.goal and 1 or 0.7, done >= n.goal and 0.3 or 0.7)
	end
	local width = content:GetWidth()
	if not width or width < 50 then width = page:GetWidth() - 30 end
	local y, ri, hi = 0, 0, 0
	for _, set in ipairs(Books.SETS) do
		local inSet, doneInSet = {}, 0
		for _, b in ipairs(Books.list) do
			if b.set == set then
				inSet[#inSet + 1] = b
				if Books:IsDone(b) then doneInSet = doneInSet + 1 end
			end
		end
		if #inSet > 0 then
			hi = hi + 1
			local h = heads[hi] or makeHead(hi)
			h.set = set
			h:SetWidth(width)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 0, -y)
			h.text:SetText(L[Books.SET_NAMES[set]])
			h.count:SetText(doneInSet .. " / " .. #inSet)
			h.count:SetTextColor(doneInSet == #inSet and 0.3 or 1, doneInSet == #inSet and 1 or 1, doneInSet == #inSet and 0.3 or 1)
			h.fold:SetTexture(folded[set] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			h:Show()
			y = y + HEAD_H + 2
			if not folded[set] then
				for _, b in ipairs(inSet) do
					ri = ri + 1
					local r = rows[ri] or makeRow(ri)
					r.book = b
					r:SetWidth(width)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", 0, -y)
					r.icon:SetTexture(Books:Icon(b))
					local isDone = Books:IsDone(b)
					r.icon:SetDesaturated(isDone)
					r.name:SetText(Books:Name(b))
					if isDone then r.name:SetTextColor(0.5, 0.5, 0.5) else r.name:SetTextColor(1, 0.82, 0) end
					r.place:SetText(placeText(b))
					r.check:SetChecked(isDone)
					r:Show()
					y = y + ROW_H
				end
			end
			y = y + 6
		end
	end
	for i = ri + 1, #rows do rows[i]:Hide() end
	for i = hi + 1, #heads do heads[i]:Hide() end
	content:SetHeight(math.max(1, y))
	footer.route:SetText(BF.BookRoute:IsOn() and L["Route: on"] or L["Optimized route"])
end

local function footerButton(text, onClick)
	local b = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
	b:SetText(L[text])
	b:SetHeight(22)
	b:SetScript("OnClick", function() onClick() Tab:Refresh() end)
	return b
end

local function buildPage(parent)
	page = CreateFrame("Frame", "BookFinderBooksTabPage", parent)
	page:SetAllPoints(parent.ContentsAnchor or parent)
	page.displayMode = MODE
	page:Hide()
	-- The quest log's own parchment behind it.
	local bg = page:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestLog-main-background") then
		bg:SetAtlas("QuestLog-main-background", false)
	else
		bg:SetColorTexture(0.06, 0.05, 0.04, 0.95)
	end
	count = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	count:SetPoint("TOPLEFT", 12, -12)
	bar = CreateFrame("StatusBar", nil, page)
	bar:SetPoint("TOPLEFT", 12, -38)
	bar:SetPoint("TOPRIGHT", -12, -38)
	bar:SetHeight(12)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.85, 0.65, 0.2)
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	barBg:SetColorTexture(0, 0, 0, 0.55)
	bar.notches = {}
	for _, r in ipairs(Books.REWARDS) do
		local n = CreateFrame("Frame", nil, bar)
		n:SetSize(10, 26)
		n.goal = r.goal
		n.line = n:CreateTexture(nil, "OVERLAY")
		n.line:SetColorTexture(1, 1, 1, 0.6)
		n.line:SetSize(1, 12)
		n.line:SetPoint("TOP")
		n.label = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		n.label:SetPoint("BOTTOM")
		n.label:SetText(r.goal)
		bar.notches[#bar.notches + 1] = n
	end
	local function placeNotches()
		local w, total = bar:GetWidth(), Books:Count()
		for _, n in ipairs(bar.notches) do
			n:ClearAllPoints()
			n:SetPoint("TOP", bar, "TOPLEFT", w * math.min(1, n.goal / total), 0)
		end
	end
	bar:SetScript("OnSizeChanged", placeNotches)
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["Library rewards"], 1, 0.82, 0)
		local done = Books:DoneCount()
		for _, r in ipairs(Books.REWARDS) do
			local got = done >= r.goal
			GameTooltip:AddDoubleLine(L[r.label], ("%d / %d"):format(math.min(done, r.goal), r.goal),
				got and 0.3 or 1, got and 1 or 1, got and 0.3 or 1, got and 0.3 or 0.7, got and 1 or 0.7, got and 0.3 or 0.7)
		end
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

	footer = CreateFrame("Frame", nil, page)
	footer:SetPoint("BOTTOMLEFT", 8, 6)
	footer:SetPoint("BOTTOMRIGHT", -8, 6)
	footer:SetHeight(24)
	footer.show = footerButton("Show all", function()
		for _, b in ipairs(Books.list) do if Books:How(b) == "ticked" then BF:CharacterState("books").ticked[b.key] = nil end end
		BF:Send("BF_BOOKS_CHANGED")
	end)
	footer.hide = footerButton("Hide all", function()
		local s = BF:CharacterState("books")
		s.ticked = s.ticked or {}
		for _, b in ipairs(Books.list) do if not Books:IsDone(b) then s.ticked[b.key] = true end end
		BF:Send("BF_BOOKS_CHANGED")
	end)
	footer.route = footerButton("Optimized route", function() BF.BookRoute:Toggle() end)
	footer.settings = footerButton("Settings", function() BF.Panel:Open("books") end)
	local buttons = { footer.show, footer.hide, footer.route, footer.settings }
	footer:SetScript("OnSizeChanged", function(self, w)
		local each = (w - 3 * 4) / 4
		for i, b in ipairs(buttons) do
			b:ClearAllPoints()
			b:SetWidth(each)
			b:SetPoint("LEFT", (i - 1) * (each + 4), 0)
		end
	end)

	scroll, content = W:Scroll(page)
	scroll:SetPoint("TOPLEFT", 8, -66)
	scroll:SetPoint("BOTTOMRIGHT", -26, 34)
	content:SetWidth(200)
	scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) Tab:Refresh() end)
	page:SetScript("OnShow", function() placeNotches() Tab:Refresh() end)
	return page
end

-- The tab ------------------------------------------------------------------------------------------------------------

local function setChecked(self, on)
	self.checked = on and true or false
	if self.SelectedTexture then self.SelectedTexture:SetShown(self.checked) end
	if self.Icon then
		self.Icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
		self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		self.Icon:SetDesaturated(not self.checked)
		self.Icon:SetAlpha(self.checked and 1 or 0.8)
	end
end

local function makeTab(parent, anchor)
	local ok, b = pcall(CreateFrame, "Button", "BookFinderBooksTab", parent, "QuestLogTabButtonTemplate")
	if not ok or not b then
		b = CreateFrame("Button", "BookFinderBooksTab", parent)
		b:SetSize(32, 32)
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
		b.SelectedTexture = b:CreateTexture(nil, "OVERLAY")
		b.SelectedTexture:SetAllPoints()
		b.SelectedTexture:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		b.SelectedTexture:SetBlendMode("ADD")
	end
	if not b.Icon then
		b.Icon = b:CreateTexture(nil, "ARTWORK")
		b.Icon:SetPoint("CENTER")
		b.Icon:SetSize(20, 20)
	end
	b.displayMode = MODE
	b.tooltipText = L["Library books"]
	b.activeAtlas, b.inactiveAtlas = nil, nil
	b.SetChecked = setChecked
	b:ClearAllPoints()
	if anchor then b:SetPoint("TOP", anchor, "BOTTOM", 0, -3) else b:SetPoint("TOPLEFT", parent, "TOPRIGHT", -2, -40) end
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Library books"], 1, 1, 1)
		GameTooltip:AddLine(("%d / %d"):format(Books:DoneCount(), Books:Count()), 1, 0.82, 0)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnMouseUp", nil)
	b:SetScript("OnMouseDown", nil)
	b:SetScript("OnClick", function() Tab:Select() end)
	setChecked(b, false)
	return b
end

local function questFrame() return rawget(_G, "QuestMapFrame") end

--- Shows the books (the quest log opened beside the map if it wasn't).
function Tab:Select()
	local qmf = questFrame()
	if qmf and qmf.SetDisplayMode and pcall(qmf.SetDisplayMode, qmf, MODE) then
		-- (shown by the hook)
	elseif page then
		-- (no game tabs: ours over the quest log)
		page:Show()
		tab:SetChecked(true)
	end
	Tab:Refresh()
end

--- Opens the map, the quest log beside it, and the Books tab.
function Tab:Open()
	if WorldMapFrame and not WorldMapFrame:IsShown() then
		if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
	end
	local qmf = questFrame()
	if qmf and not qmf:IsShown() and WorldMapFrame and WorldMapFrame.HandleUserActionToggleSidePanel then
		pcall(WorldMapFrame.HandleUserActionToggleSidePanel, WorldMapFrame)
	end
	Tab:Select()
end

function Tab:Install()
	if tab then return true end
	local qmf = questFrame()
	if not qmf then return false end
	buildPage(qmf)
	local last
	for _, t in ipairs(qmf.TabButtons or {}) do
		if t:IsShown() and (not last or (t:GetBottom() or 0) < (last:GetBottom() or 0)) then last = t end
	end
	last = last or qmf.MapLegendTab or qmf.QuestsTab
	tab = makeTab(qmf, last)
	-- (the game's own tab lists are left as they are: its SetDisplayMode with our mode shows none of its pages and
	-- lights none of its tabs, and the hook below shows ours)
	if not qmf.SetDisplayMode then
		for _, t in ipairs({ qmf.QuestsTab, qmf.MapLegendTab, qmf.EventsTab }) do
			if t then t:HookScript("OnMouseUp", function() page:Hide() tab:SetChecked(false) end) end
		end
	end
	if qmf.SetDisplayMode then
		hooksecurefunc(qmf, "SetDisplayMode", function(_, mode)
			local mine = mode == MODE
			page:SetShown(mine)
			tab:SetChecked(mine)
			if mine then Tab:Refresh() end
		end)
	end
	return true
end

function Tab:IsShown() return page ~= nil and page:IsVisible() end

BF:At("login", function()
	if not Tab:Install() and WorldMapFrame then
		WorldMapFrame:HookScript("OnShow", function() Tab:Install() end)
	end
	local soon = BF:Debounce(0.1, function() Tab:Refresh() end)
	for _, m in ipairs({ "BF_BOOKS_CHANGED", "BF_BOOKS_GROUP_CHANGED", "BF_BOOK_ROUTE_CHANGED" }) do BF:Listen(m, soon) end
	BF:On("GET_ITEM_INFO_RECEIVED", soon)
end, 83)
