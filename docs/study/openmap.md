# Study: OpenMap v0.8.9, from a player's side

Read for reference only (https://github.com/openmap-world/openmap, released 2026-11-14). What a player sees, clicks,
reads and what it says to other players. Nothing here is their code.

## What it is

One seamless world map inside the game's own map window: every zone's art stitched into one world, zoom from the
whole world down to street level and pan across zones, continents and the world. The quest log, the map's own buttons,
Questie and other map addons keep working on it.

## The map itself

- **Zoom** with the wheel toward the cursor. **Drag** pans. **Left-click** zooms into the zone or city under the cursor;
  **right-click** zooms out a level (a city's map steps out to its zone first). **Middle-click** centres on you.
  **Ctrl-click** drops a map pin. A drag that wanders back isn't a click.
- **Zone borders blend**: neighbouring zones fade into each other, mountains at borders colour-matched toward a shared
  palette (zone insides keep their colours).
- **The whole map**: land the game has no zone map for (Gilneas, ridges around Orgrimmar, west of Searing Gorge, edges
  of Stonetalon, Feralas, Silithus...) drawn from Blizzard's older maps of it; land no map ever drew left as plain
  parchment. Hand-painted gap fills and the ocean border (by Santiago Reyes, with permission) are separate switches.
- **Ocean and continent names** redrawn in the game's map font so they zoom properly.
- **Up close**: past the painted map's detail, the game's own minimap is mixed in (tree cover, rocks, buildings),
  softened, with paper grain; in major cities at half strength. Caves, mines, crypts and dungeon entrance areas show
  their own map when zoomed into (Blizzard's or the minimap's). Underground floors and dungeon floors have pickers.
- **Unexplored areas**: shown, darkened and cooled (colour and amount adjustable), or hidden like Blizzard's map; can be
  per character.
- **Your arrow** on or off ("find your way old-school"). **Party and raid members** as class-coloured dots anywhere.
- **Load the zone in view**: once the map stops, the zone or continent in view becomes the game's current map, so its
  quest areas, coordinates and other addons' icons load.
- **Coordinates bar** along the map's foot: your position, and the zone and position under the cursor ("Cursor:
  28.8, 49.8 | Player: 45.6, 59.0" in the title bar; zone name + coordinates at the bottom).
- **Zone levels**: hovering a zone shows its level range coloured for your level, and the Fishing skill needed there.
- **Fade while moving** (0 to 90%), **frame rate cap** while the map is open (60 by default since v0.8.9).
- **Window**: resize the windowed map from either bottom corner, move it by its title bar, Map size slider, reset;
  full-screen fills the screen's width; chat can stay over the full-screen map.
- **Gamepad UI**: an optional controller view of its own (test).
- **First run**: "Choose your map": **Classic** (unexplored hidden, no dungeon or flight master icons, no zone levels)
  or **OpenMap** (the whole map with everything).

## Icons on the map

- **Dungeons and raids**: entrances with their level range under the icon, coloured for your level ("12-18"). Hover:
  the dungeon, its levels, its bosses count, "Click to see what's inside" / "Click to open its map" / "Click to pick
  one" (several at one entrance). Click: the dungeon's map opens right in the map window (every floor; floor picker or
  arrows), with tabs at its edge: **Bosses** (in the game's order, pinned on the map), **Quests** (with Questie: the
  ones you can take, marked "Completed" or "In your quest log"; with Dungeon Journal or NeedRoll a button to open them
  there), **Loot** (points to NeedRoll or the Adventure Guide). "Back to the world map, where you were" (or
  right-click, Escape, scroll out). With Dungeon Journal installed, an entrance can open its page instead. Maps drawn
  for WoW: Forever's own dungeons (Blackmaw Hold, City of Dalaran with the Underbelly, Shaper's Terrace...) credited
  "Map by <name>".
- **Boats, zeppelins and airships** (Forever's too): click one to jump to the other end (the Zephras Isle airships
  open its map); their routes as lines (switch). Tooltips: "Boat"/"Zeppelin"/"Airship", "To <place>", "Click to go to
  the other end" / "Click to open its map"; Neutral routes marked.
- **Flight masters**: learned in colour, the rest greyed ("Learned"/"Not learned"). Click one, then another: the route
  you'd fly and "about 2 min", "1 stop"/"3 stops"; "No flight route from A to B.", "needs flight masters you haven't
  learned". Druid-only Nighthaven shows for druids only.
