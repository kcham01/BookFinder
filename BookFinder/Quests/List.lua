-- The quest list: BookFinder's own list of the player's quests, in the map's Quests panel where the game's list was,
-- and nothing on screen (docs/WANTS.md, "Quest list in the map, nothing on screen": the list replaces the game's in
-- the map's Quests tab; the tracker on the screen is gone; the arrow and compass still guide).
--
-- What it shows (Questie's list, docs/study/questie.md, "The quest list"): quests grouped by zone, each zone foldable;
-- each quest's title with its level in its difficulty colour, its objectives with their progress, "Ready for
-- turn-in" for a finished one (with the game's completion text unless hidden), failed and timed quests; the quest's
-- usable item as a button; a tick to track it. Its settings are the Quests > Quest list page.
--
-- Clicks (settings list.click*): open the quest (left), the map pin to the nearest place it needs (Ctrl-left), untrack
-- or link in chat (Shift-left); right-click: its menu (focus, track, show on map, map pin, fold, the quest's web page).
-- The quest log's search box narrows the list.

local _, BF = ...
local L = BF.L

local List = {}
BF.QuestList = List

local Log, Rules, Objectives, Marks, Zones = BF.Log, BF.Rules, BF.Objectives, BF.Marks, BF.Zones

local function state() return BF:CharacterState("list") end

-- Fonts: the game's quest-list faces at the sizes chosen (Quests > Quest list) ------------------------------------

local fonts = {}
local function font(name, base, size)
	local f = fonts[name]
	if not f then
		f = CreateFont("BookFinderList" .. name)
		fonts[name] = f
	end
	f:CopyFontObject(_G[base])
	local file, _, flags = f:GetFont()
	if file then f:SetFont(file, size, flags) end
	return f
end

local function zoneFont() return font("Zone", "GameFontNormalLarge", BF:Get("list.fontSizeZone")) end
local function questFont() return font("Quest", "GameFontNormal", BF:Get("list.fontSizeQuest")) end
local function objectiveFont() return font("Objective", "GameFontHighlight", BF:Get("list.fontSizeObjective")) end

-- What to list -------------------------------------------------------------------------------------------------------

local function isTracked(id)
	return C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil
end

local function matches(q, filter)
	if not filter or filter == "" then return true end
	filter = filter:lower()
	if (q.title or ""):lower():find(filter, 1, true) then return true end
	if (q.header or ""):lower():find(filter, 1, true) then return true end
	for _, o in ipairs(q.objectives) do
		if (o.text or ""):lower():find(filter, 1, true) then return true end
	end
	return false
end

local function progress(q)
	local have, need = 0, 0
	for _, o in ipairs(q.objectives) do
		have, need = have + math.min(o.have, o.need), need + o.need
	end
	if Log:IsComplete(q.id) then return 1 end
	return need > 0 and have / need or 0
end

local function nearestPlace(id)
	local best, bestDist
	for map, pins in pairs(Marks.byMap) do
		for _, pin in pairs(pins) do
			for _, r in ipairs(pin.roles) do
				if r.quest == id and (r.role == "objective" or r.role == "complete") then
					local d = Zones:DistanceTo(map, pin.x, pin.y)
					if d and (not bestDist or d < bestDist) then best, bestDist = pin, d end
					if not best then best = pin end
				end
			end
		end
	end
	return best, bestDist
end

local sorters = {
	byLevel = function(a, b) return (a.level or 0) < (b.level or 0) end,
	byLevelReversed = function(a, b) return (a.level or 0) > (b.level or 0) end,
	byComplete = function(a, b) return progress(a) > progress(b) end,
}

--- The list as groups: { {header = zone or nil, quests = { q, ... }}, ... } (zones only when sorted by zone).
function List:Groups(filter)
	local quests = {}
	for _, q in pairs(Log.quests) do
		local complete = Log:IsComplete(q.id)
		if matches(q, filter) and (BF:Get("list.showComplete") or not complete) then quests[#quests + 1] = q end
	end
	table.sort(quests, function(a, b) return (a.index or 0) < (b.index or 0) end)
	local sort = BF:Get("list.sort")
	if sort == "byZone" then
		local groups, byHeader = {}, {}
		for _, q in ipairs(quests) do
			local h = q.header or ""
			local g = byHeader[h]
			if not g then
				g = { header = h, quests = {} }
				byHeader[h] = g
				groups[#groups + 1] = g
			end
			g.quests[#g.quests + 1] = q
		end
		return groups
	end
	if sort == "byProximity" then
		-- Each quest's distance once (finding it looks at every mark on every map).
		local dist = {}
		for _, q in ipairs(quests) do
			local _, d = nearestPlace(q.id)
			dist[q.id] = d or math.huge
		end
		table.sort(quests, function(a, b) return dist[a.id] < dist[b.id] end)
	elseif sorters[sort] then
		table.sort(quests, sorters[sort])
	end
	return { { quests = quests } }
end

-- Colours ------------------------------------------------------------------------------------------------------------

local GREEN, WHITE, GREY, RED = { 0.2, 1, 0.2 }, { 0.9, 0.9, 0.9 }, { 0.6, 0.6, 0.6 }, { 1, 0.2, 0.2 }

--- The colour of an objective line by the chosen style (Quests > Quest list > Objective colours).
function List:ObjectiveColour(o)
	local style = BF:Get("list.objectiveColors")
	local share = o.need > 0 and math.min(1, o.have / o.need) or (o.finished and 1 or 0)
	if style == "white" then return WHITE end
	if style == "minimal" then return o.finished and GREY or WHITE end
	if style == "whiteAndGreen" then return o.finished and GREEN or WHITE end
	if style == "whiteToGreen" then
		return { 0.9 - 0.7 * share, 0.9 + 0.1 * share, 0.9 - 0.7 * share }
	end
	-- red to green, through yellow
	if share < 0.5 then return { 1, 0.2 + 1.6 * share, 0.2 } end
	return { 1 - 1.6 * (share - 0.5), 1, 0.2 }
end

-- Rows ---------------------------------------------------------------------------------------------------------------

local frame          -- the list's scroll frame (in the game's quest panel)
local content        -- its scroll child
local rows, used = {}, 0
local itemButtons, itemsUsed = {}, 0

local function row()
	used = used + 1
	local r = rows[used]
	if not r then
		r = CreateFrame("Button", nil, content)
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r.text = r:CreateFontString(nil, "ARTWORK")
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(true)
		r.right = r:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		r.right:SetPoint("RIGHT", -24, 0)
		r.toggle = r:CreateTexture(nil, "ARTWORK")
		r.toggle:SetSize(14, 14)
		r.toggle:SetPoint("RIGHT", -6, 0)
		r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
		r.check:SetSize(18, 18)
		r.check:SetPoint("RIGHT", -2, 0)
		r.focus = CreateFrame("Button", nil, r)
		r.focus:SetSize(14, 14)
		r.focus:SetNormalTexture("Interface\\Minimap\\Tracking\\None")
		r.focus:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		r:SetScript("OnClick", function(self, button) List:Click(self, button) end)
		r:SetScript("OnEnter", function(self) List:Hover(self) end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[used] = r
	end
	r:Show()
	r.kind, r.quest, r.objective, r.header = nil, nil, nil, nil
	r.right:SetText("")
	r.toggle:Hide()
	r.check:Hide()
	r.focus:Hide()
	r:SetAlpha(1)
	return r
end

-- The quest's usable item: a secure button of the game's (it uses the item), made and placed out of combat only.
local function itemButton(q, y, x)
	if InCombatLockdown() or not GetQuestLogSpecialItemInfo or not q.index then return 0 end
	local link, icon, charges = GetQuestLogSpecialItemInfo(q.index)
	if not link then return 0 end
	itemsUsed = itemsUsed + 1
	local b = itemButtons[itemsUsed]
	if not b then
		b = CreateFrame("Button", nil, content, "SecureActionButtonTemplate")
		b:SetSize(22, 22)
		b:RegisterForClicks("AnyUp", "AnyDown")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.count:SetPoint("BOTTOMRIGHT", 2, -2)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.link)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		itemButtons[itemsUsed] = b
	end
	b.link = link
	b:SetAttribute("type", "item")
	b:SetAttribute("item", link)
	b.icon:SetTexture(icon)
	b.count:SetText(charges and charges > 1 and charges or "")
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	b:Show()
	return 26
end

local function place(r, x, y, width, fontObject, text, colour)
	r.text:SetFontObject(fontObject)
	r.text:ClearAllPoints()
	r.text:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -2)
	r.text:SetWidth(width - 30)
	r.text:SetText(text)
	if colour then r.text:SetTextColor(colour[1], colour[2], colour[3]) end
	local h = math.max(r.text:GetStringHeight() + 4, 16)
	r:ClearAllPoints()
	r:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
	r:SetSize(width - x, h)
	return h
end

local function timeLeft(id)
	if not C_QuestLog.GetTimeAllowed then return nil end
	local total, elapsed = C_QuestLog.GetTimeAllowed(id)
	if not total or not elapsed then return nil end
	return math.max(0, total - elapsed)
end

--- Lays the list out again.
function List:Refresh()
	if not frame or not frame:IsVisible() then List.dirty = true return end
	List.dirty = false
	for i = 1, used do rows[i]:Hide() end
	used = 0
	if not InCombatLockdown() then
		for i = 1, itemsUsed do itemButtons[i]:Hide() end
		itemsUsed = 0
	end
	local width = frame:GetWidth() - 20
	content:SetWidth(width)
	local y = 4
	local s = state()
	s.collapsed, s.minimized = s.collapsed or {}, s.minimized or {}
	local focus = s.focus and Log:Has(s.focus) and s.focus or nil
	local padding = BF:Get("list.padding")

	for _, group in ipairs(List:Groups(List.filter)) do
		local folded = false
		if group.header then
			local r = row()
			r.kind, r.header = "zone", group.header
			y = y + place(r, 0, y, width, zoneFont(), group.header, WHITE)
			folded = s.collapsed[group.header] == true
			r.toggle:SetTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			r.toggle:Show()
			y = y + 2
		end
		if not folded then
			for _, q in ipairs(group.quests) do
				local complete = Log:IsComplete(q.id)
				local failed = Log:IsFailed(q.id)
				local minimized = s.minimized[q.id] == true or (complete and BF:Get("list.collapseComplete") and s.minimized[q.id] ~= false)
				local x = 10 + itemButton(q, y, 10)
				local r = row()
				r.kind, r.quest = "quest", q.id
				local title = Rules:ColoredTitle(q.id, q.title, BF:Get("list.questLevel"))
				y = y + place(r, x, y, width, questFont(), title)
				r.check:SetChecked(isTracked(q.id))
				r.check:SetScript("OnClick", function(self) List:SetTracked(q.id, self:GetChecked()) end)
				r.check:Show()
				if BF:Get("list.focusButtons") then
					r.focus:ClearAllPoints()
					r.focus:SetPoint("RIGHT", r.check, "LEFT", -2, 0)
					r.focus:SetScript("OnClick", function() List:ToggleFocus(q.id) end)
					r.focus:SetAlpha(focus == q.id and 1 or 0.4)
					r.focus:Show()
				end
				if focus and focus ~= q.id then r:SetAlpha(0.5) end
				if not minimized then
					local lines = {}
					if failed then
						lines[#lines + 1] = { L["Quest Failed!"], RED }
					elseif complete then
						lines[#lines + 1] = { QUEST_WATCH_QUEST_READY or L["Ready for turn-in"], GREEN }
						local text = not BF:Get("list.hideCompletionText") and GetQuestLogCompletionText and GetQuestLogCompletionText(q.index)
						if text and text ~= "" then lines[#lines + 1] = { text, GREY } end
					else
						for index, o in ipairs(q.objectives) do
							if not (o.finished and BF:Get("list.hideDoneObjectives")) then
								lines[#lines + 1] = { o.text, List:ObjectiveColour(o), index }
							end
						end
					end
					local left = timeLeft(q.id)
					if left then
						lines[#lines + 1] = { left > 0 and SecondsToTime and SecondsToTime(left) or L["Time's up!"], left > 0 and WHITE or RED }
					end
					for _, line in ipairs(lines) do
						local o = row()
						o.kind, o.quest, o.objective = "objective", q.id, line[3]
						y = y + place(o, x + 8, y, width, objectiveFont(), "- " .. line[1], line[2])
						if focus and focus ~= q.id then o:SetAlpha(0.5) end
					end
				end
				y = y + padding
			end
		end
		y = y + 4
	end
	content:SetHeight(math.max(y, 1))
end

-- Clicks ---------------------------------------------------------------------------------------------------------

local function modifierOf(button)
	if button == "RightButton" then return "right" end
	if IsShiftKeyDown() then return "shiftleft" end
	if IsControlKeyDown() then return "ctrlleft" end
	if IsAltKeyDown() then return "altleft" end
	return "left"
end

function List:SetTracked(id, on)
	if on then
		if C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
	elseif C_QuestLog.RemoveQuestWatch then
		C_QuestLog.RemoveQuestWatch(id)
	end
	List:Refresh()
end

function List:ToggleFocus(id)
	local s = state()
	s.focus = s.focus ~= id and id or nil
	List:Refresh()
end

--- The map pin to the nearest place a quest needs (its objectives, or where to hand it in).
function List:PinQuest(id)
	local pin = nearestPlace(id)
	if not pin then
		BF:Print(L["No place on the map for %s."], BF:QuestName(id) or id)
		return
	end
	BF.Waypoint:Set(pin.map, pin.x, pin.y, BF:QuestName(id), nil, id)
end

function List:ShowOnMap(id)
	local pin = nearestPlace(id)
	if not pin then return end
	if not WorldMapFrame:IsShown() then ToggleWorldMap() end
	WorldMapFrame:SetMapID(pin.map)
end

function List:OpenQuest(id)
	if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(id) end
end

StaticPopupDialogs["BOOKFINDER_QUEST_URL"] = {
	text = L["The quest's page (Ctrl-C to copy):"],
	button1 = CLOSE or "Close",
	hasEditBox = true,
	editBoxWidth = 320,
	OnShow = function(self, url)
		local box = self.editBox or self.EditBox
		box:SetText(url)
		box:HighlightText()
		box:SetFocus()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

--- The right-click menu of a quest (or of one of its objective lines).
function List:Menu(r)
	local id = r.quest
	local s = state()
	local items = { { text = BF:QuestName(id) or "", title = true } }
	if r.kind == "quest" then
		items[#items + 1] = { text = s.focus == id and L["Unfocus"] or L["Focus"], func = function() List:ToggleFocus(id) end }
		items[#items + 1] = { text = isTracked(id) and L["Untrack"] or L["Track"], func = function() List:SetTracked(id, not isTracked(id)) end }
	end
	items[#items + 1] = { text = L["Show on map"], func = function() List:ShowOnMap(id) end }
	items[#items + 1] = { text = L["Set the map pin"], func = function() List:PinQuest(id) end }
	if r.kind == "quest" then
		local minimized = s.minimized and s.minimized[id]
		items[#items + 1] = { text = minimized and L["Maximize"] or L["Minimize"], func = function()
			s.minimized = s.minimized or {}
			s.minimized[id] = not minimized
			List:Refresh()
		end }
		items[#items + 1] = { text = L["The quest's web page"], func = function()
			StaticPopup_Show("BOOKFINDER_QUEST_URL", nil, nil, ("https://www.wowhead.com/classic/quest=%d"):format(id))
		end }
	end
	BF.Dropdown:Open(r, items)
end

function List:Click(r, button)
	if r.kind == "zone" then
		local s = state()
		s.collapsed = s.collapsed or {}
		s.collapsed[r.header] = not s.collapsed[r.header] or nil
		List:Refresh()
		return
	end
	if not r.quest then return end
	local how = modifierOf(button)
	if how == "right" and BF:Get("list.clickOpenLog") ~= "right" and BF:Get("list.clickPin") ~= "right"
		and BF:Get("list.clickUntrack") ~= "right" then
		List:Menu(r)
		return
	end
	-- A chat box open and Shift held: link the quest.
	local edit = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if how == "shiftleft" and edit and GetQuestLink then
		ChatEdit_InsertLink(GetQuestLink(r.quest))
		return
	end
	if how == BF:Get("list.clickPin") then List:PinQuest(r.quest)
	elseif how == BF:Get("list.clickUntrack") then List:SetTracked(r.quest, not isTracked(r.quest))
	elseif how == BF:Get("list.clickOpenLog") then List:OpenQuest(r.quest)
	end
end

function List:Hover(r)
	if r.kind ~= "quest" then return end
	GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
	GameTooltip:SetText(Rules:TitleWithLevel(r.quest, Log:Get(r.quest) and Log:Get(r.quest).title))
	local function hint(setting, text)
		local how = BF:Get(setting)
		if how ~= "disabled" then
			local keys = { left = L["Click"], shiftleft = L["Shift-click"], ctrlleft = L["Ctrl-click"], altleft = L["Alt-click"], right = L["Right-click"] }
			GameTooltip:AddLine(keys[how] .. L[": "] .. text, 0.6, 0.6, 0.6)
		end
	end
	hint("list.clickOpenLog", L["open the quest"])
	hint("list.clickPin", L["map pin to the nearest place"])
	hint("list.clickUntrack", L["untrack"])
	GameTooltip:AddLine(L["Right-click"] .. L[": "] .. L["more"], 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

-- In the game's quest panel ------------------------------------------------------------------------------------------
--
-- The game's list lives in QuestScrollFrame. BookFinder's list is a scroll frame of its own on the same spot (a child
-- of it, so it shows and hides with the game's quest panel), and the game's own rows and scroll bar are kept hidden.
-- The game's search box and "Quests: n/40" stay.

local function keepHidden(f)
	if type(f) ~= "table" or not f.Hide then return end
	f:Hide()
	if f.HookScript and not f.bookFinderHidden then
		f.bookFinderHidden = true
		f:HookScript("OnShow", function(self) self:Hide() end)
	end
end

local function searchBox()
	local q = QuestMapFrame
	return (QuestScrollFrame and type(QuestScrollFrame.SearchBox) == "table" and QuestScrollFrame.SearchBox)
		or (q and q.QuestsFrame and type(q.QuestsFrame.SearchBox) == "table" and q.QuestsFrame.SearchBox)
end

local function build()
	if not QuestScrollFrame then return end
	local template = BF.Widgets:Template({ "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" })
	frame = CreateFrame("ScrollFrame", "BookFinderQuestList", QuestScrollFrame, template)
	frame:SetAllPoints(QuestScrollFrame)
	frame:SetFrameLevel(QuestScrollFrame:GetFrameLevel() + 10)
	content = CreateFrame("Frame", nil, frame)
	content:SetSize(1, 1)
	frame:SetScrollChild(content)
	frame:SetScript("OnShow", function() if List.dirty ~= false then List:Refresh() end end)
	keepHidden(QuestScrollFrame.Contents)
	keepHidden(QuestScrollFrame.ScrollBar)
	local box = searchBox()
	if box and box.HookScript then
		box:HookScript("OnTextChanged", function(self)
			List.filter = self:GetText()
			List:Refresh()
		end)
	end
	List.frame = frame
end

-- Nothing on screen: the game's on-screen quest tracker stays hidden (out of combat: it holds secure item buttons).
local function hideTracker()
	local tracker = ObjectiveTrackerFrame or QuestWatchFrame
	if type(tracker) ~= "table" then return end
	local waiting = false
	local function hide()
		if InCombatLockdown() then
			if not waiting then
				waiting = true
				BF:Once("PLAYER_REGEN_ENABLED", function() waiting = false hide() end)
			end
		else
			tracker:Hide()
		end
	end
	hide()
	if tracker.HookScript and not tracker.bookFinderHidden then
		tracker.bookFinderHidden = true
		tracker:HookScript("OnShow", hide)
	end
end

local soon = BF:Debounce(0.1, function() List:Refresh() end)

BF:At("login", function()
	build()
	hideTracker()
	BF:Listen("BF_QUEST_LOG_CHANGED", soon)
	BF:Listen("BF_QUEST_PROGRESS", soon)
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key:find("^list%.") then soon() end end)
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id)
		if BF:Get("list.autoTrack") and C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
	end)
	BF:On("QUEST_WATCH_LIST_CHANGED", soon)
	BF:On("PLAYER_REGEN_ENABLED", soon) -- item buttons wait out a fight
	BF:On("SUPER_TRACKING_CHANGED", function()
		if not BF:Get("list.followSuperTrack") or not C_SuperTrack.GetSuperTrackedQuestID then return end
		local id = C_SuperTrack.GetSuperTrackedQuestID()
		state().focus = id and id > 0 and id or nil
		soon()
	end)
	-- A timed quest counts down while the list is open.
	BF:Every(1, function()
		if frame and frame:IsVisible() then
			for id in pairs(Log.quests) do
				if timeLeft(id) then List:Refresh() return end
			end
		end
	end)
	List:Refresh()
end, 85)
