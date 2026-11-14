-- The settings panel: every setting of BookFinder, once, in one window (docs/NOTES.md, section 2).
--
-- Laid out the way the owner chose: OpenMap's panel as the core (a window in the game's frame art, pages of tick boxes
-- in two columns under gold headings, sliders and choices below them, Defaults), with a column of tabs down its right
-- side like Questie's settings: Map, Quests, Books, Journey. Inside each, its pages are tabs along the top, like
-- OpenMap's On the map / Look / More.
--
-- Pages are built from the settings' own declarations (page, group, label: Core/Settings.lua), so a setting appears
-- in exactly one place and a new one appears by being declared. A section or page with nothing to show is not shown
-- (the Journey tab appears when the Journey windows are built). Other files add pages with their own content through
-- BF.Panel:AddPage.
--
-- Opened by: the BookFinder button on the world map, /bookfinder (/bf), the game's AddOns settings.

local _, BF = ...
local L = BF.L

local Panel = {}
BF.Panel = Panel

local Widgets = BF.Widgets
local S = BF.Settings

local WIDTH, HEIGHT = 700, 540
local PAD = 18
local COLUMN_GAP = 16

-- Sections and pages ------------------------------------------------------------------------------------------------
-- A page shows the settings declared with one of its `sources` (their page field), or runs its own `build`.

Panel.sections = {
	{ key = "map", label = "Map", icon = "Interface\\Icons\\INV_Misc_Map_01", pages = {
		{ key = "onTheMap", label = "On the map", sources = { "Map/OnTheMap" } },
		{ key = "look", label = "Look", sources = { "Map/Look" } },
		{ key = "more", label = "More", sources = { "Map/More" } },
	} },
	{ key = "quests", label = "Quests", icon = "Interface\\Icons\\INV_Misc_Note_02", pages = {
		{ key = "map", label = "Map", sources = { "Quests/Map" } },
		{ key = "look", label = "Look", sources = { "Quests/Look" } },
		{ key = "tooltips", label = "Tooltips", sources = { "Quests/Tooltips" } },
		{ key = "list", label = "Quest list", sources = { "Quests/List" } },
		{ key = "automation", label = "Automation", sources = { "Quests/Automation" } },
		{ key = "advanced", label = "Advanced", sources = { "Quests/Advanced" } },
	} },
	{ key = "books", label = "Books", icon = "Interface\\Icons\\INV_Misc_Book_09", pages = {
		{ key = "books", label = "Books", sources = { "Books/Books" } },
	} },
	{ key = "journey", label = "Journey", icon = "Interface\\Icons\\INV_Misc_Spyglass_02", pages = {} },
}

local function section(key)
	for _, s in ipairs(Panel.sections) do if s.key == key then return s end end
end

