-- The quest list in the map's Quests tab (Questie's tracker, there instead of on the screen): quests by zone, folding,
-- each title with its level in its difficulty colour, its objectives with their progress, "Quest Complete!" /
-- "Quest Failed!", a usable-item button and a focus button; clicks as chosen (Quests > Quest list), a right-click menu.
-- It lies over the game's own list; a quest's details (the game's) still open over it.

local _, BF = ...
local L = BF.L

local List = {}
BF.QuestList = List

local Log, Rules = BF.Log, BF.Rules
local ROW = 16

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

local function fill()
	if not frame then return end
	used = 0
	if not InCombatLockdown() then
		for _, b in ipairs(itemButtons) do b:Hide() end
		itemUsed = 0
	end
	local s = state()
	s.folded = s.folded or {}
	local width = content:GetWidth()
	local y = 0
	local quests = {}
	-- Every quest in the log (this is the Quests tab: the log itself); untracked ones dimmed.
	for id, q in pairs(Log.quests) do
		if BF:Get("list.showComplete") or not Log:IsComplete(id) then quests[#quests + 1] = q end
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
		zr.Text:SetFontObject("GameFontNormal")
		zr.Text:SetTextColor(1, 0.82, 0)
		zr.Text:SetText(zone)
		zr.Text:ClearAllPoints()
		zr.Text:SetPoint("LEFT", 4, 0)
		zr.Text:SetPoint("RIGHT", -24, 0)
		zr.Toggle:SetTexture(s.folded[zone] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		zr.Toggle:Show()
		zr:SetScript("OnClick", function() s.folded[zone] = not s.folded[zone] fill() end)
		zr:SetHeight(ROW + 2)
		zr:ClearAllPoints()
		zr:SetPoint("TOPLEFT", 0, -y)
		zr:SetWidth(width)
		y = y + ROW + 4
		if not s.folded[zone] then
			local list = byZone[zone]
			table.sort(list, function(a, b) return sortKey(a) < sortKey(b) end)
			for _, q in ipairs(list) do
				local complete, failed = Log:IsComplete(q.id), Log:IsFailed(q.id)
				local qr = row()
				qr.quest = q.id
				qr.Text:SetFontObject("GameFontNormal")
				qr.Text:SetText(Rules:ColoredTitle(q.id, q.title, BF:Get("list.questLevel")))
				qr.Text:ClearAllPoints()
				qr.Text:SetPoint("LEFT", 14, 0)
				qr.Text:SetPoint("RIGHT", -52, 0)
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
				qr:SetHeight(ROW)
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
				y = y + ROW
				local foldThis = complete and BF:Get("list.collapseComplete")
				if complete then
					local r = row()
					r.Text:SetFontObject("GameFontHighlightSmall")
					r.Text:SetText(L["Quest Complete!"])
					r.Text:SetTextColor(0.3, 1, 0.3)
					r.Text:ClearAllPoints()
					r.Text:SetPoint("LEFT", 26, 0)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetWidth(width)
					y = y + ROW - 2
				elseif failed then
					local r = row()
					r.Text:SetFontObject("GameFontHighlightSmall")
					r.Text:SetText(L["Quest Failed!"])
					r.Text:SetTextColor(1, 0.3, 0.3)
					r.Text:ClearAllPoints()
					r.Text:SetPoint("LEFT", 26, 0)
					r:ClearAllPoints()
					r:SetPoint("TOPLEFT", 0, -y)
					r:SetWidth(width)
					y = y + ROW - 2
				end
				if not foldThis then
					for _, o in ipairs(q.objectives) do
						if not (o.finished and BF:Get("list.hideDoneObjectives")) and not (complete and BF:Get("list.hideCompletionText")) then
							local r = row()
							r.Text:SetFontObject("GameFontHighlightSmall")
							r.Text:SetText("- " .. o.text)
							r.Text:SetTextColor(objectiveColour(o))
							r.Text:ClearAllPoints()
							r.Text:SetPoint("LEFT", 26, 0)
							r.Text:SetPoint("RIGHT", -8, 0)
							r:ClearAllPoints()
							r:SetPoint("TOPLEFT", 0, -y)
							r:SetWidth(width)
							y = y + ROW - 2
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

BF.Settings:Define("list.inMap", { default = true, page = "Quests/List", label = "BookFinder's list in the map's Quests tab" })

local function build()
	local host = QuestScrollFrame
	if not host then return false end
	frame = CreateFrame("Frame", "BookFinderQuestList", host:GetParent())
	frame:SetAllPoints(host)
	frame:SetFrameLevel(host:GetFrameLevel() + 10)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.04, 0.03, 0.97)
	header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", 8, -6)
	scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -26)
	scroll:SetPoint("BOTTOMRIGHT", -24, 4)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(host:GetWidth() - 30, 10)
	scroll:SetScrollChild(content)
	frame:SetScript("OnShow", fill)
	-- A quest's details (the game's) open over the list; the list returns after.
	if QuestMapFrame and QuestMapFrame.DetailsFrame then
		QuestMapFrame.DetailsFrame:HookScript("OnShow", function() frame:Hide() end)
		QuestMapFrame.DetailsFrame:HookScript("OnHide", function() if BF:Get("list.inMap") then frame:Show() end end)
	end
	return true
end

BF:At("login", function()
	if not build() then return end
	frame:SetShown(BF:Get("list.inMap"))
	local soon = BF:Debounce(0.1, function() if frame:IsVisible() then fill() end end)
	BF:Listen("BF_QUEST_LOG_CHANGED", soon)
	BF:Listen("BF_QUEST_PROGRESS", soon)
	BF:Listen("BF_QUEST_LIST_CHANGED", soon)
	BF:On("QUEST_WATCH_LIST_CHANGED", soon)
	BF:On("PLAYER_REGEN_ENABLED", soon)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		if key == "list.inMap" then frame:SetShown(BF:Get("list.inMap")) end
		if key:find("^list%.") then soon() end
	end)
	-- Auto-track quests as they are accepted.
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id)
		if BF:Get("list.autoTrack") and C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(id) end
	end)
end, 95)
