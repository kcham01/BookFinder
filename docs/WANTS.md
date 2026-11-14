# What you want from BookFinder (running notes)

Kept up to date as you say things. Newest decisions win; anything struck out was replaced.

## The goal
- **One brand-new addon**, not addons stitched together. Built from OpenMap, Shortest Path Forever,
  Books on map Forever and Questie (with QuestieDB). Every feature of each is kept, and no two parts do the same job.
- For **personal use**. The point is that the parts work together seamlessly.
- "Beautiful" means **useful and seamless with the WoW UI and other addons**, not fluff or bloat.
- **Don't rush.** It has to be polished, seamless and gorgeous. Hand over a finished product, then you test.
- The full addon lives on `main`, and you get a zip each time.

## Settings and buttons
- **One settings window**: Options › AddOns › BookFinder, with every part as a page of it.
- **One minimap button.**

## Map
- Zooming and dragging must be **smooth**: icons and paths mustn't lag or jump.
- Routes must be real journeys (flights, boats, portals), never straight-line walks.
- OpenMap's map menu stays **the** one map menu, with no second menu stacked beside it.

## UI direction (current)
- You didn't like the books window that opens from the game options, or the separate menu on the right of the map.
  They should be **one thing**.
- You hoped it would **live in the quest log**, the way Shortest Path's Nearby services tab does.
- ~~1.3.0's overlay panel on the map~~: rejected. It duplicated Shortest Path's Nearby services and looked
  "frankenstein".
- Now:
  - **Books becomes a quest-log tab**, in Shortest Path's exact visual style (native quest-log art, search box,
    collapsible sections, large rows).
  - Shortest Path's Nearby services tab stays as it is, with no duplicate of it.
  - Questie is fully built in, not a separate addon. Its data and search are available to use.

## Feedback on 1.4.0 (screenshots, Undercity)
- **One map menu**: the map's own "Show:" dropdown (the one with Quest Objectives, Flight Masters, Nearby services,
  Town services) should hold the options from Questie's and the other addons' dropdowns too, with nothing twice.
- **One search that finds everything**: the quest log tab's search (like Nearby services' "Search services and
  goods") should search everything Questie can (quests, NPCs, objects, items) and everything the other parts can
  (places, services, goods, books).
- **One tracker**: you expected Questie's tracker to fully replace the native one, but there is still a separate
  block under it (the "Lifts" block). Nothing should look like two trackers.
- **No bloat**: too many menus and too much dead code. The settings tree is long. The front page is a column of
  "Open" buttons, and some pages hold one or three options (Travel journal, Transport). Merge thin pages and drop
  the dead ones.
- ~~**Routing at "Google Maps" quality**~~ (dropped after 1.8.1: routing is being removed): still not good enough. Journeys must be the fastest real way, with
  flights, boats, zeppelins, portals and hearthstone. Needed from you: `/path report` straight after a bad route,
  plus a screenshot.
- **Blizzard-level feel**: "like the game was built with it in". Asked you for the client's own UI export
  (`exportInterfaceFiles code`/`art`) and added `/bookfinder inspect` so the build matches the real client.

## Done in 1.4.0 (for you to test)
- The 1.3.0 overlay panel and its button are gone. OpenMap's map menu is back as the one map menu.
- The Library books tab is in the quest log, in Shortest Path's style. It replaces Books' own window, and `/bom` and
  the minimap menu open it.
- The minimap menu's Quests entry opens the quest log's own Quests tab.

## Done in 1.5.0 (for you to test)
- **One search**: the Nearby services box now also finds quests, NPCs, objects, items, places and books.
- **One map menu**: the map's Show menu has Questie's, OpenMap's and Books' switches, and OpenMap's own menu no longer
  repeats them.
- **Settings trimmed**: no Open buttons, and Shortest Path's eight pages are now three. Questie's tabs sit under Quests.
- **Dead files out**: Books' welcome page, broker, minimap button and old side panels are no longer in the build.
- **`/bookfinder inspect`**: run it, open the map's Show menu once, `/reload`, and send `SavedVariables/BookFinder.lua`.

## Done in 1.6.0 (for you to test)
- ~~One tracker skin~~: replaced in 1.7.0 by the quest list in the map.
- **The game reports back by itself**: every session it records the client snapshot, BookFinder's errors and your
  journeys, leg by leg. Send `SavedVariables/BookFinder.lua` now and then; no commands needed.
- Your search screenshots (garre) worked: quests, NPCs, objects and items, with journeys from Undercity via Grom'gol.

