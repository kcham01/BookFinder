-- Coordinates: the player's (and the cursor's) on the world map, the player's on the minimap.
--
-- Settings: coords.map, coords.minimap, coords.precision (decimals, 0 to 2). In the game's own fonts: at the top left of
-- the map window's title bar, and at the bottom of the minimap. Nothing shows where the client gives no position.

local _, BF = ...
local L = BF.L

local Coords = {}
BF.Coords = Coords

--- "48.2, 42.1" for a point in 0..1, with the chosen number of decimals.
function Coords:Format(x, y, precision)
	precision = precision or BF:Get("coords.precision")
	local f = "%." .. precision .. "f"
	return (f .. ", " .. f):format(x * 100, y * 100)
end

local function playerOn(map)
	if not map then return nil end
	local pos = C_Map.GetPlayerMapPosition(map, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return nil end
	return x, y
end

-- World map -----------------------------------------------------------------------------------------------------
--
-- Two lines at the top left of the map window's title bar, beside the portrait: the player's coordinates, and under
-- them the cursor's while it is over the map (decided: the map window's layout, docs/BUILD.md). WoW: Forever's map
-- shows the player's position at its bottom left too ("Player: 67.7, 57.0"); while BookFinder's lines show, that one
-- is hidden, so it is not said twice. With no title bar (another client), the two lines sit at the bottom of the map.

local playerText, cursorText
local gameLine -- the game's own "Player: x, y" font string, once found

local function cursorPart()
	local scroll = WorldMapFrame.ScrollContainer
	if scroll and scroll.GetNormalizedCursorPosition and scroll:IsMouseOver() then
		local cx, cy = scroll:GetNormalizedCursorPosition()
		if cx and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then return Coords:Format(cx, cy) end
	end
end

local function line(label, value)
	return value and ("%s%s|cffffffff%s|r"):format(label, L[": "], value) or ""
end

-- The game's player line: a font string inside the map whose text starts "Player:" (the client's own word for it).
local function findGameLine(frame, depth)
	if depth > 6 or not frame then return nil end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region ~= playerText and region ~= cursorText and region.GetObjectType
				and region:GetObjectType() == "FontString" then
				local text = region:GetText()
				if type(text) == "string" and not (issecretvalue and issecretvalue(text))
					and text:find("^" .. (PLAYER or "Player") .. ":") then
					return region
				end
			end
		end
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do
			local found = findGameLine(child, depth + 1)
			if found then return found end
		end
	end
end

local function showGameLine(on)
	if not gameLine then return end
	if on then gameLine:SetAlpha(1) else gameLine:SetAlpha(0) end
end

local function buildMap()
	local border = rawget(WorldMapFrame, "BorderFrame")
	local inTitle = type(border) == "table" and border.CreateFontString ~= nil
	local parent = inTitle and border or (WorldMapFrame.ScrollContainer or WorldMapFrame)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetAllPoints(parent)
	holder:SetFrameLevel(parent:GetFrameLevel() + 20)
	playerText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	cursorText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	for _, t in ipairs({ playerText, cursorText }) do t:SetJustifyH("LEFT") end
	if inTitle then
		-- beside the portrait (about 60 pixels wide at the window's top left), the two lines in the title bar's height
		playerText:SetPoint("TOPLEFT", holder, "TOPLEFT", 60, -3)
		cursorText:SetPoint("TOPLEFT", playerText, "BOTTOMLEFT", 0, -1)
	else
		cursorText:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 12, 8)
		playerText:SetPoint("BOTTOMLEFT", cursorText, "TOPLEFT", 0, 2)
	end
	Coords.playerText, Coords.cursorText = playerText, cursorText
	local elapsed, sinceSearch = 0, 1
	holder:SetScript("OnUpdate", function(_, e)
		elapsed, sinceSearch = elapsed + e, sinceSearch + e
		if elapsed < 0.1 then return end
		elapsed = 0
		-- Look for the game's line about once a second until it is there (it fills in once the map has a position).
		if not gameLine and sinceSearch >= 1 then
			sinceSearch = 0
			gameLine = findGameLine(WorldMapFrame, 0)
		end
		local on = BF:Get("coords.map")
		showGameLine(not on)
		if not on then
			playerText:SetText("")
			cursorText:SetText("")
			return
		end
		local px, py = playerOn(WorldMapFrame:GetMapID())
		playerText:SetText(line(L["Player"], px and Coords:Format(px, py)))
		cursorText:SetText(line(L["Cursor"], cursorPart()))
	end)
end

-- Minimap -------------------------------------------------------------------------------------------------------

local miniText

local function buildMinimap()
	local holder = CreateFrame("Frame", nil, Minimap)
	holder:SetAllPoints(Minimap)
	holder:SetFrameLevel(Minimap:GetFrameLevel() + 6)
	miniText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	Coords.miniText = miniText
	miniText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 14)
	local elapsed = 0
	holder:SetScript("OnUpdate", function(_, e)
		elapsed = elapsed + e
		if elapsed < 0.2 then return end
		elapsed = 0
		local text = ""
		if BF:Get("coords.minimap") then
			local x, y = playerOn(C_Map.GetBestMapForUnit("player"))
			if x then text = Coords:Format(x, y) end
		end
		miniText:SetText(text)
	end)
end

BF:At("login", function()
	if WorldMapFrame then buildMap() end
	if Minimap then buildMinimap() end
end, 72)
