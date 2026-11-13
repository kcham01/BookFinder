-- BookFinder: the map panel. One panel on the world map, in the game's own look, for everything the parts do while
-- you look at the map: the journey under way, your quests, the services near you, the library books and what the map
-- shows, with one search over places, books, quests, NPCs, objects and items. It reads and drives the parts through
-- what they offer (Shortest Path's API and journey calls, Questie's database and modules, Books' and OpenMap's own
-- functions); every call into a part is guarded, so a part that's off or replaced by its standalone copy leaves its
-- tab with a line saying so instead of an error.
--
-- It replaces the map's other buttons: OpenMap's button column and Questie's map button are off in BookFinder, and
-- this panel's button (the map's top right) opens and closes it. No secure frames: it works in combat, where the
-- parts' own refusals (no journeys in combat) say so in chat.
local ADDON, root = ...
local public = root.public
local OM, SPF, BOOKS = root.OpenMap, root.SPF, root.Books

local WIDTH, WIDTH_NARROW = 300, 250
local ROW_H, HEADER_H, CHECK_H, BUTTON_H = 20, 24, 24, 24
local PAD = 10
local MAX_RESULTS = 12          -- per kind, in a search
local GOLD, MUTED, BLUE, GREEN = { 1, 0.82, 0 }, { 0.62, 0.62, 0.58 }, { 0.36, 0.78, 1 }, { 0.4, 0.9, 0.4 }
local QUESTS = QUESTS_LABEL or "Quests"
local OWNER = "BookFinder"      -- (Shortest Path's API owner of the journeys this panel starts)

local panel, toggle, scrollFrame, content, searchBox
local tabButtons = {}
local db                        -- BookFinderDB.panel: { open, tab }
local query = ""
local refreshQueued = false
local QueueRefresh              -- (below: the panel drawn again soon, once however often it's asked)

local function say(text) print("|cff33ff99BookFinder|r: " .. text) end

--------------------------------------------------------------------------------------------------------------------
-- Parts, read safely
--------------------------------------------------------------------------------------------------------------------

local function spfAPI()
	local api = ShortestPathForever and ShortestPathForever.API
	return type(api) == "table" and api or nil
end

local function questie(module)
	local loader = _G.QuestieLoader
	if not (loader and public.Active("Questie")) then return nil end
	local ok, mod = pcall(loader.ImportModule, loader, module)
	return ok and mod or nil
end

local function openMapModule()
	if not (public.Active("OpenMap") and OM.GetModule) then return nil end
	local ok, mod = pcall(OM.GetModule, OM, "worldmap")
	return ok and mod or nil
end

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	geterrorhandler()(a)
end

local function timeText(seconds)
	if type(seconds) ~= "number" then return "" end
	if seconds < 60 then return ("%d s"):format(math.max(0, math.floor(seconds))) end
	if SecondsToTime then return SecondsToTime(seconds, true, false, 1, true) end
	return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

-- the player's place: its uiMap, x and y (0..1), and the world point
local function here()
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return nil end
	local x, y = pos:GetXY()
	local cont, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
	if not (cont and world) then return mapID, x, y end
	local wx, wy = world:GetXY()
	return mapID, x, y, cont, wx, wy
end

local function worldOf(mapID, x, y)
	if not (mapID and x and y and CreateVector2D) then return nil end
	local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
	if ok and cont and world then
		local wx, wy = world:GetXY()
		return cont, wx, wy
	end
end

-- yards from the player, or nil (another continent, or no position)
local function yardsTo(mapID, x, y)
	local _, _, _, cont, px, py = here()
	local c, wx, wy = worldOf(mapID, x, y)
	if cont and c == cont then return math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) end
end

-- a journey to one spot, through Shortest Path's API
local function journeyTo(mapID, x, y, title, kind)
	local api = spfAPI()
	if not (api and api.NavigateRoute and mapID and x and y) then
		say("journeys need Shortest Path.")
		return false
	end
	local ok, started = pcall(api.NavigateRoute, OWNER, { { map = mapID, x = x, y = y, title = title, kind = kind } })
	if ok and started then return true end
	say(InCombatLockdown() and "journeys start once combat ends." or "no journey can be planned there.")
	return false
end

-- an NPC's or object's spawn nearest you, from Questie's database: { map, x, y } (uiMap, 0..1)
local function nearestSpawn(kind, id)
	local QDB, ZoneDB = questie("QuestieDB"), questie("ZoneDB")
	if not (QDB and ZoneDB) then return nil end
	local query = kind == "object" and QDB.QueryObjectSingle or QDB.QueryNPCSingle
	local spawns = call(query, id, "spawns")
	if type(spawns) ~= "table" then return nil end
	local _, _, _, cont, px, py = here()
	local best, bestD
	for areaID, list in pairs(spawns) do
		local mapID = call(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaID)
		if mapID and type(list) == "table" then
			for _, spot in ipairs(list) do
				local x, y = spot[1] and spot[1] / 100, spot[2] and spot[2] / 100
				if x and y and x > 0 and y > 0 then
					local c, wx, wy = worldOf(mapID, x, y)
					local d = (c and cont and c == cont) and math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) or (c and 1e9) or 2e9
					if not bestD or d < bestD then best, bestD = { map = mapID, x = x, y = y }, d end
				end
			end
		end
	end
	if best and bestD < 1e9 then best.yards = bestD end
	return best
end

local function npcName(id)
	local QDB = questie("QuestieDB")
	return QDB and call(QDB.QueryNPCSingle, id, "name") or ("NPC " .. tostring(id))
end

--------------------------------------------------------------------------------------------------------------------
-- Rows (pooled): headers, text, clickable rows, checkboxes, button rows, a progress bar
--------------------------------------------------------------------------------------------------------------------

