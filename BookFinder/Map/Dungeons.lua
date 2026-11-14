-- Dungeons and raids on the seamless map (OpenMap's dungeon entrances, docs/study/openmap.md "Icons on the map"):
-- each entrance (from the data, BF.Data.dungeons) with its level range under it, coloured for the player's level.
-- Hover: the dungeon and its levels, "Click to open its map". Click: the dungeon's own map in the map window (the game's
-- map, with its floors). Switches in the Show dropdown's Dungeons section: "Dungeons and raids", "Level ranges".

local _, BF = ...
local L = BF.L

local Dungeons = {}
BF.Dungeons = Dungeons

local S = BF.Settings
S:Define("map.dungeons", { default = true, page = "Map/Show", label = "Dungeons and raids" })
S:Define("map.dungeonLevels", { default = true, page = "Map/Show", label = "Level ranges" })

local RAIDS = { [2717] = true, [2159] = true, [2677] = true, [1977] = true, [3429] = true, [3428] = true, [3456] = true }

--- A dungeon's own map and level range: map, low, high (nil when the client has none).
function Dungeons:Levels(area)
	local map = BF.Zones:UiMapForArea(area)
	if not map or not C_Map.GetMapLevels then return map end
	local low, high = C_Map.GetMapLevels(map)
	return map, low, high
end

local function levelText(low, high)
	if not low or low <= 0 then return nil end
	local c = GetQuestDifficultyColor and GetQuestDifficultyColor(low)
	local text = low == high and tostring(low) or (low .. "-" .. (high or low))
	return c and ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, text) or text
end
Dungeons.LevelText = levelText

BF.WorldCanvas:AddLayer("dungeons", function(continent, add)
	if not BF:Get("map.dungeons") then return end
	for area, d in pairs(BF.Data.dungeons) do
		for _, e in ipairs(d[4] or {}) do
			local map = BF.Zones:UiMapForArea(e[1])
			local east, north
			if map then east, north = BF.WorldCanvas:WorldOf(map, e[2] / 100, e[3] / 100) end
			if east then
				local dmap, low, high = Dungeons:Levels(area)
				add(east, north, { kind = RAIDS[area] and "raid" or "dungeon", size = 22, area = area, dungeonMap = dmap,
					label = BF:Get("map.dungeonLevels") and levelText(low, high) or nil,
					onEnter = function(b)
						GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
						GameTooltip:AddLine(d[1], 1, 0.82, 0)
						local lv = levelText(low, high)
						if lv then GameTooltip:AddLine(L["Levels"] .. L[": "] .. lv, 1, 1, 1) end
						if dmap then GameTooltip:AddLine(L["Click to open its map"], 0.6, 0.6, 0.6) end
						GameTooltip:Show()
					end,
					onClick = function(b) if b.dungeonMap then WorldMapFrame:SetMapID(b.dungeonMap) end end })
			end
		end
	end
end)
