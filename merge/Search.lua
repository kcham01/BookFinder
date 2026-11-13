-- BookFinder: one search for everything, in the BookFinder panel beside the quest log (BooksTab.lua's search box).
-- Typing two letters or more lists, in place of the books:
--   Quests     every quest Questie knows: its level and giver; click: a map pin on the giver nearest you
--   NPCs       every NPC: its title and zone; click: a map pin on its nearest spawn
--   Objects    every object (chests, herbs, quest objects): click: a map pin on the nearest one
--   Items      every item: where it drops or who sells it; click: a map pin on the nearest source
--   Places     every zone and city: click: the map there; Shift-click: a map pin in its middle
--   Books      the library books: click: a map pin on it
-- Questie's database is read once into a name index, a slice per frame, the first time the box is used; until then
-- the list says it is reading. Drawn with the books tab's kit (BooksTab.lua), so it matches the panel around it.
local ADDON, root = ...
local public = root.public
local Kit = public and public.Kit
if not (public and Kit) then return end
local function redraw() if public.RefreshSearch then public.RefreshSearch() end end

local L = setmetatable({}, { __index = function(_, k) return k end })
local SHOWN = 6          -- results per section before "type more to narrow it"
local MIN_DB = 3          -- letters before the database is searched
local SLICE = 1500        -- index entries read per frame

local function Q(name)
	local loader = rawget(_G, "QuestieLoader")
	if not (loader and loader.ImportModule) then return end
	local ok, mod = pcall(loader.ImportModule, loader, name)
	return ok and mod or nil
end

-- The index: names by type, read lazily ----------------------------------------------------------------------------
local TYPES = {
	{ key = "quest", label = QUESTS_LABEL or "Quests", query = "QueryQuestSingle", pointers = "QuestPointers", lib = "Quest" },
	{ key = "npc", label = "NPCs", query = "QueryNPCSingle", pointers = "NPCPointers", lib = "Npc" },
	{ key = "object", label = "Objects", query = "QueryObjectSingle", pointers = "ObjectPointers", lib = "Object" },
	{ key = "item", label = ITEMS or "Items", query = "QueryItemSingle", pointers = "ItemPointers", lib = "Item" },
}
local index = { ready = false, reading = false, ids = {}, names = {} }   -- per type: arrays of id and lower name
local indexDone, indexTotal = 0, 0

local function readIndex()
	if index.ready or index.reading then return end
	local db = Q("QuestieDB")
	if not db then return end
	-- every ID of a type: Questie's own list once its startup made it, else straight from the database
	local lib = rawget(_G, "LibQuestieDB")
	local function allIds(t)
		if type(db[t.pointers]) == "table" then return db[t.pointers] end
		local part = lib and lib[t.lib]
		if part and type(part.GetAllIds) == "function" then
			local ok, ids = pcall(part.GetAllIds, true)
			if ok and type(ids) == "table" then return ids end
		end
	end
	for _, t in ipairs(TYPES) do
		if not allIds(t) or type(db[t.query]) ~= "function" then return end
	end
	index.reading = true
	local jobs = {}
	for _, t in ipairs(TYPES) do
		index.ids[t.key], index.names[t.key] = {}, {}
		for id in pairs(allIds(t)) do jobs[#jobs + 1] = { t, id } end
	end
	indexTotal, indexDone = #jobs, 0
	local frame = CreateFrame("Frame")
	index.frame = frame
	frame:SetScript("OnUpdate", function(self)
		local stop = math.min(indexDone + SLICE, indexTotal)
		for i = indexDone + 1, stop do
			local t, id = jobs[i][1], jobs[i][2]
			local ok, name = pcall(db[t.query], id, "name")
			if ok and type(name) == "string" and name ~= "" then
				local ids, names = index.ids[t.key], index.names[t.key]
				ids[#ids + 1], names[#names + 1] = id, name:lower()
			end
		end
		indexDone = stop
		if indexDone >= indexTotal then
			self:SetScript("OnUpdate", nil)
			index.ready, index.reading = true, false
			jobs = nil
			redraw()
		end
	end)
end

-- Places: every zone, city and dungeon map under the continents, once
local places
local function readPlaces()
	if places then return places end
	places = {}
	if not (C_Map and C_Map.GetMapChildrenInfo) then return places end
	local seen = {}
	local function add(info, parent)
		if seen[info.mapID] then return end
		seen[info.mapID] = true
		places[#places + 1] = { mapID = info.mapID, name = info.name, lower = (info.name or ""):lower(), parent = parent }
	end
	for _, top in ipairs({ 1414, 1415, 1945 }) do
		local topInfo = C_Map.GetMapInfo(top)
		if topInfo then
			add(topInfo, nil)
			for _, child in ipairs(C_Map.GetMapChildrenInfo(top, nil, true) or {}) do
				if child.name and child.name ~= "" then add(child, topInfo.name) end
			end
		end
	end
	return places
end

-- Where things are --------------------------------------------------------------------------------------------------
local function playerWorld()
	local map = C_Map.GetBestMapForUnit("player")
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if not (pos and CreateVector2D and C_Map.GetWorldPosFromMapPos) then return end
	local cont, world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(pos.x, pos.y))
	if cont and world then return cont, world.x, world.y end
end

-- the spawn of `spawns` ({areaId = {{x, y}, ...}}) nearest the player: uiMap, x, y (0-100), yards (nil off-continent)
local function nearestSpawn(spawns)
	if type(spawns) ~= "table" then return end
	local zones = Q("ZoneDB")
	local cont, px, py = playerWorld()
	local best, bestD, first
	for area, points in pairs(spawns) do
		-- (Questie's zone table is ready once its startup ran; before that a spawn has no map)
		local okMap, map = false, nil
		if zones and zones.GetUiMapIdByAreaId then okMap, map = pcall(zones.GetUiMapIdByAreaId, zones, area) end
		if not okMap then map = nil end
		if map and type(points) == "table" then
			for _, p in ipairs(points) do
				local x, y = p[1], p[2]
				if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
					first = first or { map, x, y }
					if cont and CreateVector2D then
						local c, w = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x / 100, y / 100))
						if c == cont and w then
							local d = math.sqrt((w.x - px) ^ 2 + (w.y - py) ^ 2)
							if not bestD or d < bestD then best, bestD = { map, x, y }, d end
						end
					end
				end
			end
		end
	end
	best = best or first
	if best then return best[1], best[2], best[3], bestD end
end

local function zoneName(map)
	local info = map and C_Map.GetMapInfo(map)
	return info and info.name or nil
end

local function journey(map, x, y, title)
	return public.Waypoint and public.Waypoint(map, x, y, title) or false
end

local function yards(d)
	if not d then return "" end
	if d < 1000 then return ("%d yd"):format(math.floor(d / 10 + 0.5) * 10) end
	return ("%.1f km"):format(d / 1093.6)
end

-- What each kind of result is ---------------------------------------------------------------------------------------
local function db() return Q("QuestieDB") end
local function field(kind, id, name)
	local d = db()
	local t
	for _, tt in ipairs(TYPES) do if tt.key == kind then t = tt end end
	if not (d and t and d[t.query]) then return end
	local ok, v = pcall(d[t.query], id, name)
	return ok and v or nil
end

-- the nearest of several NPCs' and objects' spawns: uiMap, x, y, yards, the source's name
local function nearestOf(npcs, objects)
	local best
	local function try(kind, list)
		for _, id in ipairs(type(list) == "table" and list or {}) do
			local map, x, y, d = nearestSpawn(field(kind, id, "spawns"))
			if map and (not best or (d and (not best[4] or d < best[4]))) then
				best = { map, x, y, d, field(kind, id, "name") }
			end
		end
	end
	try("npc", npcs)
	try("object", objects)
	if best then return best[1], best[2], best[3], best[4], best[5] end
end

local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local ACTIVE_QUEST_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local NPC_ICON = "Interface\\Icons\\INV_Misc_Head_Human_01"
local OBJECT_ICON = "Interface\\Icons\\INV_Box_01"
local PLACE_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function inLog(questID)
	return C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

local function questSpec(id)
	local name = field("quest", id, "name") or ("#" .. id)
	local level = field("quest", id, "questLevel")
	local started = field("quest", id, "startedBy") or {}
	local logged = inLog(id)
	local giverName
	local map, x, y, d, source
	if logged then
		local finished = field("quest", id, "finishedBy") or {}
		map, x, y, d, source = nearestOf(finished[1], finished[2])
	else
		map, x, y, d, source = nearestOf(started[1], started[2])
	end
	giverName = source
	local where = zoneName(map)
	local detail = giverName and (where and ("%s · %s"):format(giverName, where) or giverName) or (where or "")
	if logged then detail = (L["In your log"] .. (detail ~= "" and (" · " .. L["turn in to"] .. " " .. detail) or "")) end
	return {
		key = "quest:" .. id, small = false, file = logged and ACTIVE_QUEST_ICON or QUEST_ICON,
		label = level and level > 0 and ("[%d] %s"):format(level, name) or name,
		detail = detail, time = yards(d), timeColor = Kit.GREY_RGB,
		tooltip = function(tt)
			tt:AddLine(name, 1, 0.82, 0)
			local text = field("quest", id, "objectivesText")
			if type(text) == "table" then text = table.concat(text, " ") end
			if type(text) == "string" and text ~= "" then tt:AddLine(text, 1, 1, 1, true) end
			local req = field("quest", id, "requiredLevel")
			if req and req > 0 then tt:AddLine(("%s %d"):format(LEVEL or "Level", req), 0.7, 0.7, 0.7) end
			tt:AddLine(" ")
			if map then tt:AddLine(logged and L["Click: a map pin where you turn it in"] or L["Click: a map pin on the quest giver"], 0.5, 1, 0.5) end
			tt:AddLine(L["Shift-click: link it"], 0.5, 1, 0.5)
		end,
		onClick = function()
			if IsShiftKeyDown() and ChatEdit_InsertLink then
				ChatEdit_InsertLink(("|cffffff00|Hquest:%d:%d|h[%s]|h|r"):format(id, level or 0, name))
			else
				journey(map, x, y, name)
			end
		end,
	}
end

local function spawnSpec(kind, id)
	local name = field(kind, id, "name") or ("#" .. id)
	local map, x, y, d = nearestSpawn(field(kind, id, "spawns"))
	local where = zoneName(map)
	local sub = kind == "npc" and field(kind, id, "subName")
	local detail = sub and sub ~= "" and ("<%s>"):format(sub) or ""
	if where then detail = detail ~= "" and (detail .. " · " .. where) or where end
	if kind == "npc" then
		local lo, hi = field("npc", id, "minLevel"), field("npc", id, "maxLevel")
		if lo and lo > 0 then detail = (lo == hi or not hi) and (("%s %d · "):format(LEVEL or "Level", lo) .. detail)
			or (("%s %d-%d · "):format(LEVEL or "Level", lo, hi) .. detail) end
	end
	return {
		key = kind .. ":" .. id, file = kind == "npc" and NPC_ICON or OBJECT_ICON,
		label = name, detail = detail ~= "" and detail or L["Not on any map"],
		time = yards(d), timeColor = Kit.GREY_RGB,
		tooltip = function(tt)
			tt:AddLine(name, 1, 0.82, 0)
			if where then tt:AddLine(where, 1, 1, 1) end
			tt:AddLine(" ")
			tt:AddLine(map and L["Click: a map pin on the nearest one"] or L["Not on any map"], 0.5, 1, 0.5)
		end,
		onClick = function() journey(map, x, y, name) end,
	}
end

local function itemSpec(id)
	local name = field("item", id, "name") or ("#" .. id)
	local map, x, y, d, source = nearestOf(field("item", id, "vendors"), nil)
	local how = map and L["Sold by %s"] or nil
	if not map then
		map, x, y, d, source = nearestOf(field("item", id, "npcDrops"), field("item", id, "objectDrops"))
		how = map and L["Drops from %s"] or nil
	end
	local where = zoneName(map)
	local detail = how and how:format(source or "?") or L["No known source"]
	if where then detail = detail .. " · " .. where end
	local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
	local color
	if quality and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		color = { r, g, b }
	end
	return {
		key = "item:" .. id, itemID = id, label = name, labelColor = color, detail = detail,
		time = yards(d), timeColor = Kit.GREY_RGB,
		tooltip = function(tt)
			tt:SetItemByID(id)
			tt:AddLine(" ")
			if map then tt:AddLine(L["Click: a map pin on the nearest source"], 0.5, 1, 0.5) end
		end,
		onClick = function()
			local link = select(2, (C_Item and C_Item.GetItemInfo or GetItemInfo)(id))
			if IsShiftKeyDown() and link and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
			journey(map, x, y, name)
		end,
	}
end

local function placeSpec(p)
	return {
		key = "place:" .. p.mapID, small = true, file = PLACE_ICON, label = p.name,
		time = p.parent or "", timeColor = Kit.GREY_RGB,
		tooltip = function(tt)
			tt:AddLine(p.name, 1, 0.82, 0)
			tt:AddLine(L["Click: show it on the map"], 0.5, 1, 0.5)
			tt:AddLine(L["Shift-click: a map pin in its middle"], 0.5, 1, 0.5)
		end,
		onClick = function()
			if IsShiftKeyDown() then journey(p.mapID, 50, 50, p.name)
			elseif WorldMapFrame then WorldMapFrame:SetMapID(p.mapID) end
		end,
	}
end

-- Searching ---------------------------------------------------------------------------------------------------------
local cache = { query = nil, sections = nil }
local collapsed = {}

-- the best `limit` matches: the exact name first, then names starting with it, then the rest; shorter names first
local function find(names, ids, q, limit)
	local hits, total = {}, 0
	for i = 1, #names do
		local at = names[i]:find(q, 1, true)
		if at then
			total = total + 1
			local name = names[i]
			hits[#hits + 1] = { rank = (name == q and 0 or at == 1 and 1 or 2), len = #name, id = ids[i], i = i }
		end
	end
	table.sort(hits, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.len ~= b.len then return a.len < b.len end
		return a.i < b.i
	end)
	local out = {}
	for i = 1, math.min(limit, #hits) do out[i] = hits[i].id end
	return out, total
end

local function search(q)
	local sections = {}
	-- places and books: from two letters
	local found = {}
	for _, p in ipairs(readPlaces()) do
		if p.lower:find(q, 1, true) then found[#found + 1] = p end
	end
	table.sort(found, function(a, b) return a.name < b.name end)
	if #found > 0 then
		local s = { key = "places", label = L["Places"], total = #found, rows = {} }
		for i = 1, math.min(#found, SHOWN) do s.rows[i] = placeSpec(found[i]) end
		sections[#sections + 1] = s
	end
	local books = root.Books
	if books and not books.__skip and books.BOOKS then
		local s = { key = "books", label = L["Library books"], rows = {} }
		local n = 0
		for _, b in ipairs(books.BOOKS) do
			local hit = (b.name or ""):lower():find(q, 1, true)
			for _, loc in ipairs(b.locs) do hit = hit or (loc[4] or ""):lower():find(q, 1, true) end
			if hit then
				n = n + 1
				if #s.rows < SHOWN then s.rows[#s.rows + 1] = Kit.BookSpec(b) end
			end
		end
		s.total = n
		if n > 0 then sections[#sections + 1] = s end
	end
	-- Questie's database: from three letters, once the index is read
	if #q >= MIN_DB and index.ready then
		for _, t in ipairs(TYPES) do
			local ids, total = find(index.names[t.key], index.ids[t.key], q, SHOWN)
			if total > 0 then
				local s = { key = t.key, label = L[t.label], total = total, rows = {} }
				for i, id in ipairs(ids) do
					local ok, spec = pcall(t.key == "quest" and questSpec or t.key == "item" and itemSpec
						or function(x) return spawnSpec(t.key, x) end, id)
					if ok and spec then s.rows[#s.rows + 1] = spec else index.lastError = spec end
				end
				-- (quests and items first, as the things most looked for)
				table.insert(sections, (t.key == "quest" or t.key == "item") and 1 or #sections + 1, s)
			end
		end
	end
	return sections
end

-- Drawing -----------------------------------------------------------------------
local Art = Kit.Art
local headers, rows, smalls, notes = {}, {}, {}, {}

local function CreateHeader(parent)
	local header = CreateFrame("Button", nil, parent)
	header:SetHeight(Kit.HEADER_HEIGHT)
	for _, layer in ipairs({ "BACKGROUND", "HIGHLIGHT" }) do
		local art = header:CreateTexture(nil, layer)
		Art.Band(art, "common-button-list-collapseExpand")
		if layer == "HIGHLIGHT" then art:SetBlendMode("ADD") art:SetAlpha(0.4) end
	end
	header.CollapseButton = CreateFrame("Button", nil, header, "CollapseButtonTemplate")
	header.CollapseButton:SetPoint("RIGHT", -6, 0)
	header.Count = header:CreateFontString(nil, "ARTWORK", "Game15Font_Shadow")
	header.Count:SetPoint("RIGHT", -28, 0)
	header.Name = header:CreateFontString(nil, "ARTWORK", "Game15Font_Shadow")
	header.Name:SetPoint("LEFT", 8, 0)
	header.Name:SetPoint("RIGHT", header.Count, "LEFT", -4, 0)
	header.Name:SetJustifyH("LEFT")
	header.Name:SetWordWrap(false)
	for _, text in ipairs({ header.Name, header.Count }) do text:SetTextColor(Kit.GOLD.r, Kit.GOLD.g, Kit.GOLD.b) end
	local function Toggle()
		collapsed[header.key] = not collapsed[header.key]
		redraw()
	end
	header:SetScript("OnClick", Toggle)
	header.CollapseButton:SetScript("OnClick", Toggle)
	return header
end

local shownCount = 0
local hinted = false

-- draws the results into the panel's list from `top` down; returns the new bottom and how many rows it drew
function public.DrawSearch(list, top, query, searchBox)
	if not hinted and searchBox and searchBox.Instructions then
		hinted = true
		searchBox.Instructions:SetText(L["Search quests, NPCs, items, places and books"])
	end
	local q = strtrim and strtrim((query or ""):lower()) or (query or ""):lower()
	local sections = {}
	if #q >= 2 then
		readIndex()
		if cache.query ~= q or cache.ready ~= index.ready then
			cache.query, cache.ready, cache.sections = q, index.ready, search(q)
		end
		sections = cache.sections
	end
	local rowAt, smallAt, headerAt, noteAt = 0, 0, 0, 0
	local function place(frame, height, indent)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 6 + (indent or 0), -top)
		frame:SetPoint("TOPRIGHT", -6, -top)
		frame:Show()
		top = top + height
	end
	if #q >= MIN_DB and not index.ready and index.reading then
		noteAt = noteAt + 1
		local note = notes[noteAt] or list:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		notes[noteAt] = note
		note:SetJustifyH("LEFT")
		note:SetText((L["Reading Questie's database… %d%%"]):format(math.floor(100 * indexDone / math.max(1, indexTotal))))
		note:ClearAllPoints()
		note:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -(top + 4))
		note:SetPoint("RIGHT", list, "RIGHT", -10, 0)
		note:Show()
		top = top + 22
	end
	for _, s in ipairs(sections) do
		headerAt = headerAt + 1
		local h = headers[headerAt] or CreateHeader(list)
		headers[headerAt] = h
		h.key = s.key
		h.Name:SetText(s.label)
		h.Count:SetText(s.total > #s.rows and ("%d of %d"):format(#s.rows, s.total) or tostring(s.total))
		if h.CollapseButton.UpdateCollapsedState then h.CollapseButton:UpdateCollapsedState(collapsed[s.key] and true or false) end
		place(h, Kit.HEADER_HEIGHT + Kit.HEADER_GAP)
		if not collapsed[s.key] then
			for _, spec in ipairs(s.rows) do
				local row
				if spec.small then
					smallAt = smallAt + 1
					row = smalls[smallAt] or Kit.CreateSmall(list)
					smalls[smallAt] = row
				else
					rowAt = rowAt + 1
					row = rows[rowAt] or Kit.CreateRow(list)
					rows[rowAt] = row
				end
				row.spec = spec
				Kit.Paint(row)
				place(row, (spec.small and Kit.SMALL_HEIGHT or Kit.ROW_HEIGHT) + Kit.ROW_GAP)
			end
			top = top + Kit.GROUP_GAP - Kit.ROW_GAP
		end
	end
	for i = rowAt + 1, #rows do rows[i]:Hide() end
	for i = smallAt + 1, #smalls do smalls[i]:Hide() end
	for i = headerAt + 1, #headers do headers[i]:Hide() end
	for i = noteAt + 1, #notes do notes[i]:Hide() end
	shownCount = rowAt + smallAt
	-- while the index reads, the percentage moves
	if index.reading and #q >= MIN_DB then
		C_Timer.After(0.25, redraw)
	end
	return top, shownCount + noteAt
end

-- for the offline test
public.SearchTest = {
	Run = function(q) cache.query = nil readIndex() return search(q) end,
	Progress = function() return indexDone, indexTotal, index.reading end,
	ReadNow = function()
		readIndex()
		local f = index.frame
		local step = f and f:GetScript("OnUpdate")
		for _ = 1, 100000 do
			if index.ready or not step then break end
			step(f)
		end
		return index.ready
	end,
	Index = index,
}
