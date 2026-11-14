-- The WoW: Forever library books, written by BookFinder.
--
-- The ORDER is part of the group protocol shared with Books on map (BooksOnMapFE: one bit per book, in this order;
-- docs/study/books-on-map.md): never reorder, insert or remove without matching that list. Names come from the game
-- (the item's name, localized by the client). Positions come from the data: the object each book lies in, where it
-- spawns (BF.Data); a book whose useful spot differs (a cave mouth, a mountain's inside) gives its own spot and a hint.
--
-- Fields: key (stable, ours), item, quest (the library turn-in), set (1 = starting set; 35, 45, 60 by level),
-- place (where it is, English; BF.L translates), at = { {area, x, y}, ... } to show instead of the data's spots,
-- hint = a line about getting to it.

local _, BF = ...

local Books = { list = {} }
BF.Books = Books

Books.list = {
	-- Starting set (16)
	{ key = "theocritus", item = 203755, quest = 79092, set = 1, place = "Tower of Azora, Elwynn Forest" },
	{ key = "antonidas", item = 203754, quest = 79091, set = 1, place = "Ironforge" },
	{ key = "bewitchments", item = 209845, quest = 78142, set = 1, place = "Moonbrook, Westfall" },
	{ key = "rumi", item = 208860, quest = 79093, set = 1, place = "Sentinel Hill, Westfall; or Thelsamar, Loch Modan" },
	{ key = "anatomy", item = 209849, quest = 78147, set = 1, place = "The Darkened Bank, Duskwood" },
	{ key = "sorcererKings", item = 209850, quest = 78148, set = 1, place = "Mo'grosh Stronghold, Loch Modan" },
	{ key = "goaz", item = 209848, quest = 78146, set = 1, place = "Whelgar's Excavation Site, Wetlands" },
	{ key = "dalaranDigest", item = 209844, quest = 78127, set = 1, place = "Ambermill, Silverpine Forest" },
	{ key = "ataeric", item = 210177, quest = 79096, set = 1, place = "The Sepulcher, Silverpine Forest",
		hint = "Inside the tomb, by Sebastian Meloche." },
	{ key = "apothecary", item = 208185, quest = 79095, set = 1, place = "Brill, Tirisfal Glades" },
	{ key = "narthalas", item = 209843, quest = 78124, set = 1, place = "Ruins of Mathystra, Darkshore" },
	{ key = "arcanic", item = 209847, quest = 78145, set = 1, place = "The Sludge Fen, The Barrens" },
	{ key = "baxtan", item = 208800, quest = 79097, set = 1, place = "Ratchet, The Barrens" },
	{ key = "dreamers", item = 209846, quest = 78143, set = 1, place = "Cavern of Mists, The Barrens",
		at = { { 17, 46.0, 36.5 } }, hint = "Through the cave mouth, deep in the Cavern of Mists." },
	{ key = "furyOfTheLand", item = 209851, quest = 78149, set = 1, place = "Grimtotem Post, Stonetalon Mountains" },
	{ key = "tazo", item = 207972, quest = 79094, set = 1, place = "Valley of Spirits, Orgrimmar",
		hint = "By the mural of Ta'zo." },

	-- Level 35 set (7)
	{ key = "basilisks", item = 213165, quest = 79535, set = 35, place = "Crystalvein Mine, Stranglethorn Vale" },
	{ key = "geomancy", item = 215683, quest = 79947, set = 35, place = "Darkcloud Pinnacle, Thousand Needles" },
	{ key = "defensiveMagics", item = 215815, quest = 79948, set = 35, place = "Gallows' Corner, Alterac Mountains" },
	{ key = "rwl", item = 215822, quest = 79952, set = 35, place = "Witch Hill, Dustwallow Marsh" },
	{ key = "webOfLies", item = 215816, quest = 79949, set = 35, place = "Witherbark Village, Arathi Highlands" },
	{ key = "demons", item = 215817, quest = 79950, set = 35, place = "Thunder Axe Fortress, Desolace" },
	{ key = "mummies", item = 215820, quest = 79951, set = 35, place = "Badlands" },

	-- Level 45 set (7)
	{ key = "sanguine", item = 220345, quest = 81947, set = 45, place = "The Temple of Atal'Hakkar, Swamp of Sorrows",
		hint = "On top of the sunken temple." },
	{ key = "tidesages", item = 220346, quest = 81949, set = 45, place = "Lost Rigger Cove, Tanaris" },
	{ key = "etiquette", item = 220348, quest = 81952, set = 45, place = "Haldarr Encampment, Azshara" },
	{ key = "stonewrought", item = 220349, quest = 81953, set = 45, place = "Blackrock Mountain, Burning Steppes",
		hint = "At the tomb's altar." },
	{ key = "venomous", item = 220350, quest = 81954, set = 45, place = "Shadra'Alor, The Hinterlands" },
	{ key = "mindOfMetal", item = 220352, quest = 81955, set = 45, place = "The Cauldron, Searing Gorge" },
	{ key = "conjurer", item = 220353, quest = 81956, set = 45, place = "Blasted Lands" },

	-- Level 60 set (8)
	{ key = "magma", item = 228133, quest = 84396, set = 60, place = "Blackrock Mountain, Burning Steppes",
		hint = "Inside the mountain, on the platform before the way into Blackrock Depths." },
	{ key = "northernKalimdor", item = 228134, quest = 84397, set = 60, place = "Timbermaw Hold, Felwood",
		hint = "In the Timbermaw tunnel." },
	{ key = "potatoes", item = 228132, quest = 84395, set = 60, place = "Felstone Field, Western Plaguelands" },
	{ key = "knightAndLady", item = 228138, quest = 84400, set = 60, place = "Eastern Plaguelands" },
	{ key = "scourge", item = 228140, quest = 84401, set = 60, place = "Eastern Plaguelands" },
	{ key = "studyOfLight", item = 228135, quest = 84398, set = 60, place = "Light's Hope Chapel, Eastern Plaguelands" },
	{ key = "kaboom", item = 228136, quest = 84399, set = 60, place = "Everlook, Winterspring" },
	{ key = "necromancy", item = 228141, quest = 84402, set = 60, place = "Caer Darrow, Western Plaguelands",
		hint = "In the keep." },
}

Books.SETS = { 1, 35, 45, 60 }
Books.SET_NAMES = { [1] = "Starting set", [35] = "Level 35 set", [45] = "Level 45 set", [60] = "Level 60 set" }

-- The library's rewards: books needed, what kind, the items (names and icons from the game).
Books.REWARDS = {
	{ goal = 10, kind = "necklace", label = "Necklace", items = { 277203, 277204 } },
	{ goal = 20, kind = "ring", label = "Ring", items = { 281634, 281635 } },
	{ goal = 25, kind = "bowCrestLight", label = "Bow, crest or light", items = { 277254, 277258, 277260 } },
	{ goal = 38, kind = "necklaceShield", label = "Necklace or shield", items = { 281637, 281636, 277202 } },
}