## Decided after 1.6.0
- **Quest list in the map, nothing on screen**: Questie's list replaces the game's in the map's Quests tab. The tracker
  on your screen is gone, and so is the journey block (you chose "gone from screen too"). The journey shows at the
  top of the Quests tab instead; the arrow and compass still guide you.
- ~~**Routing must be professional grade**~~ (dropped after 1.8.1): you've said it again; it's the next job, using the journey log.

## Done in 1.7.0 (for you to test)
- The quest list is in the map, with nothing on screen, as above.
- Fixed: the inspect snapshot raised errors at every login in 1.6.0, and Shortest Path's waypoint tooltip hit
  140 errors on a hidden minimap value.

- **`/bookfinder selftest`**: you asked for the addon to test itself in game. It runs every feature, plans
  journeys to 15 places, and logs every check, error and route.

## Said after 1.7.0
- **"It simply just won't route sometimes."** Every bit of code should work together; rewrite whatever is needed to get
  rid of the frankenstein feel.

## Done in 1.8.0 (for you to test)
- **No journey fails in silence** (`merge/Journeys.lua`). Every part asks for journeys through one door. What used to
  be dropped without a word now says why on screen and in chat: in combat (the journey is kept and starts when the
  fight ends), journeys turned off, no position (instances), a place on no map, a quest or item with no known place.
- **The Quests tab shows a journey from the first moment**: "Finding the fastest way…" while it searches, and "No way
  there from here" in red when there is none. Before, both were only in the tracker that 1.7.0 took off the screen,
  so a slow or failed search looked like nothing happened.
- **Questie's "Set TomTom Target" is "Plan a journey"** (Ctrl-click a quest, or its menu), and works with the TomTom
  stand-in switched off.
- **Every request is recorded** in `BookFinderDB.attempts` (who asked, where to, started / kept for after combat /
  refused and why, and whether a way was found). The self-test checks it and waits for each search to finish.
- **Offline routing rig** (`tools/routing/`): Shortest Path's real planner and walking search on its real data,
  without the game. 500+ journeys from all six capitals to every flight point, book and test place: every one gets a
  route, with every flight point known and with none. So the planner is sound; what failed was the hand-off.

## Your 1.8.0 self-test (The Barrens, level 30 Horde) and what it showed
- **Why it "won't route": a first plan to a far place took 15 to 30 s**, with nothing on screen meanwhile. Light's Hope
  Chapel had no plan after 18 s. Shortest Path gives its walking search 2 ms a frame.
- A search shows **interim routes before it is sure** (Camp Mojache: walk to the Great Lift, fly back to Camp Taurajo,
  then walk), which read as nonsense if you catch them.
- Three journeys in the test were replaced by map clicks during it (they ended at unnamed places in The Barrens and
  Wetlands). The test now says to leave the map alone and names the journey that took its place.
- The search failures (quest, NPC, item, object) and "0 rows" in the books tab were the test's own faults: it never
  started the database index, and it counted rows with every set folded.
- You said: "prob just do all 3": mock-ups of every screen first, then the rebuild to match them, then fixes from the
  self-test file and screenshots. "It's janky as is."

## Done in 1.8.1 (for you to test)
- **First plans about four times sooner**: while a journey has no plan at all, its search gets 8 ms a frame; once
  there is a route to follow it goes back to 2 ms.
- The self-test waits for each search's final answer (up to 45 s), keeps what it showed on the way with the second
  it appeared, and records whose journey it read. It takes two to three minutes now.

## Decided after 1.8.1 (newest: these win over anything above)
- **Remove the "Google Maps" routing.** "The routing will never get fixed and it's taking too much energy away from
  the beauty. This just isn't pro grade." Journey planning goes; the effort goes into how the addon looks and feels.
  (This replaces every routing item above: "Routing at Google Maps quality", "Routing must be professional grade",
  the journey card, the journey log, the faster first plans.) What a click on a quest, book or search result does
  instead is still to be agreed.
- **Rebuild, to iron out bugs, remove dead code and make it "stunningly beautiful".** You asked whether it had been
  rewritten from the ground up: it had not; 1.8.0 and 1.8.1 were fixes on the old build.
- **One settings panel, in the style of OpenMap's own settings panel**, which you like. Every setting moves into it
  and anything redundant is removed. (Replaces "One settings window: Options > AddOns > BookFinder".)
