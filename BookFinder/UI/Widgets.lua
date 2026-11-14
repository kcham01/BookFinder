-- The panel's building blocks, all from the game's own art (the look the owner chose: OpenMap's panel, docs/NOTES.md 2):
-- the map window's frame kit, rock background, bronze rules and edges, the settings panel's tick boxes, the action
-- bar's icon frame, the raid marker's star. Every atlas is checked before use; each has a classic fallback.

local _, BF = ...

local W = {}
BF.Widgets = W

W.BRONZE = { 0.66, 0.49, 0.28 }
W.LIT = { 1, 0.82, 0.3 }
W.STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local ICON_FRAME = "UI-HUD-ActionBar-IconFrame"

local function hasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
W.HasAtlas = hasAtlas

--- The frame: the map window's own border kit (nine-slice, no portrait) over the game's rock, darkened so small print
--- reads; else the classic dialog's gold border. Returns the title bar's height.
function W:Dress(f)
	local util = NineSliceUtil
	if util and util.GetLayout and util.GetLayout("ButtonFrameTemplateNoPortrait") then
		local ok, nine = pcall(CreateFrame, "Frame", nil, f, "NineSlicePanelTemplate")
		if ok and nine and pcall(util.ApplyLayoutByName, nine, "ButtonFrameTemplateNoPortrait") then
			nine:SetAllPoints()
			local bg = f:CreateTexture(nil, "BACKGROUND")
			bg:SetPoint("TOPLEFT", 6, -21)
			bg:SetPoint("BOTTOMRIGHT", -2, 3)
			bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
			bg:SetHorizTile(true)
			bg:SetVertTile(true)
			local shade = f:CreateTexture(nil, "BACKGROUND", nil, 1)
			shade:SetAllPoints(bg)
			shade:SetColorTexture(0, 0, 0, 0.45)
			return 21
		end
	end
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	return 0
end

--- A thin bronze rule.
function W:Rule(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 0.5)
	t:SetHeight(1)
	return t
end

--- A gold heading with a rule running from its end to the right: "Dungeons ———".
function W:Heading(parent, text, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 20)
	f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.Text:SetPoint("LEFT", 2, 0)
	f.Text:SetText(text)
	local rule = W:Rule(f)
	rule:SetPoint("LEFT", f.Text, "RIGHT", 8, 0)
	rule:SetPoint("RIGHT", -4, 0)
	return f
end

--- A tick box: the game's settings' own (minimal), else the classic one.
function W:CheckBox(parent)
	if not hasAtlas("checkbox-minimal") then
		local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		return cb
	end
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetSize(20, 20)
	local function tex(atlas, layer, blend, alpha)
		local t = cb:CreateTexture(nil, layer)
		t:SetAtlas(atlas)
		t:SetAllPoints()
		if blend then t:SetBlendMode(blend) end
		if alpha then t:SetAlpha(alpha) end
		return t
	end
	cb:SetNormalTexture(tex("checkbox-minimal", "BACKGROUND"))
	cb:SetPushedTexture(tex("checkbox-minimal", "BACKGROUND"))
	cb:SetHighlightTexture(tex("checkbox-minimal", "HIGHLIGHT", "ADD", 0.25))
	cb:SetCheckedTexture(tex("checkmark-minimal", "ARTWORK"))
	if hasAtlas("checkmark-minimal-disabled") then cb:SetDisabledCheckedTexture(tex("checkmark-minimal-disabled", "ARTWORK")) end
	return cb
end

--- An icon in the action bar's frame on a dark slot (size square). Returns the icon texture; icon.slot to place it.
function W:FramedIcon(owner, size)
	local slot = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
	slot:SetSize(size, size)
	slot:SetColorTexture(0, 0, 0, 0.6)
	local icon = owner:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.slot = slot
	local border = owner:CreateTexture(nil, "OVERLAY")
	if hasAtlas(ICON_FRAME) then
		border:SetAtlas(ICON_FRAME)
		border:SetAllPoints(slot)
		if hasAtlas(ICON_FRAME .. "-Mask") and owner.CreateMaskTexture then
			local mask = owner:CreateMaskTexture()
			mask:SetAtlas(ICON_FRAME .. "-Mask")
			mask:SetAllPoints(slot)
			icon:AddMaskTexture(mask)
		end
	else
		border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
		local o = size * 14 / 36
		border:SetPoint("TOPLEFT", slot, "TOPLEFT", -o, o)
		border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", o, -o)
	end
	icon.border = border
	return icon
end

--- An action tile: a dark face with a bronze edge (gold while lit), its icon at the top, its label under it.
function W:Tile(parent, w, h, iconSize)
	local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(w, h)
	if b.SetBackdrop then
		b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		b:SetBackdropColor(0.08, 0.06, 0.04, 0.92)
		b:SetBackdropBorderColor(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 1)
	end
	b.icon = W:FramedIcon(b, iconSize)
	b.icon.slot:SetPoint("TOP", 0, -8)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", -1, 1)
	hl:SetColorTexture(1, 0.8, 0.45, 0.14)
	b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
	b.glow:SetAllPoints(b.icon.slot)
	b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	b.glow:SetBlendMode("ADD")
	b.glow:Hide()
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.label:SetPoint("TOP", b.icon.slot, "BOTTOM", 0, -6)
	b:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(0.75, 0.75, 0.75) end)
	b:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(1, 1, 1) end)
	return b
