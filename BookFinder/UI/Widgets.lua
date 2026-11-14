-- Widgets: the few controls the settings panel is made of, each from the game's own templates (tick box, slider,
-- choice, colour swatch, heading). A choice opens BookFinder's one dropdown (UI/Dropdown.lua). Each control is bound to one setting and refreshes from it.
--
-- Templates differ between clients: Template({...}) picks the first one this client knows (C_XMLUtil), so the panel
-- uses the newest look where it exists and an older one elsewhere.

local _, BF = ...
local L = BF.L

local Widgets = {}
BF.Widgets = Widgets

--- The first template this client has, or nil.
function Widgets:Template(candidates)
	local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo
	for _, name in ipairs(candidates) do
		if not info or info(name) then return name end
	end
	return nil
end

local ROW = 26

-- Shared ----------------------------------------------------------------------------------------------------------

local function enabled(def)
	if def.enabledIf then return def.enabledIf() ~= false end
	return true
end

local function labelOf(def) return L[def.label or def.key] end

--- A gold heading with a rule under it (the game's tooltip divider).
function Widgets:Heading(parent, text, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 24)
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	f.text:SetPoint("BOTTOMLEFT", 2, 6)
	f.text:SetText(L[text])
	f.rule = f:CreateTexture(nil, "ARTWORK")
	f.rule:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
	f.rule:SetPoint("BOTTOMLEFT", 0, 0)
	f.rule:SetPoint("BOTTOMRIGHT", 0, 0)
	f.rule:SetHeight(8)
	return f
end

-- Tick box --------------------------------------------------------------------------------------------------------

function Widgets:Checkbox(parent, def, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, ROW)
	f.def = def
	local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("LEFT", 0, 0)
	f.check = cb
	f.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	f.label:SetPoint("RIGHT", f, "RIGHT", -2, 0)
	f.label:SetJustifyH("LEFT")
	f.label:SetText(labelOf(def))
	cb:SetScript("OnClick", function(self)
		BF:Set(def.key, self:GetChecked() and true or false)
		PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end)
	function f:Refresh()
		cb:SetChecked(BF:Get(def.key) == true)
		local on = enabled(def)
		cb:SetEnabled(on)
		f.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
	end
	f:Refresh()
	return f
end

-- Slider ------------------------------------------------------------------------------------------------------------

local function formatValue(def, v)
	local step = def.step or 1
	if step >= 1 then return ("%d"):format(math.floor(v + 0.5)) end
	local decimals = step >= 0.1 and 1 or 2
	return ("%." .. decimals .. "f"):format(v)
end

local function snap(def, v)
	local step = def.step or 1
	v = def.min + math.floor((v - def.min) / step + 0.5) * step
	if v < def.min then v = def.min elseif v > def.max then v = def.max end
	return tonumber(("%.4f"):format(v))
end

function Widgets:Slider(parent, def, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, ROW * 2)
	f.def = def
	f.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.label:SetPoint("TOPLEFT", 2, -2)
	f.label:SetText(labelOf(def))
	f.value = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.value:SetPoint("TOPRIGHT", -2, -3)
	local steps = math.max(1, math.floor((def.max - def.min) / (def.step or 1) + 0.5))

	local modern = Widgets:Template({ "MinimalSliderWithSteppersTemplate" })
	local slider
	local setting = false -- true while the panel itself moves the slider (no write back)
	if modern then
		slider = CreateFrame("Frame", nil, f, modern)
		slider:SetPoint("BOTTOMLEFT", 0, 4)
		slider:SetPoint("BOTTOMRIGHT", 0, 4)
		slider:SetHeight(20)
		slider:Init(BF:Get(def.key), def.min, def.max, steps)
		slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
			if not setting then BF:Set(def.key, snap(def, v)) end
		end)
		function f:SetSliderValue(v) slider:SetValue(v) end
	else
		slider = CreateFrame("Slider", nil, f, Widgets:Template({ "OptionsSliderTemplate", "UISliderTemplate" }))
		slider:SetPoint("BOTTOMLEFT", 4, 6)
		slider:SetPoint("BOTTOMRIGHT", -4, 6)
		slider:SetHeight(16)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(def.min, def.max)
		slider:SetValueStep(def.step or 1)
		slider:SetObeyStepOnDrag(true)
		slider:SetScript("OnValueChanged", function(_, v)
			if not setting then BF:Set(def.key, snap(def, v)) end
		end)
		function f:SetSliderValue(v) slider:SetValue(v) end
	end
	f.slider = slider
	function f:Refresh()
		local v = BF:Get(def.key)
		setting = true
		f:SetSliderValue(v)
		setting = false
		f.value:SetText(formatValue(def, v))
		local on = enabled(def)
		if slider.SetEnabled then slider:SetEnabled(on) end
		f.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
	end
	f:Refresh()
	return f
