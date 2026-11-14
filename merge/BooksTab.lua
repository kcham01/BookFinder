-- BookFinder: the BookFinder tab beside the world map's quest log: the one search, and the library books.
--
-- Books on map's own window (with its Rewards and Group side panels) becomes this one tab, drawn with the quest log's
-- parchment and border, its search box, its collapsible list headers and the Who list's large rows.
--
--   Search      two letters or more: quests, NPCs, objects, items, places and books (Search.lua) in the list's place
--   Header      the book glyph, "Library books", how many you have and what the next reward needs
--   Collect     the nearest book; the optimised route (start it, or its next stop and Stop)
--   Rewards     each reward tier, unlocked or how many books to go, with its items (their own tooltips and links)
--   Sets        First set, Level 35, 45 and 60: every book with its place and distance, nearest first;
--               collected books greyed and ticked at the bottom
--   Group       who in your group shares their books, and how far along they are
--
-- Click a book: the game's map pin on it. Shift-click: collected, or not. Right-click: each of its places, the map
-- there, collected. The gear beside the search box holds the list's filters, the bulk marks and the settings.
local ADDON, root = ...
local public = root.public
local BOOKS = root.Books
if not (public and BOOKS) or BOOKS.__skip or not public.Tabs then
	return
end

local L = setmetatable({}, { __index = function(_, k) return (BOOKS.L and BOOKS.L[k]) or k end })

-- the quest log's geometry (from Shortest Path's ServicesPanel, which it matched before 2.0) ------------------
local TAB_KEY = "bookfinder.books"
local TOP_BAR = 29
local PAD = 6
local HEADER_HEIGHT = 22
local HEADER_GAP = 4
local GROUP_GAP = 6
local ROW_HEIGHT = 44
local ROW_GAP = 2
local ICON = 30
local SMALL_HEIGHT = 28
local SMALL_ICON = 22
local SMALL_INDENT = 16
local TAB_ICON = 32
local LIST_TOP = 4 + 34 + 6
local GEAR = 20
-- Estimates are asked again this often while the tab stays open, so walking or a boat is reflected
local TICK = 15

-- The tab's glyph: the client's lore book where it has one, else the book icon cut round
local GLYPHS = { "Campaign-QuestLog-LoreBook" }
local BOOK_FILE = "Interface\\Icons\\INV_Misc_Book_09"
local ROUTE_FILE = "Interface\\Icons\\INV_Misc_Map_01"
local STOP_ATLAS, STOP_FILE = "common-icon-redx", "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local CHECK_ATLAS, CHECK_FILE = "common-icon-checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready"
local GEAR_ATLAS, GEAR_FILE = "questlog-icon-setting", "Interface\\Buttons\\UI-OptionsButton"
local QUESTION_MARK = 134400
-- the client's font colours (gold names, white text, grey for done)
local GOLD = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
local WHITE = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
local GREY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
local GREY_RGB = { GREY.r, GREY.g, GREY.b }

local SETS = {
	{ id = 1, label = "Starting set" },
	{ id = 35, label = "Level 35 set" },
	{ id = 45, label = "Level 45 set" },
	{ id = 60, label = "Level 60 set" },
}
-- (Books' own reward tiers, Rewards.lua; a copy only if it doesn't share them)
local TIERS = BOOKS.REWARD_TIERS or {
	{ goal = 10, label = "10 books: necklace", items = { { 277203, "Scholarly Pendant" }, { 277204, "Erudite's Amulet" } } },
	{ goal = 20, label = "20 books: ring", items = { { 281634, "Field Researcher's Loop" }, { 281635, "Philanthropist's Ring" } } },
	{ goal = 25, label = "25 books: bow, crest or light", items = {
		{ 277254, "Truthseeker's Bow" }, { 277258, "Crest of Elucidation" }, { 277260, "Researcher's Night Light" } } },
}

-- Art: helpers for the client's quest-log art ---------------
local Art = {}
local infos = {}
function Art.Info(atlas)
	local info = infos[atlas]
	if info == nil then
		info = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) or false
		infos[atlas] = info
	end
	return info or nil
end
function Art.Fit(texture, atlas, width, height)
	local info = Art.Info(atlas)
	if not info or not info.width or info.width <= 0 or not info.height or info.height <= 0 then return false end
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetAtlas(atlas)
	local scale = math.min(width / info.width, height / info.height)
	texture:SetSize(info.width * scale, info.height * scale)
	return true
end
function Art.Icon(texture, file, size)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetTexture(file)
	texture:SetSize(size, size)
end
-- an atlas when the client has it, else a file at `size`
function Art.Either(texture, atlas, file, size)
	if not Art.Fit(texture, atlas, size, size) then Art.Icon(texture, file, size) end
end
function Art.Cover(texture, atlas, width, height)
	texture:SetAtlas(atlas)
	local info = Art.Info(atlas)
	if not (info and info.width > 0 and info.height > 0 and width > 0 and height > 0) then return end
	local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	if not (left and right and top and bottom) then return end
	local box, native = width / height, info.width / info.height
	if native > box then
		local cut = (right - left) * (1 - box / native) / 2
		left, right = left + cut, right - cut
	else
		local cut = (bottom - top) * (1 - native / box) / 2
		top, bottom = top + cut, bottom - cut
	end
	texture:SetTexCoord(left, right, top, bottom)
end
function Art.CoverFrame(frame, texture, atlas, trimWidth, trimHeight)
	local function Lay(width, height) Art.Cover(texture, atlas, (width or 0) - trimWidth, (height or 0) - trimHeight) end
	Lay(frame:GetSize())
	frame:HookScript("OnSizeChanged", function(_, width, height) Lay(width, height) end)
