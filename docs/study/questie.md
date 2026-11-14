# Study: Questie 12.9.0 (with QuestieDB 1.1.1), from a player's side

Read for reference only (the zip you sent). What a player sees, clicks, reads and hears, and what it says to other
players. Nothing here is their code. The quest, NPC, object and item **data** is QuestieDB's (decided: BookFinder uses
that data, credited, GPL-3). QuestieTrace: ignored.

## What it is

Every quest made visible: where to pick quests up, where each objective is, where to hand them in, on the world map
and minimap, in tooltips, on nameplates, in a quest list, and in a searchable database of every quest, NPC, object
and item, for WoW: Forever's own content too.

## On the map and minimap (the icons)

- **Quest givers**: "!" for a quest you can take; grey "!" for a trivial (low-level) one; separate looks for repeatable
  (blue), event, PvP, quests started by an item (a mob drop or an object), dungeon and raid quests, the AQ war effort.
- **Turn-ins**: "?" where a finished quest is handed in (repeatable, event and PvP versions of it too).
- **Objectives**: an icon on each spawn of what a quest asks for: **slay** (a skull), **loot** (a bag), **object**
  (a gear/hand), **event**, **talk** (a speech bubble), **interact**. Three icon themes to choose from: **Questie's**,
  **pfQuest's** (monochrome), **Blizzard's**; each objective kind's icon can be overridden; each kind's size has its own
  slider (slay, loot, event, object), and quest icons too.
- **Unique colours** per quest for objective icons (map and minimap, separate switches); **glow** around icons (map
  and minimap, separate).
- **Patrol paths**: an NPC that walks has its route drawn as a line (width, opacity, colour; hostile NPCs in their own
  colour; highlighted on hover); map and minimap separately.