local pools, used, cursor = {}, {}, 0

local function Pool(kind, make)
	pools[kind] = pools[kind] or { free = {}, make = make }
end

local function Acquire(kind)
	local pool = pools[kind]
	local w = table.remove(pool.free) or pool.make()
	w.kind = kind
	used[#used + 1] = w
	w:ClearAllPoints()
	w:Show()
	return w
end

local function ReleaseAll()
	for i = #used, 1, -1 do
		local w = used[i]
		w:Hide()
		w.onClick, w.tip, w.get, w.set = nil, nil, nil, nil
		table.insert(pools[w.kind].free, w)
		used[i] = nil
	end
	cursor = 0
end

local function Place(w, height, indent)
	w:SetPoint("TOPLEFT", content, "TOPLEFT", indent or 0, -cursor)
	w:SetPoint("RIGHT", content, "RIGHT", 0, 0)
	w:SetHeight(height)
	cursor = cursor + height
end

local function ShowTip(owner, title, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine(title or "", 1, 0.82, 0)
	for _, l in ipairs(lines or {}) do
		if type(l) == "table" then GameTooltip:AddDoubleLine(l[1], l[2], 1, 1, 1, 0.8, 0.8, 0.8)
		else GameTooltip:AddLine(l, 1, 1, 1, true) end
	end
	GameTooltip:Show()
end

local function MakeHeader()
	local f = CreateFrame("Frame", nil, content)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.text:SetPoint("BOTTOMLEFT", 0, 4)
	f.text:SetPoint("RIGHT", -60, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(false)
	f.right = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.right:SetPoint("BOTTOMRIGHT", 0, 4)
	f.line = f:CreateTexture(nil, "ARTWORK")
	f.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
	f.line:SetPoint("BOTTOMLEFT", 0, 1)
	f.line:SetPoint("BOTTOMRIGHT", 0, 1)
	f.line:SetHeight(1)
	return f
end

local function MakeText()
	local f = CreateFrame("Frame", nil, content)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("TOPLEFT", 0, -2)
	f.text:SetPoint("RIGHT", 0, 0)
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(true)
	return f
end

local function MakeRow()
	local f = CreateFrame("Button", nil, content)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(16, 16)
	f.icon:SetPoint("LEFT", 2, 0)
	f.left = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.left:SetJustifyH("LEFT")
	f.left:SetWordWrap(false)
	f.right = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.right:SetPoint("RIGHT", -2, 0)
	f.right:SetJustifyH("RIGHT")
	f.left:SetPoint("RIGHT", f.right, "LEFT", -6, 0)
	local hl = f:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 0.82, 0, 0.12)
	f:SetScript("OnClick", function(self, button) if self.onClick then self.onClick(button) end end)
	f:SetScript("OnEnter", function(self) if self.tip then self.tip(self) end end)
	f:SetScript("OnLeave", GameTooltip_Hide)
	return f
end

local function MakeCheck()
	local f = CreateFrame("Frame", nil, content)
	f.box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.box:SetSize(22, 22)
	f.box:SetPoint("LEFT", 0, 0)
	f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.label:SetPoint("LEFT", f.box, "RIGHT", 4, 0)
	f.label:SetPoint("RIGHT", 0, 0)
	f.label:SetJustifyH("LEFT")
	f.label:SetWordWrap(false)
	f.box:SetScript("OnClick", function(self)
		local parent = self:GetParent()
		if parent.set then parent.set(self:GetChecked() and true or false) end
	end)
	f.box:SetScript("OnEnter", function(self)
		local parent = self:GetParent()
		if parent.tip then parent.tip(self) end
	end)
	f.box:SetScript("OnLeave", GameTooltip_Hide)
	return f
end

local function MakeButtons()
	local f = CreateFrame("Frame", nil, content)
	f.buttons = {}
	for i = 1, 3 do
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetHeight(22)
		b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
		f.buttons[i] = b
	end
	return f
end

local function MakeBar()
	local f = CreateFrame("Frame", nil, content)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetPoint("TOPLEFT", 0, -4)
	f.bg:SetPoint("BOTTOMRIGHT", 0, 4)
	f.bg:SetColorTexture(0, 0, 0, 0.5)
	f.bar = CreateFrame("StatusBar", nil, f)
	f.bar:SetPoint("TOPLEFT", 1, -5)
	f.bar:SetPoint("BOTTOMRIGHT", -1, 5)
	f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	f.bar:SetStatusBarColor(0.85, 0.65, 0.15)
	f.text = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("CENTER")
	return f
end

Pool("header", MakeHeader)
Pool("text", MakeText)
Pool("row", MakeRow)
Pool("check", MakeCheck)
Pool("buttons", MakeButtons)
Pool("bar", MakeBar)

local function Header(text, right)
	local f = Acquire("header")
	f.text:SetText(text or "")
	f.right:SetText(right or "")
	Place(f, HEADER_H)
end

local function Text(text, color)
	local f = Acquire("text")
	f.text:SetText(text or "")
	local c = color or MUTED
	f.text:SetTextColor(c[1], c[2], c[3])
	-- (its own height, wrapped to the panel's width)
	f.text:SetWidth(math.max(50, content:GetWidth()))
	Place(f, math.max(16, f.text:GetStringHeight() + 6))
end

-- spec: { left, right, icon, iconAtlas, color, rightColor, indent, onClick(button), tip(owner) }
local function Row(spec)
	local f = Acquire("row")
	local hasIcon = false
	f.icon:SetTexture(nil)
	if spec.iconAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(spec.iconAtlas) then
		f.icon:SetAtlas(spec.iconAtlas)
		hasIcon = true
	elseif spec.icon then
		f.icon:SetTexture(spec.icon)
		hasIcon = true
	end
	f.icon:SetShown(hasIcon)
	f.left:ClearAllPoints()
	f.left:SetPoint("LEFT", hasIcon and 22 or 4, 0)
	f.left:SetPoint("RIGHT", f.right, "LEFT", -6, 0)
	f.left:SetText(spec.left or "")
	local c = spec.color or { 1, 1, 1 }
	f.left:SetTextColor(c[1], c[2], c[3])
	f.right:SetText(spec.right or "")
	local rc = spec.rightColor or MUTED
	f.right:SetTextColor(rc[1], rc[2], rc[3])
	f.onClick, f.tip = spec.onClick, spec.tip
	Place(f, ROW_H, spec.indent)
	return f
end

local function Check(label, get, set, tip)
	local f = Acquire("check")
	f.label:SetText(label)
	f.get, f.set, f.tip = get, set, tip
	local ok, on = pcall(get)
	f.box:SetChecked(ok and on and true or false)
	Place(f, CHECK_H)
end

-- list: { { text, onClick, enabled }, ... } (up to 3)
local function Buttons(list)
	local f = Acquire("buttons")
	local n = #list
	local width = content:GetWidth()
	local each = (width - (n - 1) * 6) / math.max(n, 1)
	for i, b in ipairs(f.buttons) do
		local spec = list[i]
		b:ClearAllPoints()
		if spec then
			b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (each + 6), -1)
			b:SetWidth(each)
			b:SetText(spec[1])
			b.onClick = spec[2]
			b:SetEnabled(spec[3] ~= false)
			b:Show()
		else
			b:Hide()
		end
	end
	Place(f, BUTTON_H + 4)
end

local function Bar(value, max, text)
	local f = Acquire("bar")
	f.bar:SetMinMaxValues(0, math.max(1, max))
	f.bar:SetValue(value)
	f.text:SetText(text or "")
	Place(f, 22)
end

local function Gap(h) cursor = cursor + (h or 6) end

--------------------------------------------------------------------------------------------------------------------
-- Journey
--------------------------------------------------------------------------------------------------------------------

local function JourneyTab()
	local api = spfAPI()
	if not api then
		Text("Journeys need Shortest Path, which isn't running.")
		return
	end
	local ok, journey = pcall(api.Journey)
	if ok and type(journey) == "table" and journey.goal then
		Header(journey.goal.title or "?", timeText(journey.secondsLeft))
		for i, leg in ipairs(journey.legs or {}) do
			Row({ left = ("%d. %s"):format(i, leg.text or leg.mode or "?"), right = timeText(leg.seconds),
				color = i == 1 and GOLD or nil })
		end
		Gap()
		Buttons({ { CANCEL or "Cancel", function()
			if SPF.ClearJourney then SPF.ClearJourney() end
		end } })
	else
		Header("No journey")
		Text("Shift-click the map, or click a quest, a book, a service or a search result here, and Shortest Path takes you there: walking, flights, boats, zeppelins, portals and your hearthstone.")
	end
	Gap()
	-- the hearthstone: where it goes and whether it's ready
	local bind = GetBindLocation and GetBindLocation()
	if bind and bind ~= "" then
		local start, duration = 0, 0
		if C_Container and C_Container.GetItemCooldown then start, duration = C_Container.GetItemCooldown(6948)
		elseif GetItemCooldown then start, duration = GetItemCooldown(6948) end
		local left = (start or 0) > 0 and (start + duration - GetTime()) or 0
		Header(GetItemInfo and GetItemInfo(6948) or "Hearthstone")
		Row({ left = bind, right = left > 1 and timeText(left) or (READY or "Ready"),
			rightColor = left > 1 and MUTED or GREEN, icon = 134414 })
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------------------------------------------------

-- the quest log, as { headers = { { title, quests = { { id, title, level, complete } } } } }
local function QuestLog()
	local out, header = {}, nil
	local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries())
		or (GetNumQuestLogEntries and GetNumQuestLogEntries()) or 0
	for i = 1, n do
		local title, level, isHeader, complete, questID
		if C_QuestLog and C_QuestLog.GetInfo then
			local info = C_QuestLog.GetInfo(i)
			if info then
				title, level, isHeader, questID = info.title, info.level, info.isHeader, info.questID
				complete = questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false
			end
		elseif GetQuestLogTitle then
			local t, lv, _, hdr, _, comp, _, qid = GetQuestLogTitle(i)
			title, level, isHeader, complete, questID = t, lv, hdr, comp == 1, qid
		end
		if title then
			if isHeader then
				header = { title = title, quests = {} }
				out[#out + 1] = header
			elseif questID then
				if not header then header = { title = QUESTS, quests = {} } out[#out + 1] = header end
				header.quests[#header.quests + 1] = { id = questID, title = title, level = level, complete = complete }
			end
		end
	end
	return out
end

local function Objectives(questID)
	local list = {}
	local objectives = C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
	for _, o in ipairs(objectives or {}) do
		if o.text and o.text ~= "" then list[#list + 1] = (o.finished and "|cff66ff66" or "|cffffffff") .. o.text .. "|r" end
	end
	return list
end

-- where a quest is turned in: { npc name, map, x, y } at the finisher's spawn nearest you (Questie's database)
local function TurnIn(questID)
	local QDB = questie("QuestieDB")
	if not QDB then return nil end
	local quest = call(QDB.GetQuest, questID)
	local npcs = quest and quest.Finisher and quest.Finisher.NPC
	local objects = quest and quest.Finisher and quest.Finisher.GameObject
	local best
	for _, id in ipairs(npcs or {}) do
		local spot = nearestSpawn("npc", id)
		if spot and (not best or (spot.yards or 1e9) < (best.yards or 1e9)) then spot.name = npcName(id) best = spot end
	end
	for _, id in ipairs(objects or {}) do
		local spot = nearestSpawn("object", id)
		if spot and (not best or (spot.yards or 1e9) < (best.yards or 1e9)) then
			spot.name = call(QDB.QueryObjectSingle, id, "name") or "?"
			best = spot
		end
	end
	return best
end

-- one journey through every quest ready to turn in, nearest first from where you stand
local function RouteTurnIns(log)
	local api = spfAPI()
	if not (api and api.NavigateRoute) then say("journeys need Shortest Path.") return end
	local stops = {}
	for _, h in ipairs(log) do
		for _, q in ipairs(h.quests) do
			if q.complete then
				local t = TurnIn(q.id)
				if t then stops[#stops + 1] = { map = t.map, x = t.x, y = t.y, title = q.title, tooltip = t.name, kind = "turnin" } end
			end
		end
	end
	if #stops == 0 then say("no quest is ready to turn in.") return end
	-- nearest neighbour through them (one continent's yards; another continent after)
	local _, _, _, cont, px, py = here()
	local ordered, left = {}, stops
	while #left > 0 do
		local bestI, bestD = 1, nil
		for i, s in ipairs(left) do
			local c, wx, wy = worldOf(s.map, s.x, s.y)
			local d = (c and c == cont) and math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) or 1e9
			if not bestD or d < bestD then bestI, bestD = i, d end
		end
		local s = table.remove(left, bestI)
		ordered[#ordered + 1] = s
		cont, px, py = worldOf(s.map, s.x, s.y)
	end
	local ok, started = pcall(api.NavigateRoute, OWNER, ordered)
	if ok and started then say(("%d turn-ins, nearest first."):format(#ordered))
	else say(InCombatLockdown() and "journeys start once combat ends." or "Shortest Path couldn't plan that route.") end
end

-- quests Questie shows as available, nearest quest givers first (worked out again every 10 s at most: it reads
-- every quest giver's spawns)
local availableCache, availableAt = nil, 0
local function AvailableNear(limit)
	if availableCache and GetTime() - availableAt < 10 then return availableCache end
	local AQ, QDB = questie("AvailableQuests"), questie("QuestieDB")
	local byNpc = AQ and AQ.__availableQuestsByNpc
	if not (byNpc and QDB) then return {} end
	local list = {}
	for npcID, quests in pairs(byNpc) do
		local spot = nearestSpawn("npc", npcID)
		if spot and spot.yards then
			for questID in pairs(quests) do
				list[#list + 1] = { id = questID, npc = npcID, spot = spot }
			end
		end
	end
	table.sort(list, function(a, b) return a.spot.yards < b.spot.yards end)
	local out = {}
	for i = 1, math.min(limit, #list) do
		local q = list[i]
		q.title = call(QDB.QueryQuestSingle, q.id, "name") or ("#" .. q.id)
		q.level = call(QDB.QueryQuestSingle, q.id, "questLevel")
		out[#out + 1] = q
	end
	availableCache, availableAt = out, GetTime()
	return out
end

local function QuestsTab()
	local log = QuestLog()
	local ready = 0
	for _, h in ipairs(log) do for _, q in ipairs(h.quests) do if q.complete then ready = ready + 1 end end end
	Buttons({
		{ "Route turn-ins", function() RouteTurnIns(log) end, ready > 0 },
		{ "My Journey", function()
			local J = questie("QuestieJourney")
			if J and J.ToggleJourneyWindow then call(J.ToggleJourneyWindow, J) else say("My Journey needs Questie.") end
		end, questie("QuestieJourney") ~= nil },
	})
	if ready > 0 then
		Header("Ready to turn in", tostring(ready))
		for _, h in ipairs(log) do
			for _, q in ipairs(h.quests) do
				if q.complete then
					Row({ left = q.title, right = q.level and ("%d"):format(q.level) or "", color = GREEN,
						onClick = function()
							local t = TurnIn(q.id)
							if t then journeyTo(t.map, t.x, t.y, q.title, "turnin")
							elseif SPF.JourneyToQuest then call(SPF.JourneyToQuest, q.id) end
						end,
						tip = function(owner)
							local t = TurnIn(q.id)
							ShowTip(owner, q.title, { t and ("Turn in to " .. t.name) or "Turn in", "Click: a journey there" })
						end })
				end
			end
		end
	end
	local any = false
	for _, h in ipairs(log) do
		local open = {}
		for _, q in ipairs(h.quests) do if not q.complete then open[#open + 1] = q end end
		if #open > 0 then
			any = true
			Header(h.title, tostring(#open))
			for _, q in ipairs(open) do
				Row({ left = q.title, right = q.level and ("%d"):format(q.level) or "",
					onClick = function() if SPF.JourneyToQuest then call(SPF.JourneyToQuest, q.id) end end,
					tip = function(owner)
						local lines = Objectives(q.id)
						lines[#lines + 1] = "Click: a journey to it"
						ShowTip(owner, q.title, lines)
					end })
			end
		end
	end
	if not any and ready == 0 then
		Header(QUESTS)
		Text("Your quest log is empty.")
	end
	local near = AvailableNear(8)
	if #near > 0 then
		Header("Available near you")
		for _, q in ipairs(near) do
			Row({ left = "! " .. q.title, right = (q.level and ("%d · "):format(q.level) or "") .. ("%d yd"):format(q.spot.yards),
				color = GOLD,
				onClick = function() journeyTo(q.spot.map, q.spot.x, q.spot.y, npcName(q.npc), "pickup") end,
				tip = function(owner) ShowTip(owner, q.title, { "From " .. npcName(q.npc), "Click: a journey there" }) end })
		end
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Nearby
--------------------------------------------------------------------------------------------------------------------

local nearest = {}              -- key -> { place, seconds } or false (none), filled one a frame
local nearestQueue, nearestAt = {}, 0
local nearestWorker = CreateFrame("Frame")
nearestWorker:Hide()
nearestWorker:SetScript("OnUpdate", function(self)
	local key = table.remove(nearestQueue, 1)
	if not key then self:Hide() QueueRefresh() return end
	local place = SPF.NearbyNearest and call(SPF.NearbyNearest, key)
	local seconds
	if place and place.map and place.x then
		local api, mapID, x, y = spfAPI(), here()
		if api and api.Estimate and mapID then seconds = call(api.Estimate, mapID, x, y, place.map, place.x, place.y) end
	end
	nearest[key] = place and { place = place, seconds = seconds } or false
end)

local function NearbyTab()
	if not (public.Active("SPF") and SPF.NearbyRows) then
		Text("Nearby services need Shortest Path, which isn't running.")
		return
	end
	local rows = call(SPF.NearbyRows)
	if not rows then
		Text("Nearby services read Questie's database: it's still starting.")
		return
	end
	Buttons({ { "All services", function() call(SPF.NearbyOpen) end } })
	-- ranked again when you've moved on since the last time
	if GetTime() - nearestAt > 20 then
		nearestAt = GetTime()
		wipe(nearestQueue)
		for _, r in ipairs(rows) do nearestQueue[#nearestQueue + 1] = r.key end
		nearestWorker:Show()
	end
	Header("Near you")
	for _, r in ipairs(rows) do
		local n = nearest[r.key]
		local right = n == nil and "…" or (n and (n.seconds and timeText(n.seconds) or "")) or "none here"
		local icon = type(r.icon) == "number" and r.icon or nil
		local atlas = type(r.icon) == "string" and r.icon or nil
		Row({ left = r.label, right = right, icon = icon, iconAtlas = atlas, color = n == false and MUTED or nil,
			onClick = function() if n ~= false then call(SPF.NearbyGo, r.key, n and n.place or nil) end end,
			tip = function(owner)
				local lines = {}
				if n and n.place then lines[#lines + 1] = n.place.name or "" end
				lines[#lines + 1] = "Click: a journey to the nearest"
				ShowTip(owner, r.label, lines)
			end })
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Books
--------------------------------------------------------------------------------------------------------------------

local SET_ORDER = { 1, 35, 45, 60 }

local function BooksTab()
	if not (public.Active("Books") and BOOKS.BOOKS and BOOKS.db) then
		Text("The library books part isn't running.")
		return
	end
	local list, done = BOOKS.BOOKS, call(BOOKS.CountDone) or 0
	Bar(done, #list, ("%d / %d"):format(done, #list))
	local goals = {}
	for _, g in ipairs(BOOKS.GOALS or {}) do
		local label = BOOKS.GOAL_LABELS and BOOKS.GOAL_LABELS[g] and BOOKS.L and BOOKS.L[BOOKS.GOAL_LABELS[g]] or tostring(g)
		goals[#goals + 1] = (done >= g and "|cff66ff66" or "|cff999999") .. g .. "|r " .. label
	end
	if #goals > 0 then Text(table.concat(goals, "   ")) end
	Buttons({
		{ BOOKS.db.routeOn and "Stop route" or "Guide me", function() call(BOOKS.ToggleRoute, not BOOKS.db.routeOn) end },
		{ "Nearest", function() call(BOOKS.GoToNearest) end },
		{ "Book list", function() call(BOOKS.ToggleOptions) end },
	})
	local bySet = {}
	for _, b in ipairs(list) do bySet[b.set] = bySet[b.set] or {} table.insert(bySet[b.set], b) end
	for _, set in ipairs(SET_ORDER) do
		local books = bySet[set]
		if books then
			local missing = 0
			for _, b in ipairs(books) do if not call(BOOKS.IsDone, b) then missing = missing + 1 end end
			Header(set == 1 and "First set" or ("Level %d set"):format(set), ("%d left"):format(missing))
			for _, b in ipairs(books) do
				local isDone = call(BOOKS.IsDone, b)
				local loc = b.locs and b.locs[1]
				Row({ left = b.name, right = loc and loc[4] and loc[4]:gsub(",.*$", "") or "",
					icon = b.icon and ("Interface\\Icons\\" .. b.icon) or nil,
					color = isDone and MUTED or nil,
					onClick = function(button)
						if IsShiftKeyDown() then call(BOOKS.SetDone, b, not isDone) QueueRefresh() return end
						if loc then call(BOOKS.Waypoint, loc, b.name) end
					end,
					tip = function(owner)
						local lines = {}
						for _, l in ipairs(b.locs or {}) do lines[#lines + 1] = ("%s  (%.1f, %.1f)"):format(l[4] or "", l[2], l[3]) end
						lines[#lines + 1] = "Click: a journey there"
						lines[#lines + 1] = isDone and "Shift-click: not collected" or "Shift-click: collected"
						ShowTip(owner, b.name, lines)
					end })
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Map
--------------------------------------------------------------------------------------------------------------------

local function spfSetting(key, value)
	local setting = Settings and Settings.GetSetting and Settings.GetSetting("ShortestPathForever_" .. key)
	if setting and setting.SetValue then pcall(setting.SetValue, setting, value) end
	if SPF.db and SPF.db[key] ~= value then
		SPF.db[key] = value
		if SPF.RefreshMap then call(SPF.RefreshMap) end
	end
end

local function MapTab()
	local wm = openMapModule()
	Buttons({
		{ "Find me", function() if wm and wm.FindMe then call(wm.FindMe, wm) end end, wm ~= nil },
		{ "Drop a pin", function() if wm and wm.SetPinMode then call(wm.SetPinMode, true) end end, wm ~= nil },
		{ "Draw", function() if wm and wm.ToggleSketch then call(wm.ToggleSketch, wm, true) end end, wm ~= nil },
	})
	Buttons({
		{ "Map menu", function() if wm and wm.OpenMenu then call(wm.OpenMenu, wm) end end, wm ~= nil },
		{ SETTINGS or "Settings", function() public.OpenSettings() end },
	})
	Header("On the map")
	if public.Active("Books") and BOOKS.db then
		Check("Library books", function() return not BOOKS.db.hidden end,
			function(on) BOOKS.db.hidden = not on call(BOOKS.Refresh) end)
	end
	if public.Active("Questie") and Questie and Questie.db then
		Check("Quests (Questie)", function() return Questie.db.profile.enabled end, function(on)
			Questie.db.profile.enabled = on
			local QQ = questie("QuestieQuest")
			if QQ and QQ.ToggleNotes then call(QQ.ToggleNotes, QQ, on) end
		end)
	end
	if wm and wm.db then
		local function om(key, label, refresh)
			Check(label, function() return wm.db[key] ~= false end, function(on)
				wm.db[key] = on
				call(refresh or wm.Refresh, wm)
			end)
		end
		om("icons", "Dungeons and raids")
	end
	if public.Active("SPF") and SPF.db then
		local function sp(key, label)
			Check(label, function() return SPF.db[key] ~= false end, function(on) spfSetting(key, on) end)
		end
		sp("pins", "Boats and zeppelins")
		sp("transit", "Lifts and the tram")
		sp("portals", "Portals")
		sp("mapFlightMasters", "Flight masters")
		sp("mapRoutes", "Routes when you point at a dock")
		Check("Shops, trainers and inns", function() return SPF.db.townServices ~= "none" end, function(on)
			if on then
				spfSetting("townServices", (public.db and public.db.townServices) or "capitals")
			else
				if public.db then public.db.townServices = SPF.db.townServices end
				spfSetting("townServices", "none")
			end
		end)
	end
	if wm and wm.db then
		local function folk(key, label)
			if not (wm.db.townsfolk and wm.db.townsfolk[key] ~= nil) then return end
			Check(label, function() return wm.db.townsfolk[key] end, function(on)
				wm.db.townsfolk[key] = on
				call(wm.RefreshTownsfolk, wm)
			end)
		end
		folk("mailbox", "Mailboxes")
		folk("spirit", "Spirit healers")
		folk("rare", "Rare mobs")
		local function om(key, label, refresh)
			Check(label, function() return wm.db[key] ~= false end, function(on)
				wm.db[key] = on
				call(refresh or wm.Refresh, wm)
			end)
		end
		om("group", "Party and raid", function() call(wm.RefreshGroup) end)
		om("friends", "Friends", function() call(wm.RefreshFriends) end)
		Header("Look")
		om("zoneLevels", "Zone levels")
		om("coords", "Coordinates")
		om("playerArrow", "Your arrow")
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Search: zones and books as you type; quests, NPCs, objects and items (Questie's database) on Enter
--------------------------------------------------------------------------------------------------------------------

local zones                    -- { { id, name } } (once)
local function Zones()
	if zones then return zones end
	zones = {}
	local seen = {}
	for _, root in ipairs({ 1414, 1415, 947 }) do
		local ok, list = pcall(C_Map.GetMapChildrenInfo, root, Enum and Enum.UIMapType and Enum.UIMapType.Zone, true)
		for _, info in ipairs(ok and list or {}) do
			if not seen[info.mapID] and info.name then
				seen[info.mapID] = true
				zones[#zones + 1] = { id = info.mapID, name = info.name }
			end
		end
	end
	table.sort(zones, function(a, b) return a.name < b.name end)
	return zones
end

local dbResults                 -- the last Enter's database search: { quest = {}, npc = {}, object = {}, item = {} } of ids

local function SearchDatabase(text)
	local S = questie("QuestieSearch")
	if not S then dbResults = nil return end
	local ok, results = pcall(S.ByName, S, text)
	dbResults = ok and results or nil
end

local function ids(set)
	local list = {}
	for id in pairs(set or {}) do list[#list + 1] = id end
	table.sort(list)
	return list
end

local function SearchTab()
	local lower = query:lower()
	local count = 0
	-- zones
	local found = {}
	for _, z in ipairs(Zones()) do
		if z.name:lower():find(lower, 1, true) then found[#found + 1] = z end
		if #found >= MAX_RESULTS then break end
	end
	if #found > 0 then
		Header("Places")
		for _, z in ipairs(found) do
			Row({ left = z.name, onClick = function() WorldMapFrame:SetMapID(z.id) end,
				tip = function(owner) ShowTip(owner, z.name, { "Click: show it on the map" }) end })
		end
		count = count + #found
	end
	-- books
	if public.Active("Books") and BOOKS.BOOKS then
		local books = {}
		for _, b in ipairs(BOOKS.BOOKS) do
			if b.name:lower():find(lower, 1, true) then books[#books + 1] = b end
		end
		if #books > 0 then
			Header("Library books")
			for _, b in ipairs(books) do
				local loc = b.locs and b.locs[1]
				Row({ left = b.name, right = loc and loc[4] and loc[4]:gsub(",.*$", "") or "",
					icon = b.icon and ("Interface\\Icons\\" .. b.icon) or nil,
					onClick = function() if loc then call(BOOKS.Waypoint, loc, b.name) end end })
			end
			count = count + #books
		end
	end
	-- Questie's database, from the last Enter
	if dbResults then
		local QDB = questie("QuestieDB")
		local log = {}
		for _, h in ipairs(QuestLog()) do for _, q in ipairs(h.quests) do log[q.id] = true end end
		local quests = ids(dbResults.quest)
		if #quests > 0 and QDB then
			Header(QUESTS, #quests > MAX_RESULTS and (MAX_RESULTS .. "+") or tostring(#quests))
			for i = 1, math.min(MAX_RESULTS, #quests) do
				local id = quests[i]
				local name = call(QDB.QueryQuestSingle, id, "name") or ("#" .. id)
				local level = call(QDB.QueryQuestSingle, id, "questLevel")
				Row({ left = name, right = level and tostring(level) or "", color = log[id] and GREEN or nil,
					onClick = function()
						if log[id] and SPF.JourneyToQuest then call(SPF.JourneyToQuest, id) return end
						local starts = call(QDB.QueryQuestSingle, id, "startedBy")
						local npc = starts and starts[1] and starts[1][1]
						local spot = npc and nearestSpawn("npc", npc)
						if spot then journeyTo(spot.map, spot.x, spot.y, name, "pickup") else say("no quest giver to go to for that quest.") end
					end,
					tip = function(owner)
						ShowTip(owner, name, { log[id] and "In your log. Click: a journey to it" or "Click: a journey to its quest giver" })
					end })
			end
			count = count + #quests
		end
		for _, kind in ipairs({ { "npc", "NPCs" }, { "object", "Objects" } }) do
			local list = ids(dbResults[kind[1]])
			if #list > 0 and QDB then
				Header(kind[2], #list > MAX_RESULTS and (MAX_RESULTS .. "+") or tostring(#list))
				for i = 1, math.min(MAX_RESULTS, #list) do
					local id = list[i]
					local query = kind[1] == "npc" and QDB.QueryNPCSingle or QDB.QueryObjectSingle
					local name = call(query, id, "name") or ("#" .. id)
					local spot = nearestSpawn(kind[1], id)
					Row({ left = name, right = spot and spot.yards and ("%d yd"):format(spot.yards) or "",
						color = spot and nil or MUTED,
						onClick = function() if spot then journeyTo(spot.map, spot.x, spot.y, name) end end,
						tip = function(owner) ShowTip(owner, name, { spot and "Click: a journey to the nearest" or "Nowhere you can reach from here" }) end })
				end
				count = count + #list
			end
		end
		local items = ids(dbResults.item)
		if #items > 0 then
			Header(ITEMS or "Items", #items > MAX_RESULTS and (MAX_RESULTS .. "+") or tostring(#items))
			for i = 1, math.min(MAX_RESULTS, #items) do
				local id = items[i]
				local name = (GetItemInfo and GetItemInfo(id)) or (QDB and call(QDB.QueryItemSingle, id, "name")) or ("#" .. id)
				Row({ left = name, icon = GetItemIcon and GetItemIcon(id) or nil,
					tip = function(owner)
						GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
						if GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:AddLine(name) end
						GameTooltip:Show()
					end })
			end
			count = count + #items
		end
	elseif questie("QuestieSearch") then
		Text("Press Enter to search every quest, NPC, object and item too.")
	end
	if count == 0 then Text("Nothing found.") end
end

--------------------------------------------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------------------------------------------

local TABS = {
	{ key = "journey", label = "Journey", build = JourneyTab },
	{ key = "quests", label = QUESTS, build = QuestsTab },
	{ key = "nearby", label = "Nearby", build = NearbyTab },
	{ key = "books", label = "Books", build = BooksTab },
	{ key = "map", label = "Map", build = MapTab },
}

local function Refresh()
	refreshQueued = false
	if not (panel and panel:IsVisible()) then return end
	ReleaseAll()
	content:SetWidth(math.max(50, scrollFrame:GetWidth() - 4))
	if query ~= "" and #query >= 2 then
		SearchTab()
	else
		for _, t in ipairs(TABS) do
			if t.key == db.tab then call(t.build) end
		end
	end
	content:SetHeight(math.max(cursor + PAD, 1))
	for key, b in pairs(tabButtons) do
		local on = key == db.tab and query == ""
		b.selected:SetShown(on)
		b.line:SetShown(on)
		b.text:SetTextColor(on and GOLD[1] or 0.8, on and GOLD[2] or 0.8, on and GOLD[3] or 0.8)
	end
end
public.RefreshPanel = Refresh

QueueRefresh = function()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.15, Refresh)
end

local function SetOpen(open)
	db.open = open and true or false
	panel:SetShown(db.open)
	toggle:ClearAllPoints()
	if db.open then
		toggle:SetPoint("TOPRIGHT", panel, "TOPLEFT", -4, -4)
		Refresh()
	else
		toggle:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -8, -8)
	end
end

-- the panel at a tab, the map opened first
function public.OpenPanel(tab)
	if not (WorldMapFrame and WorldMapFrame:IsShown()) then
		if InCombatLockdown() then return false end
		if ToggleWorldMap then ToggleWorldMap() end
	end
	if not panel then return false end
	if tab then db.tab = tab end
	query = ""
	if searchBox then searchBox:SetText("") end
	SetOpen(true)
	return true
end

-- the panel open on a search: places and books at once, and the database too when `deep`
function public.SearchPanel(text, deep)
	if not public.OpenPanel() then return false end
	searchBox:SetText(text or "")
	query = (text or ""):match("^%s*(.-)%s*$")
	dbResults = nil
	if deep and #query >= 2 then SearchDatabase(query) end
	Refresh()
	return true
end

-- (the offline test reads how much a tab drew)
function public.PanelRows() return #used end

local function Build()
	if panel or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
	public.db = public.db or BookFinderDB or {}
	public.db.panel = public.db.panel or { open = true, tab = "journey" }
	db = public.db.panel

	local container = WorldMapFrame.ScrollContainer
	panel = CreateFrame("Frame", "BookFinderMapPanel", WorldMapFrame, "BackdropTemplate")
	panel:SetFrameStrata("DIALOG")
	panel:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
	panel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
	panel:SetWidth(WIDTH)
	panel:EnableMouse(true)
	if panel.SetBackdrop then
		panel:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		panel:SetBackdropColor(0, 0, 0, 0.88)
		panel:SetBackdropBorderColor(0.75, 0.62, 0.3, 1)
	end
	-- (narrower on a small map)
	container:HookScript("OnSizeChanged", function(self, w)
		panel:SetWidth((w or 0) < 760 and WIDTH_NARROW or WIDTH)
		if panel:IsVisible() then QueueRefresh() end
	end)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", PAD + 2, -PAD - 2)
	title:SetText("BookFinder")
	local gear = CreateFrame("Button", nil, panel)
	gear:SetSize(18, 18)
	gear:SetPoint("TOPRIGHT", -PAD - 22, -PAD)
	gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	gear:SetScript("OnClick", function() public.OpenSettings() end)
	gear:SetScript("OnEnter", function(self) ShowTip(self, SETTINGS or "Settings", { "Every part's settings" }) end)
	gear:SetScript("OnLeave", GameTooltip_Hide)
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() SetOpen(false) end)

	local ok, box = pcall(CreateFrame, "EditBox", "BookFinderMapSearch", panel, "SearchBoxTemplate")
	if not ok then box = CreateFrame("EditBox", "BookFinderMapSearch", panel, "InputBoxTemplate") end
	searchBox = box
	box:SetHeight(20)
	box:SetPoint("TOPLEFT", PAD + 4, -PAD - 26)
	box:SetPoint("TOPRIGHT", -PAD, -PAD - 26)
	box:SetAutoFocus(false)
	if box.Instructions then box.Instructions:SetText("Search places, quests, NPCs, items, books") end
	box:HookScript("OnTextChanged", function(self, user)
		local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
		if text ~= query then
			query = text
			dbResults = nil
			QueueRefresh()
		end
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		if #query >= 2 then SearchDatabase(query) Refresh() end
	end)
	box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)

	-- the tabs
	local tabsBar = CreateFrame("Frame", nil, panel)
	tabsBar:SetPoint("TOPLEFT", PAD, -PAD - 52)
	tabsBar:SetPoint("TOPRIGHT", -PAD, -PAD - 52)
	tabsBar:SetHeight(24)
	local prev
	for i, t in ipairs(TABS) do
		local b = CreateFrame("Button", nil, tabsBar)
		b:SetHeight(24)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.text:SetPoint("CENTER")
		b.text:SetText(t.label)
		b.selected = b:CreateTexture(nil, "BACKGROUND")
		b.selected:SetAllPoints()
		b.selected:SetColorTexture(1, 0.82, 0, 0.15)
		b.line = b:CreateTexture(nil, "ARTWORK")
		b.line:SetPoint("BOTTOMLEFT")
		b.line:SetPoint("BOTTOMRIGHT")
		b.line:SetHeight(2)
		b.line:SetColorTexture(1, 0.82, 0, 0.9)
		b:SetWidth((WIDTH - 2 * PAD) / #TABS)
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 0, 0) else b:SetPoint("LEFT", 0, 0) end
		b:SetScript("OnClick", function()
			db.tab = t.key
			query = ""
			searchBox:SetText("")
			Refresh()
		end)
		tabButtons[t.key] = b
		prev = b
	end
	tabsBar:SetScript("OnSizeChanged", function(self, w)
		for _, b in pairs(tabButtons) do b:SetWidth((w or 1) / #TABS) end
	end)

	scrollFrame = CreateFrame("ScrollFrame", "BookFinderMapPanelScroll", panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", PAD, -PAD - 82)
	scrollFrame:SetPoint("BOTTOMRIGHT", -PAD - 22, PAD)
	content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(WIDTH - 2 * PAD - 26, 1)
	scrollFrame:SetScrollChild(content)

	-- the one button on the map: opens and closes the panel
	toggle = CreateFrame("Button", "BookFinderMapToggle", WorldMapFrame)
	toggle:SetFrameStrata("DIALOG")
	toggle:SetSize(30, 30)
	toggle:SetNormalTexture("Interface\\AddOns\\" .. ADDON .. "\\OpenMap\\Media\\Textures\\OpenMapIconRound")
	toggle:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	toggle:SetScript("OnClick", function() SetOpen(not db.open) end)
	toggle:SetScript("OnEnter", function(self)
		ShowTip(self, "BookFinder", { db.open and "Click: close the panel" or "Click: open the panel" })
	end)
	toggle:SetScript("OnLeave", GameTooltip_Hide)

	-- kept current while it shows
	local events = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "BAG_UPDATE_COOLDOWN" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", function() if panel:IsVisible() and db.tab ~= "map" then QueueRefresh() end end)
	local api = spfAPI()
	if api and api.Subscribe then pcall(api.Subscribe, function() if panel:IsVisible() then QueueRefresh() end end) end
	-- the journey's time left, once a second while it shows
	local tick = 0
	panel:SetScript("OnUpdate", function(_, elapsed)
		tick = tick + elapsed
		if tick >= 1 then
			tick = 0
			if db.tab == "journey" and query == "" then Refresh() end
		end
	end)
	-- the books (collected, the route) follow Books' own refresh
	if BOOKS.RefreshBroker then
		local refreshBroker = BOOKS.RefreshBroker
		BOOKS.RefreshBroker = function(...)
			refreshBroker(...)
			if panel:IsVisible() and db.tab == "books" then QueueRefresh() end
		end
	end
	WorldMapFrame:HookScript("OnShow", function() if db.open then Refresh() end end)
	SetOpen(db.open)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	-- (after the parts' own login setup: the map is set up, Shortest Path and Questie have their modules)
	C_Timer.After(0, function()
		local ok, err = pcall(Build)
		if not ok then geterrorhandler()(err) end
	end)
end)
