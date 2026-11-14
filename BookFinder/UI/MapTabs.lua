-- The map window's tabs: a column down the right edge of the map and quest log window, "!" Quests (the game's quest
-- panel, holding BookFinder's quest list) and Books (the library books). The game's Forever map has no such tabs of
-- its own (seen in game, no addons), so BookFinder adds the column; a page other than Quests covers the quest panel.
--
-- BF.MapTabs:Add{ key, label, icon, frame = a frame laid over the quest panel (nil: the game's quest panel itself) }
-- BF.MapTabs:Select(key) opens the map on that tab.

local _, BF = ...
local L = BF.L

local MapTabs = { tabs = {} }
BF.MapTabs = MapTabs

local function state() return BF:CharacterState("mapTabs") end

local function host()
	return QuestMapFrame
end

function MapTabs:Add(spec)
	local parent = WorldMapFrame
	if not parent or not host() then return end
	local tab = BF.Widgets:SideTab(parent, spec.icon, spec.label, function() MapTabs:Select(spec.key) end)
	tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", -2, -60 - #MapTabs.tabs * 48)
	tab.spec = spec
	MapTabs.tabs[#MapTabs.tabs + 1] = tab
	if spec.frame then spec.frame:Hide() end
	MapTabs:Select(state().selected or MapTabs.tabs[1].spec.key, true)
	return tab
end

function MapTabs:Selected()
	return state().selected or (MapTabs.tabs[1] and MapTabs.tabs[1].spec.key)
end

--- Shows a tab's page (and the map, unless quiet: only remembering the choice).
function MapTabs:Select(key, quiet)
	local found = false
	for _, tab in ipairs(MapTabs.tabs) do if tab.spec.key == key then found = true end end
	if not found then return end
	state().selected = key
	-- The map first, so a page shown next is shown on screen (and fills itself in as it shows).
	if not quiet then
		if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
		-- The quest panel is where every page lives: make sure the map shows it.
		if QuestMapFrame and not QuestMapFrame:IsShown() and QuestMapFrame_Show then QuestMapFrame_Show() end
	end
	for _, tab in ipairs(MapTabs.tabs) do
		local on = tab.spec.key == key
		tab:SetChecked(on)
		if tab.spec.frame then
			if on and tab.spec.frame:IsShown() then tab.spec.frame:Hide() end -- shown again below: it refreshes
			tab.spec.frame:SetShown(on)
		end
	end
	BF:Send("BF_MAP_TAB_CHANGED", key)
end

BF:At("login", function()
	MapTabs:Add({ key = "quests", label = "Quests", icon = "Interface\\GossipFrame\\AvailableQuestIcon" })
end, 84)
