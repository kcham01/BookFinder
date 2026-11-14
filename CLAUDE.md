# BookFinder: directive for any agent working here

Read this first, then `docs/NOTES.md` (the owner's notes, in their words) and `docs/WANTS.md` (every wish and decision,
newest last). They override anything you assume.

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
6. **Note-taking mode until told otherwise**: record what the owner says in `docs/NOTES.md`; build nothing until they
   say so. Ask short questions only where the notes don't answer.
7. **Native, not bloated**: the game's own look and art, no clutter, no features nobody asked for.
8. **Report honestly**: say what was tested and what wasn't; nothing has run in game until the owner says it did.

## Where things stand

- The repository was cleared of every other addon's code (commit "Remove every other addon's code"). Their code is
  still in older history and on `main`; rewriting GitHub's history waits on the owner's go-ahead (a force-push).
- **Now**: the study. `docs/study/` holds, per addon, how it works from a player's side (in our words). Done: Books on
  map 2.3.0. Next: OpenMap v0.8.9, then Questie 12.9.0 with QuestieDB 1.1.1.
- **Then**: the owner checks the study against their notes; then the build starts, from scratch.
- Newest reference versions (kept outside the repository): Questie 12.9.0, QuestieDB 1.1.1, Books on map 2.3.0,
  OpenMap v0.8.9 (https://github.com/openmap-world/openmap). QuestieTrace: ignored.

## The owner's design notes (summary; full text in `docs/NOTES.md`)

- **The map's Show dropdown**: every map item of Questie and OpenMap, each once, one flat list in Questie's dropdown
  layout (tick box, name, icon at the right). Only **Dungeons** gets its own section. One icon per item, never both
  addons' icons for the same thing. Advanced Search, Quests by Zone/Faction, My Journey and Options are not in it.
- **Settings**: OpenMap's settings panel is the core for all settings, with a column of tabs down its right side like
  Questie's settings: OpenMap, Quests, Books, Journey (My Journey, Quests by Zone, Quests by Faction, Advanced Search).
  Inside each, its pages as tabs along the top, like OpenMap's On the map / Look / More. (A new panel of BookFinder's
  own, laid out that way; not OpenMap's code.)
- **Books tab** beside the quest log stays, showing the books.

## Working here

- Develop on the branch the session names; commit and push there. Don't open pull requests unless asked.
- Commit messages and docs: plain words, no model names.
