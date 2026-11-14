# BookFinder data rows

`tools/data/convert.py` writes these files into `BookFinder/Data/`. Rows are stored as Lua source strings
(`R[id] = [[{...}]]`) and turned into tables only when first read (`BookFinder/Core/Data.lua`), so the client builds
just the rows it uses. Positions inside a row are fixed; `nil` marks an absent value.

Coordinates are **percent of the zone's map (0-100)**, keyed by **area ID** (`BF.Data.areaToUiMap` gives the uiMapID;
instances have none: their spawns are shown at the dungeon's entrance, `BF.Data.dungeons`).

## Quest (`BF.Data.quests`)

| # | field | shape |
|---|---|---|
| 1 | name | string |
| 2 | quest level | number (-1: no fixed level; shown at the player's level) |
| 3 | required level | number |
| 4 | required max level | number |
| 5 | races mask | number, 0 = every race (bit per race: `BF.Data.raceMaskById`) |
| 6 | classes mask | number, 0 = every class (bit `2^(classID-1)`) |
| 7 | started by NPCs | {npcID...} |
| 8 | started by objects | {objectID...} |
| 9 | started by items | {itemID...} |
| 10 | finished by NPCs | {npcID...} |
| 11 | finished by objects | {objectID...} |
| 12 | objectives text | {line...} |
| 13 | objectives | {creatures, objects, items, reputation, killCredit, spell}: creatures/objects/items are {{id, text?, icon}...}; reputation {factionID, value}; killCredit {{{npcIDs...}, baseNpcID, text?, icon}...}; spell {{spellID, text?, itemID}...} |
| 14 | trigger | {text, spawns} (an exploration or event objective) |
| 15 | source item | itemID given when the quest starts |
| 16 | prerequisites, all of | {questID...} |
| 17 | prerequisites, one of | {questID...} |
| 18 | child quests | {questID...} |
| 19 | in group with | {questID...} |
| 20 | exclusive to | {questID...} |
| 21 | zone or sort | area ID (positive) or quest sort (negative: `BF.Data.sortKeys`) |
| 22 | required skill | {skillID, value} |
| 23 | required min reputation | {factionID, value} |
| 24 | required max reputation | {factionID, value} |
| 25 | required source items | {itemID...} (needed, not objectives) |
| 26 | next quest in chain | questID |
| 27 | quest flags | number (`BF.Data.questFlags`) |
| 28 | special flags | number (1: repeatable) |
| 29 | parent quest | questID (must be active) |
| 30 | reputation reward | {{factionID, value}...} |
| 31 | breadcrumb for | questID |
| 32 | breadcrumbs | {questID...} |
| 33 | extra objectives | {{spawns?, iconType, text?, objectiveIndex, references?}...}; references {{"monster"/"item"/"object", id}...} |
| 34 | required spell | spellID |
| 35 | required specialization | ID |
| 36 | available until completed | questID |
| 37 | available starting with | questID (must be active or completed) |
| 38 | required ranks | {{skillID, value}...} |
| 39 | disabled by quest | questID (active) |
| 40 | XP | {level measured at, xp} |

## NPC (`BF.Data.npcs`)

1 name, 2 min level, 3 max level, 4 rank (0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare), 5 spawns {area={{x,y}...}},
6 patrol paths {area={{{x,y}...}...}}, 7 zone (area), 8 quests it starts, 9 quests it ends, 10 faction template,
11 friendly to ("A", "H", "AH"), 12 sub name, 13 NPC flags (`BF.Data.npcFlags`).

## Object (`BF.Data.objects`)

1 name, 2 quests it starts, 3 quests it ends, 4 spawns, 5 zone, 6 faction, 7 paths.

## Item (`BF.Data.items`)

1 name, 2 dropped by NPCs, 3 found in objects, 4 found in items, 5 starts quest, 6 reward of quests, 7 flags,
8 food type, 9 item level, 10 required level, 11 ammo type, 12 class, 13 sub class, 14 sold by NPCs,
15 related quests, 16 teaches spell.

## Overrides (`BF.Data.override`)

Whole rows (same layouts) that replace the base row for a faction (`override["Horde"].quests[id]`) or a faction and
class (`override["Horde/SHAMAN"].quests[id]`, which wins). From QuestieDB's dynamic corrections.

## Other tables

`BF.Data.drops[itemID][npcID]` = drop chance in percent. `BF.Data.dungeons[areaID]` = {name, other area IDs, parent
zone area, {{area, x, y}...} entrances}. `areaToUiMap`, `uiMapToArea`, `subZoneToParent`, `instanceToArea`.
`objectiveFirst` (objective ordering hints per quest), `factionTemplate` (template -> faction group bits), and the
enums named after QuestieDB's: `zoneIDs`, `sortKeys`, `factionIDs`, `professionKeys`, `specializationKeys`, `raceKeys`,
`classKeys`, `npcFlags`, `questFlags`, `specialFlags`, `raceMaskById`.

## Questie's lists (`Data/Lists.lua`)

- `hiddenQuests[id]` = `true` (never shown) or `"HIDE_ON_MAP"` (a quest that exists, never drawn on the map);
  `hiddenNpcs[id]`, `hiddenItems[id]` = `true`. Event quests leave the hidden state while their holiday runs.
- `eventQuests` = `{ {event name, questID, start "d/m"?, end "d/m"?, start "h:m"?, end "h:m"?}, ... }`.
- `eventDates[event]` = `{startDate = "d/m", startHour, startMinute, endDate, endHour, endMinute}`, or `false` for a
  holiday that does not exist on this client. `lunarFestival[yy]` = the same shape for the Lunar Festival per year
  (two-digit year). Darkmoon Faire has no dates: it runs the week after the first Friday of each month, Elwynn Forest
  in odd months and Mulgore in even ones (BookFinder's own rule, `Quests/Events.lua`).
- `darkmoonNpcs.elwynn[npcID]`, `darkmoonNpcs.mulgore[npcID]` = whole NPC rows (tables, not strings) for the faire's
  NPCs in each place.
- `townsfolk` = { classTrainers = {CLASS = {npcID...}}, mailboxes = {objectID...}, weaponTrainers = {npcID...},
  professionTrainers = {[skillID] = {npcID...}} }: Questie's lists for WoW: Forever.
