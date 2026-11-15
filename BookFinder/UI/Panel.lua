-- BookFinder's panel: every setting and the Journey, in one window laid out as the owner drew it (docs/NOTES.md 2):
--
--   OpenMap's panel in look (image3): the title, a "Find a place" search, action tiles with stars, then pages as tabs
--   along the top (On the map / Look / More), each a two-column list of tick boxes with icons and stars under gold
--   headings, sliders and choices under the lists, a line at the foot.
--   A column of tabs down its right side like Questie's settings (image4): OpenMap, Quests, Books, Journey.
--   The Journey tab's pages are My Journey, Quests by Zone, Quests by Faction, Advanced Search (image5).
--
-- Settings are placed by the layout below (each setting once). Pages that are not lists of settings (the Journey's,
-- the books' rewards, profiles) are built by their own modules through Panel:RegisterPage(tab, page, build).

local _, BF = ...
local L = BF.L
local W = BF.Widgets

local Panel = { pages = {}, built = {} }
BF.Panel = Panel

local WIDTH, HEIGHT = 820, 760
local PAD = 16
local ROW_H = 22
local COL_GAP = 24

-- The layout ---------------------------------------------------------------------------------------------------
-- A page: { sections = { {title, items = { key | {key=, icon=, label=} | {sliders...} } } }, sliders = {keys} }

local function townsfolkItems()
	local items = {}
	for _, k in ipairs(BF.Townsfolk.kinds) do
		if BF.Townsfolk:Applies(k) then items[#items + 1] = { key = "townsfolk." .. k.key, icon = k.icon } end
	end
	return items
end

Panel.tabs = {
	{
		key = "openmap", label = "OpenMap", icon = "Interface\\Icons\\INV_Misc_Map_01", tiles = true,
		pages = {
			{ key = "onMap", label = "On the map", sections = function()
				return {
					{ title = "Quests", items = {
						{ key = "quests.map", icon = "available" }, { key = "quests.minimap", icon = "available" },
						{ key = "quests.available", icon = "available" }, { key = "quests.turnins", icon = "complete" },
						{ key = "quests.objectives", icon = "slay" }, { key = "paths.map", icon = "object" },
					} },
					{ title = "Townsfolk", items = townsfolkItems() },
					{ title = "Places", items = {
						{ key = "books.map", icon = "book" }, { key = "books.minimap", icon = "book" },
					} },
				}
			end },
			{ key = "look", label = "Look", sections = function()
				return {
					{ title = "Coordinates", items = { "coords.map", "coords.minimap" } },
					{ title = "Icons", items = { "icons.glowMap", "icons.glowMinimap", "icons.colorsMap", "icons.colorsMinimap",
						"icons.hideOnContinents", "icons.hideUnexplored" } },
				}
			end, sliders = { "coords.precision", "icons.mapScale", "icons.minimapScale", "icons.townsfolkMapScale",
				"icons.townsfolkMinimapScale" } },
			{ key = "more", label = "More", sections = function()
				return {
					{ title = "Map pin", items = { "map.ctrlClickPin" } },
					{ title = "Arrow and compass", items = { "guide.arrow", "guide.compass", "guide.compassBand",
						"guide.metres", "guide.arrivalSound" } },
				}
			end, sliders = { "guide.arrival", "guide.arrowScale", "guide.compassScale", "guide.compassWidth" },
				buttons = { { label = "Move the arrow and compass", run = function() BF.Guide:ToggleMoving() end },
					{ label = "Reset their places", run = function() BF.Guide:ResetPlaces() end } } },
			{ key = "profiles", label = "Profiles" },
		},
	},
	{
		key = "quests", label = "Quests", icon = "Interface\\Icons\\INV_Misc_Book_08",
		pages = {
			{ key = "map", label = "Map icons", sections = function()
				return {
					{ title = "What shows", items = { "quests.repeatable", "quests.events", "quests.dungeon", "quests.raid",
						"quests.pvp", "quests.aqWarEffort", "quests.itemStarts" } },
					{ title = "Where", items = { "icons.hideUntracked", "paths.minimap", "paths.highlight" } },
				}
			end, sliders = { "quests.lowLevelOffset", "quests.levelMin", "quests.levelMax" }, choices = { "quests.lowLevel" } },
			{ key = "look", label = "Look", sections = function()
				return { { title = "Fading", items = { "icons.fadeOverPlayer" } } }
			end, sliders = { "icons.scale.available", "icons.scale.event", "icons.scale.slay", "icons.scale.loot",
				"icons.scale.object", "icons.minimapFadeDistance", "icons.fadeAlpha", "icons.fadeOverPlayerDistance",
				"icons.fadeOverPlayerAlpha", "paths.width", "paths.opacity" },
				choices = { "icons.theme", "icons.slay", "icons.loot", "icons.object", "icons.event", "icons.talk", "icons.interact" },
				colors = { "paths.color", "paths.hostileColor", "paths.highlightColor" } },
			{ key = "tooltips", label = "Tooltips", sections = function()
				return {
					{ title = "Tooltips", items = { "tooltips.enabled", "tooltips.npcQuests", "tooltips.questLevel",
						"tooltips.xpAtMaxLevel", "tooltips.nextInChain", "tooltips.breadcrumbs", "tooltips.dropRates",
						"quests.frameIcons" } },
					{ title = "IDs", items = { "tooltips.ids.quest", "tooltips.ids.npc", "tooltips.ids.object",
						"tooltips.ids.item", "tooltips.ids.spell" } },
					{ title = "Nameplates", items = { "nameplates.enabled", "nameplates.target" } },
				}
			end, sliders = { "nameplates.x", "nameplates.y", "nameplates.scale", "nameplates.targetX", "nameplates.targetY",
				"nameplates.targetScale" } },
			{ key = "list", label = "Quest list", sections = function()
				return { { title = "The quest list", items = { "list.hideGameTracker", "list.autoTrack", "list.showComplete", "list.questLevel",
					"list.collapseComplete", "list.focusButtons", "list.playButtons", "list.hideDoneObjectives",
					"list.hideCompletionText", "list.followSuperTrack" } } }
			end, sliders = { "list.padding", "list.fontSizeZone", "list.fontSizeQuest", "list.fontSizeObjective" },
				choices = { "list.objectiveColors", "list.sort", "list.clickPin", "list.clickOpenLog", "list.clickUntrack" } },
			{ key = "auto", label = "Automation", sections = function()
				return {
					{ title = "Automatic", items = { "auto.accept", "auto.complete", "auto.trivial", "auto.repeatable",
						"auto.pvp", "auto.rejectInBattleground", "auto.abandonBreadcrumb" } },
					{ title = "Announce", items = { "announce.items", "announce.accepted", "announce.abandoned",
						"announce.objectives", "announce.completed", "announce.incompleteBreadcrumb", "announce.quiet",
						"party.objectives" } },
					{ title = "Sounds", items = { "sounds.questComplete", "sounds.objectiveComplete", "sounds.objectiveProgress" } },
				}
			end, sliders = { "sounds.delay" }, choices = { "auto.modifier", "announce.channel", "sounds.channel",
				"sounds.questCompleteChoice", "sounds.objectiveCompleteChoice", "sounds.objectiveProgressChoice" } },
			{ key = "advanced", label = "Advanced", sections = function()
				return {
					{ title = "Icons", items = { "icons.limitEnabled" } },
					{ title = "Deadly Boss Mods", items = { "dbm.enabled", "dbm.alert", "dbm.quest", "dbm.slay", "dbm.loot",
						"dbm.interact" } },
				}
			end, sliders = { "icons.limit", "icons.availableLimit", "icons.clusterObjectives", "icons.clusterSpawns",
				"dbm.refresh", "dbm.zoom", "dbm.radius" } },
		},
	},
	{
		key = "books", label = "Books", icon = "Interface\\Icons\\INV_Misc_Book_09",
		pages = {
			{ key = "books", label = "Books", sections = function()
				return {
					{ title = "Settings", items = { "books.map", "books.minimap", "books.notifyCollected", "books.alertNearby" } },
					{ title = "Filters", items = { "books.hideCollected", "books.onlyMyLevel", "books.groupMissing" } },
				}
			end, sliders = { "books.mapSize", "books.minimapSize" } },
			{ key = "rewards", label = "Rewards" },
		},
	},
	{
		key = "journey", label = "Journey", icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
		pages = {
			{ key = "myJourney", label = "My Journey" },
			{ key = "byZone", label = "Quests by Zone" },
			{ key = "byFaction", label = "Quests by Faction" },
			{ key = "search", label = "Advanced Search" },
		},
	},
}

--- A page built by its own module: build(content, width) fills `content` and returns its height; refresh optional.
function Panel:RegisterPage(tab, page, build, refresh)
	Panel.pages[tab .. "/" .. page] = { build = build, refresh = refresh }
end

-- Favourites (the stars): a starred setting or action is a button of its own on the map --------------------------

local function favourites() return BF:AccountState("panel").favourites or {} end
function Panel:IsFavourite(id) return favourites()[id] == true end
function Panel:SetFavourite(id, on)
	local state = BF:AccountState("panel")
	state.favourites = state.favourites or {}
	state.favourites[id] = on and true or nil
	BF:Send("BF_FAVOURITES_CHANGED")
end

-- The window -------------------------------------------------------------------------------------------------------

local frame, sideTabs, topTabs, body, scroll, content, footer, tilesHolder, search
local current = { tab = 1, page = {} }

local function settingLabel(key)
	local def = BF.Settings:Definition(key)
	return L[def and def.label or key]
end

-- One tick row: box, icon, label, star.
local function tickRow(parent, item, width)
	local key = type(item) == "table" and item.key or item
	local def = BF.Settings:Definition(key)
	if not def then return nil end
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(width, ROW_H)
	row.check = W:CheckBox(row)
	row.check:SetPoint("LEFT", 0, 0)
	local textLeft = row.check
	if type(item) == "table" and item.icon then
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(16, 16)
		row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
		BF.Icons:Apply(row.icon, item.icon)
		textLeft = row.icon
	end
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.label:SetPoint("LEFT", textLeft, "RIGHT", 6, 0)
	row.label:SetPoint("RIGHT", -24, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetText(L[(type(item) == "table" and item.label) or def.label])
	row.star = W:Star(row)
	row.star:SetPoint("RIGHT", -2, 0)
	row.check:SetScript("OnClick", function(self) BF:Set(key, self:GetChecked() and true or false) end)
	row.star:SetScript("OnClick", function(self)
		Panel:SetFavourite(key, not Panel:IsFavourite(key))
		self:SetLit(Panel:IsFavourite(key))
	end)
	row.star:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(Panel:IsFavourite(key) and L["Take this button off the map"] or L["Put this on the map as a button"])
		GameTooltip:Show()
	end)
	row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
	function row:Refresh()
		self.check:SetChecked(BF:Get(key))
		self.star:SetLit(Panel:IsFavourite(key))
	end
	row:Refresh()
	return row
end

local function sliderRow(parent, key, width)
	local def = BF.Settings:Definition(key)
	if not def then return nil end
	local f = W:Slider(parent, width, settingLabel(key))
	local s = f.slider
	local step = def.step or 1
	s:SetMinMaxValues(def.min, def.max)
	if s.SetValueStep then s:SetValueStep(step) end
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local function show(v)
		if step < 1 then f.Value:SetText(("%.2f"):format(v)) else f.Value:SetText(tostring(math.floor(v + 0.5))) end
	end
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		show(v)
		if f.ready then BF:Set(key, v) end
	end)
	function f:Refresh()
		self.ready = false
		s:SetValue(BF:Get(key))
		show(BF:Get(key))
		self.ready = true
	end
	f:Refresh()
	return f
end

local function choiceRow(parent, key, width)
	local def = BF.Settings:Definition(key)
	if not def then return nil end
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 40)
	f.Label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.Label:SetPoint("TOPLEFT", 2, 0)
	f.Label:SetText(settingLabel(key))
	f.button = W:ChoiceButton(f, width)
	f.button:SetPoint("TOPLEFT", 0, -14)
	local function labelOf(v)
		if def.choiceLabels and def.choiceLabels[v] then return L[def.choiceLabels[v]] end
		if def.iconChoice then
			for _, c in ipairs(BF.Icons.objectiveChoices) do if c.key == v then return L[c.label] end end
		end
		return L[tostring(v)]
	end
	local function choices()
		if def.iconChoice then
			local list = {}
			for _, c in ipairs(BF.Icons.objectiveChoices) do list[#list + 1] = c.key end
			return list
		end
		if def.soundChoice then return BF.SoundNames and BF.SoundNames() or { def.default } end
		return def.choices or {}
	end
	f.button:SetScript("OnClick", function(self)
		local items = {}
		for _, v in ipairs(choices()) do
			items[#items + 1] = {
				text = labelOf(v), radio = true,
				icon = def.iconChoice and v ~= "default" and v or nil,
				checked = function() return BF:Get(key) == v end,
				onClick = function()
					if def.soundChoice and BF.Sounds then BF.Sounds:Preview(v) end
					BF:Set(key, v)
					f:Refresh()
				end,
			}
		end
		BF.Dropdown:Open(self, items)
	end)
	function f:Refresh() self.button:SetText(labelOf(BF:Get(key))) end
	f:Refresh()
	return f
end

local function colorRow(parent, key, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, ROW_H)
	f.swatch = CreateFrame("Button", nil, f)
	f.swatch:SetSize(18, 18)
	f.swatch:SetPoint("LEFT", 2, 0)
	f.swatch.tex = f.swatch:CreateTexture(nil, "ARTWORK")
	f.swatch.tex:SetAllPoints()
	f.Label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.Label:SetPoint("LEFT", f.swatch, "RIGHT", 8, 0)
	f.Label:SetText(settingLabel(key))
	function f:Refresh()
		local c = BF:Get(key)
		self.swatch.tex:SetColorTexture(c[1], c[2], c[3], 1)
	end
	f.swatch:SetScript("OnClick", function()
		local c = BF:Get(key)
		if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
		local function apply()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or c[4]
			BF:Set(key, { r, g, b, a })
			f:Refresh()
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = c[1], g = c[2], b = c[3], opacity = c[4], hasOpacity = true,
			swatchFunc = apply, opacityFunc = apply,
			cancelFunc = function() BF:Set(key, c) f:Refresh() end,
		})
	end)
	f:Refresh()
	return f
