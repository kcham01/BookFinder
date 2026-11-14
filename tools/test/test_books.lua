return {
	["books: 38 in Books on map's order, with places from the data"] = function(BF)
		Login()
		equal(BF.Books:Count(), 38, "38 books")
		equal(BF.Books.list[1].key, "theocritus", "first")
		equal(BF.Books.list[38].key, "necromancy", "last")
		local places = BF.Books:Places(BF.Books.byKey.rumi)
		equal(#places, 2, "Rumi in two places")
		local p = BF.Books:Places(BF.Books.byKey.theocritus)[1]
		equal(p.map, 1429, "Tower of Azora in Elwynn")
		expect(math.abs(p.x - 0.654) < 0.001, "x")
		equal(#BF.Books:Places(BF.Books.byKey.apothecary), 1, "two spawns a hair apart are one place")
	end,

	["books: collected by bags, bank, hand-in or by hand"] = function(BF)
		World.bags[203755] = 1          -- Theocritus in the bags
		World.bank = { [203754] = 1 }   -- Antonidas in the bank
		World.completed[78142] = true   -- Bewitchments handed in
		Login()
		local B = BF.Books
		equal(B:How(B.byKey.theocritus), "carried", "bags")
		equal(B:How(B.byKey.antonidas), "carried", "bank")
		equal(B:How(B.byKey.bewitchments), "handedIn", "handed in")
		B:Tick(B.byKey.goaz, true)
		equal(B:How(B.byKey.goaz), "ticked", "by hand")
		equal(B:DoneCount(), 4, "four")
	end,

	["books: looting one says so and shows the card"] = function(BF)
		Login()
		local found
		BF:Listen("BF_BOOK_FOUND", function(_, b) found = b end)
		World.bags[209848] = 1 -- Goaz Scrolls
		Fire("BAG_UPDATE_DELAYED")
		Tick(0.5)
		equal(found and found.key, "goaz", "found")
		expect(BookFinderBookCard:IsShown(), "card")
		expect(World.printed[#World.printed]:find("1/38", 1, true), "chat line: " .. tostring(World.printed[#World.printed]))
	end,

	["group: Books on map's protocol, both ways"] = function(BF)
		IsInGroup = function() return true end
		GetNumGroupMembers = function() return 2 end
		UnitName = function(unit)
			if unit == "player" then return "Ada", "Lovelace" end
			if unit == "party1" then return "Daeler", "Backbi" end
		end
		World.bags[203755] = 1
		Login()
		Tick(1.5)
		local sent = World.sentMessages[1]
		equal(sent[1], "BooksOnMapFE", "prefix")
		equal(sent[2], "S38:1" .. string.rep("0", 37) .. ":test BookFinder", "our state")
		equal(sent[3], "PARTY", "to the party")
		equal(World.sentMessages[2][2], "R", "asks for theirs")
		-- Theirs: they have the second book only.
		Fire("CHAT_MSG_ADDON", "BooksOnMapFE", "S38:01" .. string.rep("0", 36) .. ":2.3.0", "PARTY", "Daeler Backbi-Forever")
		expect(BF.Books:MemberHas("Daeler Backbi", BF.Books.list[2]), "they have Antonidas")
		local missing = BF.Books:MembersMissing(BF.Books.list[1])
		equal(missing[1], "Daeler Backbi", "they still need Theocritus")
		-- Another list (older version): listed, books not used.
		Fire("CHAT_MSG_ADDON", "BooksOnMapFE", "S37:" .. string.rep("0", 37) .. ":2.2.6", "PARTY", "Daeler Backbi-Forever")
		equal(BF.Books.otherList["Daeler Backbi"], "2.2.6", "other version")
		expect(not BF.Books.group["Daeler Backbi"], "not shared")
	end,

	["route: set by set, guided by the map pin, moves on when one is found"] = function(BF)
		World.player.level = 60
		World.maps = { [1429] = { size = 3000 } }
		Login()
		BF.BookRoute:Start()
		local first = BF.BookRoute:Next()
		equal(first.set, 1, "starting set first")
		expect(World.waypoint, "map pin on the first book")
		local count = #BF.BookRoute.steps
		World.completed[first.quest] = true
		BF:Send("BF_COMPLETED_CHANGED", first.quest)
		Tick(0.5)
		equal(#BF.BookRoute.steps, count - 1, "one less")
		expect(BF.BookRoute:Next() ~= first, "moved on")
	end,
}
