-- BookFinder: the quest list lives in the map, and nothing tracks on screen.
--
--   * Questie's tracker (its real frame, Questie_BaseFrame, with every feature it has: item buttons, focus, collapsing
--     zones and quests, its menus) moves into the world map's Quests tab, over the game's own list, on the quest log's
--     parchment. Questie keeps hiding the game's tracker; its frame is locked, without its sizer or backdrop, and sized
--     to the room in the quest log (its own TrackerWidth and TrackerHeight, so it scrolls inside as it always has).
--   * The Forever column (Shortest Path's journey and its lift, tram and boat departures, and any other Forever
--     addon's section) leaves the screen: it is parked under a hidden frame.
--   * The journey is shown at the top of the Quests tab instead, in Questie's fonts: where it goes and the time left,
--     then each leg with its own time, the current one first and in gold; × cancels it. The arrow and compass still
--     guide you on screen.
-- Frames with Questie's secure item buttons in them can only be moved out of combat: anything asked in combat waits
-- for it to end.
local _, root = ...
local public = root.public
local Kit = public and public.Kit
if not public then return end

local hidden = CreateFrame("Frame")
hidden:Hide()

local function questieProfile()
	local q = rawget(_G, "Questie")
	return q and q.db and q.db.profile or nil
end
local function questieModule(name)
	local loader = rawget(_G, "QuestieLoader")
	local ok, mod = pcall(function() return loader:ImportModule(name) end)
	return ok and mod or nil
end

-- Questie's fonts (its tracker's), so the journey reads as part of the same list
local function fonts()
	local p = questieProfile()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local function fetch(name) return (LSM and name and LSM:Fetch("font", name, true)) or STANDARD_TEXT_FONT end
	local outline = p and p.trackerFontOutline or ""
	return {
		title = { fetch(p and p.trackerFontQuest), p and p.trackerFontSizeQuest or 11, outline },
		line = { fetch(p and p.trackerFontObjective), p and p.trackerFontSizeObjective or 10, outline },
	}
end

local function Countdown(seconds)
	seconds = math.max(0, math.floor((seconds or 0) + 0.5))
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
	return ("%d:%02d"):format(m, s)
end

-- The Forever column, off the screen ---------------------------------------------------------------------------------
local function parkColumn()
	local host = rawget(_G, "ForeverTrackerCompanion")
	if not host or host:GetParent() == hidden then return true end
	if InCombatLockdown() then return false end
	host:SetParent(hidden)
	return true
end

-- The Quests tab ------------------------------------------------------------------------------------------------------
local holder, journey, emptyText, base
local journeyShown = false
local anchoring, docked, pending = false, false, false
local lines = {}

local function api()
	local spf = ShortestPathForever and ShortestPathForever.API
	return type(spf) == "table" and spf or nil
end

local function placeBase()
	if not (base and holder) or anchoring then return end
	if InCombatLockdown() then pending = true return end
	anchoring = true
	base:ClearAllPoints()
	if journeyShown then
		base:SetPoint("TOPLEFT", journey, "BOTTOMLEFT", -4, -6)
	else
		base:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -6)
	end
	anchoring = false
end

-- Questie's size caps: the room in the quest log, in its frame's own units
local function fit()
	local p = questieProfile()
	if not (p and base and holder) then return end
	local toBase = holder:GetEffectiveScale() / math.max(0.01, base:GetEffectiveScale())
	local used = journeyShown and (journey:GetHeight() + 10) or 0
	local width = math.floor((holder:GetWidth() - 12) * toBase)
	local height = math.floor((holder:GetHeight() - used - 14) * toBase)
	if width > 50 and height > 50 and (p.TrackerWidth ~= width or p.TrackerHeight ~= height) then
		p.TrackerWidth, p.TrackerHeight = width, height
		local tracker = questieModule("QuestieTracker")
		if tracker and tracker.Update then pcall(tracker.Update, tracker) end
	end
end

local function line(i)
	local l = lines[i]
	if l then return l end
	l = CreateFrame("Frame", nil, journey)
	l:SetHeight(14)
	l.text = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l.text:SetPoint("LEFT", 10, 0)
	l.text:SetJustifyH("LEFT")
	l.text:SetWordWrap(false)
	l.time = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	l.time:SetPoint("RIGHT", -2, 0)
	l.time:SetJustifyH("RIGHT")
	l.text:SetPoint("RIGHT", l.time, "LEFT", -6, 0)
	lines[i] = l
	return l
end

local function modeMarkup(mode)
	local art = root.SPF and root.SPF.Art
	if art and art.ModeMarkup then
		local ok, markup = pcall(art.ModeMarkup, mode, 12)
		if ok and markup then return markup .. " " end
	end
	return ""
end

local function refreshJourney()
	if not journey then return end
	local spf = api()
	local ok, j = false, nil
	if spf and spf.Journey then ok, j = pcall(spf.Journey) end
	local active = ok and type(j) == "table" and type(j.goal) == "table"
	if not active then
		for _, l in ipairs(lines) do l:Hide() end
		journey:Hide()
	else
		local f = fonts()
		journey.title:SetFont(f.title[1], f.title[2], f.title[3])
		journey.title:SetText(j.goal.title or "?")
		journey.left:SetFont(f.title[1], f.title[2], f.title[3])
		journey.left:SetText(Countdown(j.secondsLeft))
		local y = -(f.title[2] + 8)
		local legs = type(j.legs) == "table" and j.legs or {}
		for i, leg in ipairs(legs) do
			local l = line(i)
			l.text:SetFont(f.line[1], f.line[2], f.line[3])
			l.time:SetFont(f.line[1], f.line[2], f.line[3])
			l:SetHeight(f.line[2] + 4)
			l.text:SetText(modeMarkup(leg.mode) .. (leg.text or ""))
			l.time:SetText(leg.seconds and leg.seconds > 0 and Countdown(leg.seconds) or "")
			local current = i == 1
			local c = current and (NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }) or (HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 })
			l.text:SetTextColor(c.r, c.g, c.b)
			l.time:SetTextColor(c.r, c.g, c.b)
			l:ClearAllPoints()
			l:SetPoint("TOPLEFT", journey, "TOPLEFT", 0, y)
			l:SetPoint("TOPRIGHT", journey, "TOPRIGHT", 0, y)
			l:Show()
			y = y - (f.line[2] + 4)
		end
		for i = #legs + 1, #lines do lines[i]:Hide() end
		journey:SetHeight(-y + 2)
		journey.goal = j.goal
		journey:Show()
	end
	if active ~= journeyShown then
		journeyShown = active
		placeBase()
		fit()
	end
