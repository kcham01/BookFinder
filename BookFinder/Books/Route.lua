-- The books route: every book the player still needs, set by set (starting, 35, 45, 60), each set ordered for the
-- least travel (nearest first, then improved by swapping legs), each set starting where the previous one ended. Another
-- continent counts as a long trip. The route is guided by the map pin (and so the arrow and compass): it moves on to
-- the next book whenever one is collected or skipped. "Recalc" starts again from the book nearest to the player.
--
-- Messages: BF_BOOK_ROUTE_CHANGED()

local _, BF = ...
local L = BF.L

local Books = BF.Books
local Route = { steps = {} } -- steps: { {book =, place =}, ... }
BF.BookRoute = Route

local FAR = 100000 -- yards a trip to another continent counts as

local skipped = {} -- [key] = true: skipped this session

local function state() return BF:CharacterState("books") end

function Route:IsOn() return state().route == true end

-- Distances ----------------------------------------------------------------------------------------------------

local function world(place)
	if not place.world then
		local i, x, y = BF.Zones:ToWorld(place.map, place.x, place.y)
		place.world = { i, x, y }
	end
	return place.world
end

local function distance(a, b)
	if not a[1] or a[1] ~= b[1] then return FAR end
	local dx, dy = a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy)
end

-- Ordering one set from a starting point: nearest first, then 2-opt (reverse any stretch that shortens the route).
local function orderSet(books, from)
	local stops = {}
	for _, b in ipairs(books) do stops[#stops + 1] = { book = b, places = Books:Places(b) } end
	local order, here = {}, from
	while #stops > 0 do
		local bestI, bestPlace, bestD = nil, nil, math.huge
		for i, s in ipairs(stops) do
			for _, p in ipairs(s.places) do
				local d = distance(here, world(p))
				if d < bestD then bestI, bestPlace, bestD = i, p, d end
			end
		end
		if not bestI then break end
		local s = table.remove(stops, bestI)
		order[#order + 1] = { book = s.book, place = bestPlace }
		here = world(bestPlace)
	end
	local function legs(i, j) return distance(i == 0 and from or world(order[i].place), world(order[j].place)) end
	local improved = true
	local guard = 0
	while improved and guard < 50 do
		improved, guard = false, guard + 1
		for i = 1, #order - 1 do
			for j = i + 1, #order do
				local before = legs(i - 1, i) + (j < #order and legs(j, j + 1) or 0)
				local after = legs(i - 1, j) + (j < #order and distance(world(order[i].place), world(order[j + 1].place)) or 0)
				if after + 1 < before then
					-- reverse order[i..j]
					local a, b = i, j
					while a < b do
						order[a], order[b] = order[b], order[a]
						a, b = a + 1, b - 1
					end
					improved = true
				end
			end
		end
	end
	return order, here
end

--- Works the route out again from where the player stands (nearestFirst: the nearest book first, whatever its set).
function Route:Build(nearestFirst)
	local instance, px, py = BF.Zones:PlayerWorld()
	local here = { instance, px or 0, py or 0 }
	local bySet = {}
	for _, b in ipairs(Books.list) do
		if not Books:IsDone(b) and not skipped[b.key] and (not BF:Get("books.onlyMyLevel") or Books:ForMyLevel(b)) then
			bySet[b.set] = bySet[b.set] or {}
			table.insert(bySet[b.set], b)
		end
	end
	local steps = {}
	if nearestFirst then
		local best, bestPlace, bestD
		for _, books in pairs(bySet) do
			for _, b in ipairs(books) do
				for _, p in ipairs(Books:Places(b)) do
					local d = distance(here, world(p))
					if not bestD or d < bestD then best, bestPlace, bestD = b, p, d end
				end
			end
		end
		if best then
			steps[1] = { book = best, place = bestPlace }
			here = world(bestPlace)
			for _, books in pairs(bySet) do
				for i = #books, 1, -1 do if books[i] == best then table.remove(books, i) end end
			end
		end
	end
	for _, set in ipairs(Books.SETS) do
		if bySet[set] then
			local order
			order, here = orderSet(bySet[set], here)
			for _, s in ipairs(order) do steps[#steps + 1] = s end
		end
	end
	Route.steps = steps
	Route:Guide()
	BF:Send("BF_BOOK_ROUTE_CHANGED")
	return steps
end

function Route:Next()
	local s = Route.steps[1]
	return s and s.book, s and s.place
end

--- The book's step number on the route (1 = next), or nil.
function Route:StepOf(book)
	if not Route:IsOn() then return nil end
	for i, s in ipairs(Route.steps) do if s.book == book then return i end end
end

--- Puts the map pin on the next step.
function Route:Guide()
	local book, place = Route:Next()
	if Route:IsOn() and book then
		BF.Waypoint:Set(place.map, place.x, place.y, Books:Name(book), L[book.place or ""])
	end
end

function Route:Start()
	state().route = true
	Route:Build(false)
	BF:Print(L["route: %d books, lowest level first."], #Route.steps)
end

function Route:Stop()
	state().route = nil
	Route.steps = {}
	BF:Send("BF_BOOK_ROUTE_CHANGED")
end

function Route:Toggle()
	if Route:IsOn() then Route:Stop() else Route:Start() end
end

--- Skips the next book for this session.
function Route:Skip()
	local book = Route:Next()
	if not book then return end
	skipped[book.key] = true
	table.remove(Route.steps, 1)
	Route:Guide()
	BF:Send("BF_BOOK_ROUTE_CHANGED")
end

function Route:Recalc()
	wipe(skipped)
	Route:Build(true)
end

--- The route as chat lines (/bf books route list).
function Route:Print()
	for i, s in ipairs(Route.steps) do
		BF:Print("%d. %s - %s (%s)", i, Books:Name(s.book), L[s.book.place or ""], BF.Zones:FormatCoords(s.place.x, s.place.y))
	end
end

BF:At("world", function()
	if Route:IsOn() then Route:Build(false) end
	BF:Listen("BF_BOOKS_CHANGED", function()
		if not Route:IsOn() then return end
		-- A collected book leaves the route; the next one is guided to.
		local first = Route.steps[1]
		for i = #Route.steps, 1, -1 do
			if Books:IsDone(Route.steps[i].book) then table.remove(Route.steps, i) end
		end
		if Route.steps[1] ~= first then Route:Guide() end
		BF:Send("BF_BOOK_ROUTE_CHANGED")
	end)
end)