- **Townsfolk** (from Questie's database; "Townsfolk (needs Questie)" without it): Vendors, Repair, Innkeepers, Bankers,
  Mailboxes, Auctioneers, Stable masters, Class trainers, Profession trainers, Spirit healers, Rare mobs ("Rare",
  "Rare Elite"). Each its own switch.
- **Quests from every zone**: the quests in your log on the map at any zoom, not only the zone you're zoomed into.
  Click: "track this quest and zoom to it" (and show it in the quest log).
- **Questie's icons**: one switch for Questie's map icons; Questie's "!" and "?" stay in front of OpenMap's icons, its
  townsfolk under them.
- **Friends and guild**: a badge on each zone with the friends or guild members there (hover: names, level, class
  colour, "Guild"/"Friend", "... and 5 more"), or a class-coloured dot where they stand for those who share their place
  ("Updated 30 s ago").
- **Hide world markers in instances** (off by default).
- **Icon size** and **Icons from zoom** (Auto, or from a set zoom); "Only places you've found".
- **Fade icons while zooming**: other addons' icons rest while zooming ("Improves performance").

## The OpenMap menu (the panel you like)

Opened by the **OpenMap button** in the map's bottom-left corner (or, with "Buttons as edge tabs", a tab at the
window's edge), `/openmap`, the minimap's AddOns list, or OpenMap's optional minimap button. A floating panel in the
map window's own frame (its metal border, bronze edges and rules), draggable, resizable ("Resize the OpenMap menu"),
remembers where it was and whether it was open, closes with Escape or ×.

- Title: "OpenMap v0.8.9". A search box: **"Find a place"** (zones, cities, dungeons, flight masters; results by kind:
  Continent, Zone, Raid, Dungeon, Flight master, Group).
- **Action tiles** (icon + label, each with a star): **Find me** (glide to you), **Drop a pin** (click, then click the
  map; right-click stops following), **Pins** (the list; right-click hides your pins), **Quill** (draw), **Quest log**
  (show or hide it beside the map), **Report a problem**, **What's new** (glows after an update).
- **Tabs**: **On the map / Look / More**, each a two-column checklist: a tick box, the item's icon, its label, a star
  at the right; headings in gold with a rule. A star puts that action or setting on the map as a button of its own.
  - On the map: Dungeons (Dungeon maps, Level ranges, Dungeon bosses, Dungeon quests, Entrances open Dungeon Journal),
    Townsfolk (the eleven above), Places (Dungeons and raids, Boats, Zeppelins, Flight masters, Only places you've
    found, Boat and zeppelin routes, Your arrow, Party and raid members, Friends on the map, Guild members on the map,
    Hide world markers in instances, Your drawings, Quests from every zone, Questie icons, Fade icons while zooming
    "Improves performance").
  - Look: Unexplored areas (Darken, Hide, Only for this character), The map (Responsive ocean & border, Zone highlight
    on hover, Zone levels, Coordinates, Buttons as edge tabs, OpenMap button on the map, Minimap button, Full-screen
    map fills the width, Chat over the full-screen map, OpenMap's map with the Gamepad UI (test)), Up close (Minimap
    detail, Minimap detail in major cities, Minimap in the gaps, Soften and paper grain, Caves underground).
  - More: Moving about (Load the zone in view, Ctrl-click drops a pin, Follow new pins), Reopen map (choose one: Center
    on player, Center on player keep zoom, Center on your zone, Always remember, Remember while visible), Sharing (Pins
    others share with you, Send new pins to group, Auto-add group's pins, Share where you are "Your guild and friends
    see you"), Tools (Map notes, Debug overlay (FPS)).
  - Sliders under the lists: Deepest zoom, Minimap detail from, Minimap opacity, Icons from, Icon size, Map size,
    Map brightness, Colour matching, Take colour out, Darkening, Minimap strength, Fade while moving, Map frame rate
    cap; **Reset size and place**, **Defaults**.
- Footer: "A star puts that action or setting on the map as a button of its own."
- **Favourites** on the map: starred actions and settings as small buttons in a row beside the OpenMap button (an
  arrow folds the row away), or as tabs at the window's edge; Shift-right-click takes one off; a setting's button is
  lit when on.

Also: an **Options page** in the game's settings (the same settings plus colour, brightness and the rest), and the
**What's new** window (versions newest first, Newer/Older, Credits, "OpenMap is made by Ji, and it's open source").

## Map pins

- As many as you like, each with a **note** and a **colour** (Gold, Red, Green, Blue, Purple), kept for every
  character. Ctrl-click the map or Drop a pin; the pin's **card** opens: its note ("Enter saves"), colour, **Follow**
  (Blizzard's waypoint and its arrow on it, and TomTom's), **Drawing** (draw on the map attached to the pin), **Share**
  (Group, Guild, Target, Code), **Done**, **Delete**.
- Hover a pin: its note, "Shared by <name>", "Followed (the waypoint)", "Click to edit its note, follow, share or
  delete it", "Shift-click: share in chat", "Alt-click: delete it".
- **Pins list** (`/openmap pins`): every pin ("Map pins (12)"), drawing/followed marks, "Click to go there, right-click
  to open its card"; **Import** (paste a code), **Share all** (as a code, to your group, to your guild), **Clear**
  ("Delete all 12 map pins?").
- **Follow new pins** (on by default), **Send new pins to group**, **Auto-add group's pins**, **Pins others share with
  you** (asked first: "<name> shared 3 map pin(s) with you:", Add them / Ignore).
- The followed waypoint has its own marker: "Waypoint", "Click to stop following it", "Shift-click: share in chat".

## The quill (drawing)

Draw on the world, continent and zone maps, kept for you: **Pen**, **Line**, **Arrow**, **Circle**, **Mark** (raid
marks; right-click the button for another), **Erase**; ink Black, Red, Blue, Green, Gold, White; width Fine, Medium,
Broad; Undo (Ctrl-Z), Clear (click twice), Done (Escape). A drawing can belong to a pin (deleting the pin takes it).
"Your drawings" switch shows or hides them. A limit warns when there's too much.

## Map notes (a tool)

Paint areas on the map (brush sizes) and write what's there: kinds "Fix this", "Look into this", "Idea"; a list, export
as text, undo, clear. Saved for copying out.

## Messages and warnings in chat

Prefixed with OpenMap's name. Examples: "Updated to v0.8.9: see What's new in the OpenMap menu.", other map addons
fighting it ("Leatrix Maps: turn off <option> there", "Enhance QoL: if its Mover > World Map is on, turn it off",
MapUtils), "You aren't on the world map here (an instance or a place it doesn't cover).", "The quest log can't be
opened or closed in combat.", "Takes effect after a /reload.", pins shared and added, flight paths forgotten.

## Commands and key bindings

`/openmap` or `/omap`: the menu. `status`, `notes`, `debug`, `bench`, `pins`, `news`, `draw`, `dungeons`, `welcome`,
`reset` (the window's size and place), `forgetflights`, and developer tools (`entrance`, `bosses`, `highlights`).
Key bindings: Find me, Drop a pin, Pins, Quill, Quest log, The map's menu. Addon compartment entry and an optional
minimap button ("Click: the map and its menu", "Right-click: the options window", "Drag: move it round the minimap").

## What it says to other players (must keep working with them)

- **Your place** (prefix **`OpenMapLoc`**), to your guild and by whisper or Battle.net to friends who use OpenMap,
  never from a dungeon, raid or battleground, only with "Share where you are" on:
  - `L1<tab>uiMapID<tab>x<tab>y<tab>CLASS<tab>level` (x, y 0..1 with four decimals), every 10 s while moving, every
    60 s standing still; a dot goes after 150 s without word.
  - `L0`: stopped sharing. `H1`: hello (a friend answers with their place, or `H2`). `H2`: "I use OpenMap".
  - Only from your guild, or whispers from friends; the other faction's places (Battle.net) are never shown.
- **Map pins** (prefix **`OpenMap`**), to party/raid, guild, or a whispered target:
  `P1<tab>uiMapID<tab>x<tab>y<tab>colour<tab>note` (at most 255 bytes, note cut short), a few a second; the receiver
  is asked first (unless "Auto-add group's pins" and it came from the group).
- **Pin codes** to paste anywhere: `OMPINS1:` then each pin `map,x,y,colour,note` joined by `;`, the note's `%`, `,`
  and `;` written as `%XX`.
- So BookFinder must speak all three to share places and pins with OpenMap users, and read their codes.

## Saved settings

Account (OpenMapDB): every switch and slider, pins, drawings, notes, favourites, the menu's place and size, the
window's size, flight data learned. Per character (OpenMapCharDB): its own choices (unexplored areas per character).
