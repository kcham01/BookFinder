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
--
-- WoW: Forever's map already shows the player's position at its bottom left ("Player: 67.7, 57.0", seen in game with
-- no addons). BookFinder does not repeat it: it adds "Cursor: x, y" right after the game's line, in the game's font.
-- Where the game's line is not found (another client, another language), BookFinder's line says both, at the bottom.

local mapText
local gameLine -- the game's own "Player: x, y" font string, once found

local function cursorPart()
	local scroll = WorldMapFrame.ScrollContainer
	if scroll and scroll.GetNormalizedCursorPosition and scroll:IsMouseOver() then
		local cx, cy = scroll:GetNormalizedCursorPosition()
		if cx and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
			return L["Cursor"] .. L[": "] .. Coords:Format(cx, cy)
		end
	end
end

local function mapLine()
	local cursor = cursorPart()
	if gameLine then return cursor or "" end
	local parts = {}
	local px, py = playerOn(WorldMapFrame:GetMapID())
	if px then parts[#parts + 1] = L["Player"] .. L[": "] .. Coords:Format(px, py) end
	if cursor then parts[#parts + 1] = cursor end
	return table.concat(parts, "     ")
end
Coords.MapLine = mapLine

-- The game's player line: a font string inside the map whose text starts "Player:" (the client's own word for it).
local function findGameLine(frame, depth)
	if depth > 6 or not frame then return nil end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region ~= mapText and region.GetObjectType and region:GetObjectType() == "FontString" then
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

local function useGameLine(found)
	gameLine = found
	mapText:ClearAllPoints()
	mapText:SetPoint("LEFT", found, "RIGHT", 16, 0)
	if found.GetFontObject and found:GetFontObject() then mapText:SetFontObject(found:GetFontObject()) end
	if found.GetTextColor then mapText:SetTextColor(found:GetTextColor()) end
end

local function buildMap()
	local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetAllPoints(parent)
	holder:SetFrameLevel(parent:GetFrameLevel() + 20)
	mapText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	Coords.mapText = mapText
	mapText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 8)
	local elapsed, sinceSearch = 0, 1
	holder:SetScript("OnUpdate", function(_, e)
		elapsed, sinceSearch = elapsed + e, sinceSearch + e
		if elapsed < 0.1 then return end
		elapsed = 0
		-- Look for the game's line about once a second until it is there (it fills in once the map has a position).
		if not gameLine and sinceSearch >= 1 then
			sinceSearch = 0
			local found = findGameLine(WorldMapFrame, 0)
			if found then useGameLine(found) end
		end
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
