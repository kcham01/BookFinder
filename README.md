# BookFinder

One WoW: Forever addon made of three:

- **[OpenMap](https://github.com/openmap-world/openmap)**: one seamless world map, every zone stitched together.
- **[Shortest Path Forever](https://github.com/cjber/shortest-path-forever)**: journeys on foot, by air, by sea
  and through portals, with directions in the tracker, an arrow and a compass.
- **Books on map (Forever)**: the library books on the map, with an optimised collection route.

Every feature of each is kept, and they work together:

- Books of **every zone in view** show on OpenMap's stitched map, with the route trail, above its art.
- Books' route goes to Shortest Path as one journey (this was broken in Books 2.2.6, which didn't accept Shortest
  Path's current API), and the route tracker shows Shortest Path's real travel time.
- Shift-clicking a neighbouring zone on the stitched map plans the journey to that zone (and its floor).
- OpenMap's menu gets switches for the books, the books route, and Shortest Path's boats, lifts, portals and
  flight masters.
- One addon-compartment entry (left-click: the map; right-click: each part's settings) and `/bookfinder`.

Every part keeps its own commands: `/openmap`, `/path`, `/way`, `/spfnear`, `/bom`.

## Install

1. Build it (or use a zip someone built): `python3 tools/build.py --zip` → `dist/BookFinder-1.0.0.zip`.
2. Extract the zip into the client's `Interface/AddOns/` (`_forever_` live, `_classic_beta_` beta). You get two
   folders: `BookFinder/` and `ForeverCore/`. ForeverCore is the shared library every Forever addon needs: keep it
   even if you have other Forever addons.
3. Disable or delete the standalone `OpenMap`, `ShortestPathForever` and `Books_on_map_Forever` folders. If one is
   still enabled, BookFinder's copy of it stands aside and says so in chat.
4. To keep your old settings, close the game and run once:
   `python3 tools/migrate_savedvariables.py "<game>/_forever_/WTF"` (add `--dry-run` to see first).
5. Restart the client fully the first time (new textures need it).

## Layout

| Path | What |
|---|---|
| `src/` | The three addons and ForeverCore, upstream plus small integration patches (see `git log`) |
| `merge/` | BookFinder's own files: `Namespaces.lua` (loads first), `Bridge.lua` (loads last) |
| `tools/build.py` | Assembles `build/BookFinder` from `src/` and `merge/`; fetches OpenMap's textures |
| `tools/offline-test/merged.py` | Loads standalone vs merged in a stubbed client and fails on anything only the merge breaks |
| `tools/migrate_savedvariables.py` | Copies the old addons' saved settings into BookFinder's |
| `docs/INVENTORY.md` | Every feature, command, setting, API and quirk, and how the merge works |

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