end

--- Lights a tile (gold edge and glow) or not.
function W:SetLit(tile, on)
	local c = on and W.LIT or W.BRONZE
	if tile.SetBackdropBorderColor then tile:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
	tile.glow:SetShown(on and true or false)
end

--- The star at a row's right: lit when the item is a button on the map.
function W:Star(parent)
	local star = CreateFrame("Button", nil, parent)
	star:SetSize(14, 14)
	star.icon = star:CreateTexture(nil, "OVERLAY")
	star.icon:SetAllPoints()
	star.icon:SetTexture(W.STAR)
	function star:SetLit(on)
		self.icon:SetDesaturated(not on)
		self.icon:SetAlpha(on and 1 or 0.35)
	end
	star:SetLit(false)
	return star
end

--- A slider with its label above and value at the right: the game's minimal slider with steppers, else a classic one.
function W:Slider(parent, width, label)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 40)
	f.Label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.Label:SetPoint("TOPLEFT", 2, 0)
	f.Label:SetText(label)
	f.Value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.Value:SetPoint("TOPRIGHT", -2, 0)
	local ok, ms = pcall(CreateFrame, "Frame", nil, f, "MinimalSliderWithSteppersTemplate")
	if ok and ms and ms.Slider then
		ms:SetPoint("TOPLEFT", 0, -14)
		ms:SetPoint("TOPRIGHT", 0, -14)
		ms:SetHeight(20)
		f.slider = ms.Slider
		f.minimal = ms
	else
		local s = CreateFrame("Slider", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
		s:SetOrientation("HORIZONTAL")
		s:SetHeight(15)
		s:SetPoint("TOPLEFT", 4, -16)
		s:SetPoint("TOPRIGHT", -4, -16)
		s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		if s.SetBackdrop then
			s:SetBackdrop({
				bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
				tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 },
			})
		end
		f.slider = s
	end
	return f
end

--- A button showing a choice; clicking opens BookFinder's dropdown of the choices.
function W:ChoiceButton(parent, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	return b
end

--- A scroll area: returns the scroll frame and its content (set the content's height).
function W:Scroll(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(10, 10)
	scroll:SetScrollChild(content)
	return scroll, content
end

--- The game's small search box.
function W:SearchBox(parent, width, hint)
	local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	if box.Instructions then box.Instructions:SetText(hint) end
	return box
end

--- A top tab (the game's minimal tab, else the classic panel button).
function W:TopTab(parent, text)
	local ok, b = pcall(CreateFrame, "Button", nil, parent, "MinimalTabTemplate")
	if ok and b then
		if b.Text then b.Text:SetText(text) end
		if b.SetTabSelected == nil then function b:SetTabSelected() end end
		b:SetSize(math.max(90, (b.Text and b.Text:GetStringWidth() or 60) + 32), 28)
		return b
	end
	b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(100, 22)
	b:SetText(text)
	function b:SetTabSelected(on) if on then self:LockHighlight() else self:UnlockHighlight() end end
	return b
end
