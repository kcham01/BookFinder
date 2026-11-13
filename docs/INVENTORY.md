# BookFinder inventory: features, functions, quirks

This is the working checklist for the merge. Every feature of the three addons is listed here so a rebuild,
an upstream update or a new patch can be checked against it. **Nothing in this list was removed by the merge.**
The rows marked ⚙ are what the merge added or changed.

Sources (what was merged):

| Part | Upstream version | Author / licence | Folder in BookFinder | Private table |
|---|---|---|---|---|
| OpenMap | v0.8.7 (commit `91c84b3`, 2026-11-12) | OpenMap contributors, MIT (code); map art Blizzard's | `OpenMap/` | `root.OpenMap` (also global `OpenMap`) |
| Shortest Path Forever | v1.34.3 | cjber, GPL-3.0-or-later | `ShortestPathForever/` | `root.SPF` |
| Books on map (Forever) | 2.2.6 | Daeler (no licence file shipped) | `Books_on_map_Forever/` | `root.Books` |
| ForeverCore (library) | v1.9.0 | cjber, GPL-3.0-or-later | stays its own addon folder | its own |

The whole is GPL-3.0-or-later because of Shortest Path. Books on map has no licence file: ask its author
before publishing BookFinder anywhere public.

---

## 1. How the merge works

### 1.1 Build

`python3 tools/build.py [--no-textures] [--zip]` writes `build/BookFinder/` and `build/ForeverCore/`
(and `dist/BookFinder-1.0.0.zip` with `--zip`). Never edit `build/`: edit `src/` or `merge/` and rebuild.

1. Each part is copied into its subfolder. Its own `.toc`, `Bindings.xml` and `README.md` stay behind (OpenMap's
   retail data, retail textures and `OpenMap_Mainline.toc` are never vendored).
2. **Private tables.** The game hands every file of one addon the same private table. Each file's first
   `local _, ns = ...`, `local ADDON, ns = ...` or `local ns = select(2, ...)` line gets
   `; ns = ns.<Part>; if ns.__skip then return end` added *on the same line*, so line numbers in error messages
   still match upstream. The build fails when a file has two such lines, or reads `...` in a form it doesn't know.
   `Libs/` are left alone (LibStub versions them). SP's `Nav/Nav*_N.lua` and `Data` tables are plain globals
   with no `ns`.