end
local ROW_ART = 69
function Art.RowTexture(row, atlas, layer)
	local texture = row:CreateTexture(nil, layer)
	texture:SetAtlas(atlas)
	local function Lay(width, height)
		if not height or height <= 0 then return end
		local scale = height / ROW_ART
		texture:SetScale(scale)
		texture:SetSize((width or 0) / scale, ROW_ART)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	end
	Lay(row:GetSize())
	row:HookScript("OnSizeChanged", function(_, width, height) Lay(width, height) end)
	return texture
end
function Art.RowArt(row)
	Art.RowTexture(row, "common-button-list-large", "BACKGROUND")
	local hover = Art.RowTexture(row, "common-button-list-large-hover", "HIGHLIGHT")
	hover:SetBlendMode("ADD")
end
function Art.Band(texture, atlas)
	texture:SetAtlas(atlas)
	texture:SetAllPoints()
end

-- Helpers ----------------------------------------------------------------------------------------------------------
-- How far a book's place is from you, in yards, straight across the continent (nil on another continent). The
-- "estimates" below are these distances: nearest first, as a straight line.
local function world(map, x, y)
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
	local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
	if not (ok and continent and pos) then return end
	local wx, wy = pos.x, pos.y
	if not wx and pos.GetXY then wx, wy = pos:GetXY() end
	return continent, wx, wy
end
local function api()
	return { Estimate = function(fromMap, fromX, fromY, toMap, toX, toY)
		local c1, x1, y1 = world(fromMap, fromX, fromY)
		local c2, x2, y2 = world(toMap, toX, toY)
		if not (c1 and c2 and c1 == c2) then return nil end
		return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
	end }
end

-- yards as the rows show them
local function Countdown(yards)
	yards = math.max(0, yards or 0)
	if yards < 1000 then return ("%d yd"):format(math.floor(yards / 10 + 0.5) * 10) end
	return ("%.1fk yd"):format(yards / 1000)
end

local function bookIcon(b) return "Interface\\Icons\\" .. (b.icon or "INV_Misc_Book_09") end
local function isDone(b) return BOOKS.IsDone and BOOKS.IsDone(b) and true or false end
local function countDone() return BOOKS.CountDone and BOOKS.CountDone() or 0 end
local function allBooks() return BOOKS.BOOKS or {} end

local function itemIcon(itemID)
	return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or QUESTION_MARK
end
local function itemInfo(itemID)
	local get = C_Item and C_Item.GetItemInfo or GetItemInfo
	if not get then return end
	return get(itemID)
end
local function itemLink(itemID)
	local _, link = itemInfo(itemID)
	return link
end

local function openMapAt(mapID)
	if not WorldMapFrame then return end
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown() or not ToggleWorldMap then return end
		ToggleWorldMap()
	end
	if mapID then WorldMapFrame:SetMapID(mapID) end
end

-- a map pin on one place of a book; the map there when it can't take one
local function goTo(b, loc)
	loc = loc or b.locs[1]
	if not loc then return end
	if not (BOOKS.Waypoint and BOOKS.Waypoint(loc, b.name)) then openMapAt(loc[1]) end
end

local function classColor(name)
	local _, class = UnitClass(name)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return GOLD.r, GOLD.g, GOLD.b
end

-- State ------------------------------------------------------------------------------------------------------------
local panel, scroll, scrollContent, content, list, searchBox, headerTitle, subtitle, emptyText
local visible = false
local query = ""
local headers, rows, smalls = {}, {}, {}
local rowsByKey = {}
-- Travel times: the last full round, kept on screen while the next one comes in (so opening the tab or the ticker
-- never blanks the times or reorders the list twice); `fresh` swaps in once every book has its time
local estimates = {}       -- book key -> seconds, the quickest of its places
local bestLoc = {}         -- book key -> that place
local fresh, freshLoc
local queue, queueAt
local ticker
local Refresh, Queue

local function folded()
	local db = BOOKS.db
	if not db then return {} end
	db.tabFolded = type(db.tabFolded) == "table" and db.tabFolded or {}
	return db.tabFolded
end
local function isCollapsed(key, default)
	local v = folded()[key]
	if v == nil then return default and true or false end
	return v
end

local function matches(b)
	if query == "" then return true end
	local q = query:lower()
	if (b.name or ""):lower():find(q, 1, true) then return true end
	for _, loc in ipairs(b.locs) do
		if (loc[4] or ""):lower():find(q, 1, true) then return true end
	end
	return false
end

-- who in the group still lacks a book (for its detail line)
local function groupMissing(b)
	if not (BOOKS.GroupNames and BOOKS.GroupHas) then return 0 end
	local n = 0
	for _, name in ipairs(BOOKS.GroupNames()) do
		if not BOOKS.GroupHas(name, b) then n = n + 1 end
	end
	return n
end

-- Rows -------------------------------------------------------------------------------------------------------------
local function tooltipFor(self)
	local spec = self.spec
	if not spec or not spec.tooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	spec.tooltip(GameTooltip)
	GameTooltip:Show()
end
local function leave(self)
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- the goods or book over a row's icon: its own item tooltip, and Shift-click links it
local function addItemButton(row, size)
	row.Item = CreateFrame("Button", nil, row)
	row.Item:SetSize(size, size)
	row.Item:SetPoint("CENTER", row.Icon)
	row.Item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row.Item:SetScript("OnEnter", function(self)
		row:LockHighlight()
		local id = row.spec and row.spec.itemID
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if id then
			GameTooltip:SetItemByID(id)
			if row.spec.itemTooltip then row.spec.itemTooltip(GameTooltip) end
		elseif row.spec and row.spec.tooltip then
			row.spec.tooltip(GameTooltip)
		end
		GameTooltip:Show()
	end)
	row.Item:SetScript("OnLeave", function(self)
		row:UnlockHighlight()
		leave(self)
	end)
	row.Item:SetScript("OnClick", function(_, button)
		local id = row.spec and row.spec.itemID
		local link = id and itemLink(id)
		if not (button == "LeftButton" and link and HandleModifiedItemClick and HandleModifiedItemClick(link)) then
			row:Click(button)
		end
	end)
