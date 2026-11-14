-- Coordinates: the player's (and the cursor's) on the world map, the player's on the minimap.
--
-- Settings (Quests > Look): coords.map, coords.minimap, coords.precision (decimals, 0 to 2). In the game's own fonts,
-- at the bottom of the map and of the minimap. Nothing shows where the client gives no position (instances).

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

local mapText

local function mapLine()
	local map = WorldMapFrame:GetMapID()
	local parts = {}
	local px, py = playerOn(map)
	if px then parts[#parts + 1] = L["Player"] .. L[": "] .. "|cffffffff" .. Coords:Format(px, py) .. "|r" end
	local scroll = WorldMapFrame.ScrollContainer
	if scroll and scroll.GetNormalizedCursorPosition and scroll:IsMouseOver() then
		local cx, cy = scroll:GetNormalizedCursorPosition()
		if cx and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
			parts[#parts + 1] = L["Cursor"] .. L[": "] .. "|cffffffff" .. Coords:Format(cx, cy) .. "|r"
		end
	end
	return table.concat(parts, "     ")
end
Coords.MapLine = mapLine

local function buildMap()
	local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetAllPoints(parent)
	holder:SetFrameLevel(parent:GetFrameLevel() + 20)
	mapText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	mapText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 8)
	local elapsed = 0
	holder:SetScript("OnUpdate", function(_, e)
		elapsed = elapsed + e
		if elapsed < 0.1 then return end
		elapsed = 0
		mapText:SetText(BF:Get("coords.map") and mapLine() or "")
	end)
end

-- Minimap -------------------------------------------------------------------------------------------------------

local miniText

local function buildMinimap()
	local holder = CreateFrame("Frame", nil, Minimap)
	holder:SetAllPoints(Minimap)
	holder:SetFrameLevel(Minimap:GetFrameLevel() + 6)
	miniText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
