-- The library books: which the player has, where the others are, and the group sharing that Books on map speaks.
--
-- A book counts as collected when it is in the bags or the bank, when its library quest has been handed in, or
-- when the player ticked it by hand. Looting one says so (chat and the "Book found!" card); one found in the bank or
-- already handed in is ticked off quietly.
--
-- Messages: BF_BOOKS_CHANGED() (the player's own books)  BF_BOOKS_GROUP_CHANGED() (what the group shares)
--           BF_BOOK_FOUND(book)  BF_BOOK_GOAL(goal)

local _, BF = ...
local L = BF.L

local Books = BF.Books
local list = Books.list

-- Settings (the Books tab) ---------------------------------------------------------------------------------------

local S = BF.Settings
local P = "Books/Books"
local G = "Settings"
S:Define("books.map", { default = true, page = P, group = G, label = "Show on the map" })
S:Define("books.mapSize", { default = 20, min = 10, max = 40, step = 1, page = P, group = G, label = "Map icon size" })
S:Define("books.minimap", { default = true, page = P, group = G, label = "Show books on the minimap" })
S:Define("books.minimapSize", { default = 14, min = 8, max = 30, step = 1, page = P, group = G, label = "Minimap icon size" })
S:Define("books.notifyCollected", { default = true, page = P, group = G, label = "Notify when a book is collected" })
S:Define("books.alertNearby", { default = true, page = P, group = G, label = "Alert when a book is nearby" })
G = "Filters"
S:Define("books.hideCollected", { default = true, page = P, group = G, label = "Hide collected books" })
S:Define("books.onlyMyLevel", { default = false, page = P, group = G, label = "Only sets for my level" })
S:Define("books.groupMissing", { default = true, page = P, group = G, label = "Also show the books my group is missing" })

-- Lookups --------------------------------------------------------------------------------------------------------

Books.byKey, Books.byItem, Books.byQuest = {}, {}, {}
for i, b in ipairs(list) do
	b.index = i
	Books.byKey[b.key], Books.byItem[b.item], Books.byQuest[b.quest] = b, b, b
end

function Books:Count() return #list end

local function state() return BF:CharacterState("books") end

--- The book's name in the client's language (the item's name), English while the client has not loaded it.
local english = {}
function Books:Name(book)
	local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(book.item)
	if name then return name end
	if not english[book.item] then english[book.item] = BF:ItemName(book.item) end
	return english[book.item] or book.key
end

function Books:Icon(book)
	return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(book.item)) or "Interface\\Icons\\INV_Misc_Book_09"
end

-- Collected ------------------------------------------------------------------------------------------------------

--- How the player has it: "handedIn", "carried" (bags or bank), "ticked" (by hand), or nil (still missing).
function Books:How(book)
	if BF.Player:HasCompleted(book.quest) then return "handedIn" end
	if GetItemCount(book.item, true) > 0 then return "carried" end
	if state().ticked and state().ticked[book.key] then return "ticked" end
	return nil
end

function Books:IsDone(book)
	return Books:How(book) ~= nil
end

function Books:DoneCount()
	local n = 0
	for _, b in ipairs(list) do if Books:IsDone(b) then n = n + 1 end end
	return n
end

--- Ticks a book by hand (or untick: done = false). Tick boxes, Shift-click on its pin, /bf books done N.
function Books:Tick(book, done)
	local s = state()
	s.ticked = s.ticked or {}
	s.ticked[book.key] = done and true or nil
	BF:Send("BF_BOOKS_CHANGED")
	if done then BF:Print(L["%s collected (%d/%d)"], Books:Name(book), Books:DoneCount(), #list) else
		BF:Print(L["%s shown on the map again"], Books:Name(book))
	end
end

--- Every book still missing ticked by hand (done = true: Hide all), or every hand tick taken off (Show all). One
--- message, one chat line.
function Books:TickAll(done)
	local s = state()
	s.ticked = s.ticked or {}
	local n = 0
	for _, b in ipairs(list) do
		if done and not Books:IsDone(b) then
			s.ticked[b.key] = true
			n = n + 1
		elseif not done and s.ticked[b.key] then
			s.ticked[b.key] = nil
			n = n + 1
		end
	end
	if n == 0 then return end
	BF:Send("BF_BOOKS_CHANGED")
	BF:Print(done and L["%d books hidden from the map."] or L["%d books shown on the map again."], n)
end

-- Watching for new books -------------------------------------------------------------------------------------------

local known = {} -- [key] = true once seen as done this session

local function snapshot()
	for _, b in ipairs(list) do known[b.key] = Books:IsDone(b) or nil end
end

local function check()
	local changed = false
	local before = Books:DoneCount()
	for _, b in ipairs(list) do
		local done = Books:IsDone(b)
		if done and not known[b.key] then
			known[b.key] = true
			changed = true
			-- Looted just now (in the bags, not handed in): say so.
			if Books:How(b) == "carried" and BF:Get("books.notifyCollected") then
				BF:Print(L["%s collected (%d/%d)"], Books:Name(b), Books:DoneCount(), #list)
				BF:Send("BF_BOOK_FOUND", b)
			end
		elseif not done and known[b.key] then
			known[b.key] = nil
			changed = true
		end
	end
	if changed then
		local after = Books:DoneCount()
		for _, r in ipairs(Books.REWARDS) do
			if before < r.goal and after >= r.goal then BF:Send("BF_BOOK_GOAL", r.goal) end
		end
		BF:Send("BF_BOOKS_CHANGED")
	end
end
local checkSoon = BF:Debounce(0.3, check)

BF:At("login", function()
	snapshot()
	BF:On("BAG_UPDATE_DELAYED", checkSoon)
	BF:On("BANKFRAME_OPENED", checkSoon)
	BF:On("PLAYERBANKSLOTS_CHANGED", checkSoon)
	BF:Listen("BF_COMPLETED_CHANGED", function(_, quest) if Books.byQuest[quest] then checkSoon() end end)
	-- The item cache fills in after login: names and the bank's counts settle a few seconds in.
	BF:After(5, check)
end, 20)

-- Places ---------------------------------------------------------------------------------------------------------

--- Where a book is: { {map, x, y, area}, ... } (0..1 on the client's map), from the book's own spots or the data.
--- Spots of the same book closer than a hair are one place (the data sometimes holds both ends of a table).
local placesCache = {}
function Books:Places(book)
	local cached = placesCache[book.key]
	if cached then return cached end
	local places = {}
	local function add(map, x, y)
		for _, p in ipairs(places) do
			if p.map == map and math.abs(p.x - x) < 0.01 and math.abs(p.y - y) < 0.01 then return end
		end
		places[#places + 1] = { map = map, x = x, y = y }
	end
	if book.at then
		for _, spot in ipairs(book.at) do
			local map = BF.Zones:UiMapForArea(spot[1])
			if map then add(map, spot[2] / 100, spot[3] / 100) end
		end
	else
		local item = BF:Item(book.item)
		for _, object in ipairs(item and item[BF.I.objectDrops] or {}) do
			local o = BF:Object(object)
			BF.Zones:EachSpawn(o and o[BF.O.spawns], function(map, x, y, inside)
				if not inside then add(map, x, y) end
			end)
		end
	end
	placesCache[book.key] = places
	return places
end

--- Whether the book's set suits the player's level (the "Only sets for my level" filter).
function Books:ForMyLevel(book)
	return book.set <= math.max(1, BF.Player.level or 1)
end

--- The next reward: { goal, label, kind } or nil when all are reached.
function Books:NextReward()
	local done = Books:DoneCount()
	for _, r in ipairs(Books.REWARDS) do
		if done < r.goal then return r end
	end
end

-- Group sharing (Books on map's protocol, BooksOnMapFE) ------------------------------------------------------------
--
-- "S<count>:<one 0/1 per book, in list order>:<version>" tells the group what we have, a second after any change
-- (several changes make one message) and when the group changes; "R" asks everyone for theirs. A state whose count
-- or length differs from ours is another version's list: the player is listed, their books are not used.

local PREFIX = "BooksOnMapFE"
local SEND_DELAY = 1
Books.group = {}     -- [name] = { bits = "0101...", version = "2.3.0" }
Books.otherList = {} -- [name] = version (another book list)

local function channel()
	if IsInRaid() then return "RAID" elseif IsInGroup() then return "PARTY" end
end

--- Full name without the realm. WoW: Forever's names are two words, and UnitName gives the surname as the realm.
function Books:UnitFullName(unit)
	local name, surname = UnitName(unit)
	if issecretvalue and (issecretvalue(name) or issecretvalue(surname)) then return nil end
	if name and surname and surname ~= "" then return name .. " " .. surname end
	return name
end

local function shortName(sender)
	return (sender:gsub("%-[^%-]*$", ""))
end

local function encode()
	local bits = {}
	for i, b in ipairs(list) do bits[i] = Books:IsDone(b) and "1" or "0" end
	return ("S%d:%s:%s"):format(#list, table.concat(bits), (BF.version or "?") .. " BookFinder")
end

local pending, pendingRequest
function Books:SendState(request)
	if not channel() then return end
	pendingRequest = pendingRequest or request
	if pending then return end
	pending = true
	BF:After(SEND_DELAY, function()
		pending = false
		local ch = channel()
		if ch then
			C_ChatInfo.SendAddonMessage(PREFIX, encode(), ch)
			if pendingRequest then C_ChatInfo.SendAddonMessage(PREFIX, "R", ch) end
		end
		pendingRequest = nil
	end)
end

--- Whether a group member who shares their books has this one.
function Books:MemberHas(name, book)
	local m = Books.group[name]
	return m and m.bits:sub(book.index, book.index) == "1"
end

--- Group members (sharing their books) who still need this book.
function Books:MembersMissing(book)
	local out = {}
	for name, m in pairs(Books.group) do
		if m.bits:sub(book.index, book.index) == "0" then out[#out + 1] = name end
	end
	table.sort(out)
	return out
end

local function inGroup(name)
	for i = 1, GetNumGroupMembers() do
		local unit = IsInRaid() and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
		if Books:UnitFullName(unit) == name then return true end
	end
	return false
end

local function prune()
	local changed = false
	for _, t in ipairs({ Books.group, Books.otherList }) do
		for name in pairs(t) do
			if not inGroup(name) then t[name] = nil changed = true end
		end
	end
	if changed then BF:Send("BF_BOOKS_GROUP_CHANGED") end
end

BF:At("login", function()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	BF:On("CHAT_MSG_ADDON", function(_, prefix, msg, _, sender)
		if prefix ~= PREFIX or not sender or (issecretvalue and issecretvalue(sender)) then return end
		local name = shortName(sender)
		if name == Books:UnitFullName("player") then return end
		if msg == "R" then
			Books:SendState()
			return
		end
		local n, bits, version = msg:match("^S(%d+):([01]+):?(.*)$")
		version = version ~= "" and version or nil
		if n and tonumber(n) == #list and #bits == #list then
			local m = Books.group[name]
			if not m or m.bits ~= bits or m.version ~= version then
				Books.group[name] = { bits = bits, version = version }
				Books.otherList[name] = nil
				BF:Send("BF_BOOKS_GROUP_CHANGED")
			end
		elseif msg:sub(1, 1) == "S" then
			Books.group[name] = nil
			Books.otherList[name] = version or "?"
			BF:Send("BF_BOOKS_GROUP_CHANGED")
		end
	end)
	BF:On("GROUP_ROSTER_UPDATE", function()
		prune()
		Books:SendState(true)
	end)
	BF:Listen("BF_BOOKS_CHANGED", function() Books:SendState() end)
	Books:SendState(true)
end, 21)

-- Item tooltips ----------------------------------------------------------------------------------------------------
--
-- Every library book's tooltip says whether the player has it, and its set: "Library book - collected (Starting set)"
-- in green, "Library book - missing (Level 35 set)" in red, as Books on map writes it.

--- "Starting set", "Level 35 set"...
function Books:SetName(set)
	if set == 1 then return L["Starting set"] end
	return L["Level %d set"]:format(set)
end

BF.Tooltips:Register("item", function(tip, item)
	local book = Books.byItem[item]
	if not book then return end
	local done = Books:IsDone(book)
	local text = ("%s - %s (%s)"):format(L["Library book"], done and L["collected"] or L["missing"], Books:SetName(book.set))
	if done then tip:AddLine(text, 0.2, 1, 0.2) else tip:AddLine(text, 1, 0.25, 0.25) end
end)
