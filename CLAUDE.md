# BookFinder: directive for any agent working here

Read this first, then `docs/BUILD.md`: its "Decisions" (every decision of the owner's, in our words) override
anything you assume.

## What BookFinder is

A **new World of Warcraft addon for WoW: Forever, written from scratch as its own thing.** It does everything three
addons do, with nothing lost, as one product that feels made by Blizzard:

- **Questie** (and its database QuestieDB): quests, NPCs, objects and items on the map and minimap, the quest list,
  tooltips, Journey windows, automation, party sharing.
- **OpenMap**: the seamless stitched world map and its menu, pins, drawing, dungeons, people and sharing.
- **Books on map (Forever)**: the WoW: Forever library books, rewards, route, alerts, group sharing.

## Hard rules (the owner has said each of these more than once)

1. **No one else's code.** Not in the repository, not in BookFinder. Other addons are **references to read**, never
   copied, adapted or shipped. Write BookFinder's own code.
2. **Never commit files the owner sends** (addon zips, documents, screenshots). They are for review only. Keep them
   outside the repository (the session's scratchpad).
3. **The one exception is data, as decided**: quest, NPC, object and item knowledge comes from **QuestieDB's data**,
   credited, under its GPL-3 licence (so BookFinder is GPL-3). Only the data; every line of code is new. The map is
   built from the **game's own map art**, by BookFinder (not OpenMap's prepared textures). The books list is written
   by BookFinder (names and places are facts, checked in game).
4. **Talk to the other addons**: a party member using Questie, OpenMap or Books on map must still share with
   BookFinder (Questie's party quest sharing, OpenMap's friend/guild positions and shared pins, Books on map's
   `BooksOnMapFE` group sharing). Match their addon-message protocols exactly.
5. **Nothing lost**: every feature of the three addons is present. Know them from a player's side, down to every
   tooltip, icon, message, click and setting (`docs/study/`).
6. **Never quote the owner in the repository.** Their words, documents and screenshots are never committed, quoted
   or described here. Record each decision in your own words in `docs/BUILD.md`, "Decisions". The build's working
   notes, plan and log are in `docs/BUILD.md` too: read it before touching code, update it as you go.
7. **Native, not bloated**: the game's own look and art, no clutter, no features nobody asked for.
8. **Report honestly**: say what was tested and what wasn't; nothing has run in game until the owner says it did.

## Where things stand (read this, then `docs/BUILD.md`'s log and its last section, "Next")

- **Code**: `BookFinder/` is the addon (TOC `BookFinder/BookFinder.toc`). Folders: `Core` (events, settings, data access,
  zones, player), `Data` (generated from QuestieDB by `tools/data/convert.py`: never edit by hand), `Quests` (log,
  rules, objectives, marks, tooltips, nameplates, the quest list, automation, announcements, sounds, chat links),
  `Map` (world map and minimap pins, paths, coordinates, arrow and compass, townsfolk, the Show dropdown, map pins,
  friends and guild), `Books`, `Comms` (Questie's protocol, party objectives), `Journey`, `UI` (one dropdown, widgets,
  the settings panel, the map window's tabs, minimap button, commands).
- **Done (phases 1-11, 13, and OpenMap's pins and people)**: see `docs/BUILD.md`, its plan and its log, newest last.
  Questie's party protocol is checked byte for byte against Questie's own code (`tools/check/`).
- **Next: phase 12, OpenMap's map**: the stitched world map from the game's own art, zooming down to minimap detail
  (the owner's favourite), dungeons, boats, flights, the quill... Decided: own code, OpenMap as the guide.
  Settle where the minimap tiles come from before building (`docs/BUILD.md`, "Next").
- **Tests**: `tools/test/run.sh` (needs `lua5.1`: `apt-get install -y lua5.1`) runs every file of the TOC against
  stand-ins of the game (`tools/test/wow.lua`) and every `tools/test/test_*.lua`: 142 pass. They prove logic only.
  **Nothing has run in game yet**: the owner is about to test. Every "Not verified in game" in `docs/BUILD.md` is a
  guess to check against their screenshots.
- **Branches**: the work is on the session's branch (pushed), in pull request kcham01/BookFinder#13 (open, not
  merged; #14 is older and contained in it). `main` is behind: it ends at "Notes: answered questions cleared".
  A new session gets its own branch name: start it from this branch's latest commit (a fast-forward, nothing lost).
- **Reference files are gone with each session** (they live only in a session's scratchpad, never in the repository):
  Questie 12.9.0 with QuestieDB 1.1.1 and Books on map 2.3.0 (ask the owner to send them again when needed), OpenMap
  v0.8.9 (public: `git clone https://github.com/openmap-world/openmap` into the scratchpad). QuestieTrace: ignored.
- The repository holds no other addon's code, and none of the owner's review files, anywhere in its history. Copies
  survive only behind the old pull requests #1 to #12; removing those needs the repository recreated.
- **Study**: `docs/study/` (per addon, from a player's side; `questie-protocol.md` is Questie's wire format byte by
  byte; `openmap.md` ends with OpenMap's place and pin protocols).

## The owner's design decisions

In `docs/BUILD.md`, "Decisions" (the Show dropdown, the settings window, one dropdown style, the quest list and Books
tab in the map, the arrow and compass, no route lines, the map and its window layout).

## Working here

- Develop on the branch the session names; commit and push there. Don't open pull requests unless asked.
- Commit messages and docs: plain words, no model names.
