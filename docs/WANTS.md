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
- **One tracker**: under Questie's list, the journey and departures block is as wide as the list and uses Questie's
  fonts and grey section names, with no native header bar, so it reads as part of Questie's tracker.
- **The game reports back by itself**: every session it records the client snapshot, BookFinder's errors and your
  journeys, leg by leg. Send `SavedVariables/BookFinder.lua` now and then; no commands needed.
- Your search screenshots (garre) worked: quests, NPCs, objects and items, with journeys from Undercity via Grom'gol.

## Still to do (waiting on your data)
- **Routing quality**: needs `/path report` after a bad route.
- **Native duplicates** in the Show menu (the game's own "Low-Level Quests" vs Questie's low-level quests): needs the
  inspect data to see which game setting each native entry uses.

## Things to show you

- What it looks like (the options, the panels), and how it works.
