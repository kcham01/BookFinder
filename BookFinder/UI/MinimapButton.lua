-- BookFinder's minimap button (Questie's and Books on map's each had one; BookFinder has one for both): the book on the
-- minimap's rim, dragged round it to move. Click: the settings and the Journey; right-click: the Books tab; Shift-click:
-- My Journey. Its tooltip: quests in the log and books collected, with the nearest missing book. Also in the minimap's
-- AddOns list where the client has one.

local _, BF = ...
local L = BF.L

local Button = {}
BF.MinimapButton = Button

BF.Settings:Define("minimap.button", { default = true, page = "OpenMap/More", label = "BookFinder minimap button" })

local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local button

local function state() return BF:AccountState("minimapButton") end

local function place()
	local angle = math.rad(state().angle or 200)
	local r = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function nearestBook()
	local best, bestYards
	for _, b in ipairs(BF.Books.list) do
		if not BF.Books:IsDone(b) then
			for _, p in ipairs(BF.Books:Places(b)) do
				local yards = BF.Zones:DistanceTo(p.map, p.x, p.y)
				if yards and (not bestYards or yards < bestYards) then best, bestYards = b, yards end
			end
		end
	end
	return best, bestYards
end

local function tooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("BookFinder", 1, 0.82, 0)
	GameTooltip:AddDoubleLine(L["Quests"], ("%d / %d"):format(BF.Log:Count(),
		C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 20), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine(L["Library books"], ("%d / %d"):format(BF.Books:DoneCount(), BF.Books:Count()), 1, 1, 1, 1, 1, 1)
	local book, yards = nearestBook()
	if book then
		GameTooltip:AddDoubleLine(L["Nearest book"], ("%s - %d %s"):format(BF.Books:Name(book), math.floor(yards + 0.5), L["yd"]),
			0.7, 0.7, 0.7, 1, 1, 1)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Click: settings and the Journey"], 0.5, 0.5, 0.5)
	GameTooltip:AddLine(L["Right-click: the Books tab"], 0.5, 0.5, 0.5)
	GameTooltip:AddLine(L["Shift-click: My Journey"], 0.5, 0.5, 0.5)
	GameTooltip:AddLine(L["Drag: move it round the minimap"], 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function click(_, mouse)
	if mouse == "RightButton" then
		BF.BooksTab:Open()
	elseif IsShiftKeyDown() then
		BF.Panel:Open("journey", "myJourney")
	else
		BF.Panel:Toggle()
	end
end
Button.Click = click

local function build()
	button = CreateFrame("Button", "BookFinderMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	-- The game's own minimap-button look: a round dark back, the icon, the tracking border.
	local back = button:CreateTexture(nil, "BACKGROUND")
	back:SetSize(20, 20)
	back:SetPoint("TOPLEFT", 7, -5)
	back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon
	if button.CreateMaskTexture then
		local mask = button:CreateMaskTexture()
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(icon)
		icon:AddMaskTexture(mask)
	end
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:SetScript("OnClick", click)
	button:SetScript("OnEnter", tooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnMouseDown", function() icon:SetTexCoord(0.13, 0.87, 0.13, 0.87) end)
	button:SetScript("OnMouseUp", function() icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			state().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			place()
		end)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	place()
end

BF:At("login", function()
	build()
	button:SetShown(BF:Get("minimap.button"))
	BF:Listen("BF_SETTING_CHANGED", function(_, key) if key == "minimap.button" then button:SetShown(BF:Get(key)) end end)
	-- The minimap's AddOns list (the client's compartment), where there is one.
	local compartment = rawget(_G, "AddonCompartmentFrame")
	if compartment and compartment.RegisterAddon then
		pcall(compartment.RegisterAddon, compartment, {
			text = "BookFinder", icon = ICON, notCheckable = true,
			func = function(_, _, _, _, mouse) click(nil, mouse) end,
		})
	end
end, 84)
