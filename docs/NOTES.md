# Notes (your words, as given)

Everything you say goes here as you say it. **The build has started** ("start the build"); its working notes are
`docs/BUILD.md`.
Your document and its pictures (image1 to image8 below) are kept on the session's machine for review only, never in
the repository.

## 1. The map's dropdown (your document)

> "This is the list of map items for questie and open map. These are the items that should show up in the in game
> drop down menu with no duplicates. I want it in the style and layout of the questie one on the list. It currently
> resembles openmaps with the unneeded category headers. Dungeons is the only think I want under its own section
> within the dropdown. Something to keep in mind for icons. Questie and open maps both ship icons. Don't overlap them.
> We will deal with advance search, quest by zone and faction, my journey and options further down. They should not
> show in the dropdown though."

- **image1**: Questie's own dropdown: Repair, Innkeeper, Mailbox, Class Trainer, Weapon Master, Auctioneer, Banker,
  Flight Master, Battlemaster, Portal Trainer, Barber, Transmogrifier, Spirit Healer, Moonwell, Available Quest,
  Trivial Quest, Objective, Profession Trainers ▸, Vendor ▸; then QuestieTrace, Advanced Search, Quests by Zone,
  Quests by Faction, Questie Options, My Journey, Cancel. Each row: tick box left, label, icon right.
- **image2**: OpenMap's map items: Dungeons (Dungeon maps, Level ranges, Dungeon bosses, Dungeon quests, Entrances
  open Dungeon Journal), Townsfolk (Vendors, Repair, Innkeepers, Bankers, Mailboxes, Auctioneers, Stable masters,
  Class trainers, Profession trainers, Spirit healers, Rare mobs), Places (Dungeons and raids, Boats, Zeppelins,
  Flight masters, Only places you've found, Boat and zeppelin routes, Your arrow, Party and raid members, Friends on
  the map, Guild members on the map, Your drawings, Quests from every zone, Questie icons, Fade icons while zooming).

## 2. Settings (your document)

> "I'm a big fan of this settings page and would like it to serve as the core for all settings. (openmaps settings
> panel.)"

- **image3**: OpenMap's panel (v0.8.8): search "Find a place", tiles (Find me, Drop a pin, Pins, Quill, Quest log,
  Report a problem, What's new) with stars, tabs On the map / Look / More, two columns of tick rows with icons and
  stars.

> "For example do you see those tabs on the right hand side of questies settings? We could add those to the open maps
> settings pane. One tab for openmaps settings, 1 tab for quest settings, 1 tab for book settings, 1 tab that has
> questis journey, quest window features. Pictured below"

- **image4**: Questie's settings window, with its column of icon tabs down the right side.
- **image5**: Questie's Journey window: tabs My Journey, Quests by Zone, Quests by Faction, Advanced Search.

> "Then those separate tabs from questie and books could be put under tabs like this."

- **image6**: OpenMap's tabs: On the map / Look / More.
- **image7**: Books on map Forever 2.3.0's window: Progress bar (10, 20, 25, 38), Settings (Show on the map, Show books
  on the minimap, Show the minimap button, Notify when a book is collected, Alert when a book is nearby, Map icon
  size, Minimap icon size), Filters (Hide collected books, Only sets for my level, Also show the books my group is
  missing), the sets list with tick boxes, Show all / Hide all / Optimized route.
- **image8**: Books' Rewards panel: 10 books necklace, 20 ring, 25 bow, crest or light, 38 necklace or shield.

## 3. Newest versions (you sent)

> "I'm going to send the most up to date versions of those 3 addons too before you start."

| Addon | In BookFinder now | You sent |
|---|---|---|
| Questie | 12.8.0 | 12.9.0 |
| QuestieDB | 1.1.0 | 1.1.1 |
| QuestieTrace | not in BookFinder | 1.11.0 (in the Questie zip): ignored, stays out |
| Books on map Forever | 2.2.6 | 2.3.0 (38 books, a 38-book reward) |
| OpenMap | v0.8.7 (commit 91c84b3) | latest at https://github.com/openmap-world/openmap (your picture shows v0.8.8) |

Kept unpacked, untouched, outside the build. Not merged yet.

## How I read it (for you to correct before anything is built)

1. **Dropdown**: the map's Show dropdown holds every map item from image1 and image2, each once, as one flat list in
   Questie's layout (tick box, label, icon at right). Only **Dungeons** gets its own section in it. No category
   headers otherwise. Each item uses one icon, never both parts' icons for the same thing. Advanced Search, Quests by
   Zone and Faction, My Journey and Options are not in the dropdown.