3. **Paths.** Every `Interface\AddOns\<Part>\…` (escaped `\\` in Lua, single `\` in XML) becomes
   `Interface\AddOns\BookFinder\<Part>\…`. The build fails if any file still points at a standalone folder.
4. **Patches** (each must match exactly once or the build fails):
   - OpenMap `Core.lua`: `ns.Media.path` built from the addon name gets `\OpenMap\` inserted.
   - OpenMap `Core.lua`: `ns.version` reads `X-OpenMap-Version` (its What's new window and report codes).
   - OpenMap `Map/Compat.lua`: "Books on map loaded?" also answers yes for the built-in part.
   - SP `UI/CompanionMaps.lua`: "OpenMap loaded?" → `BookFinder.Loaded("OpenMap")`.
   - SP `UI/WhatsNew.lua`: reads `X-SPF-Version` so What's new doesn't fire for BookFinder's own version.
   - Books `Core/Skin.lua`: media path built from the addon name gets `\Books_on_map_Forever\`.
   - Books `Group.lua`, `Welcome.lua`, `Options.lua`: version from `X-Books-Version` (group sync compares it
     with other players running standalone Books, so it must stay Books' own).
5. **The toc** is one `BookFinder.toc`: `Merge\Namespaces.lua`, then OpenMap's files, then SP's, then Books',
   then `Merge\Bridge.lua`, each in its upstream order with `[AllowLoadTextLocale xx]` kept. Metadata: union
   of `SavedVariables`, `SavedVariablesPerCharacter` and `OptionalDeps`; `Dependencies: ForeverCore`;
   `X-Forever-Core`/`X-Forever-Icon` from SP (ForeverCore reads them by addon name); one compartment entry.
6. **Bindings.xml**: every `<Binding>` of OpenMap and SP in one file.
7. **Textures**: OpenMap's `Media/Textures/Forever` (335 MB, 2369 files) is sparse-fetched from the pinned commit
   into `.cache/openmap/` once, then copied. Not in git.

### 1.2 Merge layer (`merge/`)

- `Namespaces.lua` (first file): makes `root.OpenMap`, `root.SPF`, `root.Books`. For each part whose standalone
  addon is installed, loadable and enabled for this character, it sets `__skip`: every file of that part returns
  at once and the standalone copy runs alone. It publishes the global `BookFinder`:
  `BookFinder.Active(key)`, `BookFinder.Loaded(folder)` (IsAddOnLoaded that also knows built-in parts),
  `BookFinder.components`, `BookFinder.shadowed`.
- `Namespaces.lua` also makes **the one settings window**: `BookFinder.SettingsCategory()` (a vertical-layout
  category "BookFinder", made on first use), `BookFinder.RegisterPage(key, page)`, `BookFinder.OpenSettings([key])`
  (through `ForeverCore.OpenSettingsPanel`, the secure opener), `BookFinder.PublishSettings()` (adds the category
  to the AddOns list once, at login, after every page is in). `BookFinderDB` (account) holds BookFinder's own
  settings: `minimap` (LibDBIcon's position and `hide`).
- `Bridge.lua` (last file):
  - At ADDON_LOADED (after every part's own): the front page's minimap-button switch and its World map / Books
    buttons, and the **Books** page: book list button, show on the map, map icon size, show on the minimap,
    minimap icon size, optimized route, group's missing books, collected notice, nearby alert, books language
    (reload). All proxy settings over `BooksOnMapForeverDB` (Books' inverted keys stay as they are).
  - At PLAYER_LOGIN: publishes the settings category; makes **the one launcher** (LDB data source "BookFinder",
    text = books collected) and **the one minimap button** (LibDBIcon "BookFinder"; first run takes Books' old
    button's place and hidden state); registers SP's map marks in OpenMap's menu.
  - Button, broker and compartment: left-click the world map; right-click a menu (settings, world map, books,
    nearest book, optimized route, nearby services, cancel the journey). Tooltip: books collected, nearest book,
    group progress, the journey under way with its time left.
  - `/bookfinder` and `/bfind`: no argument opens the settings window; `settings`, `map`, `books`,
    `near [service]`, `status` (each part built in, standalone or off, and both API versions).
  - SP's world-map marks as OpenMap menu switches (section "Shortest Path"): boats and zeppelins, lifts and
    tram, portals, flight masters, routes on hover. They write through the game's setting object
    (`Settings.GetSetting("ShortestPathForever_<key>")`) so SP's page and its redraw callback follow, then check the
    saved value took, and write it directly and redraw if it didn't.
  - A login line when a standalone copy took a part's place.

### 1.3 Integration patches in `src/` (on top of upstream; `git log` shows them)

| ⚙ | Where | What |
|---|---|---|
| ⚙ | Books `Core/Navigation.lua` | Accepts SP API **v1 and v2**. Books 2.2.6 checked `version == 1`, and SP 1.34 publishes v2, so Books **never reached SP**: whole-route guiding fell back to TomTom/SP's stand-in, single waypoints went through SP's one-waypoint TomTom shim. Fixed. |
| ⚙ | Books `Core/Navigation.lua` | `ns.TravelSeconds(loc)`: SP's `API.Estimate` from the player to a book, at most every 2 s per book (each step is a new origin to SP's cache). |
| ⚙ | Books `modules/Route.lua` | The route tracker shows SP's travel time (game-localised `SecondsToTime`) when the book is over 300 yd away or on another continent; yards when close; "other continent" with no SP. |
| ⚙ | Books `modules/Map.lua` | On OpenMap's stitched map, pins and the route trail are placed with `OpenMapAPI.CanvasFromWorldPos`, so **books in every zone in view show**, not only the zone underneath. Off the stitched map: exactly as before. |
| ⚙ | Books `modules/Map.lua` | Smaller pins on any map above zone level (continents, Azeroth when OpenMap zooms out), not only the two continents. |
| ⚙ | Books `modules/Map.lua` | Redraws on `OpenMap_StitchedChanged`, and on `OpenMap_ViewChanged` when the map underneath changed without telling. |
| ⚙ | Books `modules/Map.lua` | OpenMap menu switches (section "Books on map"): "Show on the map" (`db.hidden`) and "Optimized route" (`ToggleRoute`). Reuse existing translated strings. |
| ⚙ | Books `modules/Map.lua` | All calls into OpenMap go through `pcall`; the API must be major 1, version ≥ 2. |
| ⚙ | Books toc | `OptionalDeps` gains `OpenMap` (standalone load order). |
| ⚙ | SP `UI/OpenMap.lua` | `OpenMap.CursorMapPoint()`: the zone under the cursor on the stitched map (API v3 `CursorPosition` + `MapAt` + `MapFromWorld`). |
| ⚙ | SP `Journey/JourneyInput.lua` | Shift-click and Alt-click plan to the zone under the cursor when stitched, not to the centred zone's coordinates run off its edge. The underground flag (`UNDERGROUND[uiMap]`, the stop's floor) now comes from the zone clicked. |

### 1.3b The library books tab (`merge/BooksTab.lua`, since 1.4.0)

Books on map's own window (its skinned list, Rewards and Group side panels) is replaced by one tab of the world
map's quest log, registered with `ForeverCore.QuestLogTabs` (key `bookfinder.books`, order 30, below Shortest
Path's Nearby services at 20). It is built with Shortest Path's ServicesPanel kit, so the two tabs read as one
design: the quest log's parchment (`QuestLog-main-background`, covered) and border (`QuestLogBorderFrameTemplate`),
`SearchBoxTemplate`, `ScrollFrameTemplate`, list headers on `common-button-list-collapseExpand` with
`CollapseButtonTemplate`, and the Who list's 44-high rows (`common-button-list-large`, hover in HIGHLIGHT/ADD) with
Shortest Path's fonts and offsets. Shortest Path's `Art` helpers are used when it runs here (local copies otherwise).

- **Header:** the lore-book glyph (or the book icon, cut round), "Library books", "N of M collected · K to the next
  reward".
- **Collect:** the nearest missing book *by Shortest Path's travel time* (Books' straight line until the times are
  in), and the optimised route: "Optimized route" starts it; while on, its next stop (books left, time; click: Shortest
  Path guides it, Shift-click: start again from the nearest) and "Stop the route".
- **Rewards:** each tier (10 necklace, 20 ring, 25 bow/crest/light; Books' own `ns.REWARD_TIERS`): unlocked, or how
  many to go, then its items in their quality colours with their slots; hover: the item; Shift-click: link it.
  Folded by default once every tier is reached.
- **Group** (in a group only): each member who shares their books (class colour, how many of yours they still need,
  "n / M"), then the members without the addon or with another book list.
- **Sets** (Starting, Level 35, 45, 60): every book, missing ones nearest first, collected ones greyed and ticked at
  the bottom; detail = the place (and "+1" when it has two), "n in your group need it". Click: Shortest Path's
  journey to its quickest place. Shift-click: collected or not. Right-click: each place, Show on the map, Collected.
  The book's icon gives its item tooltip and links it. A set is folded by default once it's complete.
- **Gear** beside the search: Hide collected books, Only sets for my level, Also show the books my group is missing
  (Books' own filters, `BooksOnMapForeverDB`), mark every book collected / shown again, and the settings page.
- **Search:** book names and places; sets only, unfolded.
- Folds are saved (`BooksOnMapForeverDB.tabFolded`).
- Travel times: one `API.Estimate` per frame, only while the tab is shown, for every place of every missing book;
  the last round stays on screen until the next is complete (so opening the tab or the 15 s ticker never blanks
  the times or reorders twice); a new zone starts afresh.
- Redrawn (at most once a frame) on Books' `RefreshOptions`, `RefreshGroupPanel`, `ToggleRoute`, `RefreshRoute`,
  on item data arriving and the group changing. No OnShow/OnHide under the world map: ForeverCore's `shown`.
- `/bom`, the minimap menu's Library books, Books' toast click: `ns.ToggleOptions` opens this tab (or closes the map
  when it's already showing). Books' old window is never built in BookFinder.
- `BookFinder.OpenBooks([toggle])`, `BookFinder.OpenQuestLog()` (the map at its Quests tab: the minimap menu's
  Quests); `BookFinder.BooksTab` is for the offline test.

Gone with 1.4.0: the 1.3.0 map panel (`merge/Panel.lua`) and its button. It duplicated Shortest Path's Nearby
services and stacked a second menu beside OpenMap's. OpenMap's map menu is the one map menu again (its `mapButtons`
default is upstream's), Questie's map button stays off, and Shortest Path's panel-only additions
(`ns.NearbyRows`, `NearbyGo`, `JourneyToQuest`) were taken back out.

### 1.3c One search, one map menu, fewer pages, fewer files (1.5.0)

- **One search** (`merge/Search.lua`): Shortest Path's Nearby services box ("Search services, quests, NPCs, items
  and places") also lists, under its own sections: Quests, Items, Places, Library books, NPCs, Objects (six each,
  "6 of N"; the exact name first, then names starting with it, shorter first). Quest: [level], giver and zone, yards;
  click: a journey to the nearest giver (in your log: to where you turn it in); Shift-click links it. NPC/object:
  nearest spawn; item: nearest vendor, else nearest drop; place: click shows the map there, Shift-click a journey;
  book: as in the books tab. Questie's database is read into a name index once (1500 names a frame, from its own
  ID lists or `LibQuestieDB.<Type>.GetAllIds`), saying "Reading Questie's database… n%" meanwhile. Hook: Shortest
  Path's `ServicesPanel.lua` calls `ns.ExtraSearch(list, top, query, searchBox)` and exposes
  `ns.RefreshServicesPanel`.
- **One map menu** (`merge/MapMenu.lua`): the world map's Show menu (through Shortest Path's `ns.ModifyMenu`) takes
  Quests (Questie's quest givers and objective icons, OpenMap's quests from every zone), Places (dungeons and raids,
  mailboxes, spirit healers, rare mobs), People (party and raid, friends, guild), Library books (on the map, route)
  and Your drawings. OpenMap's own menu leaves those out when built in (`Map/Panel.lua`), and Shortest Path's switches
  are no longer added to it (they were always in the Show menu): no switch is in two menus. OpenMap's airships still
  follow Shortest Path's boats switch (`SetOption` hook).
- **Settings**: Shortest Path's eight pages are three (Map icons = Map marks + Transport; Journeys = Guidance +
  Party mage portals; Interface = Interface + Alerts + Travel journal), each old page a section heading; no index of
  Open buttons anywhere; no Forever addons page and no suggestions of other Forever addons (`suggestFamily` off);
  Questie's other tabs nest under Quests. Tree: BookFinder (minimap button), Map icons, Journeys, Interface, World
  map, Library books, Quests (+ its tabs).
- **Files left out** (`DROP` in tools/build.py, `merge/Retired.lua` stands in for their entry points): Books'
  `Welcome.lua`, `Broker.lua`, `Minimap.lua`, `SideTabs.lua`, `GroupPanel.lua`.
- **`/bookfinder inspect`** (`merge/Inspect.lua`): records the client's build, which atlases, fonts and templates
  exist, the Show menu's entries, quest/map/tracking CVars and the trackers' and quest log's frames into
  `BookFinderDB.inspect`.

### 1.3d The quest list in the map, and the recorder (1.6.0, 1.7.0)

- **No tracker on screen; the quest list is in the map** (`merge/QuestLog.lua`, 1.7.0; 1.6.0's TrackerSkin.lua and its
  ForeverCore width rule are gone): Questie's real tracker frame (`Questie_BaseFrame`, every feature with it) is
  parented to `BookFinderQuestList` over the map's Quests tab (`QuestMapFrame.QuestsFrame`, on the quest log's
  parchment and border), locked, without sizer or backdrop, its `TrackerWidth`/`TrackerHeight` set to the room there
  (it scrolls inside). A hook on its `SetPoint` keeps it there when Questie re-places it. The Forever column
  (`ForeverTrackerCompanion`: Shortest Path's journey and departures, any Forever addon's section) is parked under a
  hidden frame. The journey shows at the top of the tab in Questie's fonts: goal, time left, each leg with its mode
  mark and time (current in gold), × cancels, a click shows the goal's map; it counts down each second while shown
  and follows Shortest Path's `Subscribe`. Moves wait for combat to end (Questie's item buttons are secure).
- **The recorder** (`merge/Inspect.lua`): the inspect snapshot runs by itself 10 s after every login; BookFinder's
  and ForeverCore's Lua errors go to `BookFinderDB.errors` (40, deduplicated and counted, with a stack; the error
  handler before keeps running: BugGrabber, the game's). Templates are checked through `C_XMLUtil.GetTemplateInfo`
  (1.6.0 made one of each to see, which raised errors; fixed in 1.7.0); every journey Shortest Path plans goes to
  `BookFinderDB.journeys` once per goal (25: where you were, your level, the goal, every leg's mode, text and
  seconds). The Show menu snapshot is read through Shortest Path's menu modifier.
- **The self-test** (`merge/SelfTest.lua`, `/bookfinder selftest`, 1.7.0): out of combat, in about a minute, it
  checks every part runs; opens each settings page; opens the map, the books tab (rows, travel times), the quests
  tab (Questie's list there) and the services tab; checks nothing tracks on screen; searches a place, a book and
  Questie's quests, NPCs, items and objects (after the index reads); flips every Show-menu switch and back (not
  the books route); plans a journey to 15 places across both continents (skipped while a journey of yours is under
  way) and keeps each route's estimate, time and legs; builds the books route; takes the inspect snapshot; counts
  new Lua errors. Everything goes to `BookFinderDB.selftest` (checks with pass/fail, detail and ms; routes), the
  failures to chat.
- **One door for journeys** (`merge/Journeys.lua`, 1.8.0). At login it wraps `ShortestPathForever.API.NavigateRoute`
  (and `Navigate`, `Cancel`) in place, so the search, the books, Nearby services, the TomTom stand-in (Questie's
  quests) and any guide pass through it. Shortest Path answers `false` without a word in combat, with journeys off,
  with no position, and for a point on no map; the wrapper works out which (`whyNot`), says it with
  `BookFinder.Notice` (the game's `UIErrorsFrame` line and chat; the same line at most once in 4 s) and records it.
  A request in combat is copied, answered `true`, and asked again 0.2 s after `PLAYER_REGEN_ENABLED`; `Cancel` by
  the same owner forgets it. After a start it reads Shortest Path's `JourneyInfo` once a second (45 s at most): two
  "unreachable" readings running say "No way to X from here" with Shortest Path's reason.
  `BookFinder.Journey(map, x, y, title)` (x, y in 0-100) is the call for BookFinder's own parts;
  `BookFinder.JourneyStatus()` gives "searching" / "unreachable" / "planned", the title and Shortest Path's words.
  `BookFinderDB.attempts` keeps the last 60 requests: time, zone you were in, owner, title, first stop, result
  (`started`, `queued`, `refused`), why, outcome.
- **The Quests tab's journey** (1.8.0) also shows while a search has no plan yet (grey "Finding the fastest way…") and
  when it found none (red, Shortest Path's reason), from `BookFinder.JourneyStatus`.
- **Questie → journeys** (1.8.0, `src/Questie`): `TrackerUtils:SetTomTomTarget` asks `BookFinder.Journey` when no
  `TomTom` global exists; `SetQuestTomTomTarget` says so when the quest has no known place; the menu entries and
  buttons read "Plan a journey" in BookFinder.
- **Offline routing rig** (`tools/routing/rig.py`, `rig.lua`, `audit.lua`; needs `pip install lupa`): loads Shortest
  Path's data, `Transport/Model.lua`, `Routing/Planner.lua`, `PathGrid.lua`, `Path.lua` and the Nav maps into LuaJIT,
  measures the walks a journey would (`Path.FindManySync` from the start and back from the goal) and calls
  `Planner.Plan`. `python3 tools/routing/rig.py` runs the audit: each capital to every flight point, book and test
  place, both factions; it prints the suspect journeys and fails on any with no route or an error. Modes: `all`,
  `fresh` (no flight point known). Any other script gets `rig` (`rig.World`, `rig.Plan`, `rig.Walk`, `rig.Describe`).
- **Fixed in 1.7.0 from Shortest Path's own error journal** (`ShortestPathForeverDB.errors`): its waypoint
  tooltip hook compared a minimap mouseover title that can be a secret value (140 errors); it now checks
  `canaccessvalue` first (`Journey/JourneyGuide.lua`).
- **Client facts** from the first snapshot (1.60.1, build 70938, toc 16001): `Campaign-QuestLog-LoreBook`,
  `QuestLog-icon-setting`, `common-icon-checkmark` and `common-icon-redx` exist; the Show menu's native entries are
  Quest Objectives (`questPOI`), Show Quest Levels (`showQuestLevel`), Quest Difficulty Color
  (`showQuestDifficultyColor`), Low-Level Quests, Tracked Items. Questie treats Quest Objectives (the game's quest
  areas) and its own objective icons as two styles of one thing, so both stay.

### 1.4 One addon: what used to be done twice, and who does it now

Every part keeps every feature it alone has. Where two did the same job, one does it now; the other's unique
bits moved over or stayed. These hold while all three run inside BookFinder; a part replaced by its standalone
addon (quirk 2) behaves as upstream.

| Job | Before | Now | What the other side kept |
|---|---|---|---|
| Settings | OpenMap's own window (AceConfig) + its Settings stub page; SP's Settings category; Books' own window section | **One window: Options › AddOns › BookFinder.** Pages: Shortest Path's (Map marks, Transport, Travel journal, Guidance, Party mage portals, Alerts, Interface, Forever addons), **World map** (OpenMap's whole options table, embedded with `AceConfigDialog:AddToBlizOptions`), **Books**. Every way into settings opens it at its page: `/path`, `/bookfinder`, right-click on the button, the gear in Books' window, OpenMap's options page. | OpenMap's in-map menu stays: it is the map's own quick panel (what shows, search, find me, pins, draw), like Blizzard's map filter. Books' window became the Library books tab of the quest log (1.3b); its settings are the Books page. |
| Minimap button / LDB launcher | Books' LibDBIcon button + launcher; OpenMap's optional button + launcher; SP's "Journey" button under the minimap | **One: BookFinder** (`BookFinderDB.minimap`) | Books' broker text (books collected) is the button's text. Their switches are hidden. |
| Docks (boats, zeppelins) on the world map | OpenMap's + SP's | **Shortest Path's** (live departures, clusters, click opens the other end and pings it, Shift-click a journey) | OpenMap's **airships to Zephras Isle** (own pin set `airships`, follow SP's boats switch) and OpenMap's always-on **route lines** (follow SP's boats switch). OpenMap's Boats and Zeppelins switches leave its menu and options. |
| Flight masters | OpenMap's (learned/grey, click two for a route and time) + SP's (stock look, flights and times in the tooltip, super-track, Shift-click a journey) | **Shortest Path's** | A real journey covers the two-click route. OpenMap's Flight masters switch leaves its menus. |
| Townsfolk / town services | OpenMap's (vendors, repair, inns, bankers, auctioneers, stables, class and profession trainers, mailboxes, spirit healers, rares) + SP's town services | **Shortest Path's** for vendors, repair, inns, banks, auction, stables and trainers (by what they sell, a journey a click away) | OpenMap keeps **mailboxes, spirit healers and rare mobs**. |
| Guidance UI | Books' route tracker frame + arrow, and SP's tracker, arrow and compass | **Shortest Path's.** Turning the books route on sends it to SP; Books' tracker hides while SP guides it and comes back when SP doesn't (combat, journeys off, another journey took over), through SP's `Subscribe`. | Books' Skip / Recalc stay on `/bom` and in its window. |
| First-run windows | OpenMap's welcome (a real choice: OpenMap look or classic), Books' welcome page | **OpenMap's** | SP's one-line What's new after an update is unchanged. |
| Addon compartment | OpenMap's, SP's | **BookFinder's** | |

Code: OpenMap `mod.SUPERSEDED` and `mod.TravelShown` (`Map/WorldMap.lua`), the trimmed `TOWNSFOLK` kinds
(`Map/Townsfolk.lua`), `airships` pin set (`Map/Stitch.lua`), menu rows dropped (`Map/Panel.lua`), routes
(`Map/Routes.lua`), pad view (`Map/PadView.lua`), `ns.BUILT_IN` / `ns.OpenOptionsPage` (`Init.lua`), launcher
(`Map/Launcher.lua`); SP `UI/Settings.lua` (`BUILT_IN`); Books `modules/Options.lua`, `Broker.lua`, `Welcome.lua`,
`Route.lua` (`ns.OnGuidanceChanged`), `Core/Navigation.lua` (`watchGuidance`).

Dragging and zooming the seamless map (1.1.2). OpenMap changes the map underneath as the view crosses zones,
and each change tells every map addon "new map":
- Books on the stitched map is in OpenMap's own icon layer (`S.PinSet("bookfinder_books")`, world space): built
  when the books, the route or a setting change, never on a map change, drag or zoom; culled and sized by OpenMap.
  Click a book: journey there; Shift-click: collected (OpenMap's icons take left clicks only; right-click zooms out
  as everywhere on it). Off the stitched map: Books' canvas pins as upstream.
- Books' own trail is drawn only while Shortest Path isn't guiding the route (its line is the route then).
- OpenMap's scan of every canvas frame for Books' pins (Compat.lua, on each map change and zoom step) is off while
  Books is built in: Books places them above the art itself.
- Shortest Path places its route points on the stitched map with `CanvasFromWorldPos` directly: its old lookup read
  a continent number as a map ID, found nothing, and fell back to two game calls and two vectors per point on every
  redraw.

Still more than one of (different jobs, kept on purpose): bug reports (`/openmap` Report a problem, `/path report`,
`/bom bug`: each goes to its own project's tracker); search (OpenMap: places; SP Nearby: NPCs and items).

---

## 2. OpenMap (built in at `OpenMap/`)

### Features
- One seamless world map: every zone stitched; zoom from Azeroth to street level toward the cursor. It lives in
  Blizzard's world map, so the quest log, map buttons and Questie keep working.
- Closest zoom blends in the game's minimap art (`Close.lua`); zone borders fade and are colour-matched.
- Land with no Forever zone map (Gilneas, ridges round Orgrimmar, west of Searing Gorge, edges of Stonetalon,
  Feralas, Silithus…) drawn from Blizzard's classic and pre-Cataclysm maps (`Gaps`, `GapFills`, `Reveal`).
- Ocean and continent labels rebuilt to scale (`Labels`, `Banners`).
- Dungeon and raid entrances with level ranges coloured for your level; click opens the dungeon's own map in the
  map, every floor, bosses and quests beside it (Questie, Dungeon Journal or NeedRoll); player-drawn maps for
  Forever's own dungeons (`DungeonDrawn`, credited). Five Forever entrances hand-placed, the rest recorded in game.
- Boats, zeppelins and airships (Forever's own too); click one to jump to the other end; routes drawn.
- Underground: caves, mines, crypts and dungeon entrance areas show their map when zoomed in.
- Flight paths: learned in colour, others grey; click two flight masters for the route and rough time.
- Search for a zone, city, dungeon or flight master; Find me button or middle-click; how the map reopens;
  party and raid members across the whole map; optional: hide your own arrow.
- Map pins: Ctrl-click, any number, note and colour, followed with Blizzard's waypoint and TomTom's; share with
  group, guild or a friend (addon messages, prefix `OpenMap`; `OpenMapLoc` for friends' places).
- Drawing on the map: pen, lines, arrows, circles, raid marks; on its own or on a pin (`Sketch.lua`).
- Townsfolk and rares (repair, innkeepers, trainers, bankers, auctioneers, stable masters, spirit healers, rare
  mobs) from Questie's database or a registered provider; toggle Questie's own quest icons from the menu.
- Map fits the screen: resizable window or full screen.
- "Report a problem": draw on the spot, add a note, copy a code (`OM1|…`) for a GitHub issue.
- Gamepad: leaves Blizzard's map alone under the Gamepad UI unless `padMap` or `padView` is on.
- Other addons' HereBeDragons pins (Questie, TomTom, gatherers, notes) placed from every zone in view.
- Compat warnings at login when another map addon's option fights its window (Leatrix Maps, Mapster, Magnify…).
- What's new window from its own changelog.

### Commands, bindings and entry points
- `/openmap` or `/omap`: options. Sub-commands: `status`, `paint`/`notes`, `debug`, `bench [zoom]`, `pins`,
  `news`, `entrance <name>`, `draw`, `dungeons`, `bosses`, `forgetflights`, `welcome`, `highlights`, `warm`,
  `reset` (window size and place), `padview`.
- Key bindings (Keybindings › OpenMap): find me, drop pin, pins, quill (draw), quest log, menu.
- Settings › AddOns › OpenMap (button opens the AceConfig options); optional LDB minimap button.
- ⚙ Its compartment entry is now BookFinder's (left-click still calls OpenMap's own handler).

### Saved variables
`OpenMapDB` (account) and `OpenMapCharDB` (character). `worldmap` defaults: `enabled`, `autoSwitch`,
`hoverHighlight`, `icons`, `boats`, `zeppelins`, `flight`, `playerArrow`, `iconsFrom`, `iconScale`,
`brightness`, `darkening`, `darkenColor`, `routes`, `foundOnly`, `colorMatch`, `desaturate`, `unexplored`,
`gapFills`, `maxZoom`, `chart`, `padMap`, `padView`; plus pins, sketches, favourites (starred switches), window.

### Public API (`OpenMapAPI`, major 1, version 4)
`IsStitched`, `WorldFromMap`, `MapFromWorld`, `CanvasFromWorldPos` (v2), `ArtTopLevel` (v2), `MapAt`,
`CursorPosition` (v3), `GetView`, `ShowWorld`; callbacks `OpenMap_StitchedChanged`, `OpenMap_ViewChanged`,
`OpenMap_DungeonMapShown`, `OpenMap_DungeonMapHidden`; `RegisterMenuToggle`, `RegisterDungeonSection`,
`RegisterTownsfolkProvider` (v4). Global `OpenMap` is its private table (`OpenMap.modules.worldmap` …).

### Its quirks (upstream)
- Replaces the scroll container's `CalculateScrollExtentsAtScale` and, while stitched, `ResetZoom`; swaps the area
  label's OnUpdate. Map switching waits out combat.
- Never compares or nil-tests secret values (`ns.Safe`). `MOD` blend makes the map see-through; alpha-0 regions
  still cost draw time.
- Under the stitched map, `WorldMapFrame:GetMapID()` is only the zone the view is on (why Books needed patching).
- Questie's NPC data and quests are read through non-public modules; they fail quietly if Questie changes.
- Textures need a full client restart when files are added; `/reload` is enough for Lua.

---

## 3. Shortest Path Forever (built in at `ShortestPathForever/`)

### Features
- Plan a journey: Shift-click the world map or minimap, Alt-click over a Questie icon, or *Plan journey* on a
  quest. Mixes walking, flights, boats, zeppelins, lifts, the tram, portals, teleports and hearthstone; replans as
  you move. A spot inside a dungeon leads to its entrance. Walks avoid zones 4+ levels above you and the other
  faction's towns, and say so when they can't. *Keep journeys after a reload*.
- Directions in the shared Forever objective-tracker column (ForeverCore): each step, time and distance left;
  click the current step to complete it; skip a Hearthstone for that journey.
- Route on both maps: breadcrumbs on the minimap, native waypoint to the next step, rim marker off-map, smooth
  flight lines, stop pins (quest-style kinds: pickup, turnin, objective, innkeeper, dungeon, trainer, battlemaster,
  flightmaster, vendor, boat, zeppelin, lift, tram, portal).
- Direction arrow (eases to bearings, distance/time/both label, objectives under it, movable, scalable);
  compass strip (turns, stops, destination, time left; dims when the turn is behind; green in a quest's area;
  movable and resizable separately; pixel nudging with Shift-drag or arrow keys).
- Corpse run: red route to your body as a ghost; the journey resumes when alive.
- Arrival distance 5–50 yd; arrival sound; a map pin set as destination is cleared on arrival.
- Flights and departures: flight-map highlight, flight-master tooltips with times, dock tooltips with
  destinations and departure countdowns, ride times learned across sessions and characters.
- Alerts: banner, transport sound and taskbar flash before your boat; cast prompts for Hearthstone/teleports.
- Nearby services tab (world map quest log side tab): vendors by goods, trainers, inns, banks, AH, flight masters,
  stables, repair, dungeon/raid doors; travel time each; best ammo/food/drink for your level; item search;
  click to travel; nameplate arrows on arrival. Town services drawn on zone/city maps with minimap icons and
  market stalls. Needs QuestieDB; class trainers also use Tweaks Forever.
- Follow guides: RestedXP and Guidelime steps by default; *Resume guide*; TomTom waypoints from other guides when
  TomTom is absent; *Follow TomTom's arrow*; Zygor and Kaliel's Tracker hooks.
- `/way [zone] x y [title]` (claims `/way` only when TomTom and others leave it free); `/path way` always.
- Party mage portals (per-city switches), teleports, minimum hearthstone saving.
- Travel journal (`/path stats`): distance walked, journeys, transports, flights, portals.
- Other faction's boats (off by default) and a hover note when they'd be 2+ minutes faster.
- On OpenMap's stitched map: route and stops drawn across it into neighbouring zones, above OpenMap's art.
  ⚙ Shift-click resolves the zone under the cursor there.
- Forever family hints (grey suggestions for Adventure Guide / Legacy).

### Commands, bindings and entry points
- `/path` or `/shortestpath`: settings; `report`, `issue`, `perf`, `debug`, `stats`, `way …`, `follow [unit|off]`.
- `/spfnear [service]`: Nearby services tab, or route to the nearest service.
- `/way`; `/forever debug` (ForeverCore).
- Bindings (Keybindings › AddOns): travel to map pin, travel to tracked quest, clear journey
  (`CLICK ShortestPathForever…Button:LeftButton`).
- Settings › AddOns › Shortest Path Forever: pages Transport, Guidance, Map marks, Interface, Alerts, Forever addons.
- Its own compartment function `ShortestPathForever_OnAddonCompartmentClick` still exists; ⚙ the toc entry is
  BookFinder's, whose right-click menu opens SP's settings.

### Saved variables
`ShortestPathForeverDB` (account) and `ShortestPathForeverCharDB` (character). Defaults (`ns.Defaults`): `pins`,
`transit`, `portals`, `minimapPins`, `mapFlightMasters`, `mapRoutes`, `townServices` (`"capitals"`),
`townService*` (Innkeeper, Flight, Stable, Repair, Bank, Auction, Class, Professions, Food, Ammunition, Bags,
Reagents, Books, Gear), `mapPinScale`, `flightPinScale`, `minimapPinScale`, `routeColor`, `mapLine`,
`minimapLine`, `laterLegs`, `otherFaction`, `tracker`, `alerts`, `alertSound`, `flightPathReminder`,
`arrivalSound`, `journey`, `destinationPin`, `npcArrows`, `resumeJourney`, `tomtom`, `tomtomFollow`, `restedxp`,
`restedxpHideArrow`, `guidelime`, `taxiRoute`, `teleports`, `partyMagePortals`, `partyMage<City>` ×6,
`hearthMinimumSavings`, `stats`, `guideStops`, `journeyTracker`, `arrow`, `arrowLabel`, `arrowObjectives`,
`arrivalPin`, `arrivalDistance`, `metres`, `minimapButton`, `compass`, `compassTime`, `compassScale`,
`arrowScale`, `compassBackground`, `corpse`, `avoidHighZones`, `followRoads`, `whatsNew`.

### Public API (`ShortestPathForever.API`, version 2, minor 0; also `ForeverCore.APIKit` "ShortestPathForever")
`Estimate`, `EstimateDetail`, `NavigateRoute(owner, stops)` (≤64 stops; `map`, `x`, `y` 0..1, `title`,
`tooltip`, `kind`, `hold`, `radius`, `z`, `questID(s)`, `handins`, `npc`, `shapes`), `Navigate`, `CurrentStop`,
`Cancel`, `Journey`, `Pause`, `Resume`, `SkipLeg`, `RenameStop`, `Ended`, `Stats`, `Subscribe`, `Active`.
Reads answer `nil, "loading" | "none" | "combat" | "invalid" | "unreachable"`. Refuses in combat.

### Its quirks (upstream)
- Needs ForeverCore ≥ the toc's `X-Forever-Core`; otherwise `ns.broken` and every file returns.
- Estimates cost 0.5–2.5 ms uncached; callers should make at most one uncached call per frame.
- A journey owned by another addon isn't kept through a reload: the owner resubmits (Books does, 1 s after login).
- `/way` is only taken when free; with RestedXP's TomTom option on, two addons would follow the guide.

---

## 4. Books on map (Forever) (built in at `Books_on_map_Forever/`)

### Features
- The WoW Forever library books (`Data/Books.lua`: key, item, quest, set 1/35/45/60, icon, name, one or more
  locations with place names) as world-map pins; other faction's books removed.
- Pickup detection by item ID (any language) and turned-in detection by quest ID (`Core/Detection.lua`).
- Shift-click a pin: mark collected; right-click: waypoint (SP, else TomTom). Tooltip: place, coordinates,
  route step, count, group needs.
- Minimap pins (size setting), minimap button (LibDBIcon), LibDataBroker launcher.
- Optimised route: nearest neighbour + 2-opt per set, lowest set first (or nearest first), continent penalty;
  skip and recalc; route tracker frame (next book, place, distance, arrow; draggable, position saved);
  trail on the world map (next 5 steps, fading dots, moving spark, numbered pins).
- ⚙ Tracker shows SP's real travel time past 300 yd or across continents.
- Send the whole route to SP (one journey, ≤64 stops, kind `pickup`), kept in step as books are collected,
  re-sent after combat if refused, resumed after a reload; or to TomTom.
- Group: share progress with party/raid/guild, see what group members still need (desaturated pins), group panel.
- Rewards panel (goals 10 necklace, 20 ring, 25 bow/crest/light), completion toast and sound.
- Nearby notice, welcome page, side tabs, options window (list per set, filters, sizes, language selector,
  bug report button), its own skin.
- Ten languages chosen in options (auto = client).
- ⚙ On OpenMap's stitched map: books of every zone in view; switches in OpenMap's menu.

### Commands
`/bom` or `/books` (options); `list`, `next`, `recalc`, `share [group|guild|say] [missing]`, `done N`, `undo N`,
`route [list|guide|tomtom]`, `toggle`, `minimap`, `welcome`, `bug`, `reset`, `ids`, `test`.

### Saved variables
`BooksOnMapForeverGlobal` (account: `welcomeSeen`) and `BooksOnMapForeverDB` (character): `collected`, `hidden`,
`pinSize`, `hideMinimapPins`, `minimapPinSize`, `hideMinimap`, `minimapIcon`, `routeOn`, `routePos`,
`resumeRoute`, `lang`, `sideTab`, `folded`, `foldedSets`, `noToasts`, `noNearby`, `hideGroupBooks`,
`showRewards`, `myLevelOnly`, `hideCollected`, `itemIDs`.

### Its quirks (upstream)
- Before this merge it checked SP's API for `version == 1` only (fixed, see 1.3).
- Pins are canvas buttons; OpenMap's `Compat.lua` lifts any canvas child with `.book` and `.loc` above its art.
- Rebuilding pins on every zoom step flickered under OpenMap: zoom only resizes, the trail re-lays after 0.15 s.

---

## 4b. Questie and QuestieDB (built in at `Questie/` and `QuestieDB/`, since 1.2.0)

Questie 12.8.0 (WoW Forever toc) and its database QuestieDB 1.1.0, folded into the same addon. Every Questie feature
stays: quest givers, objectives and turn-ins on the world map and minimap, its quest tracker, tooltips, My Journey
(quest history and its search of every quest, NPC, object and item), party objectives, DBM HUD integration,
nameplate icons, quest links in chat, and its options.

How it's folded in:
- **Load order:** QuestieDB, then Questie, then OpenMap, Shortest Path and Books, as their standalone tocs' `OptionalDeps` had it.
- **The database:** QuestieDB is "baked": its data is its toc's metadata (131,191 `## X-` lines, 18 MB), read with
  `GetAddOnMetadata(<its addon name>, key)`. The name is the file's `...`, so inside BookFinder it reads
  BookFinder's toc, which the build fills with those lines (all `X-` fields but the build stamps). `LoadSavedVariablesFirst: 1` is Questie's,
  now BookFinder's (harmless to the other parts).
- **Private tables:** the build rewrites any `local a, b = ...` (QuestieDB's is `LibQuestieDB`), and puts a guard on
  every Questie and QuestieDB file's first line (`BookFinder.Skip("Questie")`): with a standalone Questie or
  QuestieDB enabled, both of BookFinder's stand aside together.
- **Names:** `IsAddOnLoaded("Questie" | "QuestieDB")` and `loaded(...)` become `BookFinder.Loaded(...)`;
  `("Questie", "Version")`, `("Questie", "X-QuestieDB-Contract")` and `("QuestieDB", "Version")` read BookFinder's
  `X-Questie-Version`, `X-QuestieDB-Contract`, `X-QuestieDB-Version`. Shortest Path's Nearby services reads QuestieDB's
  fields from BookFinder. Questie's "renamed addon" refusal (`VersionCheck.lua`) lets BookFinder through.
- **One of each:** Questie's settings are BookFinder's pages ("Quests", "Quests: <tab>"), and both of its windows
  (`/questie`, Shift-click) open them; BookFinder lists its window once Questie's pages are in (15 s fallback). No
  Questie minimap button or broker launcher (a stand-in table keeps its text); its My Journey and quest settings are
  in BookFinder's minimap menu.
- **Saved variables:** `QuestieConfig`, `QuestieProfilerEnabled` (account), `QuestieConfigCharacter` (character);
  `tools/migrate_savedvariables.py` copies them.

Quirks: addons outside BookFinder that look for Questie by folder name won't see it (ForeverCore uses the
`Questie` global and still does). QuestieTrace (Questie's data-collection tool for its developers) isn't included.

## 5. How the parts work together (after the merge)

| From → to | How | Works without the other? |
|---|---|---|
| Books → SP | `ShortestPathForever.API` v1/v2: Navigate, NavigateRoute, CurrentStop, Cancel, Estimate | yes: TomTom, or nothing |
| Books → OpenMap | `OpenMapAPI`: IsStitched, ArtTopLevel, CanvasFromWorldPos, callbacks, RegisterMenuToggle | yes: Blizzard's map |
| SP → OpenMap | `OpenMapAPI`: IsStitched, ArtTopLevel, CanvasFromWorldPos, ⚙ CursorPosition/MapAt/MapFromWorld | yes |
| OpenMap → Books | `Compat.lua` lifts Books' pins above the art (⚙ also for the built-in part) | yes |
| OpenMap → SP | `WorldMap.lua:979` calls `ShortestPathForever.API.Navigate("OpenMap", …)` | yes |
| Bridge → all | `/bookfinder`, compartment entry, SP switches in OpenMap's menu | — |

They talk only through these public APIs, so each part still works when another is turned off or replaced by
its standalone copy.

---

## 6. Merge quirks and risks (read before changing anything)

0. **Flight points.** Shortest Path learns flight points only at a flight master's map, and keeps them in
   `ShortestPathForeverCharDB.taxi`. Without the migration below, BookFinder starts with none, and every journey is
   planned on foot (a player's report: Thousand Needles to Blackfathom Deeps as a 33-minute walk). Since 1.1.1 the
   Bridge learns the points the game lists as found (`C_TaxiMap.GetTaxiNodesForMap`) at login, only when that list
   also marks some as undiscovered (WoW Forever can list every point as found, learned or not: OpenMap's guard),
   and never forgets any from it; and while none are known past level 10 it says in chat how to fix it.
1. **Saved settings don't carry over by themselves.** The game keeps saved variables per addon folder
   (`WTF/Account/<acct>/SavedVariables/OpenMap.lua` …). BookFinder reads `BookFinder.lua`. Run
   `tools/migrate_savedvariables.py <WTF folder>` once with the game closed: it copies the six variables from the
   old files into BookFinder's (account and every character), keeping what's already there.
2. **Don't run a standalone copy alongside.** If OpenMap, Shortest Path Forever or Books on map is also enabled,
   BookFinder's copy of that part stands aside and a chat line says so. The standalone copy then works with the
   built-in others through the same APIs.
3. **ForeverCore stays separate.** Other Forever addons (Adventure Guide, Legacy, SkillUp…) declare
   `Dependencies: ForeverCore` by folder name, and two copies would fight over the shared tracker column. Install
   `ForeverCore/` beside `BookFinder/` (the zip has both).
4. **Name-based checks from other addons.** Anything that asks `IsAddOnLoaded("ShortestPathForever")`,
   `("OpenMap")` or `("Books_on_map_Forever")` now gets false. Inside BookFinder these checks were patched.
   ForeverCore's *Forever addons* page lists Shortest Path Forever as "not installed" (cosmetic: its API is
   published and works). Unverified: whether Adventure Guide/SkillUp/Legacy find SP by name or by
   `ShortestPathForever.API` / `ForeverCore.APIKit` (SP publishes both). If one of them stops sending journeys,
   run SP standalone (quirk 2).
5. **Versions.** `## Version` is BookFinder's (1.0.0). Each part reads its own: `X-OpenMap-Version`,
   `X-SPF-Version`, `X-Books-Version`. ForeverCore's bug report shows BookFinder's version as the addon's.
6. **One addon in the game's CPU/memory profiler.** `/path perf` measures the whole BookFinder now.
7. **No doubled marks.** OpenMap's docks, flight masters and the townsfolk Shortest Path lists are off while SP runs
   inside BookFinder (1.4); their saved switches are set off (fresh saves default off). A standalone OpenMap
   keeps them, and turns them back on from its own menu.
8. **Shared libraries.** OpenMap ships LibStub, CallbackHandler, AceGUI, AceConfig; Books ships LibStub,
   CallbackHandler, LibDataBroker, LibDBIcon. Both copies load; LibStub keeps the newest.
9. **Map art not in git.** Build with textures before installing; a `--no-textures` build has no map art.
10. **Load order inside the toc** is OpenMap → SP → Books. Books and SP find each other's APIs lazily (at login or
    on use), so the order only matters for upstream `OptionalDeps`, which it follows.
11. **Licences.** GPL-3.0 (SP) + MIT (OpenMap) combine as GPL-3.0; Books' terms unknown.

---

## 7. Verification

- `luac5.1 -p` on every Lua file of `src/` and `build/` (281 files): no syntax errors.
- `python3 tools/offline-test/merged.py` (needs `pip install lupa`; build first): loads ForeverCore and the three
  standalone addons in OpenMap's WoW stub, then ForeverCore + BookFinder, then BookFinder with standalone OpenMap
  enabled ("shadow"). It fires login, entering world, combat and every part's slash commands, and fails on any
  error only the merged build has, on a missing slash command, and on these checks:
  separate private tables; `OpenMap` global = OpenMap's table; OpenMap's media path inside BookFinder; APIs
  published; OpenMap stands aside in shadow mode while SP and Books keep running; **Books sends waypoints and its
  whole route to SP v2 as `pickup` stops; Books gets SP's travel time; on a stitched map Books shows books of
  several zones above OpenMap's art, and only the zone's own off it; OpenMap's menu has all six switches and
  they change Books' and SP's settings.** A mutation test (restoring Books' old `version == 1` check) fails 4
  of them, so the checks bite.
- Unification checks (merged run): one category in the AddOns list (BookFinder) and no other top-level one;
  World map, Map marks, Transport, Guidance and Books pages in it; each page opens; one LibDBIcon button and one
  LDB launcher (BookFinder); no OpenMap or SP minimap button; OpenMap's docks and flight masters handed to SP and
  off; OpenMap's townsfolk without vendors, inns and trainers but with mailboxes, spirit healers and rares; the
  airships follow SP's boats switch; Books' tracker hidden while SP guides the route and back when it stops.
  Mutation tests (Books' launcher and button re-enabled) fail them.
- The stub has gaps both runs hit the same way (8 errors: Blizzard's settings layout, a canvas, a skinned frame):
  SP's settings page, Books' skinned frames and the real stitched map are not exercised offline.

### Still needs an in-game check
- Install, `/reload`, no Lua errors; textures show (full client restart after first install).
- The Library books tab: its glyph beside the quest log's other tabs, the parchment and rows like Shortest Path's Nearby services, travel times filling in, click/Shift-click/right-click on a book, the gear's filters.
- Stitched map: books of neighbouring zones show and line up with the art; trail follows when panning/zooming.
- Shift-click a neighbouring zone on the stitched map: SP plans to that spot (and the right floor underground).
- Books' route tracker: travel time appears, sensible.
- OpenMap menu: Books and Shortest Path sections; switches work and survive a reload.
- Compartment entry and minimap button: left-click map, right-click menu; the button's tooltip.
- Options › AddOns: one BookFinder entry; its pages all there (World map, Shortest Path's, Books) and each works
  (the offline stub stops SP's settings before Alerts and Interface, so those are checked only in game).
- World map: no OpenMap boats, zeppelins or flight masters beside SP's; Zephras Isle airships still there.
- Books route on: SP's tracker guides it and Books' tracker stays hidden; cancel SP's journey and it comes back.
- With the old standalone folders still enabled: the chat note, and nothing breaks.
