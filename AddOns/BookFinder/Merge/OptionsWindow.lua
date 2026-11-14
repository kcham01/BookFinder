-- BookFinder: its settings window. One window for every setting of the product (Options.lua), opened by the map's
-- BookFinder button, the minimap button's menu, /bookfinder and the game's AddOns settings.
--
-- Drawn only with the game's own art: the dialog box frame and its header, the quest log's highlight, the tooltip's
-- divider, Blizzard's check boxes, sliders, search box and scroll bar, and the dropdown BookFinder uses everywhere
-- (Menu.lua). A list of sections on the left (Map, Look, Quests, Library, More), the selected one's settings on the
-- right in their groups, and a search over all of them.
local _, root = ...
local public = root.public
if not public then return end
local Options = public.Options
if not Options then return end

local W, H = 720, 540
local NAV_W = 170
local ROW = { header = 30, toggle = 26, slider = 34, choice = 30, button = 30 }
local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.6, 0.6, 0.6 }
local DIVIDER = "Interface\\Common\\UI-TooltipDivider-Transparent"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local frame, nav, scroll, child, searchBox, emptyText
local current = "map"
local query = ""
local pools = { header = {}, toggle = {}, slider = {}, choice = {}, button = {} }
local used = {}

local function setIcon(tex, look)
	if not look then tex:Hide() return end
	tex:Show()
	tex:SetTexCoord(0, 1, 0, 1)
	if type(look) == "string" or type(look) == "number" then tex:SetTexture(look) return end
	local atlas = look.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(look.atlas)
	if atlas then tex:SetAtlas(look.atlas) return end
	tex:SetTexture(look.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	if look.icon or (look.texture and tostring(look.texture):find("Interface\\Icons\\", 1, true)) then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

local function safe(fn, ...) if type(fn) ~= "function" then return nil end local ok, v = pcall(fn, ...) if ok then return v end end
local function enabled(e) return not e.enabled or safe(e.enabled) ~= false end

local Refill
local function changed() C_Timer.After(0, function() if frame and frame:IsShown() then Refill() end end) end

local function tooltip(owner, e)
	if not (e.note or e.tip) then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(e.label, GOLD[1], GOLD[2], GOLD[3])
	GameTooltip:AddLine(e.note or e.tip, WHITE[1], WHITE[2], WHITE[3], true)
	GameTooltip:Show()
end

-- Rows ----------------------------------------------------------------------------------------------------------------
local function label(f, x)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	t:SetPoint("LEFT", x, 0)
	t:SetJustifyH("LEFT")
	t:SetWordWrap(false)
	return t
end

local make = {}
function make.header()
	local f = CreateFrame("Frame", nil, child)
	f:SetHeight(ROW.header)
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
	f.text:SetPoint("BOTTOMLEFT", 2, 7)
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetTexture(DIVIDER)
	line:SetHeight(8)
	line:SetPoint("BOTTOMLEFT", 0, -1)
	line:SetPoint("BOTTOMRIGHT", 0, -1)
	function f:Fill(e) self.text:SetText(e.label) end
	return f
end
function make.toggle()
	local f = CreateFrame("Button", nil, child)
	f:SetHeight(ROW.toggle)
	f.check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.check:SetSize(24, 24)
	f.check:SetPoint("LEFT", 2, 0)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(16, 16)
	f.icon:SetPoint("LEFT", f.check, "RIGHT", 4, 0)
	f.text = label(f, 52)
	f.note = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	f.note:SetPoint("LEFT", f.text, "RIGHT", 8, 0)
	f.note:SetPoint("RIGHT", -6, 0)
	f.note:SetJustifyH("LEFT")
	f.note:SetWordWrap(false)
	local hl = f:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(HIGHLIGHT)
	hl:SetBlendMode("ADD")
	hl:SetAllPoints()
	hl:SetAlpha(0.35)
	local function flip()
		local e = f.entry
		if not (e and enabled(e)) then return end
		local on = not safe(e.get)
		safe(e.set, on)
		f.check:SetChecked(safe(e.get) and true or false)
		PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		changed()
	end
	f:SetScript("OnClick", flip)
	f.check:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()) flip() end)
	f:SetScript("OnEnter", function(self) tooltip(self, self.entry) end)
	f:SetScript("OnLeave", GameTooltip_Hide)
	function f:Fill(e)
		self.entry = e
		self.check:SetChecked(safe(e.get) and true or false)
		setIcon(self.icon, e.icon)
		self.text:ClearAllPoints()
		self.text:SetPoint("LEFT", e.icon and 52 or 32, 0)
		self.text:SetText(e.label)
		self.note:SetText(e.note or "")
		local on = enabled(e)
		self:SetAlpha(on and 1 or 0.45)
		self.check:SetEnabled(on)
	end
	return f
