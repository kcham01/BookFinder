# BookFinder

One WoW: Forever addon made of four:

- **[OpenMap](https://github.com/openmap-world/openmap)**: one seamless world map, every zone stitched together.
- **[Shortest Path Forever](https://github.com/cjber/shortest-path-forever)**: journeys on foot, by air, by sea
  and through portals, with directions in the tracker, an arrow and a compass.
- **Books on map (Forever)**: the library books on the map, with an optimised collection route.
- **[Questie](https://github.com/Questie/Questie)** and its database: every quest giver, objective and turn-in on the
  map, its tracker, and its search of every quest, NPC and item.

Every feature of each is kept, nothing does the same job twice, and they work as one:

- **Library books in the quest log**: a tab beside Shortest Path's Nearby services, drawn the same way. It shows
  your progress and the next reward, the nearest book by real travel time, the optimised route (start, next stop,
  stop), the rewards, your group's books, and every book by set with its travel time. Click a book to go there,
  Shift-click to mark it collected, right-click for its places. `/bom` and the minimap menu open it.
- **One settings window**: Options › AddOns › BookFinder, the game's own settings panel. The world map, every
  journey page and the library books are its pages. `/bookfinder`, `/path`, the minimap button's right-click and the
  gear in the books tab all open it.
- **One minimap button** (and one launcher for Titan/ElvUI): your books collected, the nearest book and the journey
  under way in its tooltip; left-click the map, right-click a menu.
- **One set of travel icons**: Shortest Path draws the docks, flight masters, shops and trainers (live departures,
  flight times, a journey a click away); OpenMap keeps the seamless map, dungeons, mailboxes, spirit healers, rares
  and the Zephras Isle airships.
- **One guidance**: turn on the books route and Shortest Path guides it, with its tracker, arrow and compass.
- Books of **every zone in view** show on the seamless map, with the route trail, above its art.
- Shift-clicking a neighbouring zone on the seamless map plans the journey to that zone (and its floor).
- OpenMap's map menu has switches for the books, the route and Shortest Path's icons.

The old commands still work: `/openmap` (the map's menu), `/path`, `/way`, `/spfnear`, `/bom` (the books tab).

## Install

1. Download this repository (Code › Download ZIP).
2. Copy the two folders inside its `AddOns/` folder, `BookFinder/` and `ForeverCore/`, into the client's
   `Interface/AddOns/` (`_forever_` live, `_classic_beta_` beta). ForeverCore is the shared library every Forever addon needs: keep it
   even if you have other Forever addons.
3. Disable or delete the standalone `OpenMap`, `ShortestPathForever`, `Books_on_map_Forever`, `Questie` and
   `QuestieDB` folders. If one is
   still enabled, BookFinder's copy of it stands aside and says so in chat.
4. To keep your old settings, close the game and run once:
   `python3 tools/migrate_savedvariables.py "<game>/_forever_/WTF"` (add `--dry-run` to see first).
5. Restart the client fully the first time (new textures need it).

## Layout

| Path | What |
|---|---|
| `src/` | The three addons and ForeverCore, upstream plus small integration patches (see `git log`) |
| `merge/` | BookFinder's own files: `Namespaces.lua` (loads first), `BooksTab.lua` (the quest-log tab), `Bridge.lua` (loads last) |
| `tools/build.py` | Assembles `build/BookFinder` from `src/` and `merge/`; fetches OpenMap's textures |
| `tools/offline-test/merged.py` | Loads standalone vs merged in a stubbed client and fails on anything only the merge breaks |
| `tools/migrate_savedvariables.py` | Copies the old addons' saved settings into BookFinder's |
| `docs/INVENTORY.md` | Every feature, command, setting, API and quirk, and how the merge works |
| `docs/WANTS.md` | What the addon is meant to be: the owner's wishes and decisions, kept current |

## Checks

```bash
pip install lupa
```

```bash
python3 tools/build.py --no-textures
```

```bash
python3 tools/offline-test/merged.py
```

The offline test can't draw the map; `docs/INVENTORY.md` lists what still needs a look in game.

## Licences

Shortest Path Forever and ForeverCore are GPL-3.0-or-later, OpenMap's code is MIT (its map art is Blizzard's),
and Books on map ships no licence: the combined addon is GPL-3.0-or-later, and Books' author should be asked
before BookFinder is published anywhere.
