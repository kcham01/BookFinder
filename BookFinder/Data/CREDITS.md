# Data credits

The quest, NPC, object and item data in this folder (`Quests.lua`, `Npcs.lua`, `Objects.lua`, `Items.lua`,
`Overrides.lua`, `Zones.lua`, `Drops.lua`, `Enums.lua`, `Lists.lua`) is **QuestieDB's data**, converted into BookFinder's own row
layout by `tools/data/convert.py`. Only data is used; none of QuestieDB's or Questie's code is part of BookFinder.

- **QuestieDB** (version 1.1.1, Forever flavour; see `SOURCE.txt` for the exact build): data by Muehe, TheCrux
  (BreakBB), Drejjmit, Dyaxler, Cheeq, TechnoHunter, Yttrium and everyone else who contributed; code by Logonz.
- `Lists.lua` holds lists Questie keeps as data (hidden quests, NPCs and items; holiday quests and dates; Darkmoon
  Faire positions), from **Questie** 12.9.0, evaluated for WoW: Forever by `tools/data/questie_lists.lua`.
- `TownsfolkItems.lua` (hand-kept) holds Questie's item lists that tell what a vendor sells (food, drink, ammo,
  reagents, poisons, trade goods, bags, potions) and its mage portal trainers, and `Lists.lua`'s `townsfolk` its
  class, profession and weapon trainers and mailboxes for WoW: Forever.
- QuestieDB's data was first imported from **Questie** (https://github.com/Questie/Questie) and carries the work of
  Questie's contributors, over 100 of them.

## Licence

QuestieDB and Questie are offered under the **GNU General Public License v3** (`../../LICENSE.md`), so BookFinder is
GPL-3 too. In the projects' own words, the Questie team is "alright with others forking the repository or copying code
from it under the GPLv3 terms, but we can not promise all contributors are", and the GPL-3 grant does not extend to
the **Questie name and logo**: BookFinder uses neither as its own.
