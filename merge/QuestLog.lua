-- BookFinder: the quest list lives in the map, and nothing tracks on screen.
--
-- Questie's tracker (its real frame, Questie_BaseFrame, with every feature it has: item buttons, focus, collapsing
-- zones and quests, its menus) moves into the world map's Quests tab, over the game's own list, on the quest log's
-- parchment. Questie keeps hiding the game's tracker; its frame is locked, without its sizer or backdrop, and sized to
-- the room in the quest log (its own TrackerWidth and TrackerHeight), so it scrolls inside as it always has.
--
-- The scrollbar: Questie scrolls its list with the mouse wheel and hides its own bar, and the game's quest list bar
-- stayed beside it, still and unrelated. The holder now covers the game's list to the frame's edge, and Questie's own
-- bar is shown in that gutter, so the bar you see is the list's and moves with it.
--
-- Frames with Questie's secure item buttons in them can only be moved out of combat: anything asked in combat waits
-- for it to end.
local _, root = ...
local public = root.public
local Kit = public and public.Kit
if not public then return end

local BAR = 22   -- the gutter the game's own list keeps for its scrollbar

local function questieProfile()
	local q = rawget(_G, "Questie")
	return q and q.db and q.db.profile or nil
end
local function questieModule(name)
	local loader = rawget(_G, "QuestieLoader")
	local ok, mod = pcall(function() return loader:ImportModule(name) end)
	return ok and mod or nil
end

local holder, emptyText, base
local anchoring, docked, pending = false, false, false

local function placeBase()
	if not (base and holder) or anchoring then return end
	if InCombatLockdown() then pending = true return end
	anchoring = true
	base:ClearAllPoints()
	base:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -6)
	anchoring = false
end

-- Questie's own scrollbar, in the gutter at the holder's right edge
local function placeBar()
	local scroll = rawget(_G, "TrackedQuestsScrollFrame")
	local bar = scroll and scroll.ScrollBar
	if not (bar and holder) then return end
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -8)
	bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -4, 8)
	bar:SetShown(scroll:GetVerticalScrollRange() > 1)
end

-- Questie's size caps: the room in the quest log, in its frame's own units
local function fit()
	local p = questieProfile()
	if not (p and base and holder) then return end
	local toBase = holder:GetEffectiveScale() / math.max(0.01, base:GetEffectiveScale())
	local width = math.floor((holder:GetWidth() - 12 - BAR) * toBase)
	local height = math.floor((holder:GetHeight() - 14) * toBase)
	if width > 50 and height > 50 and (p.TrackerWidth ~= width or p.TrackerHeight ~= height) then
		p.TrackerWidth, p.TrackerHeight = width, height
		local tracker = questieModule("QuestieTracker")
		if tracker and tracker.Update then pcall(tracker.Update, tracker) end
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
	-- (to the frame's edge: the game's list and its scrollbar are covered)
	holder:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
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
		local scroll = rawget(_G, "TrackedQuestsScrollFrame")
		if scroll and scroll.HookScript then
			scroll:HookScript("OnScrollRangeChanged", placeBar)
		end
	end
	docked = true
	placeBase()
	fit()
	placeBar()
	return true
end

local function step()
	if public.Active("Questie") then dock() end
	if holder and holder:IsVisible() then
		refreshEmpty()
		placeBar()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = false
			if not docked then dock() else placeBase() end
		end
		return
	end
	build()
	-- (Questie builds its tracker a few seconds in: picked up as it appears)
	C_Timer.NewTicker(1, step)
end)

-- for the offline test
public.QuestLog = {
	Build = build, Dock = dock, Step = step,
	Refresh = function() refreshEmpty() placeBar() end,
	Holder = function() return holder end,
}
