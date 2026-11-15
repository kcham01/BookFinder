-- The tabs on the quest log's right edge, beside the map: Quests (BookFinder's quest list, Questie's way) and Books
-- (the library books). WoW: Forever's quest log has no side tabs of its own, so these are BookFinder's: a column of
-- tabs in the quest log's tab look, each showing its page over the quest log.
--
-- A quest's details (opened from the list) are the game's own: while they show, the page steps aside, and comes back
-- when the details close. The last tab chosen is remembered.

local _, BF = ...
local L = BF.L

local LogTabs = { list = {} }
BF.LogTabs = LogTabs

local GAP = 4
local installed, current

local function questFrame() return rawget(_G, "QuestMapFrame") end
local function state() return BF:CharacterState("logTabs") end

--- A tab: { key, order, icon (texture or icon kind), tip = fn(tooltip), build = fn(page), refresh = fn() }.
function LogTabs:Add(spec)
	LogTabs.list[#LogTabs.list + 1] = spec
	table.sort(LogTabs.list, function(a, b) return a.order < b.order end)
	if installed then LogTabs:Install(true) end
end

local function setChecked(b, on)
	b.checked = on and true or false
	if b.SelectedTexture then b.SelectedTexture:SetShown(b.checked) end
	b.Icon:SetDesaturated(not b.checked)
	b.Icon:SetAlpha(b.checked and 1 or 0.8)
end

local function makeTab(parent, spec)
	local ok, b = pcall(CreateFrame, "Button", "BookFinderLogTab_" .. spec.key, parent, "QuestLogTabButtonTemplate")
	if not ok or not b then
		b = CreateFrame("Button", "BookFinderLogTab_" .. spec.key, parent)
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
	-- (the template's own look switching wants atlases we don't use: ours instead)
	b.activeAtlas, b.inactiveAtlas = nil, nil
	b.SetChecked = setChecked
	BF.Icons:Set(b.Icon, spec.icon)
	b:SetScript("OnMouseUp", nil)
	b:SetScript("OnMouseDown", nil)
	b:SetScript("OnClick", function() LogTabs:Select(spec.key) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		spec.tip(GameTooltip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	setChecked(b, false)
	return b
end

local function makePage(parent, spec)
	local page = CreateFrame("Frame", "BookFinderLogPage_" .. spec.key, parent)
	page:SetAllPoints(parent.ContentsAnchor or parent)
	page:SetFrameLevel(parent:GetFrameLevel() + 20)
	page:EnableMouse(true) -- (clicks stay on the page, not the log under it)
	local bg = page:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestLog-main-background") then
		bg:SetAtlas("QuestLog-main-background", false)
	else
		bg:SetColorTexture(0.06, 0.05, 0.04, 0.97)
	end
	page:Hide()
	spec.build(page)
	return page
end

local detailsOpen = false

local function show()
	for _, spec in ipairs(LogTabs.list) do
		local mine = spec.key == current
		if spec.page then spec.page:SetShown(mine and not detailsOpen) end
		if spec.tab then spec.tab:SetChecked(mine) end
		if mine and spec.refresh and not detailsOpen then spec.refresh() end
	end
end

function LogTabs:Select(key)
	current = key
	state().current = key
	detailsOpen = false
	show()
end

function LogTabs:Current() return current end

--- Opens the map, with the quest log beside it, on that tab.
function LogTabs:Open(key)
	if WorldMapFrame and not WorldMapFrame:IsShown() then
		if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
	end
	local qmf = questFrame()
	if qmf and not qmf:IsShown() and WorldMapFrame and WorldMapFrame.HandleUserActionToggleSidePanel then
		pcall(WorldMapFrame.HandleUserActionToggleSidePanel, WorldMapFrame)
	end
	LogTabs:Select(key)
end

function LogTabs:IsShown(key)
	for _, spec in ipairs(LogTabs.list) do
		if spec.key == key then return spec.page ~= nil and spec.page:IsVisible() end
	end
	return false
end

function LogTabs:Install(again)
	local qmf = questFrame()
	if not qmf then return false end
	installed = true
	local prev
	for _, spec in ipairs(LogTabs.list) do
		spec.page = spec.page or makePage(qmf, spec)
		spec.tab = spec.tab or makeTab(qmf, spec)
		spec.tab:ClearAllPoints()
		if prev then spec.tab:SetPoint("TOP", prev, "BOTTOM", 0, -GAP)
		else spec.tab:SetPoint("TOPLEFT", qmf, "TOPRIGHT", -2, -40) end
		prev = spec.tab
	end
	if not again then
		-- A quest's details are the game's: the page steps aside while they show.
		if rawget(_G, "QuestMapFrame_ShowQuestDetails") then
			hooksecurefunc("QuestMapFrame_ShowQuestDetails", function() detailsOpen = true show() end)
		end
		if rawget(_G, "QuestMapFrame_ReturnFromQuestDetails") then
			hooksecurefunc("QuestMapFrame_ReturnFromQuestDetails", function() detailsOpen = false show() end)
		end
		current = current or state().current or (LogTabs.list[1] and LogTabs.list[1].key)
	end
	show()
	return true
end

BF:At("login", function()
	if not LogTabs:Install() and WorldMapFrame then
		WorldMapFrame:HookScript("OnShow", function() if not installed then LogTabs:Install() end end)
	end
end, 90)
