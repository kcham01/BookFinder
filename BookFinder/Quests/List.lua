-- The quest tracker on the screen, Questie's way (the game's own tracker is hidden): tracked quests by zone, each with
-- its menu button ("...") and its fold button, its title with its level in its difficulty colour ("[33D]"), its
-- objectives as "0/1 Name", "Quest Complete!" / "Quest Failed!", a usable-item button at the right; clicks as chosen
-- (Quests > Quest list), the menu on right-click or "...". No background; drag the header to move it, click it to fold.

local _, BF = ...
local L = BF.L

local List = {}
BF.QuestList = List

local Log, Rules = BF.Log, BF.Rules
local ROW = 16

-- The text sizes the list's settings choose (zone, quest, objective), in the font the row already has.
local function sized(fs, object, key)
	fs:SetFontObject(object)
	local face, _, flags = fs:GetFont()
	if face then fs:SetFont(face, BF:Get(key), flags) end
end
local function rowFor(key) return math.max(ROW, BF:Get(key) + 6) end

local frame, scroll, content, header
local rows, used = {}, 0
local folded = {}  -- zones folded (per character)
local focused       -- the focused quest (the others dim)

local function state() return BF:CharacterState("questList") end

-- Colours for objectives (list.objectiveColors), Questie's choices.
local function objectiveColour(o)
	local mode = BF:Get("list.objectiveColors")
	local done = o.need > 0 and o.have / o.need or (o.finished and 1 or 0)
	if mode == "white" then return 0.9, 0.9, 0.9 end
	if mode == "minimal" then if o.finished then return 0.3, 1, 0.3 end return 0.9, 0.9, 0.9 end
	if mode == "whiteAndGreen" then if o.finished then return 0.3, 1, 0.3 end return 1, 1, 1 end
	if mode == "whiteToGreen" then return 1 - 0.7 * done, 1, 1 - 0.7 * done end
	return 1 - done * 0.7, 0.3 + 0.7 * done, 0.3
end

-- Rows ------------------------------------------------------------------------------------------------------------------

local function newRow()
	local r = CreateFrame("Button", nil, content)
	r:SetHeight(ROW)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.Text = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.Text:SetJustifyH("LEFT")
	r.Text:SetWordWrap(false)
	r.Right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.Right:SetPoint("RIGHT", -30, 0)
	r.Toggle = r:CreateTexture(nil, "ARTWORK")
	r.Toggle:SetSize(14, 14)
	r.Toggle:SetPoint("RIGHT", -6, 0)
	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.35)
	r.Focus = CreateFrame("Button", nil, r)
	r.Focus:SetSize(14, 14)
	r.Focus:SetPoint("RIGHT", -24, 0)
	r.Focus.tex = r.Focus:CreateTexture(nil, "ARTWORK")
	r.Focus.tex:SetAllPoints()
	r.Focus.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
	return r
end

local function row()
	used = used + 1
	local r = rows[used]
	if not r then
		r = newRow()
		rows[used] = r
	end
	r:Show()
	r.Toggle:Hide()
	r.Focus:Hide()
	if r.Menu then r.Menu:Hide() end
	if r.Fold then r.Fold:Hide() end
	r.Right:SetText("")
	r:SetScript("OnEnter", nil)
	r:SetScript("OnClick", nil)
	r:SetAlpha(1)
	return r
end

-- Item buttons (secure: made and moved only out of combat) -----------------------------------------------------------

local itemButtons, itemUsed = {}, 0
local function itemButton()
	itemUsed = itemUsed + 1
	local b = itemButtons[itemUsed]
	if not b then
		b = CreateFrame("Button", nil, content, "SecureActionButtonTemplate")
		b:SetSize(22, 22)
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:SetAttribute("type", "item")
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.count:SetPoint("BOTTOMRIGHT", 0, 0)
		b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
		b.cooldown:SetAllPoints()
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.link then GameTooltip:SetHyperlink(self.link) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		itemButtons[itemUsed] = b
	end
	return b
