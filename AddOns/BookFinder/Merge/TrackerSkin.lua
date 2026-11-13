-- BookFinder: one tracker. Questie draws the quest list and hides the game's tracker; the Forever column (Shortest
-- Path's journey and its lift, tram and boat departures) sits under Questie's list. Native, it wore the game's module
-- header art and fonts, and read as a second tracker. Under Questie's list it now wears Questie's: no header art, the
-- section name in Questie's zone font and grey, each block's title in its quest font, each line in its objective
-- font, at Questie's sizes and outline. ForeverCore's TrackerHost.lua gives it the list's width; it already sits
-- right under the list. Without Questie's tracker on screen the column keeps the game's look.
local _, root = ...
local public = root.public
if not public then return end

local function questieList()
	local list = rawget(_G, "Questie_BaseFrame")
	return list and list.IsShown and list:IsShown() and list or nil
end

local function fonts()
	local q = rawget(_G, "Questie")
	local p = q and q.db and q.db.profile
	if not p then return end
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local function fetch(name) return LSM and name and LSM:Fetch("font", name, true) or STANDARD_TEXT_FONT end
	local outline = p.trackerFontOutline or ""
	return {
		zone = { fetch(p.trackerFontZone), p.trackerFontSizeZone or 12, outline },
		quest = { fetch(p.trackerFontQuest), p.trackerFontSizeQuest or 10, outline },
		objective = { fetch(p.trackerFontObjective), p.trackerFontSizeObjective or 10, outline },
	}
end

-- sets a font string's font; true when that changed it
local function setFont(text, f)
	if not (text and text.GetFont and f and f[1]) then return false end
	local file, size, flags = text:GetFont()
	if file == f[1] and size and math.abs(size - f[2]) < 0.1 and (flags or "") == f[3] then return false end
	text:SetFont(f[1], f[2], f[3])
	return true
end

local ZONE_GREY = { 0.753, 0.753, 0.753 }   -- (Questie's zone headers: |cFFC0C0C0)

local function skinModule(module, f)
	local changed = false
	local header = module.Header
	if header then
		if header.Background then header.Background:SetAlpha(0) end
		if header.Text then
			changed = setFont(header.Text, f.zone) or changed
			header.Text:SetTextColor(ZONE_GREY[1], ZONE_GREY[2], ZONE_GREY[3])
		end
	end
	-- blocks and their lines, wherever the module keeps them
	local function walk(frame, depth)
		if depth > 4 then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child.HeaderText then changed = setFont(child.HeaderText, f.quest) or changed end
			if child.Text and child ~= header then changed = setFont(child.Text, f.objective) or changed end
			walk(child, depth + 1)
		end
	end
	if module.ContentsFrame then walk(module.ContentsFrame, 0) end
	return changed
end

local hooked = {}
local busy = false
local function skin(module)
	if busy or not questieList() then return end
	local f = fonts()
	if not f then return end
	busy = true
	local ok, changed = pcall(skinModule, module, f)
	busy = false
	-- a font that changed changes the lines' heights: one more layout measures them (the next pass changes nothing)
	if ok and changed and module.MarkDirty then module:MarkDirty() end
end

-- the column's sections, hooked as they attach
local function scan()
	local host = rawget(_G, "ForeverTrackerCompanion")
	if not host then return end
	for _, module in ipairs({ host:GetChildren() }) do
		if not hooked[module] and module.Header and module.ContentsFrame then
			hooked[module] = true
			for _, method in ipairs({ "EndLayout", "Update" }) do
				if type(module[method]) == "function" then
					hooksecurefunc(module, method, skin)
					break
				end
			end
			skin(module)
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	-- (sections attach a moment after the world loads; Questie builds its list a few seconds in)
	local tries = 0
	local ticker
	ticker = C_Timer.NewTicker(2, function()
		tries = tries + 1
		scan()
		if tries >= 30 then ticker:Cancel() end
	end)
end)

-- for the offline test
public.TrackerSkin = { Scan = scan, Skin = skin, Hooked = hooked }