- **Bug: the scrollbar at the side doesn't move when you scroll, though the list does.** (Most likely the Quests tab:
  Questie's list scrolls itself while the game's own scrollbar is left showing beside it.)
- **"I hope all of my wants and changes are documented."** They are kept here, newest decisions last; struck-out
  lines were replaced.
- The mock-up page (map panel, click rules, Show menu, settings) was shown; no markup on it yet. Its journey card
  and journey states no longer apply.

- **None of Shortest Path's other features either**: not the Nearby services or dungeons list, not the flight and boat
  icons or departure times, not travel times on books, not the arrow or compass. Shortest Path leaves BookFinder
  entirely, and ForeverCore (its library) with it. A click on a quest, book or search result sets the game's own map
  pin and tracking arrow.

## Done in 2.0.0 (for you to test)
- **Shortest Path is gone, with ForeverCore**: no journeys, travel times, Nearby services, flight and boat icons of
  its own, arrow or compass. OpenMap's own docks, flight masters and town icons are back on its map.
- **A click on a quest, book or search result puts the game's own map pin on it**, with the game's arrow. Questie's
  "Set TomTom Target" is "Map pin", and Ctrl-click on a quest icon does it too.
- **One search** is now the BookFinder tab's search box (it was inside Shortest Path's Nearby services).
- **The scrollbar bug** is fixed: the bar beside the quest list is now Questie's own and moves with the list.
- **One map menu**: OpenMap's panel has every map switch again (Questie icons and the books too); BookFinder adds
  nothing to the game's Show menu.
- The self-test checks the map pin, the search in the BookFinder tab, the scrollbar and every switch on OpenMap's panel.

## Said about 2.0.0
- "It's better." Some things don't quite line up with the frames, but that's fine for now (to fix in the look pass;
  screenshots will show which).
- **The dropdowns should look like Questie's.** You really like Questie's dropdown.

## Done in 2.0.1 (for you to test)
- Every BookFinder dropdown (the minimap button's right-click, the books tab's gear, a book's right-click) is drawn
  with Questie's own dropdown, like its map menu was.
- Questie's own map menu is back: "Townsfolk and quest icons" in the minimap button's right-click opens it (vendors,
  trainers and townsfolk to show, the quest icon switches, its windows). It used to open from Questie's map button,
  which BookFinder leaves out.

## Said about 2.0.1
- "Our drop down" meant **the world map's own Show dropdown** (the native one in the map): it should look like
  Questie's. (2.0.1 had restyled BookFinder's own menus instead; they stay in Questie's style too.)

## Done in 2.0.2 (for you to test)
- The map's Show dropdown is drawn in Questie's style, with the game's own entries (Quest Objectives, Show Quest
  Levels, Quest Difficulty Color, Low-Level Quests, Tracked Items), each doing what it did. If it can't be read, the
  game's own menu opens as before.

## Asked after 2.0.2
- **Show the full addon**, every menu, settings page and dropdown as it would look in game, labelled without long
  explanations, to prove the whole is seen and to make it better. Drawn as one page (the "BookFinder 2.0 Atlas"),
  from the code. Duplicates it shows: townsfolk twice (OpenMap panel and Questie's menu), quest icons four ways,
  low-level quests three ways, coordinates three ways, the World map settings page repeating OpenMap's panel, the book
  switches three ways, two map pins, two searches; dead switches on Questie's Tracker and General pages.

## Said after the Atlas
- "Make it beautiful. Polish it. Pro grade, better than a team of Blizzard devs. Not slapped together. Every feature,
  word, window, icon. Redundancy gone, aesthetics pro grade, usability fluid." Don't call something good just because
  it is already built.

## Done in 2.1.0 (for you to test)
- **One place for every setting.** Every on/off switch is in the map's menu (the OpenMap button). The settings
  window keeps only sliders, choices, sounds, fonts and profiles.
  - World map page: only the fine-tuning (brightness, colour, darkening, zoom depth, map size, icon size, minimap
    detail strengths, fades, frame-rate cap), with a button to open the map's menu.
  - BookFinder page: the button to the map's menu, then the books' icon sizes and language. The Library books page
    is gone (its switches are in the map's menu).
- **Townsfolk once**: Questie's (map and minimap, every trainer and vendor) are switches in the map's menu's Townsfolk
  section; "Profession trainers…" and "Vendors…" open Questie's chooser. OpenMap's own townsfolk step aside (it keeps
  rare mobs). Your old OpenMap townsfolk choices carry over once.
- **Questie's dead and doubled options are gone**: its map, minimap and compartment buttons; map coordinates (the
  map's own are in the menu); townsfolk buttons; "Enable Map Icons" (it is "Quest icons" in the map's menu); and the
  tracker's window options (enable, reset, lock, sizer, hide/minimize in combat or instances, sticky frames, TomTom
  key, growth, height, width, header, background).