end

local function questItem(id)
	local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
	if not index or not GetQuestLogSpecialItemInfo then return nil end
	local link, icon, charges = GetQuestLogSpecialItemInfo(index)
	if not link then return nil end
	return link, icon, charges, index
end

-- Clicks ----------------------------------------------------------------------------------------------------------------

local function matches(binding, button)
	if binding == "disabled" then return false end
	local mod = (IsShiftKeyDown() and "shift" or "") .. (IsControlKeyDown() and "ctrl" or "") .. (IsAltKeyDown() and "alt" or "")
	local want = binding:gsub("left$", ""):gsub("right$", "")
	local wantButton = binding:find("right$") and "RightButton" or "LeftButton"
	return wantButton == button and want == mod
end

local function openInLog(id)
	if QuestMapFrame_ShowQuestDetails then QuestMapFrame_ShowQuestDetails(id) end
end

local function untrack(id)
	local tracked = C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil
	if tracked and C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(id)
	elseif C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
	BF:Send("BF_QUEST_LIST_CHANGED")
end

local function pinFor(id)
	-- The nearest place that matters: the turn-in when complete, else the first unfinished objective's nearest spot.
	local best
	local function consider(map, x, y)
		local d = BF.Zones:DistanceTo(map, x, y) or math.huge
		if not best or d < best.d then best = { map = map, x = x, y = y, d = d } end
	end
	for map in pairs(BF.Marks.byMap) do
		for _, pin in ipairs(BF.Marks:On(map)) do
			for _, r in ipairs(pin.roles) do
				if r.quest == id and (r.role == "complete" or (r.role == "objective" and not Log:IsComplete(id))) then
					consider(pin.map, pin.x, pin.y)
				end
			end
		end
	end
	if best then BF.Waypoint:Set(best.map, best.x, best.y, BF:QuestName(id), nil, id) end
end

local function menu(anchor, id)
	BF.Dropdown:Open(anchor, {
		{ text = Rules:ColoredTitle(id, nil, true), title = true },
		{ text = focused == id and L["Unfocus"] or L["Focus"], onClick = function()
			focused = focused ~= id and id or nil
			List:Refresh()
		end },
		{ text = (C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) ~= nil) and L["Untrack"] or L["Track"],
			onClick = function() untrack(id) end },
		{ text = L["Show on map"], onClick = function()
			if BF.Seamless and BF:Get("map.seamless") then
				for map in pairs(BF.Marks.byMap) do
					for _, pin in ipairs(BF.Marks:On(map)) do
						for _, r in ipairs(pin.roles) do if r.quest == id then BF.Seamless:ShowMap(pin.map) return end end
					end
				end
			end
		end },
		{ text = L["Map pin"], onClick = function() pinFor(id) end },
		{ text = L["Details"], onClick = function() BF.Panel.ShowDetails("quest", id) end },
		{ text = L["Link in chat"], onClick = function()
			if BF.Links and ChatEdit_InsertLink then ChatEdit_InsertLink(BF.Links:Quest(id)) end
		end },
	})
end

local function onQuestClick(self, button)
	local id = self.quest
	if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and IsShiftKeyDown() and BF.Links then
		ChatEdit_InsertLink(BF.Links:Quest(id))
		return
	end
	if matches(BF:Get("list.clickPin"), button) then pinFor(id)
	elseif matches(BF:Get("list.clickUntrack"), button) then untrack(id)
	elseif matches(BF:Get("list.clickOpenLog"), button) then openInLog(id)
	elseif button == "RightButton" then menu(self, id) end
end

-- Filling ------------------------------------------------------------------------------------------------------------

