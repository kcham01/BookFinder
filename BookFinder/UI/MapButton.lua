-- BookFinder's button on the world map: the book in the action bar's frame at the map's lower left. A click opens the
-- panel (every setting, the Journey); right-click opens the map's Show list. Beside it, each starred setting or action
-- of the panel (its stars) is a button of its own, lit while on: a tick box or a tile a click away, on the map.
--
-- With OpenMap the map, this stands where OpenMap's own button stood (Map/OpenMap.lua turns that one off once), so the
-- map has one menu.

local _, BF = ...
local L = BF.L
local W = BF.Widgets

local MapButton = {}
BF.MapButton = MapButton

local SIZE, FAV = 34, 26
local ICON = "Interface\\Icons\\INV_Misc_Book_09"

local button, bar
local favButtons = {}

local function canvas()
	return WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
end

local function lightUp(b, on)
	b.glow:SetShown(on and true or false)
end

local function makeButton(parent, size, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.icon = W:FramedIcon(b, size)
	b.icon.slot:SetPoint("CENTER")
	b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
	b.glow:SetAllPoints(b.icon.slot)
	b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	b.glow:SetBlendMode("ADD")
	b.glow:Hide()
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(b.icon.slot)
	hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	hl:SetBlendMode("ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(0.75, 0.75, 0.75) end)
	b:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(1, 1, 1) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- The favourites: settings (on or off) and actions (lit while running). ------------------------------------------

local function favourites()
	local list = {}
	local stars = BF:AccountState("panel").favourites or {}
	-- Actions first in the tiles' order, then settings in the panel's order.
	for _, a in ipairs(BF.Panel:Actions()) do
		if stars["action:" .. a.id] then list[#list + 1] = { action = a } end
	end
	for _, key in ipairs(BF.Settings:Keys()) do
		if stars[key] then
			local def = BF.Settings:Definition(key)
			if def and type(def.default) == "boolean" then list[#list + 1] = { key = key, icon = BF.Panel:IconOf(key) } end
		end
	end
	return list
end

local function refreshFavourites()
	if not bar then return end
	for _, b in ipairs(favButtons) do b:Hide() end
	local x = 0
	for i, fav in ipairs(favourites()) do
		local b = favButtons[i]
		if not b then
			b = makeButton(bar, FAV, function(self)
				local f = self.fav
				if f.action then BF.safecall(f.action.run) else BF:Toggle(f.key) end
				refreshFavourites()
				if BF.Panel:IsShown() then BF.Panel:Refresh() end
			end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				local f = self.fav
				if f.action then
					GameTooltip:AddLine(L[f.action.label], 1, 0.82, 0)
				else
					local def = BF.Settings:Definition(f.key)
					GameTooltip:AddLine(L[def.label or f.key], 1, 0.82, 0)
					GameTooltip:AddLine(BF:Get(f.key) and L["On"] or L["Off"], 1, 1, 1)
				end
				GameTooltip:AddLine(L["Starred in BookFinder's settings: unstar it there to take it off"], 0.6, 0.6, 0.6, true)
				GameTooltip:Show()
			end)
			favButtons[i] = b
		end
		b.fav = fav
		b:ClearAllPoints()
		b:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + FAV + 4
		if fav.action then
			b.icon:SetTexture(fav.action.icon)
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.icon:SetDesaturated(false)
			lightUp(b, fav.action.lit and fav.action.lit())
		else
			BF.Icons:Set(b.icon, fav.icon or "Interface\\Icons\\INV_Misc_Gear_01")
			local on = BF:Get(fav.key)
			b.icon:SetDesaturated(not on)
			b.icon:SetAlpha(on and 1 or 0.55)
			lightUp(b, on)
		end
		b:Show()
	end
	bar:SetWidth(math.max(1, x))
end
MapButton.Refresh = refreshFavourites

-- The button -------------------------------------------------------------------------------------------------------

local function install()
	if button then return end
	local parent = canvas()
	if not parent then return end
	button = makeButton(parent, SIZE, function(_, mouse)
		if mouse == "RightButton" and BF.ShowMenu and BF.ShowMenu.Open then
			BF.ShowMenu.Open(button)
		else
			BF.Panel:Toggle()
		end
	end)
	button:SetFrameStrata("HIGH")
	button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 10)
	button.icon:SetTexture(ICON)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("BookFinder", 1, 0.82, 0)
		GameTooltip:AddLine(L["Click: settings and the Journey"], 1, 1, 1)
		GameTooltip:AddLine(L["Right-click: what the map shows"], 1, 1, 1)
		GameTooltip:Show()
	end)
	bar = CreateFrame("Frame", nil, button)
	bar:SetSize(1, FAV)
	bar:SetPoint("LEFT", button, "RIGHT", 8, 0)
	refreshFavourites()
end
MapButton.Install = install

BF:At("login", function()
	install()
	BF:Listen("BF_FAVOURITES_CHANGED", refreshFavourites)
	BF:Listen("BF_SETTING_CHANGED", function(_, key)
		local stars = BF:AccountState("panel").favourites
		if stars and stars[key] then refreshFavourites() end
	end)
	if WorldMapFrame then WorldMapFrame:HookScript("OnShow", function() install() refreshFavourites() end) end
end, 82)
