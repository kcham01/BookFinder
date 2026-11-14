# BookFinder

One WoW: Forever addon, built on three (`docs/DESIGN.md` is the product and its rules):

- **[OpenMap](https://github.com/openmap-world/openmap)**: one seamless world map, every zone stitched together.
- **Books on map (Forever)**: the library books on the map, with a collection route.
- **[Questie](https://github.com/Questie/Questie)** and its database: every quest giver, objective and turn-in on the
  map, its quest list, and every quest, NPC and item it knows.

They work as one:

- **"Take me there" is the game's own map pin.** Click a quest, a book or a search result and the game's own pin and
  tracking arrow go on it. When a spot can't take a pin, it says so and opens the map there.
- **The BookFinder tab beside the quest log** has one search box for everything: quests, NPCs, objects, items,
  zones and the library books. With the box empty it shows the books: your progress and the next reward, the nearest
  book, the route, the rewards, your group's books and every book by set with its distance. `/bom` opens it.
- **Quests in the map, nothing on screen**: Questie's quest list (every feature of its tracker) is the map's Quests
  tab, with its own scrollbar.
- **One settings window**, BookFinder's own: Map, Look, Quests, Library and More, with a search over every setting.
  The map's BookFinder button, the minimap button, `/bookfinder` and the game's AddOns list open it.
- **One minimap button** (and one launcher for Titan/ElvUI): your books collected and the nearest book in its
  tooltip; left-click the map, right-click where to go. Every dropdown, the map's Show menu too, is drawn in
  Questie's style.
- Books of **every zone in view** show on the seamless map, with the route trail, above its art.

`/bookfinder selftest` checks every feature in game and logs the results and errors to its saved variables.

Shortest Path Forever (journey planning) was part of BookFinder until 1.8.1 and was removed in 2.0.0.

## Install

1. Download this repository (Code › Download ZIP).
2. Copy the `BookFinder/` folder inside its `AddOns/` folder into the client's `Interface/AddOns/` (`_forever_` live,
   `_classic_beta_` beta). Since 2.0.0 BookFinder no longer needs `ForeverCore/`: delete it unless another Forever
   addon you use needs it.
3. Disable or delete the standalone `OpenMap`, `Books_on_map_Forever`, `Questie` and `QuestieDB` folders. If one is
   still enabled, BookFinder's copy of it stands aside and says so in chat.
4. To keep your old settings, close the game and run once:
   `python3 tools/migrate_savedvariables.py "<game>/_forever_/WTF"` (add `--dry-run` to see first).
5. Restart the client fully the first time (new textures need it).

## Layout

| Path | What |
|---|---|
| `src/` | The parts, upstream plus small integration patches (see `git log`) |
| `merge/` | BookFinder's own files: `Namespaces.lua` (loads first), `Retired.lua`, `Waypoint.lua` (the map pin), `Tabs.lua` (tabs beside the quest log), `BooksTab.lua` (the BookFinder tab), `Search.lua`, `QuestLog.lua`, `Inspect.lua` (the recorder), `SelfTest.lua`, `Bridge.lua` (loads last) |
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

Questie is GPL-3.0, `merge/Tabs.lua` comes from ForeverCore (GPL-3.0-or-later), OpenMap's code is MIT (its map art is
Blizzard's), and Books on map ships no licence: the combined addon is GPL-3.0-or-later, and Books' author should be asked
before BookFinder is published anywhere.