end

local function rowClick(self, button)
	local spec = self.spec
	if spec and spec.onClick then spec.onClick(button, self) end
end

local function CreateRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	Art.RowArt(row)
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetPoint("LEFT", 8, 0)
	addItemButton(row, ICON)
	row.Time = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.Time:SetPoint("TOPRIGHT", -8, -8)
	row.Time:SetJustifyH("RIGHT")
	row.Check = row:CreateTexture(nil, "OVERLAY")
	row.Check:SetPoint("RIGHT", -10, 0)
	Art.Either(row.Check, CHECK_ATLAS, CHECK_FILE, 18)
	row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
	row.Label:SetJustifyH("LEFT")
	row.Label:SetWordWrap(false)
	row.Label:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, 4)
	row.Label:SetPoint("RIGHT", row.Time, "LEFT", -6, 0)
	row.Detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.Detail:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -4)
	row.Detail:SetPoint("RIGHT", row, "RIGHT", -34, 0)
	row.Detail:SetJustifyH("LEFT")
	row.Detail:SetWordWrap(false)
	row:SetScript("OnClick", rowClick)
	row:SetScript("OnEnter", tooltipFor)
	row:SetScript("OnLeave", leave)
	return row
end

-- one line, indented under its row: a reward item, a group member, an action
local function CreateSmall(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(SMALL_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	Art.RowArt(row)
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetPoint("LEFT", 6, 0)
	addItemButton(row, SMALL_ICON)
	row.Time = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.Time:SetPoint("RIGHT", -8, 0)
	row.Time:SetJustifyH("RIGHT")
	row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
	row.Label:SetPoint("RIGHT", row.Time, "LEFT", -6, 0)
	row.Label:SetJustifyH("LEFT")
	row.Label:SetWordWrap(false)
	row:SetScript("OnClick", rowClick)
	row:SetScript("OnEnter", tooltipFor)
	row:SetScript("OnLeave", leave)
	return row
end

local function CreateHeader(parent)
	local header = CreateFrame("Button", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	for _, layer in ipairs({ "BACKGROUND", "HIGHLIGHT" }) do
		local art = header:CreateTexture(nil, layer)
		Art.Band(art, "common-button-list-collapseExpand")
		if layer == "HIGHLIGHT" then
			art:SetBlendMode("ADD")
			art:SetAlpha(0.4)
		end
	end
	header.CollapseButton = CreateFrame("Button", nil, header, "CollapseButtonTemplate")
	header.CollapseButton:SetPoint("RIGHT", -6, 0)
	header.Count = header:CreateFontString(nil, "ARTWORK", "Game15Font_Shadow")
	header.Count:SetPoint("RIGHT", -28, 0)
	header.Count:SetJustifyH("RIGHT")
	header.Name = header:CreateFontString(nil, "ARTWORK", "Game15Font_Shadow")
	header.Name:SetPoint("LEFT", 8, 0)
	header.Name:SetPoint("RIGHT", header.Count, "LEFT", -4, 0)
	header.Name:SetJustifyH("LEFT")
	header.Name:SetWordWrap(false)
	if header.Name.SetMaxLines then header.Name:SetMaxLines(1) end
	for _, text in ipairs({ header.Name, header.Count }) do
		text:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
	end
	local function Toggle()
		folded()[header.key] = not header.collapsed
		Refresh()
		Queue()
	end
	header:SetScript("OnClick", Toggle)
	header.CollapseButton:SetScript("OnClick", Toggle)
	return header
end

-- paint a pooled row from its spec
local function setIcon(texture, spec, size)
	texture:SetDesaturated(spec.dim and true or false)
	texture:SetAlpha(spec.dim and 0.55 or 1)
	if spec.atlas and Art.Fit(texture, spec.atlas, size, size) then return end
	local file = spec.file or (spec.itemID and itemIcon(spec.itemID)) or QUESTION_MARK
	Art.Icon(texture, file, size)
	if spec.coords then texture:SetTexCoord(unpack(spec.coords)) end
end

local function Paint(row)
	local spec = row.spec
	setIcon(row.Icon, spec, row.Detail and ICON or SMALL_ICON)
	row.Label:SetText(spec.label or "")
	if spec.labelColor then
		row.Label:SetTextColor(unpack(spec.labelColor))
	elseif row.Detail then
		row.Label:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
	else
		row.Label:SetTextColor(WHITE.r, WHITE.g, WHITE.b)
	end
	if row.Detail then row.Detail:SetText(spec.detail or "") end
	local time = spec.time
	if spec.book and not spec.check then
		local seconds = (fresh and fresh[spec.book.key]) or estimates[spec.book.key]
		time = seconds and Countdown(seconds) or ""
	end
	row.Time:SetText(time or "")
	if spec.timeColor then
		row.Time:SetTextColor(unpack(spec.timeColor))
	else
		row.Time:SetTextColor(WHITE.r, WHITE.g, WHITE.b)
	end
	if row.Check then row.Check:SetShown(spec.check and true or false) end
end

-- Books ------------------------------------------------------------------------------------------------------------
local function placesText(b)
	local first = b.locs[1]
	if not first then return L["location unknown"] end
	local loc = bestLoc[b.key] or first
	local text = loc[4] or ""
	if #b.locs > 1 then text = text .. (" |cff8f8f8f(+%d)|r"):format(#b.locs - 1) end
	return text
end

local function bookTooltip(b)
	return function(tt)
		tt:AddLine(b.name, 1, 0.82, 0)
		for _, loc in ipairs(b.locs) do
			tt:AddLine(("%s |cff8f8f8f(%.1f, %.1f)|r"):format(loc[4] or "", loc[2], loc[3]), 1, 1, 1, true)
		end
		if isDone(b) then tt:AddLine(L["collected"], 0.1, 1, 0.1) end
		if BOOKS.AddGroupTooltip then
			-- (Books writes its group lines to the GameTooltip)
			pcall(BOOKS.AddGroupTooltip, b)
		end
		tt:AddLine(" ")
		tt:AddLine(L["Click: go there"], 0.5, 1, 0.5)
		tt:AddLine(isDone(b) and L["Shift-click: show on the map again"] or L["Shift-click: mark as collected"], 0.5, 1, 0.5)
		tt:AddLine(L["Right-click: more"], 0.5, 1, 0.5)
	end
end

local function bookMenu(owner, b)
	public.ContextMenu(owner, function(_, menu)
		menu:CreateTitle(b.name)
		for _, loc in ipairs(b.locs) do
			local where = #b.locs > 1 and (L["Go to %s"]):format(loc[4] or "?") or L["Go there"]
			menu:CreateButton(where, function() goTo(b, loc) end)
		end
		menu:CreateButton(L["Show on the map"], function() openMapAt((bestLoc[b.key] or b.locs[1] or {})[1]) end)
		menu:CreateDivider()
		menu:CreateCheckbox(L["Collected"], function() return isDone(b) end,
			function() if BOOKS.SetDone then BOOKS.SetDone(b, not isDone(b)) end end)
	end)
end

local function bookSpec(b)
	local done = isDone(b)
	local detail = placesText(b)
	local missing = groupMissing(b)
	if missing > 0 then
		detail = detail .. (" · |cff66ccff%s|r"):format(missing == 1 and L["1 in your group needs it"] or (L["%d in your group need it"]):format(missing))
	end
	return {
		key = b.key, book = b,
		file = bookIcon(b), itemID = b.item, dim = done, check = done,
		label = b.name,
		labelColor = done and GREY_RGB or nil,
		detail = detail,
		tooltip = bookTooltip(b),
		itemTooltip = function(tt)
			tt:AddLine(" ")
			tt:AddLine(done and L["collected"] or L["missing"], done and 0.1 or 1, done and 1 or 0.3, done and 0.1 or 0.3)
		end,
		onClick = function(button, row)
			if button == "RightButton" then
				bookMenu(row, b)
			elseif IsShiftKeyDown() then
				if BOOKS.SetDone then BOOKS.SetDone(b, not isDone(b)) end
			else
				goTo(b, bestLoc[b.key])
			end
		end,
	}
end

-- nearest missing book
local function nearest()
	local best, bestSeconds
	for _, b in ipairs(allBooks()) do
		local s = estimates[b.key]
		if s and not isDone(b) and (not bestSeconds or s < bestSeconds) then best, bestSeconds = b, s end
	end
	if best then return best end
	if BOOKS.NearestBook then
		local b = BOOKS.NearestBook()
		return b
	end
end

-- Sections ---------------------------------------------------------------------------------------------------------
local function collectSection()
	local s = { key = "collect", label = L["Collect"], rows = {} }
	local missing = #allBooks() - countDone()
	if missing <= 0 then
		s.rows[1] = { small = true, atlas = CHECK_ATLAS, file = CHECK_FILE, label = L["Every book has been collected."] }
		return s
	end
	local route = BOOKS.db and BOOKS.db.routeOn and BOOKS.GetRoute and BOOKS.GetRoute()
	local stop = route and route[1]
	if stop then
		local b = stop.book
		local guided = BOOKS.RouteGuided and BOOKS.RouteGuided()
		s.rows[#s.rows + 1] = {
			key = "route", book = b, file = bookIcon(b), itemID = b.item,
			label = (L["Route: %s"]):format(b.name),
			detail = ("%s · %s"):format(stop.loc[4] or "", (L["%d books left"]):format(#route)),
			tooltip = function(tt)
				tt:AddLine(L["Optimized route"], 1, 0.82, 0)
				for i, step in ipairs(route) do
					if i > 8 then tt:AddLine(("…%d"):format(#route - 8), 0.6, 0.6, 0.6) break end
					tt:AddDoubleLine(("%d. %s"):format(i, step.book.name), step.loc[4] or "", 1, 1, 1, 0.6, 0.6, 0.6)
				end
				tt:AddLine(" ")
				tt:AddLine(guided and L["The map pin is on this book."] or L["Click: put the map pin on it"], 0.5, 1, 0.5)
				tt:AddLine(L["Shift-click: start again from the nearest book"], 0.5, 1, 0.5)
			end,
			onClick = function()
				if IsShiftKeyDown() then
					if BOOKS.RecalcRoute then BOOKS.RecalcRoute() end
				elseif BOOKS.GuideRoute then
					BOOKS.GuideRoute()
				end
			end,
		}
		s.rows[#s.rows + 1] = {
			small = true, atlas = STOP_ATLAS, file = STOP_FILE, label = L["Stop the route"],
			onClick = function() if BOOKS.ToggleRoute then BOOKS.ToggleRoute(false) end end,
		}
	else
		local b = nearest()
		if b then
			local spec = bookSpec(b)
			spec.key = "nearest"
			spec.detail = ("%s · %s"):format(L["Nearest book"], placesText(b))
			s.rows[#s.rows + 1] = spec
		end
		s.rows[#s.rows + 1] = {
			key = "start", file = ROUTE_FILE, label = L["Optimized route"],
			detail = (L["All %d missing books, lowest level first"]):format(missing),
			tooltip = function(tt)
				tt:AddLine(L["Optimized route"], 1, 0.82, 0)
				tt:AddLine(L["Every book you still need, set by set, in the order that takes the least travel. The map pin moves to each one."], 1, 1, 1, true)
			end,
			onClick = function() if BOOKS.ToggleRoute then BOOKS.ToggleRoute(true, true) end end,
		}
	end
	return s
end

local function rewardsSection()
	local done = countDone()
	local s = { key = "rewards", label = L["Rewards"], rows = {}, count = ("%d / %d"):format(math.min(done, TIERS[#TIERS].goal), TIERS[#TIERS].goal) }
	local all = true
	for _, tier in ipairs(TIERS) do
		local reached = done >= tier.goal
		all = all and reached
		local first = tier.items[1] and tier.items[1][1]
		s.rows[#s.rows + 1] = {
			key = "tier" .. tier.goal, itemID = first, dim = not reached,
			label = L[tier.label],
			detail = reached and L["Unlocked: choose one at the library"] or (L["%d more books"]):format(tier.goal - done),
			time = reached and "" or ("%d / %d"):format(done, tier.goal),
			check = reached,
			timeColor = GREY_RGB,
			tooltip = function(tt)
				tt:AddLine(L[tier.label], 1, 0.82, 0)
				tt:AddLine(reached and L["Unlocked: choose one at the library"] or (L["%d more books"]):format(tier.goal - done), 1, 1, 1)
				tt:AddLine(" ")
				for _, item in ipairs(tier.items) do
					local name, _, quality = itemInfo(item[1])
					local r, g, b = 1, 1, 1
					if quality and C_Item and C_Item.GetItemQualityColor then r, g, b = C_Item.GetItemQualityColor(quality) end
					tt:AddLine(("|T%s:16|t %s"):format(itemIcon(item[1]), name or L[item[2]]), r, g, b)
				end
			end,
		}
		for _, item in ipairs(tier.items) do
			local id, fallback = item[1], item[2]
			local name, _, quality, _, _, _, _, _, equipLoc = itemInfo(id)
			local color
			if quality and C_Item and C_Item.GetItemQualityColor then
				local r, g, b = C_Item.GetItemQualityColor(quality)
				color = { r, g, b }
			end
			local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or ""
			s.rows[#s.rows + 1] = {
				small = true, indent = SMALL_INDENT, itemID = id,
				label = name or L[fallback], labelColor = color, time = slot,
				timeColor = GREY_RGB,
				tooltip = function(tt) tt:SetItemByID(id) end,
				onClick = function()
					local link = itemLink(id)
					if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
				end,
			}
		end
	end
	s.defaultCollapsed = all
	return s
end

-- each set's books: missing ones nearest first (straight order until the times land), then the collected ones
local function setSections()
	local out = {}
	local level = UnitLevel("player") or 60
	local db = BOOKS.db or {}
	for _, set in ipairs(SETS) do
		if not (db.myLevelOnly and set.id > level) then
			local s = { key = "set" .. set.id, label = L[set.label], rows = {} }
			local missing, collected, n, total = {}, {}, 0, 0
			for i, b in ipairs(allBooks()) do
				if b.set == set.id then
					total = total + 1
					local done = isDone(b)
					if done then n = n + 1 end
					if matches(b) and not (done and db.hideCollected and not (BOOKS.GroupNeeds and BOOKS.GroupNeeds(b))) then
						local list = done and collected or missing
						list[#list + 1] = { b = b, i = i }
					end
				end
			end
			table.sort(missing, function(x, y)
				local a, c = estimates[x.b.key], estimates[y.b.key]
				if a and c and a ~= c then return a < c end
				if (a ~= nil) ~= (c ~= nil) then return a ~= nil end
				return x.i < y.i
			end)
			for _, e in ipairs(missing) do s.rows[#s.rows + 1] = bookSpec(e.b) end
			for _, e in ipairs(collected) do s.rows[#s.rows + 1] = bookSpec(e.b) end
			s.count = ("%d / %d"):format(n, total)
			s.defaultCollapsed = n == total and query == ""
			if #s.rows > 0 or query == "" then out[#out + 1] = s end
		end
	end
	return out
end

local function groupSection()
	if not (IsInGroup and IsInGroup()) or not BOOKS.GroupNames then return end
	local s = { key = "group", label = L["Group"], rows = {} }
	local names = BOOKS.GroupNames()
	local total = #allBooks()
	local sharing = {}
	for _, name in ipairs(names) do
		sharing[name] = true
		local n = 0
		for _, b in ipairs(allBooks()) do if BOOKS.GroupHas(name, b) then n = n + 1 end end
		local version = BOOKS.GroupVersion and BOOKS.GroupVersion(name)
		local needMine = 0
		for _, b in ipairs(allBooks()) do
			if isDone(b) and not BOOKS.GroupHas(name, b) then needMine = needMine + 1 end
		end
		local r, g, bl = classColor(name)
		local _, class = UnitClass(name)
		local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
		s.rows[#s.rows + 1] = {
			key = "member:" .. name,
			file = coords and "Interface\\TargetingFrame\\UI-Classes-Circles" or BOOK_FILE,
			coords = coords and { coords[1], coords[2], coords[3], coords[4] } or nil,
			label = name, labelColor = { r, g, bl },
			detail = needMine > 0 and (L["%d of yours they still need"]):format(needMine) or (version and ("v" .. version) or ""),
			time = ("%d / %d"):format(n, total),
			tooltip = function(tt) if BOOKS.AddGroupProgressTooltip then pcall(BOOKS.AddGroupProgressTooltip, tt) end end,
		}
	end
	for _, name in ipairs(BOOKS.GroupRoster and BOOKS.GroupRoster() or {}) do
		if not sharing[name] then
			local other = BOOKS.GroupOtherVersion and BOOKS.GroupOtherVersion(name)
			local r, g, bl = classColor(name)
			s.rows[#s.rows + 1] = {
				small = true, file = BOOK_FILE, dim = true,
				label = name, labelColor = { r, g, bl },
				time = other and (L["another book list (v%s)"]):format(other) or L["no BookFinder or Books on map"],
				timeColor = GREY_RGB,
			}
		end
	end
	if #s.rows == 0 then return end
	s.count = tostring(#names)
	return s
end

local function sections()
	local out = {}
	if query == "" then
		out[#out + 1] = collectSection()
		out[#out + 1] = rewardsSection()
		local g = groupSection()
		if g then out[#out + 1] = g end
	end
	for _, s in ipairs(setSections()) do out[#out + 1] = s end
	for _, s in ipairs(out) do
		s.collapsed = query == "" and isCollapsed(s.key, s.defaultCollapsed)
		s.count = s.count or ""
	end
	return out
end

-- Layout -----------------------------------------------------------------------------------------------------------
local shownRows = 0

local searchShown = false
function Refresh()
	if not visible or not panel then return end
	if not BOOKS.db then return end
	rowsByKey = {}
	-- two letters or more: the one search (Search.lua) takes the list's place
	local q = strtrim and strtrim(query) or query
	if #q >= 2 and public.DrawSearch then
		for _, r in ipairs(rows) do r:Hide() end
		for _, r in ipairs(smalls) do r:Hide() end
		for _, h in ipairs(headers) do h:Hide() end
		searchShown = true
		local bottom, drawn = public.DrawSearch(list, 0, query, searchBox)
		shownRows = drawn or 0
		emptyText:SetShown(shownRows == 0)
		if shownRows == 0 then
			emptyText:SetText(L["Nothing matches."])
			emptyText:ClearAllPoints()
			emptyText:SetPoint("TOPLEFT", 10, -((bottom or 0) + 8))
			emptyText:SetPoint("TOPRIGHT", -10, -((bottom or 0) + 8))
		end
		content:SetHeight(LIST_TOP + (bottom or 0) + PAD)
		scrollContent:SetSize(panel:GetWidth(), LIST_TOP + (bottom or 0) + PAD)
		return
	end
	if searchShown and public.DrawSearch then
		searchShown = false
		public.DrawSearch(list, 0, "", searchBox)   -- (takes its rows away)
	end
	local top = 0
	local rowAt, smallAt, headerAt = 0, 0, 0
	for _, section in ipairs(sections()) do
		headerAt = headerAt + 1
		local header = headers[headerAt] or CreateHeader(list)
		headers[headerAt] = header
		header.key, header.collapsed = section.key, section.collapsed
		header.Name:SetText(section.label)
		header.Count:SetText(section.count)
		if header.CollapseButton.UpdateCollapsedState then header.CollapseButton:UpdateCollapsedState(section.collapsed) end
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", 6, -top)
		header:SetPoint("TOPRIGHT", -6, -top)
		header:Show()
		top = top + HEADER_HEIGHT + HEADER_GAP
		if not section.collapsed then
			for _, spec in ipairs(section.rows) do
				local row, height
				if spec.small then
					smallAt = smallAt + 1
					row = smalls[smallAt] or CreateSmall(list)
					smalls[smallAt] = row
					height = SMALL_HEIGHT
				else
					rowAt = rowAt + 1
					row = rows[rowAt] or CreateRow(list)
					rows[rowAt] = row
					height = ROW_HEIGHT
				end
				row.spec = spec
				if spec.key then rowsByKey[spec.key] = row end
				Paint(row)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 6 + (spec.indent or 0), -top)
				row:SetPoint("TOPRIGHT", -6, -top)
				row:Show()
				top = top + height + ROW_GAP
			end
			top = top + GROUP_GAP - ROW_GAP
		end
	end
	for at = rowAt + 1, #rows do rows[at]:Hide() end
	for at = smallAt + 1, #smalls do smalls[at]:Hide() end
	for at = headerAt + 1, #headers do headers[at]:Hide() end
	shownRows = rowAt + smallAt

	local status
	if #allBooks() == 0 then
		status = L["The book list is still loading."]
	elseif query ~= "" and shownRows == 0 then
		status = L["No book matches."]
	end
	emptyText:SetText(status or "")
	emptyText:SetShown(status ~= nil)
	if status then
		local y = top > 0 and -top - GROUP_GAP or -8
		emptyText:ClearAllPoints()
		emptyText:SetPoint("TOPLEFT", 10, y)
		emptyText:SetPoint("TOPRIGHT", -10, y)
	end
	content:SetHeight(LIST_TOP + top + PAD)
	scrollContent:SetSize(panel:GetWidth(), LIST_TOP + top + PAD)

	local done, total = countDone(), #allBooks()
	local nextGoal
	for _, tier in ipairs(TIERS) do
		if done < tier.goal then nextGoal = tier break end
	end
	local line = (L["%d of %d collected"]):format(done, total)
	if nextGoal then
		line = line .. " · " .. (L["%d to the next reward"]):format(nextGoal.goal - done)
	elseif total > 0 and done >= total then
		line = L["Every book collected"]
	end
	subtitle:SetText(line)
end

-- one estimate a frame, only while the tab is shown; the frame script is cleared as soon as the queue is empty
local function StepQueue()
	local step = queue and queue[queueAt]
	local spf = api()
	if not step or not spf then
		queue = nil
		panel:SetScript("OnUpdate", nil)
		return
	end
	queueAt = queueAt + 1
	local loc = step.loc
	local ok, seconds = pcall(spf.Estimate, step.map, step.x, step.y, loc[1], loc[2] / 100, loc[3] / 100)
	if ok and type(seconds) == "number" then
		local key = step.book.key
		if not fresh[key] or seconds < fresh[key] then
			fresh[key], freshLoc[key] = seconds, loc
		end
		local row = rowsByKey[key]
		if row and row:IsShown() and row.spec and row.spec.book == step.book then Paint(row) end
	end
	if queueAt > #queue then
		queue = nil
		panel:SetScript("OnUpdate", nil)
		estimates, bestLoc, fresh, freshLoc = fresh, freshLoc, nil, nil
		-- every time is in: the sets reorder by it, the nearest book is the nearest by travel, once
		Refresh()
	end
end

function Queue()
	if not visible or not panel then return end
	queue = nil
	panel:SetScript("OnUpdate", nil)
	if not api() then return end
	local map = C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return end
	local x, y = pos.x, pos.y
	if not (x and y) then x, y = pos:GetXY() end
	local steps = {}
	for _, b in ipairs(allBooks()) do
		if not isDone(b) then
			for _, loc in ipairs(b.locs) do
				steps[#steps + 1] = { book = b, loc = loc, map = map, x = x, y = y }
			end
		end
	end
	if #steps == 0 then return end
	queue, queueAt = steps, 1
	fresh, freshLoc = {}, {}
	panel:SetScript("OnUpdate", StepQueue)
end

-- a new zone: the old times were from somewhere else
local function Requeue()
	estimates, bestLoc = {}, {}
	Refresh()
	Queue()
end
-- the same place, asked again: the old times stay until the new ones are in
local function Recheck()
	Refresh()
	Queue()
end

-- Books' own changes (a book collected, the group's books, the route) redraw the tab, once per frame at most
local pending = false
local function Soon()
	if not visible or pending then return end
	pending = true
	C_Timer.After(0, function()
		pending = false
		Refresh()
	end)
end

-- The top bar: the quest log's search box, and the gear with the list's filters ----------------------------------
local function filterMenu(owner)
	public.ContextMenu(owner, function(_, menu)
		local db = BOOKS.db or {}
		local function flag(key, invert)
			return function() return (db[key] and true or false) ~= (invert or false) end,
				function()
					db[key] = not db[key] or nil
					if BOOKS.Refresh then BOOKS.Refresh() end
					Refresh()
				end
		end
		menu:CreateTitle(L["Books"])
		menu:CreateCheckbox(L["Hide collected books"], flag("hideCollected"))
		menu:CreateCheckbox(L["Only sets for my level"], flag("myLevelOnly"))
		menu:CreateDivider()
		menu:CreateButton(L["Mark every book collected"], function() if BOOKS.SetAll then BOOKS.SetAll(true) end end)
		menu:CreateButton(L["Show every book on the map again"], function() if BOOKS.SetAll then BOOKS.SetAll(false) end end)
		menu:CreateDivider()
		menu:CreateButton(L["Book switches (the map's menu)"], function() if public.OpenMapMenu then public.OpenMapMenu() end end)
	end)
end

local function BuildTopBar(parent)
	local gear = CreateFrame("Button", nil, parent)
	gear:SetSize(GEAR, GEAR)
	gear:SetPoint("TOPRIGHT", -3, -2)
	local art = gear:CreateTexture(nil, "ARTWORK")
	art:SetPoint("CENTER")
	Art.Either(art, GEAR_ATLAS, GEAR_FILE, GEAR - 2)
	local glow = gear:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	glow:SetBlendMode("ADD")
	gear:SetScript("OnClick", filterMenu)
	gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Filters"])
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", leave)

	searchBox = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
	if searchBox.Instructions then searchBox.Instructions:SetText(L["Search quests, NPCs, items, places and books"]) end
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", 6, -2)
	searchBox:SetPoint("RIGHT", gear, "LEFT", -4, 0)
	searchBox:SetMaxLetters(60)
	searchBox:HookScript("OnTextChanged", function()
		local text = searchBox:GetText() or ""
		if text == query then return end
		query = text
		Refresh()
		if scroll then scroll:SetVerticalScroll(0) end
	end)
end

local function BuildHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", 8, -4)
	header:SetPoint("TOPRIGHT", -8, -4)
	header:SetHeight(34)
	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("LEFT", 2, 0)
	local glyph = false
	for _, atlas in ipairs(GLYPHS) do
		if Art.Fit(icon, atlas, ICON, ICON) then glyph = true break end
	end
	if not glyph then Art.Icon(icon, BOOK_FILE, ICON - 2) end
	headerTitle = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge2")
	headerTitle:SetPoint("TOP", 0, -1)
	headerTitle:SetText(L["Library books"])
	subtitle = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	subtitle:SetPoint("TOP", headerTitle, "BOTTOM", 0, -2)
	return header
end

local function BuildContent(parent)
	BuildTopBar(parent)
	local body = CreateFrame("Frame", nil, parent)
	body:SetPoint("TOPLEFT", 0, -TOP_BAR)
	body:SetPoint("BOTTOMRIGHT")
	CreateFrame("Frame", nil, body, "QuestLogBorderFrameTemplate")
	local viewport = CreateFrame("Frame", nil, body)
	viewport:SetPoint("TOPLEFT")
	viewport:SetPoint("BOTTOMRIGHT")
	scroll = CreateFrame("ScrollFrame", nil, viewport, "ScrollFrameTemplate")
	scroll:SetAllPoints()
	if scroll.ScrollBar then
		scroll.ScrollBar:ClearAllPoints()
		scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 2)
		scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, -4)
	end
	scrollContent = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollContent)
	scroll:SetScript("OnSizeChanged", function(_, width) scrollContent:SetWidth(width) end)
	content = CreateFrame("Frame", nil, scrollContent)
	content:SetPoint("TOPLEFT")
	content:SetPoint("TOPRIGHT")
	local header = BuildHeader(content)
	list = CreateFrame("Frame", nil, content)
	list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	list:SetPoint("BOTTOMRIGHT")
	emptyText = list:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("TOPLEFT", 10, -8)
	emptyText:SetPoint("TOPRIGHT", -10, -8)
	emptyText:SetJustifyH("LEFT")
end

local function StartTicker(on)
	if on and not ticker then
		ticker = C_Timer.NewTicker(TICK, function()
			if visible and not queue then Recheck() end
		end)
	elseif not on and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local tab
local function Attach()
	if panel then return end
	local map = QuestMapFrame
	if not map then return end
	panel = CreateFrame("Frame", "BookFinderBooksPanel", map)
	panel:SetPoint("TOPLEFT", map.ContentsAnchor or map)
	panel:SetPoint("BOTTOMRIGHT", map.ContentsAnchor or map, -22, 0)
	panel:SetFrameLevel(map:GetFrameLevel() + 20)
	panel:EnableMouse(true)
	panel:Hide()
	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", 0, -TOP_BAR)
	background:SetPoint("BOTTOMRIGHT")
	BuildContent(panel)
	Art.CoverFrame(panel, background, "QuestLog-main-background", 0, TOP_BAR)
	panel:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	panel:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	panel:RegisterEvent("GROUP_ROSTER_UPDATE")
	panel:SetScript("OnEvent", function(_, event)
		if not visible then return end
		if event == "ZONE_CHANGED_NEW_AREA" then Requeue() else Soon() end
	end)
	-- no OnShow/OnHide under the world map (Tabs.lua reports it through `shown`)
	local function Shown(shown)
		visible = shown
		if shown then
			Recheck()
			StartTicker(true)
		else
			queue, fresh, freshLoc = nil, nil, nil
			panel:SetScript("OnUpdate", nil)
			StartTicker(false)
		end
	end
	tab = public.Tabs.Register(TAB_KEY, {
		name = "BookFinderBooksTab",
		tooltip = L["Library books"],
		panel = panel,
		order = 30,
		shown = Shown,
	})
	if tab and tab.Icon then
		local glyph = false
		for _, atlas in ipairs(GLYPHS) do
			if Art.Fit(tab.Icon, atlas, TAB_ICON, TAB_ICON) then glyph = true break end
		end
		if not glyph then
			Art.Icon(tab.Icon, BOOK_FILE, TAB_ICON - 10)
			if tab.Icon.SetMask then pcall(tab.Icon.SetMask, tab.Icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
		end
	end
end

-- Books' changes redraw the tab; Books' window is this tab now ------------------------------------------------------
for _, name in ipairs({ "RefreshOptions", "RefreshGroupPanel", "ToggleRoute", "RefreshRoute" }) do
	if type(BOOKS[name]) == "function" then hooksecurefunc(BOOKS, name, Soon) end
end

-- the map with its quest log, at the books tab (true when shown)
local function showTab()
	if not (WorldMapFrame and QuestMapFrame) then return false end
	Attach()
	if not panel then return false end
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown() or not ToggleWorldMap then return false end
		ToggleWorldMap()
	end
	if WorldMapFrame.SetQuestLogPanelShown and not QuestMapFrame:IsShown() then
		pcall(WorldMapFrame.SetQuestLogPanelShown, WorldMapFrame, true)
	end
	public.Tabs.Select(TAB_KEY)
	return true
end

function public.OpenBooks(toggle)
	if toggle and visible and WorldMapFrame and WorldMapFrame:IsShown() then
		if ToggleWorldMap then ToggleWorldMap() end
		return true
	end
	return showTab()
end

-- the quest log itself (Questie's list lives there): the map, at its Quests tab
function public.OpenQuestLog()
	if not (WorldMapFrame and QuestMapFrame) then return false end
	if not WorldMapFrame:IsShown() then
		if InCombatLockdown() or not ToggleWorldMap then return false end
		ToggleWorldMap()
	end
	if WorldMapFrame.SetQuestLogPanelShown and not QuestMapFrame:IsShown() then
		pcall(WorldMapFrame.SetQuestLogPanelShown, WorldMapFrame, true)
	end
	public.Tabs.ShowQuests()
	return true
end

-- every way into Books' window (/bom, the toast, the minimap menu) opens the tab
BOOKS.ToggleOptions = function() public.OpenBooks(true) end

-- the kit, for the search (Search.lua): the same rows, art and fonts as this tab
public.RefreshSearch = function() Refresh() end

public.Kit = {
	Art = Art, CreateRow = CreateRow, CreateSmall = CreateSmall, Paint = Paint,
	ROW_HEIGHT = ROW_HEIGHT, SMALL_HEIGHT = SMALL_HEIGHT, HEADER_HEIGHT = HEADER_HEIGHT, HEADER_GAP = HEADER_GAP,
	ROW_GAP = ROW_GAP, GROUP_GAP = GROUP_GAP, GOLD = GOLD, WHITE = WHITE, GREY_RGB = GREY_RGB,
	GoTo = goTo, BookSpec = bookSpec, Matches = matches,
}

-- for the offline test: build, show and count without a world map script running
public.BooksTab = {
	Attach = Attach,
	Shown = function(shown)
		Attach()
		if shown then public.Tabs.Select(TAB_KEY) end
		visible = shown
		if shown then Requeue() end
	end,
	Refresh = function() Refresh() end,
	Search = function(text) if searchBox then searchBox:SetText(text or "") end query = text or "" Refresh() end,
	Rows = function() return shownRows end,
	State = function()
		local shownHeaders, folded = 0, 0
		for _, h in ipairs(headers) do if h:IsShown() then shownHeaders = shownHeaders + 1 if h.collapsed then folded = folded + 1 end end end
		return ("visible %s, panel %s, books %d, %d sections (%d folded), %d rows"):format(tostring(visible), tostring(panel ~= nil), #allBooks(), shownHeaders, folded, shownRows)
	end,
	Step = function() if queue then StepQueue() end return queue ~= nil end,
	Estimates = function() local n = 0 for _ in pairs(estimates) do n = n + 1 end return n end,
	Spec = function(key) local row = rowsByKey[key] return row and row.spec end,
}

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Attach)
end
