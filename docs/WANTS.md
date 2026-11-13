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
- **Routing at "Google Maps" quality**: still not good enough. Journeys must be the fastest real way, with
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
- **Routing must be professional grade**: you've said it again; it's the next job, using the journey log.

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

## Still to do (waiting on your data)
- **If a journey still doesn't start**, it now says why. Send `BookFinder.lua`: `attempts` has each one.
- **Routing quality**: run `/bookfinder selftest` somewhere, `/reload`, and send `BookFinder.lua`. Its 15 routes, plus
  the journey log from normal play, are what the routing work starts from.
- **Native duplicates** in the Show menu (the game's own "Low-Level Quests" vs Questie's low-level quests): needs the
  inspect data to see which game setting each native entry uses.

## Things to show you

- What it looks like (the options, the panels), and how it works.
