# Study: Books on map (Forever) 2.3.0, from a player's side

Read for reference only: what a player sees, clicks, reads and hears, and what it says to other players. Nothing
here is their code. Version studied: 2.3.0 (the zip you sent), author Daeler.

## What it is

The WoW: Forever library books: 39 in the list (one book exists for one faction only, so 38 count for each player),
in four sets: **Starting set** (16), **Level 35 set** (7), **Level 45 set** (7), **Level 60 set** (8). A book can have
more than one place (Rumi of Gnomeregan: Sentinel Hill, Westfall, or Thelsamar, Loch Modan). Books the other faction
can't loot are dropped from your list at login.

Each book: its name, its set, its item icon, an item ID and the library turn-in quest ID (both used to tick it off by
itself), and each place as zone + coordinates + a place name ("Tower of Azora, Elwynn Forest"; some are long hints:
"Cave entrance, then Cavern of Mists (52.8, 54.7 on cave map)", "Inside Blackrock Mountain, platform before the
Blackrock Depths entrance (48.4, 63.6 on the mountain map)").

**Rewards** at the library: 10 books a necklace (Scholarly Pendant or Erudite's Amulet), 20 a ring (Field Researcher's
Loop or Philanthropist's Ring), 25 a bow, crest or light (Truthseeker's Bow, Crest of Elucidation, Researcher's Night
Light), 38 a necklace or shield (Antique Bulwark, Museum Keeper's Chain, Artifact Seeker's Pendant). The 38 tier is new
in 2.3.0.

## Ticking books off (automatic)

- A book in your bags, or already in your bank, is collected (by item ID in any language, else by its name in any of
  the ten languages; French apostrophes and spaces are evened out).
- A book handed in at the library (its quest completed) is collected, at login too.
- Looting one says so (see Messages) and shows the "Book found!" card; one found in the bank or already handed in is
  ticked off quietly.
- Ticking by hand: Shift-click its map pin or minimap pin, or tick its box in the window; `/bom done N`, `/bom undo N`.
- Every item tooltip of a library book gets a line: "Library book - collected / missing (its set)", collected in green,
  missing in red.

## On the world map

- Each missing book is a pin at each of its places: the book's own item icon, 20 px by default (10 to 40), smaller
  (70%) on continent maps. Pins keep their size on screen while zooming.
- Books your group still needs (and you don't) show greyed and a little faded.
- Hover: book name (gold), place and coordinates, "Route step N" if on the route, "Books: 12/38", the group lines
  (each member, collected in green / missing in red), "Shift-click: mark as collected", "Right-click: <TomTom or
  Shortest Path> waypoint".
- Right-click: a waypoint (Shortest Path, else TomTom). Shift-click: collected.
- With the route on: the next five steps numbered on their pins, and a trail of soft dots between them, fading with
  each step further away, with a single spark running along it toward the next books.

## On the minimap

- Missing books within the minimap's range, as their icons (14 px, 8 to 30), following a rotating minimap, a square
  minimap, indoor and outdoor zoom. The route's next book stays on the minimap's edge even when it's out of range.
- Hover: as on the map, plus the distance in yards. Same clicks.

## The book window (`/bom`)

A dark, rounded, blue-accented window of its own (470 x 760), draggable, closes with Escape. Title: the addon icon,
"Books on map Forever", the version, a **Bug** button and a **language** dropdown (Auto, EN, FR, DE, ES, IT, PT, RU,
KO, ZH, TW; changing it asks to reload).

- **Progress**: a bar of books collected with notches at 10, 20, 25 and 38, the numbers under them going green once
  reached; hover lists the four rewards, reached ones green.
- **Settings** (foldable): Show on the map; Map icon size; Show books on the minimap; Minimap icon size; Show the
  minimap button; Notify when a book is collected; Alert when a book is nearby.
- **Filters** (foldable): Hide collected books; Only sets for my level; Also show the books my group is missing.
- **The list**: each set as a foldable header with "n / total", each book a row: icon, name, place and coordinates,
  and a tick box (ticked = collected, hidden from the map). Click a row: the map opens on its zone. Right-click: a
  waypoint. Hover: name, every place, the group lines, the click hints.
- **Footer**: Show all, Hide all, Optimized route.
- **Side tabs** on the window's right edge open panels beside it:
  - **Rewards**: each tier ("10 books: necklace" ... "1 / 10"), its items with their real icons, names in quality
    colour and slot ("Neck", "Ranged - Bows"); hover: the item's tooltip; Shift-click links it, Ctrl-click tries it on.
  - **Group**: each member who shares their books (class colour, "n / 38", their version), "(you)" for you, and the
    books they still need greyed out ("Greyed out = missing - Click: map"); then "Other group members" without the
    addon or with another version ("no addon or < v1.0.7", "older/newer/different version (vX)") and "Books are only
    shared with the same version of the addon: update it." Empty: "You are not in a group." / "Nobody in your group
    shares their books yet."
- **Welcome page** (once per version, `/bom welcome`): tagline "Every WoW Forever library book on your map. Collect
  them all and earn the library rewards.", Features (Map and minimap, Automatic detection, Optimized route, Group mode,
  Rewards), "New in this version", Commands, buttons "Let's go!", "Open the book list", "Report a bug".

## Optimized route

- Every book you still need, set by set (Starting, 35, 45, 60), each set ordered for least travel (nearest first, then
  improved), each set starting where the last ended; another continent counts as a long trip. "Recalc" starts it from
  the nearest book.
- A **route tracker** on screen (draggable, its place saved): the next book's icon, "1/17 Name", its place and
  coordinates, the distance in yards ("other continent" if far), an arrow pointing at it; buttons **Skip** (this
  session), **Recalc**, **Guide** (sends the whole route to Shortest Path) or **TomTom** (to TomTom), and a close ×.
- Collecting a book moves the route on; `/bom route list` prints it.

## Alerts (cards at the top of the screen)

One card at a time, queued, top centre, coloured by kind; it slides in, its icon pops, a light sweep passes over it,
a thin line counts down (pauses while hovered). Left-click opens the window, right-click dismisses.

- **Book nearby!** (blue, with a sonar ping sound): within 50 yards of a book you don't have; the book's name, its
  place and coordinates, the distance. Re-arms once you're 100 yards away. A book in your bags is ticked instead.
- **Book found!** (green): the book's name and a progress bar to the next count.
- **Reward reached** (gold, with its own completion sound): "10 books: hand them in at the library!", "Necklace
  unlocked" (and Ring, Bow crest or light, Necklace or shield).
- **New reward tier!** (gold, once): "38 books: 3 new rewards", "A necklace or a shield - click to see them".
- `/bom test` plays them all.

## Minimap button and launcher

A minimap button (LibDBIcon) and a DataBroker launcher (Titan, ElvUI...): text "12/38"; tooltip "Collected: 12/38",
"Nearest: name - 340 yd" (or "other continent"), the group's counts; left-click opens the window, right-click hides
or shows the map icons.

## Chat

Every line starts "Books on map:" in green. Examples: "<book> collected (12/38)", "<book> shown on map again",
"book nearby: <book> - <place> (x, y), 32 yd", "nearest book: ...", "route: 17 books, lowest level first.",
"list reset.", "map icons hidden/shown.", "TomTom is not installed.", "17 waypoints sent to TomTom.", "17 stops sent to
Shortest Path.", "Shortest Path could not start guiding (in combat, or its journeys are turned off)."

## Commands

`/bom` or `/books`: the window. `list` (every book, collected in green), `next` (nearest book and a waypoint),
`recalc`, `route` (on/off), `route list|guide|tomtom`, `share [group|guild|say] [missing]` (posts "Books on map:
12/38 library books - next reward: ring (20)" and, with `missing`, the missing books' names in lines under 250
characters), `done N`, `undo N`, `toggle` (map icons), `minimap` (button), `welcome`, `bug` (a Discord link to copy),
`test`, `reset`, `ids` (prints every bag item's ID).

## Languages

Ten: English, French, German, Spanish, Italian, Portuguese, Russian, Korean, Simplified and Traditional Chinese; book
and place names translated; the window can use a language other than the client's (with that alphabet's font).

## What it says to other players (must keep working with them)

- Addon message prefix **`BooksOnMapFE`**, to the party or raid.
- **State**: `S<book count>:<one 0/1 per book, in the list's order>:<version>`, sent a second after any change (several
  changes make one message) and when the group changes.
- **Request**: `R`: everyone answers with their state.
- A state whose book count or length differs from yours is "another version": listed, books not shared.
- Names are full names without the realm (on Forever, names are two words).
- So BookFinder must: keep the same 39 books **in the same order** (the order is the protocol), send and answer `R`,
  and treat a different count as another version.

## Saved settings

Per character: collected books, hidden, pin sizes, minimap pins, minimap button, toasts, nearby alerts, filters, folded
sets and sections, route on and the tracker's place, language. Account: which welcome page was seen.
