-- The panel's pages that are not lists of settings: Profiles (OpenMap tab) and Rewards (Books tab).

local _, BF = ...
local L = BF.L
local W = BF.Widgets
local Panel = BF.Panel

-- Profiles ---------------------------------------------------------------------------------------------------------
-- As Questie's: the profile in use, a new one by name, copy another's settings into this one, reset it, delete one.

StaticPopupDialogs["BOOKFINDER_DELETE_PROFILE"] = {
	text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(_, name) BF.Settings:DeleteProfile(name) Panel:Open("openmap", "profiles") end,
}
StaticPopupDialogs["BOOKFINDER_RESET_PROFILE"] = {
	text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function() BF.Settings:ResetProfile() end,
}

local function profileMenu(anchor, include, onPick)
	local items = {}
	for _, name in ipairs(BF.Settings:Profiles()) do
		if include(name) then
			items[#items + 1] = { text = name, radio = true,
				checked = function() return BF.Settings:ProfileName() == name end,
				onClick = function() onPick(name) end }
		end
	end
	if #items == 0 then items[1] = { text = L["No other profiles"], title = true } end
	BF.Dropdown:Open(anchor, items)
end

Panel:RegisterPage("openmap", "profiles", function(holder, width)
	local y = 0
	local function heading(text)
		local h = W:Heading(holder, L[text], width)
		h:SetPoint("TOPLEFT", 0, -y)
		y = y + 26
	end
	local function note(text)
		local f = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f:SetPoint("TOPLEFT", 2, -y)
		f:SetWidth(width - 4)
		f:SetJustifyH("LEFT")
		f:SetText(L[text])
		y = y + 20
		return f
	end

	heading("Profile in use")
	note("Each character can use its own settings, or share a profile with others.")
	local currentLabel = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	currentLabel:SetPoint("TOPLEFT", 2, -y)
	local pick = W:ChoiceButton(holder, 220)
	pick:SetPoint("TOPLEFT", 200, -y + 4)
	pick:SetScript("OnClick", function(self)
		profileMenu(self, function() return true end, function(name) BF.Settings:UseProfile(name) end)
	end)
	local reset = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	reset:SetSize(140, 22)
	reset:SetPoint("LEFT", pick, "RIGHT", 10, 0)
	reset:SetText(L["Reset profile"])
	reset:SetScript("OnClick", function()
		StaticPopup_Show("BOOKFINDER_RESET_PROFILE", L["Put every setting of the profile '%s' back to its default?"]:format(BF.Settings:ProfileName()))
	end)
	y = y + 34

	heading("New")
	local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
	box:SetSize(220, 20)
	box:SetAutoFocus(false)
	box:SetPoint("TOPLEFT", 8, -y)
	local create = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	create:SetSize(140, 22)
	create:SetPoint("LEFT", box, "RIGHT", 10, 0)
	create:SetText(L["Create and use"])
	local function make()
		local name = strtrim(box:GetText() or "")
		if name ~= "" then
			BF.Settings:UseProfile(name)
			box:SetText("")
			box:ClearFocus()
		end
	end
	create:SetScript("OnClick", make)
	box:SetScript("OnEnterPressed", make)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	y = y + 34

	heading("Copy from")
	note("Copy another profile's settings into the one in use.")
	local copy = W:ChoiceButton(holder, 220)
	copy:SetPoint("TOPLEFT", 0, -y)
	copy:SetText(L["Choose a profile..."])
	copy:SetScript("OnClick", function(self)
		profileMenu(self, function(n) return n ~= BF.Settings:ProfileName() end, function(name) BF.Settings:CopyProfile(name) end)
	end)
	y = y + 34

	heading("Delete a profile")
	local del = W:ChoiceButton(holder, 220)
	del:SetPoint("TOPLEFT", 0, -y)
	del:SetText(L["Choose a profile..."])
	del:SetScript("OnClick", function(self)
		profileMenu(self, function(n) return n ~= BF.Settings:ProfileName() and n ~= "Default" end, function(name)
			StaticPopup_Show("BOOKFINDER_DELETE_PROFILE", L["Delete the profile '%s'?"]:format(name), nil, name)
		end)
	end)
	y = y + 34

	holder.refreshProfile = function()
		currentLabel:SetText(L["Current profile:"] .. " |cffffffff" .. BF.Settings:ProfileName() .. "|r")
		pick:SetText(BF.Settings:ProfileName())
	end
	holder.refreshProfile()
	BF:Listen("BF_PROFILE_CHANGED", holder.refreshProfile)
	return y
end)