end

-- Dropdown ----------------------------------------------------------------------------------------------------------

--- The choices of a setting as { {value, label}, ... }.
function Widgets:Choices(def)
	local list = {}
	if def.iconChoice then
		for _, c in ipairs(BF.Icons.objectiveChoices) do
			list[#list + 1] = { c.key, L[c.label], icon = c.key ~= "default" and c.key or nil }
		end
	elseif def.choices then
		for _, value in ipairs(def.choices) do
			local label = def.choiceLabels and def.choiceLabels[value] or value
			list[#list + 1] = { value, L[label] }
		end
	end
	return list
end

function Widgets:Dropdown(parent, def, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, ROW * 2)
	f.def = def
	f.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.label:SetPoint("TOPLEFT", 2, -2)
	f.label:SetText(labelOf(def))
	local choices = Widgets:Choices(def)

	local function items()
		local list = {}
		for _, c in ipairs(choices) do
			list[#list + 1] = { text = c[2], radio = true, icon = c.icon,
				checked = function() return BF:Get(def.key) == c[1] end,
				func = function() BF:Set(def.key, c[1]) end }
		end
		return list
	end

	local function current()
		local v = BF:Get(def.key)
		for _, c in ipairs(choices) do if c[1] == v then return c[2] end end
		return tostring(v)
	end

	-- The face: a game button showing the choice; pressing it opens BookFinder's one dropdown (UI/Dropdown.lua).
	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetScript("OnClick", function(self) BF.Dropdown:Toggle(self, items) end)
	button.arrow = button:CreateTexture(nil, "OVERLAY")
	button.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	button.arrow:SetSize(18, 18)
	button.arrow:SetPoint("RIGHT", -4, 0)
	function f:ShowValue() button:SetText(current()) end
	button:SetPoint("BOTTOMLEFT", 0, 2)
	button:SetSize(math.min(width - 4, 220), 24)
	f.button = button
	function f:Refresh()
		f:ShowValue()
		local on = enabled(def)
		if button.SetEnabled then button:SetEnabled(on) end
		f.label:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
	end
	f:Refresh()
	return f
end

-- Colour --------------------------------------------------------------------------------------------------------------

function Widgets:Colour(parent, def, width)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, ROW)
	f.def = def
	local swatch = CreateFrame("Button", nil, f)
	swatch:SetSize(20, 20)
	swatch:SetPoint("LEFT", 2, 0)
	swatch.border = swatch:CreateTexture(nil, "BACKGROUND")
	swatch.border:SetColorTexture(1, 1, 1, 1)
	swatch.border:SetPoint("TOPLEFT", -1, 1)
	swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
	swatch.colour = swatch:CreateTexture(nil, "ARTWORK")
	swatch.colour:SetAllPoints()
	swatch.colour:SetColorTexture(1, 1, 1, 1)
	f.swatch = swatch
	f.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
	f.label:SetText(labelOf(def))

	swatch:SetScript("OnClick", function()
		local c = BF:Get(def.key)
		local before = { c[1], c[2], c[3], c[4] or 1 }
		local function current()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			local a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or before[4]
			return { r, g, b, a }
		end
		local info = {
			r = before[1], g = before[2], b = before[3], opacity = before[4], hasOpacity = true,
			swatchFunc = function() BF:Set(def.key, current()) end,
			opacityFunc = function() BF:Set(def.key, current()) end,
			cancelFunc = function() BF:Set(def.key, before) end,
		}
		if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info) end
	end)
	function f:Refresh()
		local c = BF:Get(def.key)
		swatch.colour:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	end
	f:Refresh()
	return f
end

--- The control for a setting, or nil when it has none (a choice whose list is not built yet, a pending setting).
function Widgets:For(parent, def, width)
	if def.pending or def.soundChoice then return nil end
	local t = type(def.default)
	if def.color then return Widgets:Colour(parent, def, width), "wide" end
	if def.iconChoice or def.choices then return Widgets:Dropdown(parent, def, width), "wide" end
	if t == "boolean" then return Widgets:Checkbox(parent, def, width), "check" end
	if t == "number" and def.min and def.max then return Widgets:Slider(parent, def, width), "wide" end
	return nil
end
