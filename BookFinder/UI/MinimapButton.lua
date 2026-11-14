-- The minimap button: one round button on the minimap's edge, the library book on it (docs/DESIGN.md, "One minimap
-- button"). Click: where to go (World Map, Quest Log, Library books, Nearest book, My Journey, Settings), in the one
-- dropdown. Right-click: the settings. Drag: moves it round the minimap (its place is kept). Hover: the books count.
-- Switched on and off on the Map tab's More page ("Minimap button"), as Books on map's "Show the minimap button".
-- Also an entry in the game's AddOns menu (the addon compartment), where the client has one.

local _, BF = ...
local L = BF.L

local Button = {}
BF.MinimapButton = Button

BF.Settings:Define("minimap.button", { default = true, page = "Map/More", group = "Minimap button", label = "Show the minimap button" })

local function state() return BF:AccountState("minimapButton") end

local RADIUS = 80

local function place(b)
	local angle = math.rad(state().angle or 225)
	local x, y = math.cos(angle), math.sin(angle)
	if GetMinimapShape and GetMinimapShape() == "SQUARE" then
		local m = math.max(math.abs(x), math.abs(y))
		x, y = x / m * 0.75, y / m * 0.75
	end
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", x * RADIUS, y * RADIUS)
end

--- The nearest book still missing: the map pin on it.
function Button:NearestBook()
	local best, bestYards, bestPlace
	for _, book in ipairs(BF.Books.list) do
		if not BF.Books:IsDone(book) then
			local p, yards = BF.BooksTab.NearestPlace(book)
			if p and yards and (not bestYards or yards < bestYards) then best, bestYards, bestPlace = book, yards, p end
		end
	end
	if not best then
		BF:Print(L["No book left to find nearby."])
		return
	end
	BF.Waypoint:Set(bestPlace.map, bestPlace.x, bestPlace.y, BF.Books:Name(best), L[best.place or ""])
end

function Button:Items()
	return {
		{ text = "BookFinder", title = true },
		{ text = L["World Map"], func = function() if not WorldMapFrame:IsShown() then ToggleWorldMap() end end },
		{ text = L["Quest Log"], func = function() BF.MapTabs:Select("quests") end },
		{ text = L["Library books"], func = function() BF.MapTabs:Select("books") end },
		{ text = L["Nearest book"], func = function() Button:NearestBook() end },
		{ text = L["My Journey"], func = function() BF.Panel:Show("journey", "myJourney") end },
		{ divider = true },
		{ text = L["Settings"], func = function() BF.Panel:Show() end },
	}
end

local function build()
	local b = CreateFrame("Button", "BookFinderMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b.icon = b:CreateTexture(nil, "BACKGROUND")
	b.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	b.icon:SetSize(20, 20)
	b.icon:SetPoint("CENTER", 0, 1)
	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b.border:SetSize(53, 53)
	b.border:SetPoint("TOPLEFT")
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" then BF.Panel:Toggle() else BF.Dropdown:Toggle(self, Button:Items()) end
	end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			state().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			place(self)
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("BookFinder")
		GameTooltip:AddLine(L["Books: %d/%d"]:format(BF.Books:DoneCount(), BF.Books:Count()), 1, 1, 1)
		GameTooltip:AddLine(L["Click: where to go"], 0.6, 0.6, 0.6)
		GameTooltip:AddLine(L["Right-click: settings"], 0.6, 0.6, 0.6)
		GameTooltip:AddLine(L["Drag: move it round the minimap"], 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	place(b)
	Button.frame = b
	return b
end

BF:At("login", function()
	local b = build()
	b:SetShown(BF:Get("minimap.button"))
	BF:Listen("BF_SETTING_CHANGED", function(_, key, value) if key == "minimap.button" then b:SetShown(value) end end)
	if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
		AddonCompartmentFrame:RegisterAddon({
			text = "BookFinder",
			icon = "Interface\\Icons\\INV_Misc_Book_09",
			notCheckable = true,
			func = function() BF.Panel:Toggle() end,
		})
	end
end, 82)
