-- The Books tab beside the quest log: the library books, in the quest log's own place (docs/NOTES.md: "lets say yes
-- for the books tab"; docs/WANTS.md: a quest-log tab with native art, a search box, collapsible sections, large rows).
-- It does what Books on map's window did (docs/study/books-on-map.md), without a window of its own:
--   - "Books: 12/38" and a progress bar with a notch at each reward (10, 20, 25, 38), green once reached;
--   - the route (when on): the next book, Skip and Recalc;
--   - each set foldable with "n / total", each book a large row: its icon, name, place and coordinates, and a tick box
--     (ticked: collected, off the map). Click: the map on its zone; Right-click: the map pin; Shift-click: tick it;
--   - Rewards: each tier and its items (hover: the item; Shift-click: link; Ctrl-click: try it on);
--   - Group: who shares their books, and who does not;
--   - Show all, Hide all, Optimized route.
-- The settings (show on the map, sizes, alerts, filters) are in the settings panel's Books tab.

local _, BF = ...
local L = BF.L

local Books, Route, BookMap = BF.Books, BF.BookRoute, BF.BookMap
local Tab = {}
BF.BooksTab = Tab

local ROW, BOOK_ROW = 20, 38
local GREEN, GREY = { 0.2, 1, 0.2 }, { 0.6, 0.6, 0.6 }

local function state()
	local s = BF:CharacterState("booksTab")
	s.folded = s.folded or {}
	return s
end

-- Lines in the list ------------------------------------------------------------------------------------------------

local frame, scroll, content, search, bar
local pool, used = {}, 0

local function line()
	used = used + 1
	local r = pool[used]
	if not r then
		r = CreateFrame("Button", nil, content)
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		r.text:SetJustifyH("LEFT")
		r.sub = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		r.sub:SetJustifyH("LEFT")
		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		r.right:SetPoint("RIGHT", -28, 0)
		r.toggle = r:CreateTexture(nil, "ARTWORK")
		r.toggle:SetSize(14, 14)
		r.toggle:SetPoint("RIGHT", -6, 0)
		r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
		r.check:SetSize(22, 22)
		r.check:SetPoint("RIGHT", -2, 0)
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		r:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(self, button) end end)
		r:SetScript("OnEnter", function(self) if self.onEnter then self.onEnter(self) end end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		pool[used] = r
	end
	r:Show()
	r.icon:Hide()
	r.sub:SetText("")
	r.right:SetText("")
	r.toggle:Hide()
	r.check:Hide()
	r.onClick, r.onEnter, r.book = nil, nil, nil
	r.text:SetFontObject("GameFontHighlight")
	r.text:SetTextColor(1, 1, 1)
	return r
end

local y, width

local function put(r, height, indent)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", content, "TOPLEFT", indent or 0, -y)
	r:SetSize(width - (indent or 0), height)
	y = y + height
end

-- A foldable heading: gold name, a count at the right, + / -.
local function heading(key, text, count)
	local r = line()
	r.text:SetFontObject("GameFontNormal")
	r.text:ClearAllPoints()
	r.text:SetPoint("LEFT", 4, 0)
	r.text:SetText(text)
	r.right:SetText(count or "")
	local folded = state().folded[key] == true
	r.toggle:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
	r.toggle:Show()
	r.kind = "heading"
	r.onClick = function()
		state().folded[key] = not folded or nil
		Tab:Refresh()
	end
	put(r, ROW + 4)
	return folded
end

local function matches(book, filter)
	if not filter or filter == "" then return true end
	filter = filter:lower()
	return Books:Name(book):lower():find(filter, 1, true) ~= nil or (L[book.place or ""]):lower():find(filter, 1, true) ~= nil
end

-- A book's place nearest the player (several places: the closest one; else the first).
local function nearestPlace(book)
	local best, bestYards
	for _, p in ipairs(Books:Places(book)) do
		local d = BF.Zones:DistanceTo(p.map, p.x, p.y)
		if d and (not bestYards or d < bestYards) then best, bestYards = p, d end
	end
	return best or Books:Places(book)[1], bestYards
end
Tab.NearestPlace = nearestPlace

local function bookRow(book)
	local r = line()
	r.kind, r.book = "book", book
	r.icon:SetTexture(Books:Icon(book))
	r.icon:SetSize(28, 28)
	r.icon:ClearAllPoints()
	r.icon:SetPoint("LEFT", 6, 0)
	r.icon:Show()
	r.icon:SetDesaturated(Books:IsDone(book))
	r.text:ClearAllPoints()
	r.text:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
	r.text:SetPoint("RIGHT", r, "RIGHT", -30, 0)
	r.text:SetText(Books:Name(book))
	if Books:IsDone(book) then r.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end
	local place = nearestPlace(book)
	r.sub:ClearAllPoints()
	r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -2)
	r.sub:SetPoint("RIGHT", r, "RIGHT", -30, 0)
	r.sub:SetText(L[book.place or ""] .. (place and ("   " .. BF.Zones:FormatCoords(place.x, place.y)) or ""))
	local how = Books:How(book)
	r.check:SetChecked(how ~= nil)
	-- The game decides a book in the bags or handed in; only a hand tick can be taken off.
	r.check:SetEnabled(how == nil or how == "ticked")
	r.check:SetScript("OnClick", function(self) Books:Tick(book, self:GetChecked() and true or false) end)
	r.check:Show()
	r.onEnter = function(self)
		local p, yards = nearestPlace(book)
		if p then BookMap:ShowTooltip(self, book, p, yards) end
	end
	r.onClick = function(self, button)
		local p = nearestPlace(book)
		if button == "RightButton" then
			if p then BF.Waypoint:Set(p.map, p.x, p.y, Books:Name(book), L[book.place or ""]) end
		elseif IsShiftKeyDown() then
			Books:Tick(book, not Books:IsDone(book))
		elseif p and WorldMapFrame then
			WorldMapFrame:SetMapID(p.map)
		end
	end
	put(r, BOOK_ROW, 6)