--- Adds a page of its own content: page = { key, label, build = function(content, width) return height end }.
--- order: position among the section's pages (default: last).
function Panel:AddPage(sectionKey, page, order)
	local s = assert(section(sectionKey), "no panel section " .. tostring(sectionKey))
	table.insert(s.pages, math.min(order or (#s.pages + 1), #s.pages + 1), page)
	if Panel.frame then Panel:Rebuild() end
end

--- The settings a page shows, in declaration order (pending settings and those without a control left out).
function Panel:SettingsOf(page)
	local list = {}
	if not page.sources then return list end
	local from = {}
	for _, src in ipairs(page.sources) do from[src] = true end
	for _, key in ipairs(S:Keys()) do
		local def = S:Definition(key)
		if from[def.page] and not def.pending and not def.soundChoice then list[#list + 1] = def end
	end
	return list
end

function Panel:PageShows(page)
	return page.build ~= nil or #Panel:SettingsOf(page) > 0
end

function Panel:VisiblePages(s)
	local list = {}
	for _, p in ipairs(s.pages) do if Panel:PageShows(p) then list[#list + 1] = p end end
	return list
end

function Panel:VisibleSections()
	local list = {}
	for _, s in ipairs(Panel.sections) do if #Panel:VisiblePages(s) > 0 then list[#list + 1] = s end end
	return list
end

-- Building a settings page ------------------------------------------------------------------------------------------

local controls = {} -- the controls on the page shown, refreshed when settings change
-- The game never frees a frame: each page and each section's top tabs are made once and kept (until a rebuild, when
-- pages or settings came or went).
local pageCache, tabCache = {}, {}

-- Lays a page's settings out: per group, a heading, the tick boxes in two columns, then the other controls in two
-- columns under them (OpenMap's sliders under its lists). Returns the height used.
local function buildSettings(content, page, width)
	local colWidth = (width - COLUMN_GAP) / 2
	local y = 0
	local groups, order = {}, {}
	for _, def in ipairs(Panel:SettingsOf(page)) do
		local g = def.group or ""
		if not groups[g] then
			groups[g] = { checks = {}, wides = {} }
			order[#order + 1] = g
		end
		local control, kind = Widgets:For(content, def, colWidth)
		if control then
			controls[#controls + 1] = control
			if kind == "check" then table.insert(groups[g].checks, control) else table.insert(groups[g].wides, control) end
		end
	end
	local function grid(list)
		local rowHeight = 0
		for i, control in ipairs(list) do
			local col = (i - 1) % 2
			if col == 0 and i > 1 then y = y + rowHeight; rowHeight = 0 end
			control:ClearAllPoints()
			control:SetPoint("TOPLEFT", content, "TOPLEFT", col * (colWidth + COLUMN_GAP), -y)
			rowHeight = math.max(rowHeight, control:GetHeight())
		end
		y = y + rowHeight
	end
	for _, g in ipairs(order) do
		local group = groups[g]
		if #group.checks + #group.wides > 0 then
			if g ~= "" then
				local heading = Widgets:Heading(content, g, width)
				heading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
				y = y + heading:GetHeight() + 4
			end
			grid(group.checks)
			if #group.wides > 0 then y = y + 4 end
			grid(group.wides)
			y = y + 10
		end
	end
	return y
end

-- The window --------------------------------------------------------------------------------------------------------

local function state() return BF:AccountState("panel") end

local function makeSideTab(frame, s, index)
	local tab = CreateFrame("CheckButton", nil, frame)
	tab:SetSize(32, 32)
	tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -36 - (index - 1) * 48)
	-- The spellbook's side tab: the game's own art for a column of tabs down a window's edge.
	tab.bg = tab:CreateTexture(nil, "BACKGROUND")
	tab.bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	tab.bg:SetSize(64, 64)
	tab.bg:SetPoint("TOPLEFT", -3, 11)
	tab:SetNormalTexture(s.icon)
	tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	tab:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L[s.label])
		GameTooltip:Show()
	end)
	tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
	tab:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN or SOUNDKIT.IG_CHARACTER_INFO_TAB)
		Panel:Show(s.key)
	end)
	tab.section = s
	return tab
end

local topTemplate

local function makeTopTab(frame, p, index, previous)
	topTemplate = topTemplate or Widgets:Template({ "PanelTopTabButtonTemplate", "TabButtonTemplate" })
	local tab = CreateFrame("Button", nil, frame, topTemplate)
	tab:SetID(index)
	tab:SetText(L[p.label])
	if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
	if previous then tab:SetPoint("LEFT", previous, "RIGHT", 2, 0)
	else tab:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -30) end
	tab:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		Panel:Show(Panel.current, p.key)
	end)
	tab.page = p
	return tab
end

local function build()
	local template = Widgets:Template({ "PortraitFrameTemplate", "BasicFrameTemplateWithInset" })
	local frame = CreateFrame("Frame", "BookFinderPanel", UIParent, template)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint(1)
		state().point = { point, relativePoint, x, y }
	end)
	local p = state().point
	if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER") end
	frame:Hide()
	tinsert(UISpecialFrames, "BookFinderPanel") -- Escape closes it

	local title = ("BookFinder %s"):format(BF.version or "")
	if frame.SetTitle then frame:SetTitle(title)
	elseif frame.TitleText then frame.TitleText:SetText(title) end
	if frame.SetPortraitToAsset then frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09") end

	-- The page area: a scroll frame of the game's.
	local scroll = CreateFrame("ScrollFrame", nil, frame, Widgets:Template({ "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" }))
	scroll:SetPoint("TOPLEFT", PAD, -70)
	scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, 46)
	frame.scroll = scroll

	-- Defaults: the page's settings back to their defaults (after asking).
	local defaults = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	defaults:SetSize(120, 22)
	defaults:SetPoint("BOTTOMRIGHT", -PAD, 14)
	defaults:SetText(L["Defaults"])
	defaults:SetScript("OnClick", function()
		StaticPopup_Show("BOOKFINDER_PAGE_DEFAULTS", L[Panel.currentPage and Panel.currentPage.label or ""])
	end)
	frame.defaults = defaults

	frame:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) state().open = true end)
	frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) state().open = false end)
	Panel.frame = frame
	Panel:Rebuild()
	return frame
end

