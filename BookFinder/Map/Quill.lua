-- The quill: drawing on the seamless map (OpenMap's, docs/study/openmap.md "The quill"). Tools Pen, Line, Arrow,
-- Circle, Mark (a raid mark; right-click the button for the next one), Erase; inks Black, Red, Blue, Green, Gold, White;
-- widths Fine, Medium, Broad; Undo (Ctrl-Z), Clear (click twice), Done (Escape). Drawings are kept in world yards, for
-- every character, and drawn on the canvas with "Your drawings" on (the Show dropdown).
-- Opened by the Quill button on the seamless map or /bf draw.

local _, BF = ...
local L = BF.L

local Quill = {}
BF.Quill = Quill

BF.Settings:Define("map.drawings", { default = true, page = "Map/Show", label = "Your drawings" })

local Canvas = BF.WorldCanvas

Quill.INKS = { { "Black", 0.1, 0.1, 0.1 }, { "Red", 0.9, 0.15, 0.1 }, { "Blue", 0.2, 0.45, 1 }, { "Green", 0.2, 0.8, 0.25 },
	{ "Gold", 1, 0.82, 0 }, { "White", 1, 1, 1 } }
Quill.WIDTHS = { { "Fine", 2 }, { "Medium", 4 }, { "Broad", 7 } }
Quill.TOOLS = { "Pen", "Line", "Arrow", "Circle", "Mark", "Erase" }
local MAX_STROKES = 2000

local function db()
	local s = BF:AccountState("drawings")
	s.list = s.list or {}
	return s
end

local state = { tool = "Pen", ink = 2, width = 2, mark = 1, on = false }
Quill.state = state

function Quill:Strokes() return db().list end

local function changed() BF:Send("BF_DRAWINGS_CHANGED") end

function Quill:Add(stroke)
	local list = db().list
	if #list >= MAX_STROKES then
		BF:Print(L["Too much drawn: undo or clear some first."])
		return
	end
	list[#list + 1] = stroke
	changed()
end

function Quill:Undo()
	local list = db().list
	if #list > 0 then table.remove(list) changed() end
end

function Quill:Clear() wipe(db().list) changed() end

-- The distance from a point to a segment (yards).
local function toSegment(e, n, a, b)
	local de, dn = b[1] - a[1], b[2] - a[2]
	local len2 = de * de + dn * dn
	local t = len2 > 0 and math.max(0, math.min(1, ((e - a[1]) * de + (n - a[2]) * dn) / len2)) or 0
	local pe, pn = a[1] + t * de, a[2] + t * dn
	return math.sqrt((e - pe) ^ 2 + (n - pn) ^ 2)
end

--- Erases the stroke nearest a world point within `reach` yards; true if one went.
function Quill:EraseAt(e, n, reach)
	local list = db().list
	for i = #list, 1, -1 do
		local s = list[i]
		local pts = s.points
		local hit = s.tool == "Mark" and math.sqrt((e - pts[1][1]) ^ 2 + (n - pts[1][2]) ^ 2) <= reach
		for j = 2, #pts do
			if toSegment(e, n, pts[j - 1], pts[j]) <= reach then hit = true break end
		end
		if hit then table.remove(list, i) changed() return true end
	end
	return false
end

-- Drawing on the canvas -----------------------------------------------------------------------------------------------

local function circlePoints(c, edge)
	local r = math.sqrt((edge[1] - c[1]) ^ 2 + (edge[2] - c[2]) ^ 2)
	local pts = {}
	for i = 0, 36 do
		local a = i / 36 * 2 * math.pi
		pts[#pts + 1] = { c[1] + r * math.cos(a), c[2] + r * math.sin(a) }
	end
	return pts
end

-- The lines of a stroke as world segments (an arrow gets its head; a circle its ring).
local function segments(s)
	local pts = s.points
	if s.tool == "Circle" then pts = circlePoints(pts[1], pts[#pts]) end
	local segs = {}
	for i = 2, #pts do segs[#segs + 1] = { pts[i - 1], pts[i] } end
	if s.tool == "Arrow" and #pts >= 2 then
		local a, b = pts[1], pts[#pts]
		local angle = math.atan2(b[2] - a[2], b[1] - a[1])
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2) * 0.2
		for _, d in ipairs({ 2.6, -2.6 }) do
			segs[#segs + 1] = { b, { b[1] + len * math.cos(angle + d), b[2] + len * math.sin(angle + d) } }
		end
	end
	return segs
end
Quill.Segments = segments

local drawing -- the stroke being drawn

Canvas:AddLayer("drawings", function(continent, add)
	if not BF:Get("map.drawings") then return end
	local _, _, _, _, instance = BF.Stitch:Bounds(continent)
	local list = {}
	for _, s in ipairs(db().list) do list[#list + 1] = s end
	if drawing then list[#list + 1] = drawing end
	for _, s in ipairs(list) do
		if s.instance == instance then
			local ink = Quill.INKS[s.ink] or Quill.INKS[1]
			if s.tool == "Mark" then
				add(s.points[1][1], s.points[1][2], { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. (s.mark or 1), size = 20 })
			else
				for _, seg in ipairs(segments(s)) do
					add.line(seg[1][1], seg[1][2], seg[2][1], seg[2][2], { thickness = s.width, colour = { ink[2], ink[3], ink[4], 1 } })
				end
			end
		end
	end
end)

-- Input while the quill is on: the canvas's own mouse handling steps aside.
local function worldUnderCursor()
	local f = Canvas.frame
	local x, y = GetCursorPosition()
	local s = f:GetEffectiveScale()
	return Canvas:WorldAt(x / s - (f:GetLeft() or 0), (f:GetTop() or 0) - y / s)
end

function Quill:Begin()
	local e, n = worldUnderCursor()
	local cont = Canvas.ContinentOf(WorldMapFrame:GetMapID())
	local _, _, _, _, instance = BF.Stitch:Bounds(cont or 0)
	if state.tool == "Erase" then
		Quill:EraseAt(e, n, 12 / Canvas:Zoom())
		return
	end
	local stroke = { tool = state.tool, ink = state.ink, width = Quill.WIDTHS[state.width][2], instance = instance,
		points = { { e, n } }, mark = state.tool == "Mark" and state.mark or nil }
	if state.tool == "Mark" then
		Quill:Add(stroke)
		return
	end
	drawing = stroke
end

function Quill:Move()
	if not drawing then return end
	local e, n = worldUnderCursor()
	if drawing.tool == "Pen" then
		local last = drawing.points[#drawing.points]
		if math.sqrt((e - last[1]) ^ 2 + (n - last[2]) ^ 2) * Canvas:Zoom() >= 3 then drawing.points[#drawing.points + 1] = { e, n } end
	else
		drawing.points[2] = { e, n }
	end
	Canvas:Redraw()
end

function Quill:Finish()
	if drawing and #drawing.points >= 2 then Quill:Add(drawing) end
	drawing = nil
	Canvas:Redraw()
end

-- The toolbar -----------------------------------------------------------------------------------------------------------

local bar

local function buildBar()
	local f = Canvas.frame
	bar = CreateFrame("Frame", "BookFinderQuillBar", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	bar:SetPoint("TOP", 0, -8)
	bar:SetSize(560, 58)
	bar:SetFrameLevel(f:GetFrameLevel() + 260)
	if bar.SetBackdrop then
		bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		bar:SetBackdropColor(0.09, 0.09, 0.09, 0.9)
	end
	bar.buttons = {}
	local function button(text, x, y, w, onClick)
		local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		b:SetSize(w or 64, 20)
		b:SetPoint("TOPLEFT", x, y)
		b:SetText(L[text])
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", onClick)
		bar.buttons[text] = b
		return b
	end
	for i, tool in ipairs(Quill.TOOLS) do
		button(tool, 8 + (i - 1) * 66, -8, 64, function(_, mouse)
			if tool == "Mark" and mouse == "RightButton" then state.mark = state.mark % 8 + 1 end
			state.tool = tool
			Quill:RefreshBar()
		end)
	end
	for i, ink in ipairs(Quill.INKS) do
		local s = CreateFrame("Button", nil, bar)
		s:SetSize(18, 18)
		s:SetPoint("TOPLEFT", 8 + (i - 1) * 22, -32)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		s.tex:SetColorTexture(ink[2], ink[3], ink[4], 1)
		s:SetScript("OnClick", function() state.ink = i Quill:RefreshBar() end)
		bar.buttons["ink" .. i] = s
	end
	for i, wdt in ipairs(Quill.WIDTHS) do
		button(wdt[1], 146 + (i - 1) * 66, -32, 64, function() state.width = i Quill:RefreshBar() end)
	end
	button("Undo", 350, -32, 64, function() Quill:Undo() end)
	button("Clear", 416, -32, 64, function(self)
		if self.armed then Quill:Clear() self.armed = nil self:SetText(L["Clear"]) return end
		self.armed = true
		self:SetText(L["Sure?"])
		BF:After(3, function() if self.armed then self.armed = nil self:SetText(L["Clear"]) end end)
	end)
	button("Done", 482, -32, 64, function() Quill:Stop() end)
	bar:EnableKeyboard(true)
	bar:SetPropagateKeyboardInput(true)
	bar:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Quill:Stop()
		elseif key == "Z" and IsControlKeyDown() then
			self:SetPropagateKeyboardInput(false)
			Quill:Undo()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	bar:Hide()
end

function Quill:RefreshBar()
	if not bar then return end
	for _, tool in ipairs(Quill.TOOLS) do bar.buttons[tool]:SetAlpha(state.tool == tool and 1 or 0.6) end
	for i = 1, #Quill.INKS do bar.buttons["ink" .. i]:SetAlpha(state.ink == i and 1 or 0.35) end
	for i, wdt in ipairs(Quill.WIDTHS) do bar.buttons[wdt[1]]:SetAlpha(state.width == i and 1 or 0.6) end
end

function Quill:Start()
	if not BF:Get("map.seamless") then BF:Set("map.seamless", true) end
	if not WorldMapFrame:IsShown() then ToggleWorldMap() end
	if not Canvas.frame:IsShown() then return end
	if not bar then buildBar() end
	state.on = true
	bar:Show()
	Quill:RefreshBar()
	BF:Set("map.drawings", true)
end

function Quill:Stop()
	state.on = false
	drawing = nil
	if bar then bar:Hide() end
	Canvas:Redraw()
end

function Quill:IsOn() return state.on end

BF:At("login", function()
	local f = Canvas.frame
	if not f then return end
	-- The canvas asks the quill first: while it is on, presses draw instead of panning.
	Canvas.inputHook = function(event, button)
		if not state.on or button ~= "LeftButton" then return false end
		if event == "down" then Quill:Begin() elseif event == "up" then Quill:Finish() end
		return true
	end
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(70, 22)
	b:SetPoint("LEFT", BF.FindPlace.box or f, BF.FindPlace.box and "RIGHT" or "TOPLEFT", 8, 0)
	b:SetFrameLevel(f:GetFrameLevel() + 250)
	b:SetText(L["Quill"])
	b:SetScript("OnClick", function() if state.on then Quill:Stop() else Quill:Start() end end)
	f:HookScript("OnHide", function() Quill:Stop() end)
	BF:Listen("BF_DRAWINGS_CHANGED", function() Canvas:Redraw() end)
	local mover = CreateFrame("Frame", nil, f)
	mover:SetScript("OnUpdate", function() if drawing then Quill:Move() end end)
end, 81)
