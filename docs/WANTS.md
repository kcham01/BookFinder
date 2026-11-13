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

## Done in 1.4.0 (for you to test)
- The 1.3.0 overlay panel and its button are gone. OpenMap's map menu is back as the one map menu.
- The Library books tab is in the quest log, in Shortest Path's style. It replaces Books' own window, and `/bom` and
  the minimap menu open it.
- The minimap menu's Quests entry opens the quest log's own Quests tab.

## Things to show you

- What it looks like (the options, the panels), and how it works.