end
function make.slider()
	local f = CreateFrame("Frame", nil, child)
	f:SetHeight(ROW.slider)
	f.text = label(f, 32)
	f.value = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.value:SetPoint("RIGHT", -6, 0)
	f.value:SetWidth(44)
	f.value:SetJustifyH("RIGHT")
	local ok, s = pcall(CreateFrame, "Slider", nil, f, "MinimalSliderTemplate")
	if not ok or not s then ok, s = pcall(CreateFrame, "Slider", nil, f, "OptionsSliderTemplate") end
	if not ok or not s then s = CreateFrame("Slider", nil, f) end
	s:SetSize(220, 16)
	s:SetPoint("RIGHT", f.value, "LEFT", -10, 0)
	s:SetOrientation("HORIZONTAL")
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	for _, k in ipairs({ "Low", "High", "Text" }) do if s[k] then s[k]:Hide() end end
	f.slider = s
	local function show(e, v)
		if e.fmt == "percent" then return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
		if (e.step or 1) >= 1 then return tostring(math.floor(v + 0.5)) end
		return ("%.2f"):format(v)
	end
	s:SetScript("OnValueChanged", function(self, v)
		local e = f.entry
		if not e or f.filling then return end
		local step = e.step or 1
		v = math.floor(v / step + 0.5) * step
		f.value:SetText(show(e, v))
		f.pending = v
	end)
	-- (the setting is written when the slider is let go: some parts redraw the whole map for it)
	s:SetScript("OnMouseUp", function()
		local e = f.entry
		if e and f.pending ~= nil then safe(e.set, f.pending) f.pending = nil changed() end
	end)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self) tooltip(self, self.entry) end)
	f:SetScript("OnLeave", GameTooltip_Hide)
	function f:Fill(e)
		self.entry = e
		self.filling = true
		s:SetMinMaxValues(e.min or 0, e.max or 1)
		s:SetValueStep(e.step or 1)
		local v = tonumber(safe(e.get)) or e.min or 0
		s:SetValue(v)
		self.filling = false
		self.value:SetText(show(e, v))
		self.text:SetText(e.label)
		local on = enabled(e)
		s:SetEnabled(on)
		self:SetAlpha(on and 1 or 0.45)
	end
	return f