local function sortKey(q)
	local mode = BF:Get("list.sort")
	if mode == "byLevel" then return Rules:Level(q.id) end
	if mode == "byLevelReversed" then return -Rules:Level(q.id) end
	if mode == "byComplete" then
		local have, need = 0, 0
		for _, o in ipairs(q.objectives) do have, need = have + o.have, need + math.max(o.need, 1) end
		return -(need > 0 and have / need or 1)
	end
	if mode == "byProximity" then return 0 end
	return q.index or 0
end

-- "Kobold Vermin slain: 4/10" -> "4/10 Kobold Vermin slain" (Questie's way round).
local function objectiveText(text)
	local name, count = (text or ""):match("^(.-):%s*(%d+%s*/%s*%d+)$")
	if name then return count .. " " .. name end
	return text
end

local function fill()
	if not frame then return end
	used = 0
	if not InCombatLockdown() then
		for _, b in ipairs(itemButtons) do b:Hide() end
		itemUsed = 0
	end
	local s = state()
	s.folded = s.folded or {}
	-- Measured now (at login the map window had no size yet: every row came out 0 wide).
	local width = math.max(160, (frame:GetWidth() or 0) - 4)
	content:SetWidth(width)
	local y = 0
	local quests = {}
	-- The tracked quests (as the game tracks them).
	for id, q in pairs(Log.quests) do
		local tracked = not C_QuestLog.GetQuestWatchType or C_QuestLog.GetQuestWatchType(id) ~= nil
		if tracked and (BF:Get("list.showComplete") or not Log:IsComplete(id)) then quests[#quests + 1] = q end
	end
	local byZone, zones = {}, {}
	local mode = BF:Get("list.sort")
	for _, q in ipairs(quests) do
		local zone = mode == "byZone" and (q.header or L["Other"]) or L["Quests"]
		if not byZone[zone] then
			byZone[zone] = {}
			zones[#zones + 1] = zone
		end
		table.insert(byZone[zone], q)
	end
	table.sort(zones)
	header:SetText(L["Quests: %d/%d"]:format(Log:Count(), C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 20))
	local pad = BF:Get("list.padding")
	for _, zone in ipairs(zones) do
		local zr = row()
		sized(zr.Text, "GameFontNormal", "list.fontSizeZone")
		zr.Text:SetTextColor(0.8, 0.8, 0.8)
		zr.Text:SetText(zone)
		zr.Text:ClearAllPoints()
		zr.Text:SetPoint("LEFT", 4, 0)
		zr.Text:SetPoint("RIGHT", -24, 0)
		zr.Toggle:SetTexture(s.folded[zone] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		zr.Toggle:Show()
		zr:SetScript("OnClick", function() s.folded[zone] = not s.folded[zone] fill() end)
		zr:SetHeight(rowFor("list.fontSizeZone") + 2)
		zr:ClearAllPoints()
		zr:SetPoint("TOPLEFT", 0, -y)
		zr:SetWidth(width)
		y = y + rowFor("list.fontSizeZone") + 4
		if not s.folded[zone] then
			local list = byZone[zone]
			table.sort(list, function(a, b) return sortKey(a) < sortKey(b) end)
			for _, q in ipairs(list) do
				local complete, failed = Log:IsComplete(q.id), Log:IsFailed(q.id)
				local qr = row()
				qr.quest = q.id
				sized(qr.Text, "GameFontNormal", "list.fontSizeQuest")
				qr.Text:SetText(Rules:ColoredTitle(q.id, q.title, BF:Get("list.questLevel")))
				qr.Text:ClearAllPoints()
				qr.Text:SetPoint("LEFT", 40, 0)
				qr.Text:SetPoint("RIGHT", -28, 0)
				-- Questie's two small buttons before the title: the menu, and fold/unfold.
				qr.Menu = qr.Menu or CreateFrame("Button", nil, qr)
				qr.Menu:SetSize(14, 14)
				qr.Menu:SetPoint("LEFT", 6, 0)
				qr.Menu:SetNormalFontObject("GameFontHighlightSmall")
				qr.Menu:SetText("...")
				qr.Menu:SetScript("OnClick", function(self) menu(self, q.id) end)
				qr.Menu:Show()
				qr.Fold = qr.Fold or CreateFrame("Button", nil, qr)
				qr.Fold:SetSize(14, 14)
				qr.Fold:SetPoint("LEFT", 22, 0)
				s.foldedQuests = s.foldedQuests or {}
				local isFolded = s.foldedQuests[q.id]
				qr.Fold:SetNormalTexture(isFolded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
				qr.Fold:SetScript("OnClick", function() s.foldedQuests[q.id] = not s.foldedQuests[q.id] or nil fill() end)
				qr.Fold:Show()
				qr:SetScript("OnClick", onQuestClick)
				qr:SetScript("OnEnter", function(self) BF.QuestTip:Show(self, q.id) end)
				qr:SetScript("OnLeave", function() GameTooltip:Hide() end)
				if BF:Get("list.focusButtons") then
					qr.Focus:Show()
					qr.Focus.tex:SetDesaturated(focused ~= q.id)
					qr.Focus.tex:SetAlpha(focused == q.id and 1 or 0.4)
					qr.Focus:SetScript("OnClick", function() focused = focused ~= q.id and q.id or nil fill() end)
				end
				local tracked = not C_QuestLog.GetQuestWatchType or C_QuestLog.GetQuestWatchType(q.id) ~= nil
				if (focused and focused ~= q.id) or not tracked then qr:SetAlpha(0.5) end
				qr:SetHeight(rowFor("list.fontSizeQuest"))
				qr:ClearAllPoints()
				qr:SetPoint("TOPLEFT", 0, -y)
				qr:SetWidth(width)
				-- The quest's usable item, at the row's right.
				local link, icon, charges = questItem(q.id)
				if link and not InCombatLockdown() then
					local b = itemButton()
					b.link = link
					b.icon:SetTexture(icon)
					b.count:SetText(charges and charges > 1 and charges or "")
					b:SetAttribute("item", link)
					b:ClearAllPoints()
					b:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -y - 1)
					b:Show()
				end
				y = y + rowFor("list.fontSizeQuest")
				local foldThis = (complete and BF:Get("list.collapseComplete")) or (s.foldedQuests and s.foldedQuests[q.id])
				if complete then
					local r = row()
					sized(r.Text, "GameFontHighlightSmall", "list.fontSizeObjective")
					r.Text:SetText(L["Quest Complete!"])
					r.Text:SetTextColor(0.3, 1, 0.3)
					r.Text:ClearAllPoints()
					r.Text:SetPoint("LEFT", 52, 0)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetWidth(width)
					y = y + rowFor("list.fontSizeObjective") - 2
				elseif failed then
					local r = row()
					sized(r.Text, "GameFontHighlightSmall", "list.fontSizeObjective")
					r.Text:SetText(L["Quest Failed!"])
					r.Text:SetTextColor(1, 0.3, 0.3)
					r.Text:ClearAllPoints()
					r.Text:SetPoint("LEFT", 52, 0)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetWidth(width)
					y = y + rowFor("list.fontSizeObjective") - 2
				end
				if not foldThis then
					for _, o in ipairs(q.objectives) do
						if not (o.finished and BF:Get("list.hideDoneObjectives")) and not (complete and BF:Get("list.hideCompletionText")) then
							local r = row()
							sized(r.Text, "GameFontHighlightSmall", "list.fontSizeObjective")
							r.Text:SetText(objectiveText(o.text))
							r.Text:SetTextColor(objectiveColour(o))
							r.Text:ClearAllPoints()
							r.Text:SetPoint("LEFT", 52, 0)
							r.Text:SetPoint("RIGHT", -8, 0)
							r:ClearAllPoints()
							r:SetPoint("TOPLEFT", 0, -y)
							r:SetWidth(width)
							y = y + rowFor("list.fontSizeObjective") - 2
						end
					end
				end
				y = y + pad
			end
		end
	end
	for i = used + 1, #rows do rows[i]:Hide() end
	content:SetHeight(math.max(y, 10))
end

function List:Refresh() fill() end

-- The frame over the game's list ---------------------------------------------------------------------------------

BF.Settings:Define("list.enabled", { default = true, page = "Quests/List", label = "Quest tracker on the screen" })
BF.Settings:Define("list.locked", { default = false, page = "Quests/List", label = "Lock the tracker in place" })
BF.Settings:Define("list.maxHeight", { default = 520, min = 150, max = 1200, step = 10, page = "Quests/List", label = "Tracker height" })
BF.Settings:Define("list.width", { default = 290, min = 180, max = 500, step = 5, page = "Quests/List", label = "Tracker width" })

local collapsedAll = false

local function build()
	frame = CreateFrame("Frame", "BookFinderTracker", UIParent)
	frame:SetSize(BF:Get("list.width"), BF:Get("list.maxHeight"))
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetFrameStrata("MEDIUM")
	local place = BF:AccountState("tracker").place
	if place then frame:SetPoint(place[1], UIParent, place[2], place[3], place[4])
	else frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -220) end

	-- The header: "Quests: 13/40"; click folds the whole tracker, drag moves it (unless locked).
	local head = CreateFrame("Button", nil, frame)
	head:SetHeight(18)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:RegisterForDrag("LeftButton")
	head:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	header = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("LEFT", 4, 0)
	head:SetScript("OnDragStart", function() if not BF:Get("list.locked") then frame:StartMoving() end end)
	head:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local p, _, rp, x, y = frame:GetPoint(1)
		BF:AccountState("tracker").place = { p, rp, math.floor(x + 0.5), math.floor(y + 0.5) }
	end)
	head:SetScript("OnClick", function(_, button)
		if button == "RightButton" then BF.Panel:Open("quests", "list") return end
		collapsedAll = not collapsedAll
		scroll:SetShown(not collapsedAll)
	end)

	scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", 0, -20)
	scroll:SetPoint("BOTTOMRIGHT", 0, 0)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 40)))
	end)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(BF:Get("list.width"), 10)
	scroll:SetScrollChild(content)
	frame:SetScript("OnShow", fill)
	return true
