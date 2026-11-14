# BookFinder: the product

One addon, made for one player: the world map, every quest and the library books, as if the game shipped with it.
This is what it is meant to be, and the rules every part of it keeps. `docs/WANTS.md` is why; this file is what.

## What it is

- **The map** is the home. Every zone stitched into one world, your quests and the books on it, and beside it the
  quest log with two tabs: **Quests** (your quest list) and **BookFinder** (search everything, the library books).
- **One settings window**, BookFinder's own: Map, Look, Quests, Library, More. Opened from the map's BookFinder
  button, the minimap button, `/bookfinder`, and the game's AddOns settings.
- **One minimap button**: where to go (World Map, Quest Log, Library books, Nearest book, My Journey), then Settings.
- **Nothing on screen** but the game's own arrow to the map pin. No trackers, no extra frames.
- **"Take me there"** is always the game's own map pin and arrow.

## Rules

1. **Blizzard's art only.** Dialog boxes, quest-log parchment and list rows, tooltip boxes, Blizzard check boxes,
   sliders, buttons, search boxes and scroll bars. No custom textures, colours or fonts beyond the game's.
2. **One look per kind of thing.** One row, one section header, one dropdown (the classic tooltip-box dropdown),
   one window frame. A new screen uses them; it doesn't invent its own.
3. **Gold names, white values, grey hints.** Titles and headers gold (`GameFontNormal`), entries white
   (`GameFontHighlight`), notes grey (`GameFontDisable`). Red only for what's wrong.
4. **Every setting in one place**, in the settings window, once. No switch in two menus.
5. **Plain words, the player's words.** Name things by what you see in the game, not by the part that draws it:
   "Quest icons", never "Questie icons". Sentence case. No jargon, no apologies.
6. **Clicks mean the same everywhere.** Click: do it (a pin, open, tick). Shift-click: link or mark. Right-click: its
   menu. Hover: what it is and what each click does.
7. **Never silent.** Anything that can't be done says why, once, on screen.
8. **Nothing dead.** A control that does nothing is removed; a part's feature nobody can reach is removed or given a
   place.

## The parts underneath (engines, not seen)

| Engine | What it does for BookFinder | Its own screens |
|---|---|---|
| OpenMap | stitches the map, draws its art, dungeons, people, pins, drawings | menu panel: replaced by BookFinder's settings window |
| Questie (and its database) | quests, NPCs, objects and items; their icons on the map; the quest list | options pages: replaced; tracker: docked in the Quests tab |
| Books on map | the books, sets and rewards; their pins; the route | its window: replaced by the BookFinder tab |

## Rebuild: done and next

| Surface | State |
|---|---|
| Settings window (all settings, one model) | **2.2.0: BookFinder's own** (`merge/Options.lua`, `merge/OptionsWindow.lua`) |
| Dropdowns | 2.0.1: one dropdown everywhere (`merge/Menu.lua`); the map's Show menu too (2.0.2) |
| BookFinder tab (search, books) | BookFinder's own since 1.4 (`merge/BooksTab.lua`, `merge/Search.lua`) |
| Minimap button and menu | BookFinder's own (`merge/Bridge.lua`) |
| Map pin and arrow | the game's own (`merge/Waypoint.lua`) |
| Quests tab | next: BookFinder's own list drawn from Questie's quest data, in the BookFinder tab's rows |
| The map's corner buttons | next: BookFinder's own row (Settings, Find me, Drop a pin), OpenMap's rail and favourites gone |
| Map pins and tooltips | next: one tooltip style for quests, books, dungeons and townsfolk |
| Messages | next: one voice for every line BookFinder prints |
| On-screen book alerts | next: the game's own alert style |