end
function make.choice()
	local f = CreateFrame("Frame", nil, child)
	f:SetHeight(ROW.choice)
	f.text = label(f, 32)
	f.button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.button:SetSize(200, 22)
	f.button:SetPoint("RIGHT", -6, 0)
	f.arrow = f.button:CreateTexture(nil, "OVERLAY")
	f.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	f.arrow:SetSize(12, 12)
	f.arrow:SetPoint("RIGHT", -8, 0)
	f.arrow:SetRotation(-math.pi / 2)
	f.button:SetScript("OnClick", function(self)
		local e = f.entry
		if not (e and enabled(e)) then return end
		public.ContextMenu(self, function(_, menu)
			menu:CreateTitle(e.label)
			for _, c in ipairs(safe(e.choices) or {}) do
				menu:CreateCheckbox(tostring(c.label), function() return safe(e.get) == c.value end,
					function() safe(e.set, c.value) changed() end)
			end
		end)
	end)
	f.button:SetScript("OnEnter", function(self) tooltip(self, f.entry) end)
	f.button:SetScript("OnLeave", GameTooltip_Hide)
	function f:Fill(e)
		self.entry = e
		self.text:SetText(e.label)
		local now, shown = safe(e.get), nil
		for _, c in ipairs(safe(e.choices) or {}) do if c.value == now then shown = c.label end end
		self.button:SetText(shown and tostring(shown) or "")
		local on = enabled(e)
		self.button:SetEnabled(on)
		self:SetAlpha(on and 1 or 0.45)
	end
	return f
end
function make.button()
	local f = CreateFrame("Frame", nil, child)
	f:SetHeight(ROW.button)
	f.text = label(f, 32)
	f.button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.button:SetSize(120, 22)
	f.button:SetPoint("RIGHT", -6, 0)
	f.button:SetScript("OnClick", function()
		local e = f.entry
		if e and e.run then safe(e.run) changed() end
	end)
	function f:Fill(e)
		self.entry = e
		self.text:SetText(e.label)
		self.button:SetText(e.buttonText or "Open")
	end
	return f
end

local function take(kind)
	used[kind] = (used[kind] or 0) + 1
	local pool = pools[kind]
	local f = pool[used[kind]]
	if not f then f = make[kind]() pool[used[kind]] = f end
	return f
end

-- The list on the right ------------------------------------------------------------------------------------------
local function matches(e, q)
	return (e.label or ""):lower():find(q, 1, true) or (e.group or ""):lower():find(q, 1, true) or (e.note or ""):lower():find(q, 1, true)
end