- **Your party's objectives**: from party members using Questie, their objectives on your map too (up to 5 players).
- **Townsfolk** (switches in Questie's map menu): Repair, Innkeeper, Mailbox, Class Trainer, Weapon Master, Auctioneer,
  Banker, Flight Master, Battlemaster, Portal Trainer, Barber, Transmogrifier, Spirit Healer, Moonwell (with Tailoring),
  Meeting Stones (with their dungeon and level range), **Profession Trainers ▸** (each profession, "Known Professions"),
  **Vendor ▸** (Food, Drink, Ammo, Bags, Trade Goods, Reagents, Poisons, Potions, Pet Food... built for your class).
  Map and minimap, their own icon sizes.
- **Hiding**: Shift-click a quest's icon to hide that quest ("Are you sure you want to hide the quest '<name>'? If this
  quest isn't actually available, please report it to us!"); hide icons of untracked quests; hide in unexplored areas;
  hide on continent maps; minimap icons fade with distance and over your arrow.
- **Icon limits** and filter distances (Advanced), so busy zones stay usable.
- **Ctrl-click** an icon: TomTom waypoint (BookFinder: the game's map pin).
- **Season of Discovery runes** by phase (not on Forever).

### Icon tooltips (hover any icon)

The NPC's or object's name in green, then each quest there: its title with its level ("[33D] Hearts of Zeal": D for
dungeon, R raid, + elite...), the reward in XP ("1,450 xp") or reputation (with an icon), "(Active)" for one in your
log, "(Hold Shift)" when more detail is held back. Holding Shift shows the objectives with progress ("0/20 Heart of
Zeal"), the instance, **Breadcrumb Quests**, **Next in chain**, quest kinds (Event, PvP, Daily, Weekly, Monthly,
Account, Repeatable, Rune), and "Shift-click to hide". Several icons at one spot list them all, "Nearby" for those
close. Party members' progress shows per player.

## Tooltips elsewhere

- **NPC and object tooltips** (in the world, on nameplates' mouseover): the quests that need them, with your progress
  ("Hearts of Zeal: 0/20") and your party's ("Nearby"), quests they start and end; optional quest levels, quest XP at
  max level, next quests in the chain, breadcrumb quests, **item drop rates**.
- **Item tooltips**: which quest needs it, drop rates.
- **Developer IDs** on tooltips (NPC, object, item, spell, quest), off by default.

## Nameplates and target frame

A quest icon beside the nameplate of a mob your quests need (position X/Y and scale adjustable), and on the target
frame (its own position and scale); resets for each.

## The quest list (Questie's tracker)

- Your quests grouped by **zone** (collapsible), each quest a title with its level and difficulty colour, under it each
  objective with progress; finished objectives can hide; finished quests show "Quest Complete!" in green (or fold);
  failed show "Quest Failed!"; timed quests count down ("Time's up!").
- **Achievements**, **Recipes** and **Challenge Mode** sections where the client has them.
- Each quest: an **item button** for a quest's usable item (with its count and cooldown; a second button for a second
  item), a **focus** button (focus one quest: others dim), a **play** button (VoiceOver audio, where installed), an
  expand/collapse button.
- **Clicks** (bindable): left-click the title opens the quest log at that quest; Shift-click untracks (or links it in
  chat with a chat box open); Ctrl-click sets a TomTom target (BookFinder: the map pin); right-click opens its menu:
  Focus / Unfocus, Untrack, Show on map, Set TomTom Target, Minimize/Maximize, Copy URL (to the quest's database page:
  "Copied URL to clipboard"), and per objective: Show on map, Set TomTom Target.
- **Header**: "Questie Tracker: 13/40" (quests / max), min/max; its icon: left-click options, right-click My Journey.
- Options: auto track quests, show quest level, follow Blizzard's super-tracking, achievements first, padding, objective
  colour and sorting, fonts and sizes (header, zones, titles, objectives) and outline, fading of buttons, hover fade;
  (window options: lock, sizer, background, border, hide/minimize in combat or instances: not used in BookFinder's
  layout, where the list lives in the map).

## Journey window (`/questie journey`)

One window titled "<Character>'s Journey", tabs along the top, a **Questie Options** button top right, **Close**:

- **My Journey**: your character's history, by level ("Accepted", "Completed", "Abandoned", with dates), your notes
  (add, delete: "Are you sure you want to delete this note?"), "It's about time you embark on your first Journey!";
  import another character's journey; a fresh character resets it.
- **Quests by Zone**: pick a category (Zones, Dungeons, Battlegrounds, Events, Scenarios, Professions) and a zone; its
  quests sorted into **Available Quests**, **Breadcrumb Quests**, **Repeatable Quests**, **Completed Quests**,
  **Missing Requirement**, **Unobtainable Quests**, **Hidden Quests**.
- **Quests by Faction**: the same lists by reputation faction.
- **Advanced Search**: search quests, NPCs, objects and items by name or ID; results by kind; each opens its details:
  - **Quest**: ID, level, required level, class, profession, reputation reward, repeatable/daily/weekly, "Doable",
    "Requires one/all of these quests to be finished", who starts and ends it (with their IDs), hide it ("Hidden by
    Questie"), **Show on Map** / **Remove from Map**, **Set TomTom Target** (BookFinder: map pin).
  - **NPC**: ID, title, level, health, faction ("Friendly to"), quests it starts and ends, where it spawns ("No spawn
    data available.").
  - **Object**: ID, quests it starts and ends, where it is.
  - **Item**: ID, "12 NPCs drop this item", "3 Objects drop this item", "2 Vendors sell this item" (lists).

## Questie's map menu (the dropdown you like)

The classic dropdown (tooltip box, tick box at the left, name, icon at the right): the townsfolk above, **Available
Quest**, **Trivial Quest**, **Objective**, **Profession Trainers ▸**, **Vendor ▸**; then Advanced Search, Quests by
Zone, Quests by Faction, Questie Options, My Journey, Cancel (Reload UI with debugging on). Opened from Questie's
button on the map (left-click there hides/shows all of Questie's icons).

## Chat links

Quest links Questie makes clickable: "[[33] Hearts of Zeal]"; hovering or clicking one shows a quest tooltip: title,
"You are on this quest" / "You have completed this quest" / "This quest is repeatable" / "You have not done this
quest", objectives with "Your progress", "Started by", "Ended by", "Found in", the instance, "Completed on".

## Announcements (opt-in) and party

- Announce to party or a chosen channel: quest accepted, abandoned, completed, objective completed, items that start a
  quest ("Picked up <item> which starts <quest>!"), incomplete breadcrumbs; or only to yourself. "Questie ShutUp!"
  silences other players' Questie messages and your own.
- Party members' tracked objectives on your map and tooltips.
- Quest XP and reputation are shown from the data.

## Automation

- **Auto accept** and **auto complete** quests, with a modifier key (Shift, Ctrl, Alt) to skip; rules per kind for NPCs
  and for players' shares (normal, repeatable, dungeon/raid, PvP, event, trivial).
- **Auto reject** quests shared in battlegrounds ("Automatically rejected quest shared by player."), by non-friends;
  abandon a quest whose breadcrumb isn't done ("Automatically abandoned quest <a> because breadcrumb quest <b> is not
  completed.").
- Warns before deleting a quest item a quest might need.

## Sounds

Quest complete, objective complete, objective progress: each on/off with a chosen sound, a sound channel, a delay; can
load custom sounds.

## Other

- **Instant quest text**, custom quest frame icons, map and minimap coordinates (with precision).
- **Phases**: Isle of Quel'Danas phase picker and reminder; AQ war effort note; first-run choices (objective style:
  Questie, pfQuest or Blizzard objectives, since Forever has Blizzard's own; reject shared quests in battlegrounds).
- **Profiles** (new, copy, delete, reset), **locale** picker, reset, developer options and a profiler.
- **DBM HUD** integration (quest icons on Deadly Boss Mods' HUD).
- Minimap button (left: options, right: journey), addon compartment entry, map button.
- Messages in chat start with "Questie": update warnings ("You have an outdated version of Questie!"), missing data
  ("The quest X is missing from Questie's database. Please report this on GitHub or Discord!"), "Please wait a moment
  for Questie to finish loading".

## Commands

`/questie` (also `/q`, `/questieclassic`): options. `help`, `toggle` (all icons), `reload`, `minimap`, `journey`,
`tracker show|hide|reset`, `tomap <npc|object> <name or ID>` (marks it on the map; no argument: your target) and
`tomap reset`, `search`, `flex` (says how many quests you've completed), `eligible <quest>`, `version`.

## What it says to other players (must keep working with them)

- **`questie`** prefix (AceComm, multipart, its own binary serializer; message version 5.x, compatible while the whole
  number matches): your quest log and each quest's objective progress to your party, raid or instance group, on change
  and on request (full list, quest update, quest removed, request full list); version checks; yelling progress to
  nearby players (not to big raids or battlegrounds). Incompatible versions warn.
- **`QuestieV1`** prefix (CBOR, deflate, addon-channel encoding): which of your quests' objectives your party should
  see (a snapshot), up to 5 players.
- **`QuestieDailiesV2`**: daily quest sharing (switched off in this version).
- Quest links in chat: `|Hquestie:<questID>:<senderGUID>|h[...]`.
- So BookFinder must speak `questie` and `QuestieV1` byte for byte to show a Questie user's quests and objectives
  and to share its own, and read Questie's chat links.

## Saved settings

Profiles (QuestieConfig) for every option above; per character (QuestieConfigCharacter): journey, hidden quests,
tracked and collapsed quests, townsfolk learned, notes.
