-- Books on map (Forever): book data
-- Sources: https://foreverchanges.pro/library-books, https://www.zockify.com/forever/library-books/, Wowhead
local _, ns = ...

-- Classic uiMapIDs
local ELWYNN, IRONFORGE, WESTFALL, DUSKWOOD, LOCHMODAN, WETLANDS = 1429, 1455, 1436, 1431, 1432, 1437
local SILVERPINE, TIRISFAL, DARKSHORE, BARRENS, STONETALON, ORGRIMMAR = 1421, 1420, 1439, 1413, 1442, 1454
local STV, NEEDLES, ALTERAC, DUSTWALLOW, BADLANDS, SEARING = 1434, 1441, 1416, 1445, 1418, 1427
local ARATHI, DESOLACE, SWAMP, TANARIS, AZSHARA, BURNING = 1417, 1443, 1435, 1446, 1447, 1428
local HINTERLANDS, BLASTED, FELWOOD, WPL, EPL, WINTERSPRING = 1425, 1419, 1448, 1422, 1423, 1452
ns.CONTINENTS = { [1414] = true, [1415] = true } -- Kalimdor, Eastern Kingdoms

-- key = stable id; set = quest set (1 = starting set, 35/45/60 = level); icon = item icon (Interface\Icons); name = English item name (used to detect pickup, translated by Locales\*.lua)
-- item = itemID (optional, detects pickup in any language); quest = questID of the library turn-in (optional, detects books already handed in)
-- faction = "Alliance" / "Horde" (optional): book only lootable by that faction, removed for the other one
-- locs = { {mapID, x, y, place}, ... } (place: English, translated by Locales\*.lua)
ns.BOOKS = {
  -- First set
  { key = "theocritus", item = 203755, quest = 79092, set = 1, icon = "inv_misc_book_12", name = "Archmage Theocritus' Research Journal", locs = { { ELWYNN, 65.4, 70.1, "Tower of Azora, Elwynn Forest" } } },
  { key = "antonidas", item = 203754, quest = 79091, set = 1, icon = "inv_misc_book_12", name = "Archmage Antonidas: The Unabridged Autobiography", locs = { { IRONFORGE, 75.7, 10.5, "Ironforge" } } },
  { key = "envoutements", item = 209845, quest = 78142, set = 1, icon = "inv_misc_book_01", name = "Bewitchments and Glamours", locs = { { WESTFALL, 45.4, 70.4, "Moonbrook, Westfall" } } },
  { key = "rumi", item = 208860, quest = 79093, set = 1, icon = "inv_misc_book_12", name = "Rumi of Gnomeregan: The Collected Works", locs = {
      { WESTFALL, 52.7, 53.8, "Sentinel Hill, Westfall" },
      { LOCHMODAN, 35.6, 48.9, "Thelsamar, Loch Modan (same book)" } } },
  { key = "anatomie", item = 209849, quest = 78147, set = 1, icon = "inv_misc_book_06", name = "Crimes Against Anatomy", locs = { { DUSKWOOD, 16.6, 28.5, "The Darkened Bank, Duskwood" } } },
  { key = "runes", item = 209850, quest = 78148, set = 1, icon = "inv_scroll_02", name = "Runes of the Sorcerer-Kings", locs = { { LOCHMODAN, 77.4, 14.0, "Mo'grosh Stronghold, Loch Modan" } } },
  { key = "goaz", item = 209848, quest = 78146, set = 1, icon = "inv_scroll_15", name = "Goaz Scrolls", locs = { { WETLANDS, 33.6, 47.9, "Whelgar's Excavation Site, Wetlands" } } },
  { key = "dalaran", item = 209844, quest = 78127, set = 1, icon = "inv_relics_libramoftruth", name = "The Dalaran Digest, Vol. 23", locs = { { SILVERPINE, 63.5, 63.1, "Ambermill, Silverpine Forest" } } },
  { key = "ataeric", item = 210177, quest = 79096, set = 1, icon = "inv_misc_book_12", name = "Ataeric: On Arcane Curiosities", locs = { { SILVERPINE, 43.4, 41.2, "The Sepulcher, inside the tomb near Sebastian Meloche, Silverpine Forest" } } },
  { key = "abecedaire", item = 208185, quest = 79095, set = 1, icon = "inv_misc_book_05", name = "The Apothecary's Metaphysical Primer", locs = { { TIRISFAL, 59.4, 52.3, "Brill, Tirisfal Glades" } } },
  { key = "narthalas", item = 209843, quest = 78124, set = 1, icon = "inv_scroll_12", name = "Nar'thalas Almanac, Vol. 74", locs = { { DARKSHORE, 59.6, 22.2, "Ruins of Mathystra, Darkshore" } } },
  { key = "arcaniques", item = 209847, quest = 78145, set = 1, icon = "inv_misc_toy_05", name = "Arcanic Systems Manual", locs = { { BARRENS, 56.3, 8.8, "The Sludge Fen, The Barrens" } } },
  { key = "baxtan", item = 208800, quest = 79097, set = 1, icon = "inv_misc_book_12", name = "Baxtan: On Destructive Magics", locs = { { BARRENS, 62.7, 36.3, "Ratchet, The Barrens" } } },
  { key = "reveurs", item = 209846, quest = 78143, set = 1, icon = "inv_scroll_09", name = "Secrets of the Dreamers", locs = { { BARRENS, 46.0, 36.5, "Cave entrance, then Cavern of Mists (52.8, 54.7 on cave map)" } } },
  { key = "fureur", item = 209851, quest = 78149, set = 1, icon = "inv_holiday_tow_spicebandage", name = "Fury of the Land", locs = { { STONETALON, 74.4, 85.7, "Grimtotem Post, Stonetalon Mountains" } } },
  { key = "tazo", item = 207972, quest = 79094, set = 1, icon = "inv_scroll_02", name = "The Lessons of Ta'zo", locs = { { ORGRIMMAR, 38.7, 78.4, "Ta'zo Mural, Orgrimmar" } } },

  -- Level 35 set
  { key = "basilics", item = 213165, quest = 79535, set = 35, icon = "inv_inscription_scroll", name = "Basilisks: Should Petrification be Feared?", locs = { { STV, 41.4, 50.9, "Crystalvein Mine, Stranglethorn Vale" } } },
  { key = "geomancie", item = 215683, quest = 79947, set = 35, icon = "inv_misc_book_08", name = "Geomancy: The Stone-Cold Truth", locs = { { NEEDLES, 34.4, 40.1, "Darkcloud Pinnacle, Thousand Needles" } } },
  { key = "defensive", item = 215815, quest = 79948, set = 35, icon = "inv_misc_book_04", name = "Defensive Magics 101", locs = { { ALTERAC, 48.4, 57.6, "Gallows' Corner, Alterac Mountains" } } },
  { key = "rwl", item = 215822, quest = 79952, set = 35, icon = "inv_misc_book_08", name = "RwlRwlRwlRwl!", locs = { { DUSTWALLOW, 57.2, 20.8, "Witch Hill, Dustwallow Marsh" } } },
  { key = "weblies", item = 215816, quest = 79949, set = 35, icon = "inv_misc_note_05", name = "A Web of Lies: Debunking Myths and Legends", locs = { { ARATHI, 73.6, 65.2, "Witherbark Village, Arathi Highlands" } } },
  { key = "demons", item = 215817, quest = 79950, set = 35, icon = "inv_misc_book_01", name = "Demons and You", locs = { { DESOLACE, 55.1, 26.2, "Thunder Axe Fortress, Desolace" } } },
  { key = "mummies", item = 215820, quest = 79951, set = 35, icon = "inv_scroll_01", name = "Mummies: A Guide to the Unsavory Undead", locs = { { BADLANDS, 56.7, 39.9, "Badlands" } } },
  { key = "luddite", item = 215824, quest = 79953, set = 35, icon = "inv_misc_book_10", name = "A Luddite's Guide to Caring for Your Demonic Pet", locs = { { SWAMP, 61.4, 22.4, "Fallow Sanctuary, Swamp of Sorrows" } } },

  -- Level 45 set
  { key = "sanguine", item = 220345, quest = 81947, set = 45, icon = "inv_misc_book_06", name = "Sanguine Sorcery", locs = { { SWAMP, 70.0, 51.0, "Top of the Sunken Temple, Swamp of Sorrows" } } },
  { key = "tidesages", item = 220346, quest = 81949, set = 45, icon = "inv_scroll_05", name = "Legends of the Tidesages", locs = { { TANARIS, 72.7, 47.8, "Lost Rigger Cove, Tanaris" } } },
  { key = "etiquette", item = 220348, quest = 81952, set = 45, icon = "inv_misc_book_08", name = "Everyday Etiquette", locs = { { AZSHARA, 20.7, 62.0, "Haldarr Encampment, Azshara" } } },
  { key = "stonewrought", item = 220349, quest = 81953, set = 45, icon = "inv_misc_book_11", name = "Stonewrought Design", locs = { { BURNING, 29.0, 28.9, "Blackrock Mountain tomb altar, Burning Steppes" } } },
  { key = "venomous", item = 220350, quest = 81954, set = 45, icon = "inv_scroll_06", name = "Venomous Journeys", locs = { { HINTERLANDS, 36.0, 72.8, "Shadra'Alor, The Hinterlands" } } },
  { key = "mindmetal", item = 220352, quest = 81955, set = 45, icon = "inv_misc_book_11", name = "A Mind of Metal", locs = { { SEARING, 37.8, 49.3, "The Cauldron, Searing Gorge" } } },
  { key = "conjurer", item = 220353, quest = 81956, set = 45, icon = "inv_misc_book_04", name = "Conjurer's Codex", locs = { { BLASTED, 55.4, 32.2, "Blasted Lands" } } },

  -- Level 60 set
  { key = "magma", item = 228133, quest = 84396, set = 60, icon = "inv_misc_book_10", name = "Magma or Lava?", locs = { { BURNING, 29.6, 28.2, "Inside Blackrock Mountain, platform before the Blackrock Depths entrance (48.4, 63.6 on the mountain map)" } } },
  { key = "kalimdor", item = 228134, quest = 84397, set = 60, icon = "inv_misc_book_03", name = "Northern Kalimdor - A Comprehensive Guide", locs = { { FELWOOD, 65.2, 3.3, "Timbermaw Hold tunnel, Felwood" } } },
  { key = "undeadpotatoes", item = 228132, quest = 84395, set = 60, icon = "inv_misc_book_09", name = "Undead Potatoes", locs = { { WPL, 38.3, 54.6, "Felstone Field, Western Plaguelands" } } },
  { key = "knightlady", item = 228138, quest = 84400, set = 60, icon = "inv_misc_book_04", name = "The Knight and the Lady", locs = { { EPL, 47.3, 42.3, "Eastern Plaguelands" } } },
  { key = "scourge", item = 228140, quest = 84401, set = 60, icon = "inv_misc_book_01", name = "Scourge: Undead Menace or Misunderstood?", locs = { { EPL, 26.5, 15.1, "Eastern Plaguelands" } } },
  { key = "studylight", item = 228135, quest = 84398, set = 60, icon = "inv_misc_book_13", name = "A Study of the Light", locs = { { EPL, 71.8, 48.2, "Light's Hope Chapel, Eastern Plaguelands" } } },
  { key = "kaboom", item = 228136, quest = 84399, set = 60, icon = "inv_misc_book_11", name = "Ka-Boom!", locs = { { WINTERSPRING, 60.7, 37.7, "Everlook, Winterspring" } } },
  { key = "necromancy", item = 228141, quest = 84402, set = 60, icon = "inv_misc_book_06", name = "Necromancy 101", locs = { { WPL, 69.4, 72.8, "Caer Darrow keep, Western Plaguelands" } } },
}
