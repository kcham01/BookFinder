-- The Profiles page (the Map section's last): which profile this character uses, a new one, copying another's
-- settings in, deleting one, every setting back to its default. Profiles hold every setting of BookFinder
-- (Core/Settings.lua); each character remembers its own.

local _, BF = ...
local L = BF.L

local S = BF.Settings
local Profiles = {}
BF.ProfilesPage = Profiles

StaticPopupDialogs["BOOKFINDER_NEW_PROFILE"] = {
	text = L["Name of the new profile:"],
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
	hasEditBox = true,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox
		Profiles:New(box and box:GetText())
	end,
	EditBoxOnEnterPressed = function(self)
		Profiles:New(self:GetText())
		self:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs["BOOKFINDER_DELETE_PROFILE"] = {
	text = L["Delete the profile \"%s\"?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, name) S:DeleteProfile(name) Profiles:Refresh() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs["BOOKFINDER_RESET_PROFILE"] = {
	text = L["Put every setting of the profile \"%s\" back to its default?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function() S:ResetProfile() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

--- Makes a profile of that name (trimmed; nothing if empty) and switches to it.
function Profiles:New(name)
	name = name and strtrim(name) or ""
	if name == "" then return end
	S:UseProfile(name)
	Profiles:Refresh()
end

local function others()
	local list = {}
	for _, name in ipairs(S:Profiles()) do
		if name ~= S:ProfileName() then list[#list + 1] = name end
	end
	return list
end

-- A row: a label and a button that opens a menu of profile names.
local function menuRow(parent, y, label, buttonText, names, pick)
	local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", 2, -y)
	text:SetText(L[label])
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(200, 22)
	b:SetPoint("TOPLEFT", 240, -y + 4)
	b:SetText(buttonText())
	b:SetScript("OnClick", function(self)
		if not MenuUtil or not MenuUtil.CreateContextMenu then return end
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, name in ipairs(names()) do root:CreateButton(name, function() pick(name) end) end
		end)
	end)
	b.refresh = function() b:SetText(buttonText()) b:SetEnabled(#names() > 0) end
	return b
end

local rows = {}

function Profiles:Refresh()
	for _, r in ipairs(rows) do r.refresh() end
end

function Profiles.Build(content)
	wipe(rows)
	local y = 0
	local heading = BF.Widgets:Heading(content, "Profiles", content:GetWidth())
	heading:SetPoint("TOPLEFT", 0, 0)
	y = y + 34
	rows[#rows + 1] = menuRow(content, y, "This character uses", function() return S:ProfileName() or "" end,
		function() return S:Profiles() end,
		function(name) S:UseProfile(name) Profiles:Refresh() end)
	y = y + 32
	rows[#rows + 1] = menuRow(content, y, "Copy settings from", function() return L["Choose a profile"] end,
		others, function(name) S:CopyProfile(name) end)
	y = y + 32
	rows[#rows + 1] = menuRow(content, y, "Delete a profile", function() return L["Choose a profile"] end,
		function()
			local list = {}
			for _, name in ipairs(others()) do if name ~= "Default" then list[#list + 1] = name end end
			return list
		end,
		function(name) StaticPopup_Show("BOOKFINDER_DELETE_PROFILE", name, nil, name) end)
	y = y + 40
	local new = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	new:SetSize(160, 22)
	new:SetPoint("TOPLEFT", 0, -y)
	new:SetText(L["New profile"])
	new:SetScript("OnClick", function() StaticPopup_Show("BOOKFINDER_NEW_PROFILE") end)
	local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
	reset:SetSize(160, 22)
	reset:SetPoint("LEFT", new, "RIGHT", 12, 0)
	reset:SetText(L["Reset profile"])
	reset:SetScript("OnClick", function() StaticPopup_Show("BOOKFINDER_RESET_PROFILE", S:ProfileName()) end)
	Profiles:Refresh()
	return y + 30
end

BF:Listen("BF_PROFILE_CHANGED", function() Profiles:Refresh() end)

BF:At("login", function()
	BF.Panel:AddPage("map", { key = "profiles", label = "Profiles", build = Profiles.Build })
end, 81)