end

local function textRow(text, colour, indent)
	local r = line()
	r.kind = "text"
	r.text:ClearAllPoints()
	r.text:SetPoint("LEFT", 4, 0)
	r.text:SetPoint("RIGHT", -4, 0)
	r.text:SetFontObject("GameFontHighlightSmall")
	r.text:SetText(text)
	if colour then r.text:SetTextColor(colour[1], colour[2], colour[3]) end
	put(r, ROW, indent or 10)
	return r
end

local function itemRow(item)
	local r = line()
	r.kind = "item"
	r.icon:SetTexture(C_Item.GetItemIconByID(item))
	r.icon:SetSize(20, 20)
	r.icon:ClearAllPoints()
	r.icon:SetPoint("LEFT", 6, 0)
	r.icon:Show()
	r.text:ClearAllPoints()
	r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.text:SetPoint("RIGHT", -4, 0)
	r.text:SetFontObject("GameFontHighlightSmall")
	r.text:SetText(C_Item.GetItemNameByID(item) or BF:ItemName(item) or ("item:" .. item))
	local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(item)
	local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if c then r.text:SetTextColor(c.r, c.g, c.b) end
	r.onEnter = function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(item)
		GameTooltip:Show()
	end
	r.onClick = function()
		local _, link = C_Item.GetItemInfo(item)
		if not link then return end
		if IsShiftKeyDown() then ChatEdit_InsertLink(link)
		elseif IsControlKeyDown() and DressUpItemLink then DressUpItemLink(link) end
	end
	put(r, 24, 16)
end

-- The page -----------------------------------------------------------------------------------------------------------

