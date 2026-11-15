-- The panel's actions (its tiles, and their stars' buttons on the map): Find me, Drop a pin, Quest log; and the
-- "Find a place" search (zones, cities, dungeons and raids, flight masters).

local _, BF = ...
local L = BF.L

local Actions = {}
BF.MapActions = Actions

local function openMap(map)
	if not WorldMapFrame:IsShown() then
		if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
	end
	if map then WorldMapFrame:SetMapID(map) end
end

--- The map opens on the player's own map.
function Actions:FindMe()
	openMap(C_Map.GetBestMapForUnit("player"))
end

function Actions:QuestLog()
	if ToggleQuestLog then ToggleQuestLog() else openMap(nil) end
end

-- Drop a pin: the next click on the map puts the map pin there (right-click stops).
local catcher, dropping
function Actions:IsDropping() return dropping == true end

function Actions:DropPin()
	openMap(nil)
	local canvas = WorldMapFrame.ScrollContainer or WorldMapFrame
	if not catcher then
		catcher = CreateFrame("Button", nil, canvas)
		catcher:SetAllPoints(canvas)
		catcher:SetFrameStrata("DIALOG")
		catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		catcher:SetScript("OnClick", function(_, button)
			dropping = false
			catcher:Hide()
			if button == "LeftButton" and canvas.GetNormalizedCursorPosition then
				local x, y = canvas:GetNormalizedCursorPosition()
				local map = WorldMapFrame:GetMapID()
				if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
					BF.Waypoint:Set(map, x, y, L["Map pin"], BF.Zones:MapName(map))
				end
			end
			if BF.Panel then BF.Panel:Refresh() end
		end)
		catcher:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine(L["Click the map to drop a pin"], 1, 0.82, 0)
			GameTooltip:AddLine(L["Right-click: stop"], 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		catcher:SetScript("OnLeave", function() GameTooltip:Hide() end)
		WorldMapFrame:HookScript("OnHide", function() dropping = false catcher:Hide() end)
	end
	dropping = true
	catcher:Show()
end

-- Find a place ---------------------------------------------------------------------------------------------------

local FindPlace = {}
BF.FindPlace = FindPlace

local index
local function buildIndex()
	index = {}
	local seen = {}
	local function addMap(map)
		if not map or map == 0 or seen[map] then return end
		seen[map] = true
		local info = C_Map.GetMapInfo(map)
		if not info or not info.name or info.name == "" then return end
		local kind = "Zone"
		if info.mapType == Enum.UIMapType.Continent then kind = "Continent"
		elseif info.mapType == Enum.UIMapType.Dungeon then kind = "Dungeon" end
		index[#index + 1] = { name = info.name, kind = kind, map = map }
	end
	for _, map in pairs(BF.Data.areaToUiMap) do addMap(map) end
	for map in pairs(BF.Data.uiMapToArea) do addMap(map) end
	-- Dungeons and raids by their entrance.
	for area, d in pairs(BF.Data.dungeons) do
		local e = d[4] and d[4][1]
		local map = e and BF.Zones:UiMapForArea(e[1])
		if map then index[#index + 1] = { name = d[1], kind = "Dungeon or raid", map = map, x = e[2] / 100, y = e[3] / 100 } end
	end
	-- Flight masters friendly to the player.
	local flag = BF.Data.npcFlags.FLIGHT_MASTER
	for id in BF:AllIDs("npcs") do
		local n = BF:Npc(id)
		local flags = n and n[BF.N.flags]
		if flags and flags % (flag * 2) >= flag and BF.Player:FriendlyTo(n[BF.N.friendlyTo]) then
			BF.Zones:EachSpawn(n[BF.N.spawns], function(map, x, y, inside)
				if not inside then
					index[#index + 1] = { name = n[BF.N.name], kind = "Flight master", map = map, x = x, y = y,
						detail = BF.Zones:MapName(map) }
				end
			end)
		end
	end
	table.sort(index, function(a, b) return a.name < b.name end)
end

--- Shows what matches under the search box (by kind), up to a screenful; a click goes there.
function FindPlace:Show(box, text)
	text = (text or ""):lower()
	if #text < 2 then
		BF.Dropdown:Close()
		return
	end
	if not index then buildIndex() end
	local byKind, order = {}, { "Continent", "Zone", "Dungeon or raid", "Dungeon", "Flight master" }
	local count = 0
	for _, e in ipairs(index) do
		if e.name:lower():find(text, 1, true) then
			byKind[e.kind] = byKind[e.kind] or {}
			table.insert(byKind[e.kind], e)
			count = count + 1
			if count >= 40 then break end
		end
	end
	local items = {}
	for _, kind in ipairs(order) do
		if byKind[kind] then
			items[#items + 1] = { text = L[kind], title = true }
			for _, e in ipairs(byKind[kind]) do
				items[#items + 1] = { text = e.detail and (e.name .. "  |cff998866" .. e.detail .. "|r") or e.name, onClick = function()
					openMap(e.map)
					if e.x then BF.Waypoint:Set(e.map, e.x, e.y, e.name, e.detail) end
				end }
			end
		end
	end
	if #items == 0 then items[1] = { text = L["Nothing found"], title = true } end
	if BF.Dropdown:IsOpen() then BF.Dropdown:Close() end
	BF.Dropdown:Show(1, box, items)
end

-- Ctrl-click on the world map drops the map pin there (and the arrow and compass take you to it). A setting turns it off.
BF.Settings:Define("map.ctrlClickPin", { default = true, page = "Map/More", label = "Ctrl-click drops a pin" })

BF:At("login", function()
	local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer
	if not canvas then return end
	canvas:HookScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or not IsControlKeyDown() or not BF:Get("map.ctrlClickPin") then return end
		-- With OpenMap the map, its own Ctrl-click pin is the one (it sets the game's map pin, which the arrow follows).
		if BF.OpenMap and BF.OpenMap:Present() then return end
		if not self.GetNormalizedCursorPosition then return end
		local x, y = self:GetNormalizedCursorPosition()
		local map = WorldMapFrame:GetMapID()
		if map and x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
			BF.Waypoint:Set(map, x, y, L["Map pin"], BF.Zones:MapName(map))
		end
	end)
end, 81)