local function groupsToShow(all)
	local q = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if q == "" then return Options.Section(current, all) end
	-- a search: every section's matches, under the section's name and the group's
	local out = {}
	for _, s in ipairs(Options.SECTIONS) do
		for _, g in ipairs(Options.Section(s.key, all)) do
			local hits = {}
			for _, e in ipairs(g.entries) do if matches(e, q) then hits[#hits + 1] = e end end
			if #hits > 0 then out[#out + 1] = { label = s.label .. ": " .. g.label, entries = hits } end
		end
	end
	return out
end

function Refill()
	if not frame then return end
	for _, pool in pairs(pools) do for _, f in ipairs(pool) do f:Hide() end end
	used = {}
	local all = Options.All()
	local y, width = 0, scroll:GetWidth() - 4
	local shown = 0
	for _, g in ipairs(groupsToShow(all)) do
		if g.label and g.label ~= "" then
			local h = take("header")
			h:Fill(g)
			h:SetPoint("TOPLEFT", 0, -y) h:SetWidth(width) h:Show()
			y = y + ROW.header + 2
		end
		for _, e in ipairs(g.entries) do
			local kind = make[e.kind] and e.kind or "toggle"
			local f = take(kind)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", 0, -y)
			f:SetWidth(width)
			local ok, err = pcall(f.Fill, f, e)
			if ok then f:Show() y = y + ROW[kind] shown = shown + 1 elseif geterrorhandler then geterrorhandler()(err) end
		end
		y = y + 8
	end
	child:SetSize(width, math.max(y, 10))
	emptyText:SetShown(shown == 0)
	emptyText:SetText(query ~= "" and "Nothing matches." or "Nothing here yet: some settings appear once the world has loaded.")
	-- the sections on the left: the current one lit (none while searching)
	for _, b in ipairs(nav.buttons) do
		local on = query == "" and b.key == current
		b.lit:SetShown(on)
		b.text:SetTextColor(unpack(on and GOLD or WHITE))
	end
end

-- The window ------------------------------------------------------------------------------------------------------
local function build()
	if frame then return frame end
	frame = CreateFrame("Frame", "BookFinderOptions", UIParent, "BackdropTemplate")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	frame:Hide()
	tinsert(UISpecialFrames, "BookFinderOptions")
	-- the dialog box's header, with the name on it
	local head = frame:CreateTexture(nil, "ARTWORK")
	head:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	head:SetSize(300, 64)
	head:SetPoint("TOP", 0, 12)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", head, "TOP", 0, -14)
	title:SetText("BookFinder")
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	-- the sections
	nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", 16, -36)
	nav:SetPoint("BOTTOMLEFT", 16, 16)
	nav:SetWidth(NAV_W)
	nav.buttons = {}
	for i, s in ipairs(Options.SECTIONS) do
		local b = CreateFrame("Button", nil, nav)
		b:SetHeight(32)
		b:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
		b:SetPoint("TOPRIGHT", 0, -(i - 1) * 34)
		b.key = s.key
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(22, 22)
		b.icon:SetPoint("LEFT", 6, 0)
		setIcon(b.icon, s.icon)
		b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
		b.text:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
		b.text:SetText(s.label)
		b.lit = b:CreateTexture(nil, "BACKGROUND")
		b.lit:SetTexture(HIGHLIGHT)
		b.lit:SetBlendMode("ADD")
		b.lit:SetAllPoints()
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetTexture(HIGHLIGHT)
		hl:SetBlendMode("ADD")
		hl:SetAllPoints()
		hl:SetAlpha(0.5)
		b:SetScript("OnClick", function()
			current = s.key
			if query ~= "" then searchBox:SetText("") query = "" end
			scroll:SetVerticalScroll(0)
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			Refill()
		end)
		nav.buttons[i] = b
	end
	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(0.6, 0.5, 0.3, 0.35)
	rule:SetWidth(1)
	rule:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
	rule:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 10, 0)

	-- the search, over every section
	searchBox = CreateFrame("EditBox", "BookFinderOptionsSearch", frame, "SearchBoxTemplate")
	searchBox:SetSize(220, 20)
	searchBox:SetPoint("TOPRIGHT", -36, -34)
	searchBox:SetAutoFocus(false)
	if searchBox.Instructions then searchBox.Instructions:SetText("Search settings") end
	searchBox:HookScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		if text == query then return end
		query = text
		scroll:SetVerticalScroll(0)
		Refill()
	end)

	-- the settings
	scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 22, -26)
	scroll:SetPoint("BOTTOMRIGHT", -36, 18)
	child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)
	emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
	frame:SetScript("OnShow", function() Refill() end)
	return frame
end

-- Open at a section ("map", "look", "quests", "library", "more"); a second call while open closes it
function public.OpenOptions(section, toggle)
	if InCombatLockdown() then
		if public.Notice then public.Notice("Settings open after combat.") end
		return false
	end
	build()
	if toggle and frame:IsShown() and (not section or section == current) then frame:Hide() return true end
	if section then current = section end
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
	frame:Show()
	frame:Raise()
	Refill()
	return true
end

-- Every way into any part's settings opens this window, at the section it belongs to
local SECTION_OF = { map = "map", books = "library", quests = "quests", library = "library", look = "look", more = "more" }
function public.OpenSettings(key)
	return public.OpenOptions(SECTION_OF[key] or "map")
end
function public.OpenMapMenu() return public.OpenOptions("map") end

public.OptionsWindow = {
	Build = build, Refill = function() if frame then Refill() end end,
	Shown = function() return frame and frame:IsShown() or false end,
	Rows = function() local n = 0 for _, pool in pairs(pools) do for _, f in ipairs(pool) do if f:IsShown() then n = n + 1 end end end return n end,
	Search = function(text) build() searchBox:SetText(text or "") query = text or "" Refill() end,
	Select = function(key) build() current = key query = "" Refill() end,
}
