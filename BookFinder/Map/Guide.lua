-- The arrow and the compass: they guide the player to the map pin (docs/study/arrow-and-compass.md), the way 2.0's
-- did. No lines are drawn on any map.
--
-- The arrow, under the top of the screen: the gold map pin with the game's tracking arrow going round it to point the
-- way (easing, not snapping), the distance and the pin's title under it. While the game draws its own marker for the
-- pin in the world, that leads and the arrow steps aside. Within the arrival distance the arrow becomes the pin with
-- what to do there; the game's map pin is then taken away, and the pin stays until the player walks off.
-- The compass: a thin ribbon of parchment ticks and N, E, S, W across the top of the screen, no panel, fading out at
-- both ends, the pin on it with its distance. With the pin well behind the player both dim; on arrival the ribbon turns
-- quietly green. In instances (no position) nothing is drawn. Both can be moved (drag, or the arrow keys) and sized.

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
S:Define("guide.compassWidth", { default = 360, min = 200, max = 900, step = 10, page = P, label = "Compass width" })
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
--
-- The game's own look for a tracked place off to one side: the gold map pin, with the game's tracking arrow going
-- round it on a circle to point the way. When the game draws its own marker for the pin in the world (its navigation
-- marker, on with "showInGameNavigation"), that leads and this arrow steps aside; the compass stays.

local RADIUS = 36          -- the arrow's circle round the pin, as the game's marker has it
local EASE = 18            -- how quickly the drawn bearing catches up (frame-rate independent)
local BEHIND_FROM, BEHIND_UNTIL = math.rad(100), math.rad(80)   -- dims past 100 degrees, back under 80
local BEHIND_ALPHA = 0.45

local TICK = { 0.72, 0.67, 0.55 }
local TICK_ARRIVED = { 0.6, 0.76, 0.58 }
local CENTER = { 1, 0.82, 0, 0.85 }
local CENTER_ARRIVED = { 0.62, 0.9, 0.55, 0.85 }

