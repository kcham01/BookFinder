-- Map pins: as many as the player likes, each with a note and a colour, kept for every character (OpenMap's pins,
-- docs/study/openmap.md). Ctrl-click the map drops one (and follows it: the game's map pin, arrow and compass); click a
-- pin for its card (note, colour, Follow, Share, Delete); Alt-click deletes it; Shift-click puts its code in chat.
-- The Map tab's Pins page lists them all (go there, edit, share all, import a code, delete all).
--
-- Shared the way OpenMap shares them, so OpenMap users and BookFinder users trade pins both ways:
--   addon messages "P1<tab>map<tab>x<tab>y<tab>colour<tab>note" (prefix OpenMap) to the group, guild or target;
--   codes "OMPINS1:map,x,y,colour,note;..." to paste anywhere.
-- Pins that arrive are gathered for a moment, then the player is asked (or, from the group with "Auto-add group's
-- pins", added).
--
-- A pin: { id, map, x, y, note, color (1 Gold, 2 Red, 3 Green, 4 Blue, 5 Purple), from?, at }

local _, BF = ...
local L = BF.L

local Pins = {}
BF.UserPins = Pins

local S = BF.Settings
local P, G = "Map/More", "Map pins"
S:Define("map.ctrlClickPin", { default = true, page = P, group = G, label = "Ctrl-click drops a pin" })
S:Define("map.pinsFollowNew", { default = true, page = P, group = G, label = "Follow new pins" })
G = "Sharing"
S:Define("map.pinsShared", { default = true, page = P, group = G, label = "Pins others share with you" })
S:Define("map.pinsShareGroup", { default = false, page = P, group = G, label = "Send new pins to group" })
S:Define("map.pinsGroupAdd", { default = false, page = P, group = G, label = "Auto-add group's pins" })

local PREFIX, CODE = "OpenMap", "OMPINS1:"
local NOTE_MAX, SHARE_MAX, NEAR = 160, 100, 5e-4
Pins.COLORS = {
	{ "Gold", 1, 0.82, 0 }, { "Red", 1, 0.38, 0.32 }, { "Green", 0.5, 0.95, 0.4 }, { "Blue", 0.45, 0.72, 1 },
	{ "Purple", 0.82, 0.55, 1 },
}

local function db()
	local s = BF:AccountState("pins")
	s.list = s.list or {}
	s.nextId = s.nextId or 1
	return s
end

function Pins:List() return db().list end

local function round(v) return math.floor(v * 10000 + 0.5) / 10000 end

local function clean(note)
	note = tostring(note or ""):gsub("[\r\n\t|]", " ")
	note = strtrim(note)
	if #note > NOTE_MAX then note = note:sub(1, NOTE_MAX):gsub("[\192-\255][\128-\191]*$", "") end
	return note
end

local function changed() BF:Send("BF_USER_PINS_CHANGED") end

function Pins:Add(map, x, y, note, color, from)
	local s = db()
	local p = { id = s.nextId, map = map, x = round(x), y = round(y), note = clean(note),
		color = Pins.COLORS[color or 1] and color or 1, from = from, at = time() }
	s.nextId = s.nextId + 1
	table.insert(s.list, p)
	changed()
	return p
end

function Pins:Delete(p)
	local list = db().list
	for i = #list, 1, -1 do if list[i] == p then table.remove(list, i) end end
	if Pins:IsFollowed(p) then BF.Waypoint:Clear() end
	changed()
end

function Pins:Clear()
	wipe(db().list)
	changed()
end

function Pins:SetNote(p, note) p.note = clean(note) changed() end
function Pins:SetColor(p, color) if Pins.COLORS[color] then p.color = color changed() end end

local function same(p, map, x, y) return p.map == map and math.abs(p.x - x) < NEAR and math.abs(p.y - y) < NEAR end

function Pins:Follow(p)
	BF.Waypoint:Set(p.map, p.x, p.y, p.note ~= "" and p.note or L["Map pin"])
end

function Pins:IsFollowed(p)
	local w = BF.Waypoint:Get()
	return w ~= nil and same(p, w.map, w.x, w.y)
end

-- Sharing ------------------------------------------------------------------------------------------------------------

--- The message for a pin: at most 255 bytes, the note cut at a whole character.
function Pins:Message(p)
	local head = ("P1\t%d\t%.4f\t%.4f\t%d\t"):format(p.map, p.x, p.y, p.color or 1)
	local note = p.note or ""
	if #head + #note > 255 then note = note:sub(1, 255 - #head):gsub("[\192-\255][\128-\191]*$", "") end
	return head .. note
end

local function channelFor(to)
	if to == "group" then
		if IsInRaid() then return "RAID" end
		if IsInGroup() then return "PARTY" end
	elseif to == "guild" then
		if IsInGuild() then return "GUILD" end
	elseif to == "target" and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
		return "WHISPER", GetUnitName("target", true)
	end
end

local queue, sending = {}, false
local function sendNext()
	local m = table.remove(queue, 1)
	if not m then sending = false return end
	C_ChatInfo.SendAddonMessage(PREFIX, m[1], m[2], m[3])
	BF:After(0.3, sendNext)
end

--- Shares pins with "group", "guild" or "target"; says so. False when there is nobody there.
function Pins:Share(list, to)
	local channel, target = channelFor(to)
	if not channel or #list == 0 then
		BF:Print(L["Nobody to share with there."])
		return false
	end
	for _, p in ipairs(list) do queue[#queue + 1] = { Pins:Message(p), channel, target } end
	if not sending then
		sending = true
		sendNext()
	end
	BF:Print(L["Sharing %d map pin(s) with %s (players with OpenMap or BookFinder are asked whether to add them)."], #list,
		target or (to == "group" and L["your group"]) or L["your guild"])
	return true
end

local function escape(note) return (note:gsub("[%%,;]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function unescape(note) return (note:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

function Pins:Code(list)
	local parts = {}
	for _, p in ipairs(list) do
		parts[#parts + 1] = ("%d,%.4f,%.4f,%d,%s"):format(p.map, p.x, p.y, p.color or 1, escape(p.note or ""))
	end
	return CODE .. table.concat(parts, ";")
end

local function valid(m, x, y, color, note)
	m, x, y, color = tonumber(m), tonumber(x), tonumber(y), tonumber(color)
	if not (m and x and y) or x < 0 or x > 1 or y < 0 or y > 1 or not BF.Zones:MapSize(m) then return nil end
	return { map = m, x = round(x), y = round(y), color = Pins.COLORS[color or 1] and color or 1, note = clean(note) }
end

--- Pins read from the first code in a text (a code someone pasted), or nil.
function Pins:FromCode(text)
	-- (to the end of the line: OpenMap stops at the first space, which cuts notes that have spaces)
	local body = tostring(text or ""):match("OMPINS1:([^\r\n]+)")
	body = body and strtrim(body)
	if not body then return nil end
	local list = {}
	for part in body:gmatch("[^;]+") do
		local m, x, y, color, note = strsplit(",", part, 5)
		local q = valid(m, x, y, color, unescape(note or ""))
		if q then list[#list + 1] = q end
		if #list >= SHARE_MAX * 5 then break end
	end
	return list
end

--- Adds pins not already here (same place, same note); how many were added.
function Pins:AddAll(list, from)
	local n = 0
	for _, q in ipairs(list) do
		local dup = false
		for _, p in ipairs(db().list) do if same(p, q.map, q.x, q.y) and p.note == q.note then dup = true end end
		if not dup then
			local s = db()
			table.insert(s.list, { id = s.nextId, map = q.map, x = q.x, y = q.y, note = q.note, color = q.color, from = from, at = time() })
			s.nextId = s.nextId + 1
			n = n + 1
		end
	end
	if n > 0 then changed() end
	return n
end

-- Receiving: gathered per sender until 1.5 s after the last, then asked about all at once.
local incoming, asking = {}, false

StaticPopupDialogs["BOOKFINDER_PINS_SHARED"] = {
	text = "%s",
	button1 = L["Add them"],
	button2 = L["Ignore"],
	OnAccept = function(_, batch) BF:Print(L["Added %d map pin(s) from %s."], Pins:AddAll(batch.pins, batch.from), batch.from) end,
	OnHide = function() asking = false end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

local function ask(batch)
	local lines = {}
	for i = 1, math.min(3, #batch.pins) do
		local q = batch.pins[i]
		lines[i] = (BF.Zones:MapName(q.map) or "?") .. (q.note ~= "" and (": " .. q.note) or "")
	end
	if #batch.pins > 3 then lines[#lines + 1] = L["... and %d more"]:format(#batch.pins - 3) end
	asking = true
	StaticPopup_Show("BOOKFINDER_PINS_SHARED", L["%s shared %d map pin(s) with you:"]:format(batch.from, #batch.pins)
		.. "\n|cffffffff" .. table.concat(lines, "\n") .. "|r", nil, batch)
end

local function settle()
	if asking then BF:After(0.5, settle) return end
	local now = GetTime()
	for from, batch in pairs(incoming) do
		if now - batch.at >= 1.5 then
			incoming[from] = nil
			if batch.group and BF:Get("map.pinsGroupAdd") then
				local n = Pins:AddAll(batch.pins, batch.from)
				if n > 0 then BF:Print(L["Added %d map pin(s) from %s."], n, batch.from) end
			else
				ask(batch)
				if next(incoming) then BF:After(0.5, settle) end
				return
			end
		end
	end
	if next(incoming) then BF:After(0.5, settle) end
end

function Pins:Receive(text, channel, from)
	if not BF:Get("map.pinsShared") or type(text) ~= "string" or type(from) ~= "string" then return end
	if issecretvalue and (issecretvalue(text) or issecretvalue(from)) then return end
	local name = Ambiguate(from, "none")
	if name == UnitName("player") then return end
	local kind, m, x, y, color, note = strsplit("\t", text, 6)
	if kind ~= "P1" then return end
	local q = valid(m, x, y, color, note or "")
	if not q then return end
	local batch = incoming[name] or { from = name, pins = {}, group = channel == "PARTY" or channel == "RAID" }
	incoming[name] = batch
	if #batch.pins >= SHARE_MAX then return end
	batch.pins[#batch.pins + 1] = q
	batch.at = GetTime()
	BF:After(1.6, settle)
end

-- The pin's card -------------------------------------------------------------------------------------------------------

StaticPopupDialogs["BOOKFINDER_PIN_CODE"] = {
	text = "%s",
	button1 = CLOSE or "Close",
	hasEditBox = true,
	editBoxWidth = 320,
	OnShow = function(self, data)
		local box = self.editBox or self.EditBox
		box:SetText(data.text or "")
		box:HighlightText()
		box:SetFocus()
	end,
	EditBoxOnEnterPressed = function(self, data)
		if data.import then
			local list = Pins:FromCode(self:GetText())
			BF:Print(L["Added %d map pin(s) from %s."], list and Pins:AddAll(list, L["a code"]) or 0, L["a code"])
		end
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

function Pins:ShowCode(list)
	StaticPopup_Show("BOOKFINDER_PIN_CODE", L["The code (Ctrl-C to copy):"], nil, { text = Pins:Code(list) })
end

function Pins:ImportBox()
	StaticPopup_Show("BOOKFINDER_PIN_CODE", L["Paste a code of map pins, then Enter:"], nil, { import = true })
end

local card

local function buildCard()
	local f = CreateFrame("Frame", "BookFinderPinCard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(300, 150)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	end
	f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	f.title:SetPoint("TOP", 0, -16)
	f.note = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.note:SetSize(250, 20)
	f.note:SetPoint("TOP", 0, -38)
	f.note:SetAutoFocus(false)
	f.note:SetMaxLetters(NOTE_MAX)
	f.note:SetScript("OnEnterPressed", function(self) Pins:SetNote(f.pin, self:GetText()) f:Hide() end)
	f.note:SetScript("OnEscapePressed", function() f:Hide() end)
	f.swatches = {}
	for i, c in ipairs(Pins.COLORS) do
		local s = CreateFrame("Button", nil, f)
		s:SetSize(18, 18)
		s:SetPoint("TOPLEFT", 26 + (i - 1) * 24, -66)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		s.tex:SetColorTexture(c[2], c[3], c[4], 1)
		s:SetScript("OnClick", function() Pins:SetColor(f.pin, i) Pins:RefreshCard() end)
		s:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:SetText(L[c[1]]) GameTooltip:Show() end)
		s:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.swatches[i] = s
	end
	local function button(text, x, onClick)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(64, 22)
		b:SetPoint("BOTTOMLEFT", x, 16)
		b:SetText(L[text])
		b:SetScript("OnClick", onClick)
		return b
	end
	f.follow = button("Follow", 16, function() Pins:Follow(f.pin) Pins:RefreshCard() end)
	f.share = button("Share", 84, function(self)
		local list = { f.pin }
		BF.Dropdown:Toggle(self, {
			{ text = L["To your group"], func = function() Pins:Share(list, "group") end },
			{ text = L["To your guild"], func = function() Pins:Share(list, "guild") end },
			{ text = L["To your target"], func = function() Pins:Share(list, "target") end },
			{ text = L["As a code"], func = function() Pins:ShowCode(list) end },
		})
	end)
	f.done = button("Done", 152, function() Pins:SetNote(f.pin, f.note:GetText()) f:Hide() end)
	f.delete = button("Delete", 220, function() Pins:Delete(f.pin) f:Hide() end)
	f:SetScript("OnHide", function()
		if f.pin and f.isNew and BF:Get("map.pinsShareGroup") and IsInGroup() then Pins:Share({ f.pin }, "group") end
		f.isNew = nil
	end)
	tinsert(UISpecialFrames, "BookFinderPinCard")
	f:Hide()
	return f
end

function Pins:RefreshCard()
	if not card or not card.pin then return end
	local p = card.pin
	card.title:SetText(("%s  %s"):format(BF.Zones:MapName(p.map) or "", BF.Zones:FormatCoords(p.x, p.y)))
	for i, s in ipairs(card.swatches) do s:SetAlpha(p.color == i and 1 or 0.4) end
	card.follow:SetEnabled(not Pins:IsFollowed(p))
end

--- Opens a pin's card (isNew: just dropped; with "Send new pins to group" it goes to the group when closed).
function Pins:Edit(p, isNew)
	card = card or buildCard()
	card.pin, card.isNew = p, isNew
	card.note:SetText(p.note or "")
	card:ClearAllPoints()
	card:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	Pins:RefreshCard()
	card:Show()
	if isNew then card.note:SetFocus() end
end

--- Drops a pin (Ctrl-click on the map): followed when chosen, its card open for a note.
function Pins:Drop(map, x, y)
	local p = Pins:Add(map, x, y, "", 1)
	if BF:Get("map.pinsFollowNew") then Pins:Follow(p) end
	Pins:Edit(p, true)
	return p
end

-- On the world map ---------------------------------------------------------------------------------------------------

local TEMPLATE = "BookFinderUserPinTemplate"
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
Pins.Provider = Provider

function Provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(TEMPLATE) end

function Provider:RefreshAllData()
	self:RemoveAllData()
	local map = self:GetMap():GetMapID()
	if not map then return end
	for _, p in ipairs(db().list) do
		local x, y = BF.Zones:Translate(p.map, p.x, p.y, map)
		if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then self:GetMap():AcquirePin(TEMPLATE, p, x, y) end
	end
end

BookFinderUserPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BookFinderUserPinMixin:OnLoad()
	self:SetScalingLimits(1, 1.0, 1.2)
	if self.SetPassThroughButtons and not InCombatLockdown() then pcall(self.SetPassThroughButtons, self, "RightButton") end
end

function BookFinderUserPinMixin:OnAcquired(p, x, y)
	self.pin = p
	local followed = Pins:IsFollowed(p)
	local kind = followed and "waypoint" or "userPin"
	BF.Icons:Apply(self.Icon, kind)
	local c = Pins.COLORS[p.color] or Pins.COLORS[1]
	if p.color ~= 1 then self.Icon:SetVertexColor(c[2], c[3], c[4], 1) end
	local size = followed and 30 or 24
	self:SetSize(size, size)
	self:SetPosition(x, y)
end

function BookFinderUserPinMixin:OnMouseEnter()
	local p = self.pin
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(p.note ~= "" and p.note or L["Map pin"], 1, 0.82, 0, true)
	GameTooltip:AddLine(("%s  %s"):format(BF.Zones:MapName(p.map) or "", BF.Zones:FormatCoords(p.x, p.y)), 1, 1, 1)
	if p.from then GameTooltip:AddLine(L["Shared by %s"]:format(p.from), 0.6, 0.8, 1) end
	if Pins:IsFollowed(p) then GameTooltip:AddLine(L["Followed"], 0.2, 1, 0.2) end
	GameTooltip:AddLine(L["Click to edit its note, follow, share or delete it"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Shift-click: share in chat"], 0.6, 0.6, 0.6)
	GameTooltip:AddLine(L["Alt-click: delete it"], 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function BookFinderUserPinMixin:OnMouseLeave() GameTooltip:Hide() end

function BookFinderUserPinMixin:OnMouseUp(button)
	if button ~= "LeftButton" then return end
	local p = self.pin
	if IsAltKeyDown() then Pins:Delete(p)
	elseif IsShiftKeyDown() then
		local edit = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
		if edit then edit:Insert(Pins:Code({ p })) else Pins:ShowCode({ p }) end
	else Pins:Edit(p, false) end
end

-- Ctrl-click on the map drops a pin where the cursor is.
local function onMapClick(_, button)
	if button ~= "LeftButton" or not IsControlKeyDown() or not BF:Get("map.ctrlClickPin") then return end
	local scroll = WorldMapFrame.ScrollContainer
	if not scroll or not scroll.GetNormalizedCursorPosition then return end
	local x, y = scroll:GetNormalizedCursorPosition()
	local map = WorldMapFrame:GetMapID()
	if map and x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then Pins:Drop(map, x, y) end
end

-- The Pins page (Map tab) ----------------------------------------------------------------------------------------------

local page

local function renderPage()
	if not page then return 0 end
	local rows = page.rows
	rows:Begin(page.width)
	local list = db().list
	rows:Heading(nil, L["Map pins (%d)"]:format(#list))
	rows:Buttons({
		{ "Import", function() Pins:ImportBox() end, 90 },
		{ "Share all", function(self)
			BF.Dropdown:Toggle(self, {
				{ text = L["As a code"], func = function() Pins:ShowCode(list) end },
				{ text = L["To your group"], func = function() Pins:Share(list, "group") end },
				{ text = L["To your guild"], func = function() Pins:Share(list, "guild") end },
			})
		end, 100 },
		{ "Delete all", function() if #list > 0 then StaticPopup_Show("BOOKFINDER_PINS_CLEAR", #list) end end, 100 },
	})
	if #list == 0 then rows:Line(L["Ctrl-click the map to drop a pin."], { hint = true }) end
	for _, p in ipairs(list) do
		local c = Pins.COLORS[p.color] or Pins.COLORS[1]
		local text = ("%s  |cffaaaaaa%s|r%s"):format(BF.Zones:MapName(p.map) or "?", BF.Zones:FormatCoords(p.x, p.y),
			p.note ~= "" and ("  " .. p.note) or "")
		rows:Line(text, { colour = { c[2], c[3], c[4] }, right = Pins:IsFollowed(p) and L["Followed"] or nil,
			onClick = function(_, button)
				if button == "RightButton" then Pins:Edit(p, false) return end
				Pins:Follow(p)
				if not WorldMapFrame:IsShown() then ToggleWorldMap() end
				WorldMapFrame:SetMapID(p.map)
			end,
			onEnter = function(row)
				GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
				GameTooltip:AddLine(L["Click to go there, right-click to open its card"], 0.6, 0.6, 0.6)
				GameTooltip:Show()
			end })
	end
	return rows:Finish()
end

StaticPopupDialogs["BOOKFINDER_PINS_CLEAR"] = {
	text = L["Delete all %d map pins?"],
	button1 = YES, button2 = NO,
	OnAccept = function() Pins:Clear() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

local refresh = BF:Debounce(0.05, function()
	if WorldMapFrame and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
	renderPage()
	Pins:RefreshCard()
end)

BF:At("login", function()
	if WorldMapFrame and WorldMapFrame.AddDataProvider then WorldMapFrame:AddDataProvider(Provider) end
	local scroll = WorldMapFrame and WorldMapFrame.ScrollContainer
	if scroll and scroll.HookScript then scroll:HookScript("OnMouseUp", onMapClick) end
	BF.Wire:Listen(PREFIX, function(text, channel, sender) Pins:Receive(text, channel, sender) end)
	BF.Panel:AddPage("map", { key = "pins", label = "Pins", build = function(content, width)
		page = { rows = BF.Rows:New(content, {}), width = width }
		return renderPage()
	end })
	BF:Listen("BF_USER_PINS_CHANGED", refresh)
	BF:Listen("BF_WAYPOINT_CHANGED", refresh)
end, 76)