-- Rewards (Books tab) ----------------------------------------------------------------------------------------------
-- The progress bar to 38 with its notches, then each tier: "10 books: Necklace", "4 / 10", its items with their icons
-- and names in their quality's colour; hover shows the item, Shift-click links it, Ctrl-click tries it on.

Panel:RegisterPage("books", "rewards", function(holder, width)
	local Books = BF.Books
	local y = 0
	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.25, 0.55, 1)
	bar:SetSize(width - 20, 14)
	bar:SetPoint("TOPLEFT", 10, -6)
	bar:SetMinMaxValues(0, Books:Count())
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	barBg:SetColorTexture(0, 0, 0, 0.5)
	bar.notches = {}
	for _, r in ipairs(Books.REWARDS) do
		local x = (width - 20) * r.goal / Books:Count()
		local mark = bar:CreateTexture(nil, "OVERLAY")
		mark:SetColorTexture(1, 0.82, 0, 1)
		mark:SetSize(2, 18)
		mark:SetPoint("CENTER", bar, "LEFT", x, 0)
		local n = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		n:SetPoint("TOP", mark, "BOTTOM", 0, -2)
		n:SetText(r.goal)
		bar.notches[#bar.notches + 1] = { text = n, goal = r.goal }
	end
	y = 44

	local tiers = {}
	for _, r in ipairs(Books.REWARDS) do
		local head = W:Heading(holder, L["%d books: %s"]:format(r.goal, L[r.label]:lower()), width)
		head:SetPoint("TOPLEFT", 0, -y)
		head.count = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		head.count:SetPoint("RIGHT", -4, 0)
		tiers[#tiers + 1] = { head = head, goal = r.goal }
		y = y + 24
		for _, itemID in ipairs(r.items) do
			local b = CreateFrame("Button", nil, holder)
			b:SetSize(width, 30)
			b:SetPoint("TOPLEFT", 6, -y)
			b.icon = W:FramedIcon(b, 26)
			b.icon.slot:SetPoint("LEFT", 0, 0)
			b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			b.name:SetPoint("LEFT", b.icon.slot, "RIGHT", 10, 6)
			b.slot = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			b.slot:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
			function b:Paint()
				self.icon:SetTexture(C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or 134400)
				local name, link, quality, _, _, _, subType, _, equipLoc
				if C_Item.GetItemInfo then name, link, quality, _, _, _, subType, _, equipLoc = C_Item.GetItemInfo(itemID) end
				self.link = link
				local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
				self.name:SetText(name or BF:ItemName(itemID) or ("Item " .. itemID))
				if color then self.name:SetTextColor(color.r, color.g, color.b) end
				local slotName = equipLoc and _G[equipLoc]
				self.slot:SetText(table.concat({ slotName or "", subType or "" }, slotName and subType and " - " or ""))
			end
			b:Paint()
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if GameTooltip.SetItemByID then GameTooltip:SetItemByID(itemID) end
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			b:SetScript("OnClick", function(self)
				if IsShiftKeyDown() and self.link and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link)
				elseif IsControlKeyDown() and self.link and DressUpItemLink then DressUpItemLink(self.link) end
			end)
			tiers[#tiers].rows = tiers[#tiers].rows or {}
			table.insert(tiers[#tiers].rows, b)
			y = y + 32
		end
		y = y + 8
	end

	holder.refreshRewards = function()
		local done = Books:DoneCount()
		bar:SetValue(done)
		for _, n in ipairs(bar.notches) do
			if done >= n.goal then n.text:SetTextColor(0.3, 1, 0.3) else n.text:SetTextColor(1, 1, 1) end
		end
		for _, t in ipairs(tiers) do
			local reached = done >= t.goal
			t.head.count:SetText(("%d / %d"):format(math.min(done, t.goal), t.goal))
			t.head.count:SetTextColor(reached and 0.3 or 1, reached and 1 or 1, reached and 0.3 or 1)
			for _, row in ipairs(t.rows or {}) do row:Paint() end
		end
	end
	holder.refreshRewards()
	BF:Listen("BF_BOOKS_CHANGED", holder.refreshRewards)
	BF:On("GET_ITEM_INFO_RECEIVED", function() if holder:IsVisible() then holder.refreshRewards() end end)
	return y
end)