local function hasAtlas(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil end

local function pinArt(texture, size)
	if hasAtlas("Waypoint-MapPin-Tracked") then
		texture:SetAtlas("Waypoint-MapPin-Tracked")
	else
		Icons:Apply(texture, "waypoint")
	end
	texture:SetSize(size, size)
end

local arrow = CreateFrame("Frame", "BookFinderArrow", UIParent)
arrow:SetSize(100, 100)
arrow:SetFrameStrata("BACKGROUND")
arrow:SetClampedToScreen(true)
arrow:Hide()

arrow.Pin = arrow:CreateTexture(nil, "ARTWORK")
arrow.Pin:SetPoint("CENTER")

arrow.Pointer = arrow:CreateTexture(nil, "OVERLAY")

arrow.Distance = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arrow.Distance:SetPoint("TOP", arrow.Pin, "BOTTOM", 0, -8)

arrow.Title = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arrow.Title:SetPoint("TOP", arrow.Distance, "BOTTOM", 0, -4)
arrow.Title:SetWidth(240)
arrow.Title:SetMaxLines(2)

arrow.Lines = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
arrow.Lines:SetPoint("TOP", arrow.Title, "BOTTOM", 0, -4)
arrow.Lines:SetWidth(240)
arrow.Lines:SetJustifyH("CENTER")
arrow.Lines:SetMaxLines(3)

local function drawPointer(angle)
	arrow.Pointer:SetRotation(angle)
	arrow.Pointer:ClearAllPoints()
	arrow.Pointer:SetPoint("CENTER", arrow.Pin, "CENTER", -math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
end

local function pointerArt()
	if hasAtlas("Navigation-Tracked-Arrow") then
		arrow.Pointer:SetAtlas("Navigation-Tracked-Arrow", true)
	else
		arrow.Pointer:SetTexture("Interface\\Minimap\\MinimapArrow")
		arrow.Pointer:SetSize(32, 32)
	end
	pinArt(arrow.Pin, 36)
	drawPointer(0)
end

--- Whether the game draws its own marker for our pin in the world (then it leads and the arrow steps aside).
local function gameMarkerShown()
	if not (C_Navigation and C_Navigation.GetFrame and C_Navigation.GetFrame()) then return false end
	if not (GetCVarBool and GetCVarBool("showInGameNavigation")) then return false end
	return C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint() or false
end

-- The compass ----------------------------------------------------------------------------------------------------
--
-- A thin ribbon of parchment ticks with N, E, S and W, no panel: half a turn across its width, east to the right,
-- the ticks fading away towards both ends so it floats in the world. Straight ahead is a small gold mark; the pin
-- is the gold map pin with its distance under it.

local FOV = pi
local FADE_PIXELS = 80
local HEIGHT = 60

local compass = CreateFrame("Frame", "BookFinderCompass", UIParent)
compass:SetSize(360, HEIGHT)
compass:SetFrameStrata("LOW")
compass:SetClampedToScreen(true)
compass:Hide()

compass.Band = compass:CreateTexture(nil, "BACKGROUND")
compass.Band:SetAllPoints()
compass.Band:SetColorTexture(0, 0, 0, 0.35)

compass.Center = compass:CreateTexture(nil, "OVERLAY")
compass.Center:SetSize(1, 6)
compass.Center:SetPoint("TOP", compass, "TOP", 0, -3)

compass.ticks = {}
local DIRECTIONS = { [0] = "N", [6] = "W", [12] = "S", [18] = "E" }
for i = 0, 23 do
	local t = compass:CreateTexture(nil, "ARTWORK")
	t.major = i % 6 == 0
	t:SetColorTexture(1, 1, 1, 1)
	t:SetSize(1, t.major and 5 or 3)
	t.angle = i * TWO_PI / 24 -- counter-clockwise from north, like the facing
	if DIRECTIONS[i] then
		t.label = compass:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t.label:SetText(L[DIRECTIONS[i]])
		t.label:SetPoint("TOP", t, "BOTTOM", 0, -1)
	end
	compass.ticks[#compass.ticks + 1] = t
end

compass.Goal = compass:CreateTexture(nil, "OVERLAY")
compass.Distance = compass:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
compass.Distance:SetPoint("TOP", compass.Goal, "BOTTOM", 0, -2)

local function stripX(angleFromFacing, width)
	-- Left of centre is counter-clockwise (positive), so it goes to negative x.
	return -angleFromFacing / (FOV / 2) * (width / 2)
end

-- A smooth ramp at both ends instead of a cut: the ribbon has no edges of its own.
local function fade(x, width)
	local edge = math.max(0, math.min(1, (width / 2 - abs(x)) / FADE_PIXELS))
	return edge * edge
end

-- Following ------------------------------------------------------------------------------------------------------

local state = {
	angle = nil,      -- the drawn bearing (relative to facing), easing toward the true one
	behind = false,   -- the pin behind the player (with some give, so it doesn't flicker at the edge)
	arrived = false,  -- in the pin's area: the gold pin shows with what to do there
	arrivedAt = nil,  -- where the player arrived (the pin, kept after the game's pin is cleared)
	moving = false,   -- the move mode (settings): shown without a pin, taking the mouse
}

local function objectiveLines(waypoint)
	local lines = {}
	if waypoint and waypoint.quest and BF.Log:Has(waypoint.quest) then
		for _, o in ipairs(BF.Objectives:For(waypoint.quest)) do
			if not o.finished and o.text and o.text ~= "" and o.kind ~= "extra" then lines[#lines + 1] = o.text end
			if #lines >= 3 then break end
		end
	end
	return table.concat(lines, "\n")
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
		state.arrived, state.angle, state.behind = false, nil, false
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
	local delta = shortestTurn(state.angle, relative)
	state.angle = (state.angle + delta * (1 - exp(-EASE * (elapsed or 0)))) % TWO_PI
	if state.angle > pi then state.angle = state.angle - TWO_PI end
	if state.behind then state.behind = abs(relative) > BEHIND_UNTIL else state.behind = abs(relative) > BEHIND_FROM end
	local dim = state.behind and not state.arrived and BEHIND_ALPHA or 1

	-- The arrow (stepping aside while the game's own marker leads)
	if BF:Get("guide.arrow") and (state.arrived or not gameMarkerShown()) then
		arrow:SetScale(BF:Get("guide.arrowScale"))
		arrow.Pin:Show()
		if state.arrived then
			arrow.Pointer:Hide()
			arrow.Distance:SetText(waypoint.title or "")
			arrow.Title:SetText("")
			arrow.Lines:SetText(objectiveLines(waypoint))
		else
			arrow.Pointer:Show()
			drawPointer(state.angle)
			arrow.Distance:SetText(distanceText(yards))
			arrow.Title:SetText(waypoint.title or "")
			arrow.Lines:SetText(objectiveLines(waypoint))
		end
		arrow:SetAlpha(dim)
		arrow:Show()
	elseif not state.moving then
		arrow:Hide()
	end

	-- The compass
	if BF:Get("guide.compass") then
		local width = BF:Get("guide.compassWidth")
		compass:SetWidth(width)
		compass:SetScale(BF:Get("guide.compassScale"))
		compass.Band:SetShown(BF:Get("guide.compassBand") or state.moving)
		local tc = state.arrived and TICK_ARRIVED or TICK
		for _, t in ipairs(compass.ticks) do
			local x = stripX(shortestTurn(facing, t.angle), width)
			local a = fade(x, width) * (t.major and 0.85 or 0.5)
			t:SetShown(a > 0)
			t:ClearAllPoints()
			t:SetPoint("TOP", compass, "TOP", x, -6)
			t:SetVertexColor(tc[1], tc[2], tc[3], 1)
			t:SetAlpha(a)
			if t.label then
				t.label:SetShown(a > 0)
				t.label:SetAlpha(a)
			end
		end
		local cc = state.arrived and CENTER_ARRIVED or CENTER
		compass.Center:SetColorTexture(cc[1], cc[2], cc[3], cc[4])
		local gx = stripX(state.angle, width)
		local edge = width / 2
		if gx > edge then gx = edge elseif gx < -edge then gx = -edge end
		pinArt(compass.Goal, 18)
		compass.Goal:ClearAllPoints()
		compass.Goal:SetPoint("CENTER", compass, "CENTER", gx, -6)
		compass.Goal:SetAlpha(dim)
		compass.Distance:SetText(state.arrived and "" or distanceText(yards))
		compass.Distance:SetAlpha(dim)
		compass:Show()
	elseif not state.moving then
		compass:Hide()
	end
end

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	since = since + elapsed
	-- Every frame while something shows (it eases as you turn); otherwise a look for a pin a few times a second.
	if not (arrow:IsShown() or compass:IsShown()) and since < 0.1 then return end
	local dt = since
	since = 0
	update(dt)
end)

BF:Listen("BF_WAYPOINT_CHANGED", function(_, waypoint)
	if waypoint then state.arrived, state.arrivedAt, state.angle, state.behind = false, nil, nil, false end
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
		arrow.Pin:Show()
		arrow.Pointer:Show()
		drawPointer(0)
		arrow.Distance:SetText(L["Drag to move"])
		compass.Band:Show()
		BF:Print(L["Drag the arrow and the compass where you like (the arrow keys move them by a pixel). Again to finish."])
	else
		update(0)
	end
end

function Guide:ResetPlaces()
	BF:AccountState("guide").arrow, BF:AccountState("guide").compass = nil, nil
	savedPlace(arrow, "arrow", { "TOP", UIParent, "TOP", 0, -120 })
	savedPlace(compass, "compass", { "TOP", UIParent, "TOP", 0, -24 })
end

BF:At("login", function()
	pointerArt()
	makeMovable(arrow, "arrow")
	makeMovable(compass, "compass")
	savedPlace(arrow, "arrow", { "TOP", UIParent, "TOP", 0, -120 })
	savedPlace(compass, "compass", { "TOP", UIParent, "TOP", 0, -24 })
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key:find("^guide%.") then update(0) end end)
end)