end

-- Building a page of settings: sections flow into two columns (each section whole, the shorter column next), then the
-- sliders, choices, colours and buttons under them in two columns.
local rows = {}

local function buildSettingsPage(page, holder, width)
	local colWidth = (width - COL_GAP) / 2
	local heights = { 0, 0 }
	for _, section in ipairs(page.sections and page.sections() or {}) do
		local items = {}
		for _, item in ipairs(section.items) do
			local key = type(item) == "table" and item.key or item
			if BF.Settings:Definition(key) then items[#items + 1] = item end
		end
		if #items > 0 then
			local col = heights[1] <= heights[2] and 1 or 2
			local x = (col - 1) * (colWidth + COL_GAP)
			local head = W:Heading(holder, L[section.title], colWidth)
			head:SetPoint("TOPLEFT", x, -heights[col])
			heights[col] = heights[col] + 24
			for _, item in ipairs(items) do
				local row = tickRow(holder, item, colWidth)
				row:SetPoint("TOPLEFT", x, -heights[col])
				heights[col] = heights[col] + ROW_H + 2
				rows[#rows + 1] = row
			end
			heights[col] = heights[col] + 10
		end
	end
	local y = math.max(heights[1], heights[2]) + 6
	local function grid(keys, maker, h)
		if not keys or #keys == 0 then return end
		local i = 0
		for _, key in ipairs(keys) do
			local row = maker(holder, key, colWidth)
			if row then
				local col = i % 2
				row:SetPoint("TOPLEFT", col * (colWidth + COL_GAP), -(y + math.floor(i / 2) * h))
				rows[#rows + 1] = row
				i = i + 1
			end
		end
		y = y + math.ceil(i / 2) * h + 6
	end
	grid(page.choices, choiceRow, 46)
	grid(page.sliders, sliderRow, 46)
	grid(page.colors, colorRow, ROW_H + 4)
	if page.buttons then
		local x = 0
		for _, spec in ipairs(page.buttons) do
			local b = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
			b:SetText(L[spec.label])
			b:SetSize(math.max(140, (b:GetFontString() and b:GetFontString():GetStringWidth() or 100) + 30), 22)
			b:SetPoint("TOPLEFT", x, -y)
			b:SetScript("OnClick", spec.run)
			x = x + b:GetWidth() + 8
		end
		y = y + 30
	end
	return y
end

-- The tiles (OpenMap tab): actions, each with a star -----------------------------------------------------------

Panel.actions = {
	{ id = "findMe", label = "Find me", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
		run = function() if BF.MapActions then BF.MapActions:FindMe() end end },
	{ id = "dropPin", label = "Drop a pin", icon = "Interface\\Icons\\INV_Misc_Map_01",
		run = function() if BF.MapActions then BF.MapActions:DropPin() end end,
		lit = function() return BF.MapActions and BF.MapActions:IsDropping() end },
	{ id = "questLog", label = "Quest log", icon = "Interface\\QuestFrame\\UI-QuestLog-BookIcon",
		run = function() if BF.MapActions then BF.MapActions:QuestLog() end end },
	{ id = "books", label = "Library books", icon = "Interface\\Icons\\INV_Misc_Book_09",
		run = function() if BF.BooksTab then BF.BooksTab:Open() end end },
	{ id = "route", label = "Optimized route", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
		run = function() BF.BookRoute:Toggle() end, lit = function() return BF.BookRoute:IsOn() end },
}

local tiles = {}
local function buildTiles(holder, width)
	local perRow, gap, h = 4, 8, 70
	local tw = (width - gap * (perRow - 1)) / perRow
	for i, a in ipairs(Panel.actions) do
		local t = W:Tile(holder, tw, h, 30)
		t:SetPoint("TOPLEFT", ((i - 1) % perRow) * (tw + gap), -math.floor((i - 1) / perRow) * (h + gap))
		t.icon:SetTexture(a.icon)
		t.label:SetText(L[a.label])
		t.action = a
		t:SetScript("OnClick", function() BF.safecall(a.run) Panel:Refresh() end)
		t.star = W:Star(t)
		t.star:SetPoint("TOPRIGHT", -3, -3)
		t.star:SetScript("OnClick", function(self)
			Panel:SetFavourite("action:" .. a.id, not Panel:IsFavourite("action:" .. a.id))
			self:SetLit(Panel:IsFavourite("action:" .. a.id))
		end)
		tiles[#tiles + 1] = t
	end
	return math.ceil(#Panel.actions / perRow) * (h + gap)
end

-- Showing a page ---------------------------------------------------------------------------------------------------

local pageHolders = {}

local function showPage(tabIndex, pageIndex)
	current.tab = tabIndex
	current.page[tabIndex] = pageIndex
	local tab = Panel.tabs[tabIndex]
	local page = tab.pages[pageIndex]
	for i, t in ipairs(sideTabs) do
		t.glow:SetShown(i == tabIndex)
		W:SetLit(t, i == tabIndex)
	end
	-- the top tabs for this side tab
	for _, b in ipairs(topTabs) do b:Hide() end
	local x = PAD
	for i, p in ipairs(tab.pages) do
		local b = topTabs[i]
		if not b then
			b = W:TopTab(frame, "")
			topTabs[i] = b
		end
		if b.Text then b.Text:SetText(L[p.label]) else b:SetText(L[p.label]) end
		local fs = b.Text or (b.GetFontString and b:GetFontString())
		b:SetWidth(math.max(90, (fs and fs:GetStringWidth() or 60) + 34))
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", body, "TOPLEFT", x - PAD, 2)
		x = x + b:GetWidth() + 2
		b:SetScript("OnClick", function() showPage(tabIndex, i) end)
		b:SetTabSelected(i == pageIndex)
		b:Show()
	end
	tilesHolder:SetShown(tab.tiles == true)
	search:SetShown(tab.tiles == true)
	for _, h in pairs(pageHolders) do h:Hide() end
	local id = tab.key .. "/" .. page.key
	local holder = pageHolders[id]
	local width = content:GetWidth()
	if not holder then
		holder = CreateFrame("Frame", nil, content)
		holder:SetPoint("TOPLEFT")
		holder:SetWidth(width)
		local custom = Panel.pages[id]
		local h
		if custom then
			h = custom.build(holder, width) or 400
		else
			h = buildSettingsPage(page, holder, width)
		end
		holder:SetHeight(h)
		holder.custom = custom
		pageHolders[id] = holder
	elseif holder.custom and holder.custom.refresh then
		local h = holder.custom.refresh(holder, width)
		if h then holder:SetHeight(h) end
	end
	holder:Show()
	content:SetHeight(holder:GetHeight())
	if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
	footer:SetText(tab.key == "openmap" and L["A star puts that action or setting on the map as a button of its own."] or "")
	BF:CharacterState("panel").tab, BF:CharacterState("panel").page = tabIndex, pageIndex
end

local function layoutBody()
	local top = -(frame.titleHeight + 12)
	if Panel.tabs[current.tab].tiles then
		search:ClearAllPoints()
		search:SetPoint("TOPLEFT", PAD + 6, top)
		search:SetPoint("TOPRIGHT", -PAD, top)
		tilesHolder:ClearAllPoints()
		tilesHolder:SetPoint("TOPLEFT", PAD, top - 28)
		tilesHolder:SetPoint("TOPRIGHT", -PAD, top - 28)
		top = top - 28 - tilesHolder:GetHeight() - 8
	end
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", PAD, top - 34)
	body:SetPoint("BOTTOMRIGHT", -PAD, 30)
end

-- Building the window --------------------------------------------------------------------------------------------

local function build()
	frame = CreateFrame("Frame", "BookFinderPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()
	table.insert(UISpecialFrames, "BookFinderPanel")
	frame.titleHeight = W:Dress(frame)
	if frame.titleHeight == 0 then frame.titleHeight = 24 end

	frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.Title:SetPoint("TOP", 0, -4)
	frame.Title:SetText("BookFinder |cff998866" .. (BF.version or "") .. "|r")
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 0)

	search = W:SearchBox(frame, 300, L["Find a place"])
	search:SetScript("OnTextChanged", function(self, user)
		if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
		if user and BF.FindPlace then BF.FindPlace:Show(self, self:GetText()) end
	end)

	tilesHolder = CreateFrame("Frame", nil, frame)
	tilesHolder:SetHeight(buildTiles(tilesHolder, WIDTH - PAD * 2))

	body = CreateFrame("Frame", nil, frame)
	local rule = W:Rule(frame)
	rule:SetPoint("BOTTOMLEFT", body, "TOPLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", 0, 0)
	scroll, content = W:Scroll(body)
	scroll:SetPoint("TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", -22, 0)
	content:SetWidth(WIDTH - PAD * 2 - 26)

	footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetPoint("BOTTOMLEFT", PAD, 12)

	-- The column of tabs down the right side (Questie's settings' side tabs, in the action bar's frames).
	sideTabs = {}
	for i, tab in ipairs(Panel.tabs) do
		local t = CreateFrame("Button", nil, frame)
		t:SetSize(44, 44)
		t:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -(frame.titleHeight + 20) - (i - 1) * 52)
		t.icon = W:FramedIcon(t, 40)
		t.icon.slot:SetPoint("CENTER")
		t.icon:SetTexture(tab.icon)
		t.glow = t:CreateTexture(nil, "OVERLAY", nil, 1)
		t.glow:SetAllPoints(t.icon.slot)
		t.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		t.glow:SetBlendMode("ADD")
		local hl = t:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(t.icon.slot)
		hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
		hl:SetBlendMode("ADD")
		t:SetScript("OnClick", function()
			showPage(i, current.page[i] or 1)
			layoutBody()
		end)
		t:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(L[tab.label], 1, 0.82, 0)
			GameTooltip:Show()
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() end)
		sideTabs[i] = t
	end
	topTabs = {}

	BF:Listen("BF_SETTING_CHANGED", function() if frame:IsShown() then Panel:Refresh() end end)
	BF:Listen("BF_PROFILE_CHANGED", function() if frame:IsShown() then Panel:Refresh() end end)
end

--- Updates every row and tile to the settings now.
function Panel:Refresh()
	if not frame then return end
	for _, r in ipairs(rows) do if r.Refresh then r:Refresh() end end
	for _, t in ipairs(tiles) do
		W:SetLit(t, t.action.lit and t.action.lit() or false)
		t.star:SetLit(Panel:IsFavourite("action:" .. t.action.id))
	end
end

--- Opens the panel (at a tab and page by key, else where it was last).
function Panel:Open(tabKey, pageKey)
	if not frame then build() end
	local tabIndex, pageIndex = BF:CharacterState("panel").tab or 1, BF:CharacterState("panel").page or 1
	if tabKey then
		for i, t in ipairs(Panel.tabs) do
			if t.key == tabKey then
				tabIndex, pageIndex = i, 1
				for j, p in ipairs(t.pages) do if p.key == pageKey then pageIndex = j end end
			end
		end
	end
	if not Panel.tabs[tabIndex] then tabIndex = 1 end
	if not Panel.tabs[tabIndex].pages[pageIndex] then pageIndex = 1 end
	frame:Show()
	layoutBody()
	showPage(tabIndex, pageIndex)
	layoutBody()
	Panel:Refresh()
end

--- A page whose height changed: the scroll area follows it.
function Panel:Resize(holder)
	if holder and holder:IsShown() and content then content:SetHeight(holder:GetHeight()) end
end

function Panel:Toggle(tabKey, pageKey)
	if frame and frame:IsShown() then frame:Hide() else Panel:Open(tabKey, pageKey) end
end

function Panel:IsShown() return frame ~= nil and frame:IsShown() end

--- Every setting key placed somewhere in the layout (the offline test checks none is left out).
function Panel:PlacedKeys()
	local placed = {}
	for _, tab in ipairs(Panel.tabs) do
		for _, page in ipairs(tab.pages) do
			for _, section in ipairs(page.sections and page.sections() or {}) do
				for _, item in ipairs(section.items) do placed[type(item) == "table" and item.key or item] = true end
			end
			for _, list in ipairs({ page.sliders or {}, page.choices or {}, page.colors or {} }) do
				for _, key in ipairs(list) do placed[key] = true end
			end
		end
	end
	return placed
end