end

BF:At("login", function()
	if not build() then return end
	frame:SetShown(BF:Get("list.enabled"))
	-- Questie tracks every quest: so do we at login when auto-tracking (new ones as they are accepted).
	if BF:Get("list.autoTrack") and C_QuestLog.AddQuestWatch then
		for id in pairs(Log.quests) do
			if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(id) == nil then C_QuestLog.AddQuestWatch(id) end
		end
	end
	local soon = BF:Debounce(0.1, function() if frame:IsVisible() then fill() end end)
	BF:Listen("BF_QUEST_LOG_CHANGED", soon)
	BF:Listen("BF_QUEST_PROGRESS", soon)
	BF:Listen("BF_QUEST_LIST_CHANGED", soon)
	-- Following the game's focused quest (the one its map pin and objective arrow point at): it is the list's focus.
	BF:On("SUPER_TRACKING_CHANGED", function()
		if not BF:Get("list.followSuperTrack") or not (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) then return end
		local id = C_SuperTrack.GetSuperTrackedQuestID()
		focused = id and id > 0 and Log:Has(id) and id or nil
		soon()
	end)
	BF:On("QUEST_WATCH_LIST_CHANGED", soon)
	BF:On("PLAYER_REGEN_ENABLED", soon)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key == "list.enabled" then frame:SetShown(BF:Get("list.enabled")) end
		if key == "list.width" or key == "list.maxHeight" then frame:SetSize(BF:Get("list.width"), BF:Get("list.maxHeight")) end
		if key:find("^list%.") then soon() end
	end)
	-- Auto-track quests as they are accepted.
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id)
		if BF:Get("list.autoTrack") and C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
	end)
end, 95)