2. **Settings**: OpenMap's panel (image3) is the one settings window for everything, with a column of tabs down its
   right side like Questie's (image4): OpenMap, Quests, Books, Journey (My Journey, Quests by Zone, Quests by
   Faction, Advanced Search: image5). Inside each, the part's own pages become sub-tabs along the top like
   On the map / Look / More (image6).
3. **Before starting**: update to the versions above.

## Answers

- **QuestieTrace**: "no ignore trace." It stays out of BookFinder and out of the dropdown.
- **Settings window**: "yes replace yours with open maps as i laid out in the document." BookFinder's 2.2.0 settings
  window goes; OpenMap's panel becomes the one settings window, as section 2 describes.
- **Books tab** (the book-icon tab under the "!" Quests tab on the map's right edge: Library books, Collect, Rewards,
  the sets): "lets say yes for the books tab and see how it rocks out." It keeps showing the books.
- **Other people's files**: "nobody elses files should be going onto my github btw. they are there for u to review."
  Files you send (addon zips, documents, screenshots) are for review only and are never committed.

- **Nobody's code**: "i mean noones code should be stolen at all i only send u addon zips so u can look at the code
  not literally use them in a effort to steal in lazyness lol". BookFinder must be its own code. Other addons are
  references to learn from, not parts to ship. (Until now BookFinder has been built from their code: Questie,
  QuestieDB, OpenMap and Books on map are in `src/` and in every build.)

- **"It should be its own new thing like I've said multiple times. Yes take their code from my repo."** BookFinder is
  written fresh, fully original (option 1: quest help is only what the game itself provides). Their code is out of
  the branch; taking it out of GitHub's history too needs a force-push, which waits on your go-ahead.

- **"Nothing should be lost from the 3 addons. All features better be present."** Every feature of Questie, OpenMap
  and Books on map is in the new BookFinder, written as BookFinder's own code. Open: where Questie's quest, NPC, object
  and item data comes from (asked in chat).

- **Quest data: "2"** (asked: does Questie not use open-source data?). BookFinder's quest, NPC, object and item
  knowledge is QuestieDB's data file, credited, under its GPL-3 licence (so BookFinder is GPL-3 too). Only the data:
  every line of BookFinder's code is new. Reason: it is the one source with WoW: Forever's own content (the server
  projects' open data has none of it).

- **"These should be their full new own things but they should still be able to talk to the other addons so things
  will work right, like for instance if I'm in a party with someone who has Questie I want it to still be able to
  track their quests and all of that."**
  - The map (answer to the map-art question), the quest system and the books are each BookFinder's own, new.
  - BookFinder speaks the other addons' languages with players who use them: Questie's party sharing (their tracked
    quests and progress), Books on map's group sharing (who still needs which book), OpenMap's sharing (where friends
    and guild members are, shared pins).
- **"Just make sure you really understand how all 3 addons work from a usage standpoint and all of the small tiny
  details that matter, from tooltips to icons to messages. All of it. Also keeping all of my notes and docs in mind."**
  Before anything is built: a full usage study of Questie, OpenMap and Books on map (their newest versions), every
  window, menu, tooltip, icon, message, click, setting and what they send each other, written in BookFinder's docs
  for you to check, together with these notes and `docs/WANTS.md`.

- **"Start the study."** First pass done: `docs/study/books-on-map.md`, `openmap.md`, `questie.md`. "Make sure you
  update the directive so any other agents know what's going on": `CLAUDE.md` at the repository's root.

- **"We also kinda want the stuff that Shortest Path added as far as the little arrow and compass at the top that
  tells you where you go when you drop a pin. Remember that I hated the lines on the map."** BookFinder gets its own
  arrow and compass at the top of the screen, guiding you to the map pin (`docs/study/arrow-and-compass.md`). No
  route lines drawn on the map. (This brings back the arrow and compass that 2.0.0 removed with Shortest Path; still no
  journeys or routing.)
- **Lines on the map** (asked which of the three addons' lines stay): keep OpenMap's **boat and zeppelin routes** and
  Questie's **NPC patrol paths**. **Books' route trail goes** (the dots and spark between route stops); the route itself
  stays, guided by the map pin, arrow and compass.
- **"Once you have everything confirmed let me know when you're ready to build."**

- **"Start the build. Be sure to keep notes for yourself, a Claude agent computer. You know how you understand things
  best, so as you're building leave yourself useful notes."** Building from scratch; my working notes are
  `docs/BUILD.md`.

- **"I want you to remember my standards of quality. The better it is the first time, the less work you have to do.
  Your path to success will not be found in a shortcut."** (Also at the top of `docs/BUILD.md`'s ground rules.)

## Questions (only what I can't tell from your notes)

- None open. (QuestieTrace, the Books tab and the settings window were answered above.)