end

local function refreshEmpty()
	if not emptyText then return end
	local showing = base and base:IsShown()
	emptyText:SetShown(not showing)
	emptyText:SetText(public.Active("Questie") and "No quests in your log." or "")
end

local function build()
	if holder then return holder end
	local quests = QuestMapFrame and QuestMapFrame.QuestsFrame
	if not quests then return nil end
	local anchor = QuestMapFrame.ContentsAnchor or quests
	holder = CreateFrame("Frame", "BookFinderQuestList", quests)
	holder:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
	holder:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -22, 0)
	holder:SetFrameLevel(quests:GetFrameLevel() + 20)
	holder:EnableMouse(true)
	if holder.SetClipsChildren then holder:SetClipsChildren(true) end
	local background = holder:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	if Kit and Kit.Art and Kit.Art.CoverFrame then
		Kit.Art.CoverFrame(holder, background, "QuestLog-main-background", 0, 0)
	else
		background:SetColorTexture(0.1, 0.08, 0.05, 1)
	end
	CreateFrame("Frame", nil, holder, "QuestLogBorderFrameTemplate")
	journey = CreateFrame("Button", nil, holder)
	journey:SetPoint("TOPLEFT", holder, "TOPLEFT", 10, -8)
	journey:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -10, -8)
	journey:SetHeight(20)
	journey:Hide()
	journey.title = journey:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	journey.title:SetPoint("TOPLEFT", 0, 0)
	journey.title:SetJustifyH("LEFT")
	journey.title:SetWordWrap(false)
	journey.cancel = CreateFrame("Button", nil, journey)
	journey.cancel:SetSize(14, 14)
	journey.cancel:SetPoint("TOPRIGHT", 0, 1)
	local x = journey.cancel:CreateTexture(nil, "ARTWORK")
	x:SetAllPoints()
	if not (Kit and Kit.Art and Kit.Art.Fit and Kit.Art.Fit(x, "common-icon-redx", 14, 14)) then
		x:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	end
	journey.cancel:SetScript("OnClick", function()
		local SPF = root.SPF
		if SPF and SPF.ClearJourney then SPF.ClearJourney() end
		refreshJourney()
	end)
	journey.cancel:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(CANCEL or "Cancel")
		GameTooltip:Show()
	end)
	journey.cancel:SetScript("OnLeave", function() GameTooltip:Hide() end)
	journey.left = journey:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	journey.left:SetPoint("RIGHT", journey.cancel, "LEFT", -6, 0)
	journey.title:SetPoint("RIGHT", journey.left, "LEFT", -6, 0)
	journey:SetScript("OnClick", function(self)
		local goal = self.goal
		if goal and goal.map and WorldMapFrame then WorldMapFrame:SetMapID(goal.map) end
	end)
	emptyText = holder:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("TOP", holder, "TOP", 0, -40)
	return holder
end

-- Questie's tracker, into the Quests tab
local hookedBase = false
local function dock()
	if docked then return true end
	base = rawget(_G, "Questie_BaseFrame")
	if not (base and build()) then return false end
	if InCombatLockdown() then pending = true return false end
	local p = questieProfile()
	if p then
		p.trackerLocked = true
		p.sizerHidden = true
		p.trackerBackdropEnabled = false
	end
	base:SetParent(holder)
	base:SetFrameStrata(holder:GetFrameStrata())
	base:SetFrameLevel(holder:GetFrameLevel() + 5)
	local sizer = rawget(_G, "Questie_Sizer")
	if sizer then sizer:Hide() end
	if not hookedBase then
		hookedBase = true
		-- (Questie puts it back at its saved place now and then: it stays in the quest log)
		hooksecurefunc(base, "SetPoint", function() if not anchoring then placeBase() end end)
	end
	docked = true
	placeBase()
	fit()
	return true
end

local function step()
	parkColumn()
	if public.Active("Questie") then dock() end
	if holder and holder:IsVisible() then
		refreshJourney()
		refreshEmpty()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = false
			parkColumn()
			if not docked then dock() else placeBase() end
		end
		return
	end
	build()
	-- (Questie builds its tracker a few seconds in, the Forever column attaches after the world loads; each is picked up
	-- as it appears. While the map shows the Quests tab, the journey's times count down.)
	C_Timer.NewTicker(1, step)
	local spf = api()
	if spf and type(spf.Subscribe) == "function" then
		pcall(spf.Subscribe, function() if holder and holder:IsVisible() then refreshJourney() end end)
	end
end)

-- for the offline test
public.QuestLog = {
	Build = build, Dock = dock, Park = parkColumn, Step = step,
	Refresh = function() refreshJourney() refreshEmpty() end,
	Holder = function() return holder end, Hidden = hidden,
	Legs = function() local n = 0 for _, l in ipairs(lines) do if l:IsShown() then n = n + 1 end end return n end,
	JourneyShown = function() return journeyShown end,
}
