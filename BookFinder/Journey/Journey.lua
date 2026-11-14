-- My Journey: the character's history, kept as it happens (quests accepted, handed in, abandoned; levels reached;
-- the player's own notes), shown by level, newest first, on the Journey tab's first page (docs/study/questie.md,
-- "Journey window"). Each character has its own journey; a new character starts an empty one.
--
-- Messages: BF_JOURNEY_CHANGED()

local _, BF = ...
local L = BF.L

local Journey = {}
BF.Journey = Journey

local function state()
	local s = BF:CharacterState("journey")
	s.entries = s.entries or {}
	return s
end

--- Every entry, oldest first: { t = time, kind = "accepted" | "completed" | "abandoned" | "level" | "note", quest?,
--- level, text? }
function Journey:Entries() return state().entries end

function Journey:Add(kind, fields)
	local e = { t = time(), kind = kind, level = BF.Player.level or UnitLevel("player") }
	for k, v in pairs(fields or {}) do e[k] = v end
	table.insert(state().entries, e)
	BF:Send("BF_JOURNEY_CHANGED")
	return e
end

function Journey:AddNote(text)
	text = text and strtrim(text) or ""
	if text == "" then return end
	Journey:Add("note", { text = text })
end

function Journey:Remove(entry)
	local list = state().entries
	for i = #list, 1, -1 do
		if list[i] == entry then table.remove(list, i) end
	end
	BF:Send("BF_JOURNEY_CHANGED")
end

BF:At("login", function()
	BF:Listen("BF_QUEST_ACCEPTED", function(_, id) Journey:Add("accepted", { quest = id }) end)
	BF:Listen("BF_QUEST_REMOVED", function(_, id, turnedIn) Journey:Add(turnedIn and "completed" or "abandoned", { quest = id }) end)
	BF:Listen("BF_LEVEL_CHANGED", function(_, level) Journey:Add("level", { level = level }) end)
end, 30)

-- The page ----------------------------------------------------------------------------------------------------------

StaticPopupDialogs["BOOKFINDER_JOURNEY_NOTE"] = {
	text = L["Your note:"],
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
	hasEditBox = true,
	editBoxWidth = 300,
	OnAccept = function(self)
		local box = self.editBox or self.EditBox
		Journey:AddNote(box and box:GetText())
	end,
	EditBoxOnEnterPressed = function(self)
		Journey:AddNote(self:GetText())
		self:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs["BOOKFINDER_JOURNEY_DELETE_NOTE"] = {
	text = L["Are you sure you want to delete this note?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, entry) Journey:Remove(entry) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local WORDS = { accepted = "Accepted", completed = "Completed", abandoned = "Abandoned" }
local COLOURS = { accepted = { 1, 1, 1 }, completed = { 0.2, 1, 0.2 }, abandoned = { 1, 0.3, 0.3 } }

local page -- { rows, width }

local function render()
	if not page then return end
	local rows = page.rows
	rows:Begin(page.width)
	local name = BF.Player.name or UnitName("player") or ""
	rows:Heading(nil, L["%s's Journey"]:format(name))
	rows:Buttons({ { "Add a note", function() StaticPopup_Show("BOOKFINDER_JOURNEY_NOTE") end } })
	local entries = Journey:Entries()
	if #entries == 0 then
		rows:Line(L["It's about time you embark on your first Journey!"], { hint = true })
		return rows:Finish()
	end
	-- By level, newest first.
	local byLevel, levels = {}, {}
	for _, e in ipairs(entries) do
		local lv = e.level or 0
		if not byLevel[lv] then
			byLevel[lv] = {}
			levels[#levels + 1] = lv
		end
		table.insert(byLevel[lv], 1, e)
	end
	table.sort(levels, function(a, b) return a > b end)
	for _, lv in ipairs(levels) do
		if not rows:Heading("level" .. lv, L["Level %d"]:format(lv), #byLevel[lv]) then
			for _, e in ipairs(byLevel[lv]) do
				local when = date("%d %b %Y", e.t)
				if e.kind == "level" then
					rows:Line(L["Reached level %d"]:format(e.level), { colour = { 1, 0.82, 0 }, right = when })
				elseif e.kind == "note" then
					rows:Line(L["Note"] .. L[": "] .. e.text, { right = when, colour = { 0.6, 0.8, 1 },
						onClick = function(_, button)
							if button == "RightButton" then StaticPopup_Show("BOOKFINDER_JOURNEY_DELETE_NOTE", nil, nil, e) end
						end,
						onEnter = function(row)
							GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
							GameTooltip:SetText(L["Note"])
							GameTooltip:AddLine(e.text, 1, 1, 1, true)
							GameTooltip:AddLine(L["Right-click: delete it"], 0.6, 0.6, 0.6)
							GameTooltip:Show()
						end })
				else
					local title = BF.Rules:TitleWithLevel(e.quest)
					rows:Line(L[WORDS[e.kind]] .. L[": "] .. title, { right = when, colour = COLOURS[e.kind],
						onClick = function() if BF.Search then BF.Search:ShowQuest(e.quest) end end })
				end
			end
		end
	end
	return rows:Finish()
end
Journey.Render = render

BF:At("login", function()
	BF.Panel:AddPage("journey", { key = "myJourney", label = "My Journey", build = function(content, width)
		page = { rows = BF.Rows:New(content, BF:CharacterState("journeyFolded")), width = width }
		page.rows.onFold = render
		return render()
	end }, 1)
	BF:Listen("BF_JOURNEY_CHANGED", function() render() end)
end, 90)
