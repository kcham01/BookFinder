-- The arrow and the compass: they guide the player to the map pin (docs/study/arrow-and-compass.md). No lines are
-- drawn on any map.
--
-- The arrow, under the top of the screen, turns (easing, not snapping) toward the pin, with the distance under it.
-- Within the arrival distance it becomes the gold pin with what to do there; the game's map pin is then taken away,
-- and the gold pin stays until the player walks off. The compass is a thin strip of the game's parchment ticks and the
-- letters N, E, S, W across the top of the screen, fading out at both ends, the pin marked on it with its distance.
-- With the pin behind the player both dim; on arrival the strip turns quietly green. In instances (no position)
-- nothing is drawn. Both can be moved (drag, or the arrow keys to the pixel) and sized.

local _, BF = ...
local L = BF.L

local Guide = {}
BF.Guide = Guide

local Zones, Icons = BF.Zones, BF.Icons
local pi, abs, exp, floor = math.pi, math.abs, math.exp, math.floor
local TWO_PI = 2 * pi

-- Settings (the Map tab's Guide page) -----------------------------------------------------------------------------

local S = BF.Settings
local P = "Map/Guide"
S:Define("guide.arrow", { default = true, page = P, label = "Arrow to the map pin" })
S:Define("guide.compass", { default = true, page = P, label = "Compass at the top of the screen" })
S:Define("guide.arrowScale", { default = 1, min = 0.5, max = 2, step = 0.05, page = P, label = "Arrow size" })
S:Define("guide.compassWidth", { default = 420, min = 200, max = 900, step = 10, page = P, label = "Compass width" })
S:Define("guide.compassScale", { default = 1, min = 0.5, max = 2, step = 0.05, page = P, label = "Compass size" })
S:Define("guide.compassBand", { default = false, page = P, label = "Dark band behind the compass" })
S:Define("guide.metres", { default = false, page = P, label = "Distances in metres" })
S:Define("guide.arrival", { default = 10, min = 5, max = 50, step = 1, page = P, label = "Arrived within (yards)" })
S:Define("guide.arrivalSound", { default = true, page = P, label = "Sound on arrival" })

-- Where the player is, and the pin -------------------------------------------------------------------------------

local function distanceText(yards)
	if BF:Get("guide.metres") then
		local m = yards * 0.9144
		if m >= 1000 then return ("%.1f km"):format(m / 1000) end
		return ("%d m"):format(floor(m + 0.5))
	end
	return ("%d %s"):format(floor(yards + 0.5), L["yd"])
end

local function shortestTurn(a, b) -- from a to b, in -pi..pi
	local d = (b - a) % TWO_PI
	if d > pi then d = d - TWO_PI end
	return d
end

-- The arrow -------------------------------------------------------------------------------------------------------

local GOLD = { 1, 0.82, 0 }
local PARCHMENT = { 0.93, 0.84, 0.62 }
local ARRIVED = { 0.55, 0.85, 0.45 }

local arrow = CreateFrame("Frame", "BookFinderArrow", UIParent)
arrow:SetSize(56, 76)
arrow:SetFrameStrata("MEDIUM")
arrow:SetClampedToScreen(true)
arrow:Hide()

arrow.Pointer = arrow:CreateTexture(nil, "ARTWORK")
arrow.Pointer:SetSize(42, 42)
arrow.Pointer:SetPoint("TOP")

arrow.Goal = arrow:CreateTexture(nil, "ARTWORK")
arrow.Goal:SetSize(30, 38)
arrow.Goal:SetPoint("TOP", 0, -2)
arrow.Goal:Hide()

arrow.Distance = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
arrow.Distance:SetPoint("TOP", arrow.Pointer, "BOTTOM", 0, -1)

arrow.Title = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrow.Title:SetPoint("TOP", arrow.Distance, "BOTTOM", 0, -2)
arrow.Title:SetWidth(220)

arrow.Lines = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
arrow.Lines:SetPoint("TOP", arrow.Title, "BOTTOM", 0, -2)
arrow.Lines:SetWidth(240)
arrow.Lines:SetJustifyH("CENTER")

local function pointerArt()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Navigation-Tracked-Arrow") then
		arrow.Pointer:SetAtlas("Navigation-Tracked-Arrow")
	else
		arrow.Pointer:SetTexture("Interface\\Minimap\\MinimapArrow")
	end
	Icons:Apply(arrow.Goal, "waypoint")
end

-- The compass ----------------------------------------------------------------------------------------------------

local FOV = pi -- the strip spans half a turn: 90 degrees either side of where the player faces
local TICK_STEP = pi / 12 -- 15 degrees
local FADE_PIXELS = 70

local compass = CreateFrame("Frame", "BookFinderCompass", UIParent)
compass:SetSize(420, 34)
compass:SetFrameStrata("MEDIUM")
compass:SetClampedToScreen(true)
compass:Hide()

compass.Band = compass:CreateTexture(nil, "BACKGROUND")
compass.Band:SetAllPoints()
compass.Band:SetColorTexture(0, 0, 0, 0.35)

compass.Center = compass:CreateTexture(nil, "ARTWORK")
compass.Center:SetColorTexture(1, 1, 1, 0.9)
compass.Center:SetSize(2, 10)
compass.Center:SetPoint("TOP", 0, 0)

compass.ticks, compass.letters = {}, {}
local LETTERS = { [0] = "N", [6] = "W", [12] = "S", [18] = "E", [3] = "NW", [9] = "SW", [15] = "SE", [21] = "NE" }
for i = 0, 23 do
	local t = compass:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(1, 1, 1, 1)
	local major = i % 6 == 0
	t:SetSize(major and 2 or 1, major and 10 or 6)
	t.angle = i * TICK_STEP -- counter-clockwise from north, like the facing
	compass.ticks[#compass.ticks + 1] = t
	if LETTERS[i] then
		local f = compass:CreateFontString(nil, "OVERLAY", major and "GameFontNormal" or "GameFontNormalSmall")
		f:SetText(L[LETTERS[i]])
		f.angle = t.angle
		f.major = major
		compass.letters[#compass.letters + 1] = f
	end
end

compass.Goal = compass:CreateTexture(nil, "OVERLAY")
compass.Goal:SetSize(16, 20)
compass.Distance = compass:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

local function stripX(angleFromFacing, width)
	-- Left of centre is counter-clockwise (positive), so it goes to negative x.
	return -angleFromFacing / (FOV / 2) * (width / 2)
end

local function fade(x, width)
	local edge = width / 2 - abs(x)
	if edge <= 0 then return 0 end
	return math.min(1, edge / FADE_PIXELS)
end

-- Following ------------------------------------------------------------------------------------------------------

local state = {
	angle = nil,      -- the arrow's drawn bearing (relative), easing toward the true one
	arrived = false,  -- in the pin's area: the gold pin shows
	arrivedAt = nil,  -- where the player arrived (the pin, kept after the game's pin is cleared)
	moving = false,   -- the move mode (settings): shown without a pin, taking the mouse
}

local function objectiveLines(waypoint)
	local lines = {}
	if waypoint and waypoint.quest and BF.Log:Has(waypoint.quest) then
		for _, o in ipairs(BF.Objectives:For(waypoint.quest)) do
			if not o.finished and o.text and o.text ~= "" and o.kind ~= "extra" then lines[#lines + 1] = o.text end
			if #lines >= 4 then break end
		end
	end
	return table.concat(lines, "\n")
end

local function colourCompass(c, alpha)
	for _, t in ipairs(compass.ticks) do t:SetVertexColor(c[1], c[2], c[3]) end
	for _, f in ipairs(compass.letters) do
		if f.major then f:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else f:SetTextColor(c[1], c[2], c[3]) end
	end
	compass:SetAlpha(alpha)
end

local function hideAll()
	if not state.moving then
		arrow:Hide()
		compass:Hide()
	end
end

local function update(elapsed)
	local waypoint = state.arrivedAt or BF.Waypoint:Get()
	if not waypoint then
		state.arrived, state.angle = false, nil
		return hideAll()
	end
	local yards, bearing = Zones:DistanceTo(waypoint.map, waypoint.x, waypoint.y)
	if not yards then return hideAll() end -- an instance, or the pin is in another world
	local facing = GetPlayerFacing()
	if not facing then return hideAll() end
	-- Facing can be secret in some situations on WoW: Forever: then nothing is drawn.
	if issecretvalue and issecretvalue(facing) then return hideAll() end

	local arrival = BF:Get("guide.arrival")
	if not state.arrived and yards <= arrival then
		state.arrived = true
		state.arrivedAt = waypoint
		if BF:Get("guide.arrivalSound") then PlaySound(SOUNDKIT.MAP_PING or 3175, "Master") end
		BF.Waypoint:Clear() -- the game's pin is done with: the gold pin stays until the player walks off
	elseif state.arrived and yards > arrival * 2 then
		state.arrived, state.arrivedAt = false, nil
		return hideAll()
	end

	local relative = shortestTurn(facing, bearing) -- positive: the pin is to the left (counter-clockwise)
	if state.angle == nil then state.angle = relative end
	state.angle = state.angle + shortestTurn(state.angle, relative) * (1 - exp(-(elapsed or 0.05) * 10))
	local behind = abs(relative) > FOV / 2

	-- The arrow
	if BF:Get("guide.arrow") then
		arrow:SetScale(BF:Get("guide.arrowScale"))
		if state.arrived then
			arrow.Pointer:Hide()
			arrow.Goal:Show()
			arrow.Distance:SetText("")
			arrow.Title:SetText(waypoint.title or "")
			arrow.Lines:SetText(objectiveLines(waypoint))
		else
			arrow.Goal:Hide()
			arrow.Pointer:Show()
			arrow.Pointer:SetRotation(state.angle)
			arrow.Distance:SetText(distanceText(yards))
			arrow.Title:SetText(waypoint.title or "")
			arrow.Lines:SetText("")
		end
		arrow:SetAlpha(behind and not state.arrived and 0.55 or 1)
		arrow:Show()
	else
		arrow:Hide()
	end

	-- The compass
	if BF:Get("guide.compass") then
		local width = BF:Get("guide.compassWidth")
		compass:SetWidth(width)
		compass:SetScale(BF:Get("guide.compassScale"))
		compass.Band:SetShown(BF:Get("guide.compassBand"))
		for _, t in ipairs(compass.ticks) do
			local x = stripX(shortestTurn(facing, t.angle), width)
			local a = fade(x, width)
			t:SetShown(a > 0)
			t:ClearAllPoints()
			t:SetPoint("TOP", compass, "TOP", x, -2)
			t:SetAlpha(a)
		end
		for _, f in ipairs(compass.letters) do
			local x = stripX(shortestTurn(facing, f.angle), width)
			local a = fade(x, width)
			f:SetShown(a > 0)
			f:ClearAllPoints()
			f:SetPoint("TOP", compass, "TOP", x, -13)
			f:SetAlpha(a)
		end
		local gx = stripX(state.angle, width)
		local edge = width / 2 - 10
		if gx > edge then gx = edge elseif gx < -edge then gx = -edge end
		Icons:Apply(compass.Goal, "waypoint")
		compass.Goal:ClearAllPoints()
		compass.Goal:SetPoint("BOTTOM", compass, "TOP", gx, -14)
		compass.Distance:ClearAllPoints()
		compass.Distance:SetPoint("TOP", compass.Goal, "BOTTOM", 0, -16)
		compass.Distance:SetText(state.arrived and "" or distanceText(yards))
		colourCompass(state.arrived and ARRIVED or PARCHMENT, behind and not state.arrived and 0.55 or 1)
		compass.Goal:SetAlpha(behind and 0.6 or 1)
		compass:Show()
	else
		compass:Hide()
	end
end

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	since = since + elapsed
	-- Every frame while there is a pin (the arrow eases); otherwise a slow look for one.
	if not (arrow:IsShown() or compass:IsShown()) and since < 0.25 then return end
	local dt = since
	since = 0
	update(dt)
end)

BF:Listen("BF_WAYPOINT_CHANGED", function(_, waypoint)
	if waypoint then state.arrived, state.arrivedAt, state.angle = false, nil, nil end
	update(0)
end)

-- Placing them (Map > Guide: "Move the arrow and the compass") ---------------------------------------------------

local function savedPlace(frame, key, default)
	local place = BF:AccountState("guide")[key]
	frame:ClearAllPoints()
	if place then
		frame:SetPoint(place[1], UIParent, place[3], place[4], place[5])
	else
		frame:SetPoint(unpack(default))
	end
end

local function savePlace(frame, key)
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	BF:AccountState("guide")[key] = { point, "UIParent", relativePoint, floor(x + 0.5), floor(y + 0.5) }
end

local function makeMovable(frame, key)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if state.moving then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePlace(self, key)
	end)
	-- The arrow keys move it by a pixel while the pointer rests on it.
	frame:SetScript("OnKeyDown", function(self, keyName)
		if not state.moving or not self:IsMouseOver() then
			self:SetPropagateKeyboardInput(true)
			return
		end
		local dx, dy = 0, 0
		if keyName == "LEFT" then dx = -1 elseif keyName == "RIGHT" then dx = 1
		elseif keyName == "UP" then dy = 1 elseif keyName == "DOWN" then dy = -1 end
		if dx == 0 and dy == 0 then
			self:SetPropagateKeyboardInput(true)
			return
		end
		self:SetPropagateKeyboardInput(false)
		local point, rel, relativePoint, x, y = self:GetPoint(1)
		self:ClearAllPoints()
		self:SetPoint(point, rel, relativePoint, x + dx, y + dy)
		savePlace(self, key)
	end)
end

--- Move mode: both shown (without a pin), taking the mouse; again to finish.
function Guide:ToggleMoving()
	state.moving = not state.moving
	for _, f in ipairs({ arrow, compass }) do
		f:EnableMouse(state.moving)
		f:EnableKeyboard(state.moving)
		if state.moving then f:Show() end
	end
	if state.moving then
		arrow.Pointer:Show()
		arrow.Pointer:SetRotation(0)
		arrow.Distance:SetText(L["Drag to move"])
		compass.Band:Show()
		BF:Print(L["Drag the arrow and the compass where you like (the arrow keys move them by a pixel). Again to finish."])
	else
		update(0)
	end
end

function Guide:ResetPlaces()
	BF:AccountState("guide").arrow, BF:AccountState("guide").compass = nil, nil
	savedPlace(arrow, "arrow", { "TOP", UIParent, "TOP", 0, -96 })
	savedPlace(compass, "compass", { "TOP", UIParent, "TOP", 0, -24 })
end

BF:At("login", function()
	pointerArt()
	makeMovable(arrow, "arrow")
	makeMovable(compass, "compass")
	savedPlace(arrow, "arrow", { "TOP", UIParent, "TOP", 0, -96 })
	savedPlace(compass, "compass", { "TOP", UIParent, "TOP", 0, -24 })
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key:find("^guide%.") then update(0) end end)
end)
