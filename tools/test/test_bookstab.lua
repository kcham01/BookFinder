-- The Books tab beside the quest log.

local function setup()
	World.maps = { [1429] = { size = 3000, mapID = 1429, name = "Elwynn Forest", mapType = 3 } }
	Login()
	Tick(6)
	SlashCmdList.BOOKFINDERBOOKS("")
end

local function rows()
	local list = {}
	local content = BookFinderBooksTab.children
	for _, child in ipairs(content) do
		if child.kind == "ScrollFrame" then
			for _, inner in ipairs(child.children) do
				for _, r in ipairs(inner.children or {}) do if r.kind and r.shown then list[#list + 1] = r end end
			end
		end
	end
	return list
end

local function rowWith(fragment)
	for _, r in ipairs(rows()) do if r.text.text and r.text.text:find(fragment, 1, true) then return r end end
end

return {
	["/bom opens the map on the Books tab: the count, the four sets, the rewards"] = function(BF)
		setup()
		expect(WorldMapFrame.shown and BookFinderBooksTab.shown, "the Books tab open")
		equal(BookFinderBooksTab.count.text, "Books: 0/38", "the count")
		for _, set in ipairs({ "Starting set", "Level 35 set", "Level 45 set", "Level 60 set" }) do
			expect(rowWith(set), set)
		end
		equal(rowWith("Starting set").right.text, "0 / 16", "the set's count")
		expect(rowWith("10 books: Necklace"), "the first reward")
		expect(rowWith("You are not in a group."), "the group")
	end,

	["the Quests tab covers the books again"] = function(BF)
		setup()
		BF.MapTabs:Select("quests")
		expect(not BookFinderBooksTab.shown, "books hidden")
		BF.MapTabs:Select("books")
		expect(BookFinderBooksTab.shown, "books shown")
	end,

	["a book's tick box marks it collected; Hide all and Show all"] = function(BF)
		setup()
		local r = rows()[2] -- the first book of the starting set
		equal(r.kind, "book", "a book row")
		r.check:SetChecked(true)
		r.check.scripts.OnClick(r.check)
		equal(BF.Books:DoneCount(), 1, "one collected")
		Tick(1)
		equal(BookFinderBooksTab.count.text, "Books: 1/38", "the count follows")
		BF.Books:TickAll(true)
		equal(BF.Books:DoneCount(), 38, "all hidden")
		BF.Books:TickAll(false)
		equal(BF.Books:DoneCount(), 0, "all shown again")
	end,

	["a book in the bags cannot be unticked by hand"] = function(BF)
		World.bags[203755] = 1
		setup()
		local r = rowWith("Theocritus") or rows()[2]
		expect(r.check.checked, "ticked")
		equal(r.check.enabled, false, "the game decides it")
	end,

	["sets fold; the search narrows the list"] = function(BF)
		setup()
		local h = rowWith("Starting set")
		h.scripts.OnClick(h, "LeftButton")
		local books = 0
		for _, r in ipairs(rows()) do if r.kind == "book" then books = books + 1 end end
		equal(books, 22, "the 16 starting books folded away")
		rowWith("Starting set").scripts.OnClick(rowWith("Starting set"), "LeftButton") -- open it again
		local box = BookFinderBooksTab.search
		box.text = "Westfall"
		box.scripts.OnTextChanged(box)
		books = 0
		for _, r in ipairs(rows()) do if r.kind == "book" then books = books + 1 end end
		equal(books, 2, "the two books in Westfall")
	end,

	["the route: on, the next book first, Skip and Recalc shown"] = function(BF)
		setup()
		BookFinderBooksTab.routeButton.scripts.OnClick(BookFinderBooksTab.routeButton)
		expect(BF.BookRoute:IsOn(), "on")
		expect(rowWith("Optimized route"), "the route heading")
		expect(BookFinderBooksTab.skip.shown, "Skip")
		equal(BookFinderBooksTab.routeButton.text, "Stop the route", "the button says how to stop it")
	end,

	["a reward item: Shift-click links it, Ctrl-click tries it on"] = function(BF)
		setup()
		local item
		for _, r in ipairs(rows()) do if r.kind == "item" then item = r break end end
		World.shift = true
		item.scripts.OnClick(item, "LeftButton")
		World.shift = false
		expect(World.insertedLink, "linked")
		World.ctrl = true
		item.scripts.OnClick(item, "LeftButton")
		World.ctrl = false
		expect(World.triedOn, "tried on")
	end,
}