StaticPopupDialogs["BOOKFINDER_PAGE_DEFAULTS"] = {
	text = L["Put every setting on the page \"%s\" back to its default?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function() Panel:ResetPage() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

--- Rebuilds the tabs (a page or section added, settings that came or went).
function Panel:Rebuild()
	local frame = Panel.frame
	if not frame then return end
	for _, t in ipairs(frame.sideTabs or {}) do t:Hide() end
	for _, t in ipairs(frame.topTabs or {}) do t:Hide() end
	for _, c in pairs(pageCache) do c.content:Hide() end
	wipe(pageCache)
	wipe(tabCache)
	frame.topTabs, frame.content = {}, nil
	frame.sideTabs = {}
	for i, s in ipairs(Panel:VisibleSections()) do frame.sideTabs[i] = makeSideTab(frame, s, i) end
	if frame:IsShown() then Panel:Show(Panel.current, Panel.currentPage and Panel.currentPage.key) end
end

--- Every setting on the page shown back to its default.
function Panel:ResetPage()
	for _, def in ipairs(Panel.currentPage and Panel:SettingsOf(Panel.currentPage) or {}) do BF:Reset(def.key) end
end

--- Shows the panel at a section and page (the last ones seen by default).
function Panel:Show(sectionKey, pageKey)
	local frame = Panel.frame or build()
	local sections = Panel:VisibleSections()
	local s = section(sectionKey or state().section or "")
	if not s or #Panel:VisiblePages(s) == 0 then s = sections[1] end
	local pages = Panel:VisiblePages(s)
	local page
	for _, p in ipairs(pages) do if p.key == (pageKey or (state().pages or {})[s.key]) then page = p end end
	page = page or pages[1]
	Panel.current, Panel.currentPage = s.key, page
	state().section = s.key
	state().pages = state().pages or {}
	state().pages[s.key] = page.key

	for _, t in ipairs(frame.sideTabs) do t:SetChecked(t.section == s) end

	-- Top tabs for this section's pages.
	for _, t in ipairs(frame.topTabs or {}) do t:Hide() end
	local tabs = tabCache[s.key]
	if not tabs then
		tabs = {}
		local previous
		for i, p in ipairs(pages) do
			tabs[i] = makeTopTab(frame, p, i, previous)
			previous = tabs[i]
		end
		tabCache[s.key] = tabs
	end
	frame.topTabs = tabs
	for _, tab in ipairs(tabs) do
		tab:Show()
		if tab.page == page then
			if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
		elseif PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab)
		end
	end

	-- The page.
	if frame.content then frame.content:Hide() end
	local cacheKey = s.key .. "/" .. page.key
	local cached = pageCache[cacheKey]
	if not cached then
		controls = {}
		local width = WIDTH - 2 * PAD - 22
		local content = CreateFrame("Frame", nil, frame.scroll)
		content:SetWidth(width)
		local height = page.build and page.build(content, width) or buildSettings(content, page, width)
		content:SetHeight(math.max(height or 0, 1))
		cached = { content = content, controls = controls }
		pageCache[cacheKey] = cached
	end
	controls = cached.controls
	for _, c in ipairs(controls) do c:Refresh() end
	cached.content:Show()
	frame.scroll:SetScrollChild(cached.content)
	frame.content = cached.content
	frame.defaults:SetShown(page.build == nil)
	frame:Show()
end

function Panel:Hide()
	if Panel.frame then Panel.frame:Hide() end
end

function Panel:Toggle()
	if Panel.frame and Panel.frame:IsShown() then Panel:Hide() else Panel:Show() end
end

function Panel:Controls() return controls end

BF:Listen("BF_SETTING_CHANGED", function()
	if not (Panel.frame and Panel.frame:IsShown()) then return end
	for _, c in ipairs(controls) do c:Refresh() end
end)

-- Ways in -----------------------------------------------------------------------------------------------------------

-- The BookFinder button on the world map: the book, in an action button's frame, at the map's bottom right.
local function mapButton()
	local parent = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
	if not parent then return end
	local b = CreateFrame("Button", "BookFinderMapButton", parent)
	b:SetSize(28, 28)
	b:SetFrameLevel(parent:GetFrameLevel() + 30)
	b:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -48, 10)
	b:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
	b:SetPushedTexture("Interface\\Icons\\INV_Misc_Book_09")
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	b.border:SetPoint("CENTER")
	b.border:SetSize(48, 48)
	b:SetScript("OnClick", function() Panel:Toggle() end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("BookFinder")
		GameTooltip:AddLine(L["Click: settings"], 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Panel.mapButton = b
end

-- The game's AddOns settings: one BookFinder entry, with a button that opens the panel.
local function addOnsEntry()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local f = CreateFrame("Frame")
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.text:SetPoint("TOPLEFT", 16, -16)
	f.text:SetText(L["Every BookFinder setting is in its own window."])
	local open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	open:SetSize(160, 24)
	open:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -12)
	open:SetText(L["Open BookFinder"])
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel.Close then SettingsPanel:Close(true) end
		Panel:Show()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(f, "BookFinder")
	Settings.RegisterAddOnCategory(category)
	Panel.category = category
end

BF:At("login", function()
	mapButton()
	addOnsEntry()
	SLASH_BOOKFINDER1, SLASH_BOOKFINDER2 = "/bookfinder", "/bf"
	SlashCmdList.BOOKFINDER = function() Panel:Toggle() end
end, 80)