- **The books**: their switches (on the map, on the minimap, your group's, collected notice, nearby alert) are in the
  map's menu under Library books. The route is started and stopped in the books tab only.
- **The minimap menu** is where to go: World Map, Quest Log, Library books, Nearest book, My Journey, then Map menu
  and Settings. No switches in it.
- **OpenMap's What's new and Report a problem are gone** (they were OpenMap's own changelog and bug reports).

## Said after 2.1.0
- "It should be one full cohesive product. One thing. New. Not just the addons slapped together." A full rebuild from
  the ground up. "I don't want some addon I could get from CurseForge. I want it to feel custom made by Blizzard for
  me." Quality standards are not a joke.
- The product and its rules are written down in `docs/DESIGN.md`; the rebuild goes surface by surface from there.

## Done in 2.2.0 (for you to test): the rebuild's first surface
- **BookFinder's own settings window.** Every setting of the product, once, in one window drawn with the game's own
  dialog art: Map, Look, Quests, Library, More, and a search over all of them. The map's BookFinder button (bottom
  left of the map), the minimap button's Settings, `/bookfinder` and the game's AddOns list all open it.
- **The old settings are gone**: OpenMap's map menu panel, the World map page, Questie's nine pages and the Library
  books page. The game's AddOns list has one BookFinder entry with an Open button.
- **Quests, in plain words**: the 37 quest settings a player uses (quest icons, quests to pick up, the quest list,
  tooltips, automatic accept and turn-in, nameplates, sounds, group); the rest keep Questie's defaults.

## Said after 2.2.0
- "I just want to be able to find things quickly and feel like I'm getting a lot of use from the addon." The
  Dungeon Journal addon was an example of something both pretty and genuinely useful, not a gimmick: not a request
  to copy it.

## Still to do
- ~~**Finding things quickly**: an instant search key, a page for anything, "what to do here"~~: you didn't want
  these. **No bloat; everything should feel native.** No new features for now.
- **Your test of 2.2.0** (screenshots):
  - **The map's Show dropdown is the menu for what the map shows**, with Questie-style tick boxes. 2.2.0 still opened
    the game's own: BookFinder covered the wrong button (the map's floor picker is the same kind of button).
  - **Questie's quest items seem broken** in the Quests tab (what exactly: waiting on you; the next self-test checks
    them).
  - The list's header said "Questie Tracker: 13/40".

## Done in 2.2.2 (for you to test)
- **The green squares on the map are gone**: they were quest objective icons whose saved texture paths still pointed
  at the standalone Questie folder (Questie keeps the icons you chose as file paths). At login, BookFinder now points
  every saved path into a part's old folder inside BookFinder instead, for Questie, OpenMap and the books.

## Done in 2.2.1 (for you to test)
- **The Show dropdown** finds the right button, and holds the game's entries, then BookFinder's switches for what the
  map shows, in Questie's style: quest icons, places, dungeons, townsfolk, people, the books (longer groups as
  submenus). Those switches left the settings window, so each is in one place. If the game's entries can't be read,
  the first line is "Game map filters…", which opens the game's own.
- **The Quests tab's header** reads "Quests: 13/40", without Questie's button.
- The self-test checks the Show dropdown and every quest item button shown in the Quests tab.
- **The rest of the rebuild**, in `docs/DESIGN.md`'s order: the Quests tab as BookFinder's own list, the map's
  corner buttons, one tooltip style, one voice for messages, the book alerts.
- **Frames that don't line up**: send screenshots of the ones you mean; they need eyes on the game.
- **Every setting into OpenMap's panel**, redundancy removed (you asked for this; next).
- **The look**: the mock-ups (map panel, settings) wait for your markup; the journey card in them no longer applies.

## Still to do (waiting on your data)

- **Routing quality**: run `/bookfinder selftest` somewhere, `/reload`, and send `BookFinder.lua`. Its 15 routes, plus
  the journey log from normal play, are what the routing work starts from.
- **Native duplicates** in the Show menu (the game's own "Low-Level Quests" vs Questie's low-level quests): needs the
  inspect data to see which game setting each native entry uses.

## Things to show you

- What it looks like (the options, the panels), and how it works.