local function progress()
	local done, total = Books:DoneCount(), Books:Count()
	frame.count:SetText(L["Books: %d/%d"]:format(done, total))
	bar:SetMinMaxValues(0, total)
	bar:SetValue(done)
	for _, notch in ipairs(bar.notches) do
		local reached = done >= notch.goal
		notch.label:SetTextColor(reached and GREEN[1] or 1, reached and GREEN[2] or 1, reached and GREEN[3] or 1)
	end
end

function Tab:Refresh()
	if not frame or not frame:IsVisible() then Tab.dirty = true return end
	Tab.dirty = false
	progress()
	for i = 1, used do pool[i]:Hide() end
	used = 0
	y, width = 4, scroll:GetWidth() - 8
	content:SetWidth(width)
	local filter = search:GetText()

	if Route:IsOn() then
		local next = Route:Next()
		if not heading("route", L["Optimized route"], next and ("1/" .. #Route.steps) or "") and next then
			bookRow(next)
		end
	end

	for _, set in ipairs(Books.SETS) do
		local books, done = {}, 0
		for _, b in ipairs(Books.list) do
			if b.set == set then
				if Books:IsDone(b) then done = done + 1 end
				if matches(b, filter) then books[#books + 1] = b end
			end
		end
		local total = 0
		for _, b in ipairs(Books.list) do if b.set == set then total = total + 1 end end
		if #books > 0 and not heading("set" .. set, Books:SetName(set), ("%d / %d"):format(done, total)) then
			for _, b in ipairs(books) do bookRow(b) end
		end
	end

	if not heading("rewards", L["Rewards"]) then
		local count = Books:DoneCount()
		for _, r in ipairs(Books.REWARDS) do
			local reached = count >= r.goal
			textRow(L["%d books: %s"]:format(r.goal, L[r.label]) .. "   " .. ("%d / %d"):format(math.min(count, r.goal), r.goal),
				reached and GREEN or nil)
			for _, item in ipairs(r.items) do itemRow(item) end
		end
	end

	if not heading("group", L["Group"]) then
		if not IsInGroup() then
			textRow(L["You are not in a group."], GREY)
		else
			local me = Books:UnitFullName("player")
			local mine = Books:DoneCount()
			textRow(("%s %s   %d / %d"):format(me or "", L["(you)"], mine, Books:Count()))
			local names = {}
			for name in pairs(Books.group) do names[#names + 1] = name end
			table.sort(names)
			for _, name in ipairs(names) do
				local m = Books.group[name]
				local n = select(2, m.bits:gsub("1", ""))
				textRow(("%s   %d / %d   %s"):format(name, n, Books:Count(), m.version or ""))
			end
			if #names == 0 then textRow(L["Nobody in your group shares their books yet."], GREY) end
			local others = {}
			for name, version in pairs(Books.otherList) do others[#others + 1] = ("%s (%s)"):format(name, version) end
			if #others > 0 then
				table.sort(others)
				textRow(L["Another version of the book list:"] .. " " .. table.concat(others, ", "), GREY)
			end
		end
	end
	content:SetHeight(math.max(y, 1))
	frame.routeButton:SetText(Route:IsOn() and L["Stop the route"] or L["Optimized route"])
	frame.skip:SetShown(Route:IsOn())
	frame.recalc:SetShown(Route:IsOn())
end

local function button(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetText(L[text])
	b:SetScript("OnClick", onClick)
	return b
end

local function build()
	local host = QuestMapFrame
	if not host then return end
	frame = CreateFrame("Frame", "BookFinderBooksTab", host)
	frame:SetAllPoints(host)
	frame:SetFrameLevel(host:GetFrameLevel() + 40)
	frame:EnableMouse(true)
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	frame.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	frame.bg:SetVertexColor(0.05, 0.05, 0.05, 1)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 12, -10)
	frame.title:SetText(L["Library books"])
	frame.count = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.count:SetPoint("TOPRIGHT", -12, -12)

	search = CreateFrame("EditBox", nil, frame, BF.Widgets:Template({ "SearchBoxTemplate", "InputBoxTemplate" }))
	search:SetSize(200, 20)
	search:SetPoint("TOPLEFT", 16, -34)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function() Tab:Refresh() end)
	frame.search = search

	-- Progress: the bar, a notch and number at each reward.
	bar = CreateFrame("StatusBar", nil, frame)
	bar:SetPoint("TOPLEFT", 14, -62)
	bar:SetPoint("TOPRIGHT", -14, -62)
	bar:SetHeight(12)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.25, 0.6, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar.notches = {}
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["Rewards"], 1, 0.82, 0)
		local done = Books:DoneCount()
		for _, r in ipairs(Books.REWARDS) do
			local reached = done >= r.goal
			GameTooltip:AddLine(L["%d books: %s"]:format(r.goal, L[r.label]), reached and 0.2 or 1, reached and 1 or 1, reached and 0.2 or 1)
		end
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.bar = bar
	bar:SetScript("OnSizeChanged", function(self, w)
		for _, notch in ipairs(self.notches) do
			notch.tick:ClearAllPoints()
			notch.tick:SetPoint("CENTER", self, "LEFT", w * notch.goal / Books:Count(), 0)
		end
	end)
	for _, r in ipairs(Books.REWARDS) do
		local notch = { goal = r.goal }
		notch.tick = bar:CreateTexture(nil, "OVERLAY")
		notch.tick:SetColorTexture(1, 0.82, 0, 1)
		notch.tick:SetSize(2, 16)
		notch.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		notch.label:SetPoint("TOP", notch.tick, "BOTTOM", 0, -1)
		notch.label:SetText(r.goal)
		bar.notches[#bar.notches + 1] = notch
	end

	scroll = CreateFrame("ScrollFrame", nil, frame, BF.Widgets:Template({ "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" }))
	scroll:SetPoint("TOPLEFT", 8, -94)
	scroll:SetPoint("BOTTOMRIGHT", -26, 40)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	frame.showAll = button(frame, "Show all", 90, function() Books:TickAll(false) end)
	frame.showAll:SetPoint("BOTTOMLEFT", 10, 10)
	frame.hideAll = button(frame, "Hide all", 90, function() Books:TickAll(true) end)
	frame.hideAll:SetPoint("LEFT", frame.showAll, "RIGHT", 4, 0)
	frame.routeButton = button(frame, "Optimized route", 130, function() Route:Toggle() Tab:Refresh() end)
	frame.routeButton:SetPoint("BOTTOMRIGHT", -10, 10)
	frame.skip = button(frame, "Skip", 60, function() Route:Skip() end)
	frame.skip:SetPoint("BOTTOMLEFT", frame.showAll, "TOPLEFT", 0, 4)
	frame.recalc = button(frame, "Recalc", 70, function() Route:Recalc() end)
	frame.recalc:SetPoint("LEFT", frame.skip, "RIGHT", 4, 0)

	frame:SetScript("OnShow", function() if Tab.dirty ~= false then Tab:Refresh() end end)
	Tab.frame = frame
end

--- Opens the map on the Books tab (/bom, the alerts' cards).
function Tab:Open()
	BF.MapTabs:Select("books")
end

local soon = BF:Debounce(0.1, function() Tab:Refresh() end)

BF:At("login", function()
	build()
	if not frame then return end
	BF.MapTabs:Add({ key = "books", label = "Library books", icon = "Interface\\Icons\\INV_Misc_Book_09", frame = frame })
	for _, m in ipairs({ "BF_BOOKS_CHANGED", "BF_BOOKS_GROUP_CHANGED", "BF_BOOK_ROUTE_CHANGED" }) do BF:Listen(m, soon) end
	BF:On("GROUP_ROSTER_UPDATE", soon)
	BF:On("GET_ITEM_INFO_RECEIVED", soon) -- reward names and icons arrive from the server
	SLASH_BOOKFINDERBOOKS1 = "/bom"
	SlashCmdList.BOOKFINDERBOOKS = function() Tab:Open() end
	Tab:Refresh()
end, 86)
