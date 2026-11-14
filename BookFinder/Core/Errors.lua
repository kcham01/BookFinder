-- Errors, made easy to send: every Lua error (BookFinder's, the game's, other addons') is caught with its stack and
-- the values at that moment, counted when it repeats, and kept (the newest 50) across reloads. One chat line says
-- one was caught; /bf errors opens a window holding them all as one report, selected, so Ctrl+C copies it.
-- Blocked actions (taint) are kept too. The game's own error window still opens as before.

local _, BF = ...
local L = BF.L

local Errors = {}
BF.Errors = Errors

local MAX = 50
local list = {}      -- this session's view of the kept errors (newest last)
local told = false   -- the chat line, once per session

local function store()
	if not BookFinderDB then return list end
	BookFinderDB.errors = BookFinderDB.errors or {}
	return BookFinderDB.errors
end

local function record(message, stack, locals)
	message = tostring(message or "?")
	local errors = store()
	for _, e in ipairs(errors) do
		if e.message == message then
			e.count = e.count + 1
			e.last = date("%Y-%m-%d %H:%M:%S")
			return
		end
	end
	errors[#errors + 1] = {
		message = message, stack = stack, locals = locals, count = 1,
		first = date("%Y-%m-%d %H:%M:%S"), last = date("%Y-%m-%d %H:%M:%S"),
		version = BF.version,
	}
	while #errors > MAX do table.remove(errors, 1) end
	if not told then
		told = true
		BF:After(0.5, function()
			BF:Print(L["an error was caught. Type /bf errors to copy it (with anything after it) and send it."])
		end)
	end
	if Errors.window and Errors.window:IsShown() then Errors:Show() end
end

-- Wrap the error handler in force (the game's, or another addon's): ours records, then hands on.
local previous = geterrorhandler()
local function handler(message, ...)
	local stack = debugstack and debugstack(3) or ""
	local locals = debuglocals and debuglocals(3) or ""
	pcall(record, message, stack, locals)
	if previous then return previous(message, ...) end
end
seterrorhandler(handler)
-- Another addon that sets its own handler later wraps ours, or replaces it: put ours back on top at login.
BF:At("login", function()
	local current = geterrorhandler()
	if current ~= handler then
		previous = current
		seterrorhandler(handler)
	end
	-- Errors from before saved variables were loaded: kept now.
	if #list > 0 and BookFinderDB then
		for _, e in ipairs(list) do table.insert(store(), e) end
		wipe(list)
	end
end, 0)

local function blocked(_, addon, action)
	record(("Blocked action: %s tried %s"):format(tostring(addon), tostring(action)), debugstack and debugstack(2) or "", "")
end
BF:On("ADDON_ACTION_BLOCKED", blocked)
BF:On("ADDON_ACTION_FORBIDDEN", blocked)

--- All kept errors as one text report.
function Errors:Report()
	local lines = {}
	local version, build, _, toc = GetBuildInfo()
	lines[#lines + 1] = ("BookFinder %s | game %s (%s) interface %s | %s | %s"):format(BF.version or "?", version or "?",
		build or "?", toc or "?", GetLocale(), date("%Y-%m-%d %H:%M"))
	local errors = store()
	if #errors == 0 then
		lines[#lines + 1] = "No errors caught."
	end
	for i = #errors, 1, -1 do
		local e = errors[i]
		lines[#lines + 1] = ""
		lines[#lines + 1] = ("#%d  x%d  first %s  last %s  (BookFinder %s)"):format(#errors - i + 1, e.count, e.first, e.last, e.version or "?")
		lines[#lines + 1] = e.message
		if e.stack and e.stack ~= "" then lines[#lines + 1] = "Stack:\n" .. e.stack end
		if e.locals and e.locals ~= "" then lines[#lines + 1] = "Locals:\n" .. e.locals end
	end
	return table.concat(lines, "\n")
end

function Errors:Clear()
	wipe(store())
	if Errors.window and Errors.window:IsShown() then Errors:Show() end
end

-- The window -------------------------------------------------------------------------------------------------------

local function build()
	local W = BF.Widgets
	local f = CreateFrame("Frame", "BookFinderErrors", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(720, 520)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	table.insert(UISpecialFrames, "BookFinderErrors")
	W:Dress(f)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -4)
	title:SetText(L["BookFinder errors"])
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 0)

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 16, -30)
	hint:SetText(L["Everything below is selected: press Ctrl+C to copy it, then paste it where you send it."])

	local scroll = CreateFrame("ScrollFrame", nil, f, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -50)
	scroll:SetPoint("BOTTOMRIGHT", -36, 44)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontSmall")
	box:SetWidth(660)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	-- The text stays as it is (typing does nothing to it).
	box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.report or "") self:HighlightText() end end)
	scroll:SetScrollChild(box)
	f.box = box

	local selectAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	selectAll:SetSize(130, 22)
	selectAll:SetPoint("BOTTOMLEFT", 16, 14)
	selectAll:SetText(L["Select all"])
	selectAll:SetScript("OnClick", function() box:SetFocus() box:HighlightText() end)
	local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	clear:SetSize(130, 22)
	clear:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
	clear:SetText(L["Clear"])
	clear:SetScript("OnClick", function() Errors:Clear() end)
	f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.count:SetPoint("BOTTOMRIGHT", -20, 18)
	Errors.window = f
	return f
end

function Errors:Show()
	local f = Errors.window or build()
	f.report = Errors:Report()
	f.box:SetText(f.report)
	f.count:SetText(L["%d kept"]:format(#store()))
	f:Show()
	f.box:SetFocus()
	f.box:HighlightText()
end

BF:At("login", function()
	BF.Commands:Add("errors", "every error caught, ready to copy", function() Errors:Show() end)
end)
