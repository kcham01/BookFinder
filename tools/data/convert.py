#!/usr/bin/env python3
"""BookFinder's data converter (not part of the addon).

Reads QuestieDB's data (the "baked" store in QuestieDB_Forever.toc plus its support files and its dynamic
corrections) and writes BookFinder's own data files into BookFinder/Data/. Only data crosses over; the files written
here are read by BookFinder's own code. Credits: BookFinder/Data/CREDITS.md. Layout of every row: tools/data/SCHEMA.md.

Usage:  python3 -I tools/data/convert.py <QuestieDB folder> <Questie folder> [<output folder>]
        (Questie's folder gives the lists Questie keeps as data: hidden quests, NPCs and items, holiday quests and
        dates, Darkmoon Faire positions.)
Needs:  python3 with cbor2 (pip install cbor2), lua5.1 (apt-get install lua5.1).
"""

import base64
import json
import os
import subprocess
import sys
import zlib

import cbor2

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

# --------------------------------------------------------------------------------------------------------------------
# Reading QuestieDB's baked store
# --------------------------------------------------------------------------------------------------------------------


def read_metadata(toc_path):
    meta = {}
    with open(toc_path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("## X-"):
                key, _, value = line[3:].partition(":")
                meta[key.strip()] = value.strip()
    return meta


def stored(meta, key):
    value = meta.get(key)
    if value is not None and value.startswith("~") and value.endswith("~"):
        parts = int(value[1:-1])
        value = "".join(meta[f"{key}-{i}"] for i in range(1, parts + 1))
    return value


def text(v):
    """CBOR strings arrive as bytes; JSON strings as str. Everything becomes str, recursively."""
    if isinstance(v, bytes):
        return v.decode("utf-8")
    if isinstance(v, list):
        return [text(x) for x in v]
    if isinstance(v, dict):
        return {text(k) if isinstance(k, bytes) else k: text(x) for k, x in v.items()}
    return v


def decode_ids(meta, prefix):
    raw = base64.b64decode(stored(meta, f"X-{prefix}IDS"))
    try:
        raw = zlib.decompress(raw)
    except zlib.error:
        raw = zlib.decompress(raw, -15)
    return cbor2.loads(raw)


def decode_entity(meta, prefix, ident, field_count, table_fields):
    """Returns {questieFieldIndex: value} for one entity, or None."""
    s = stored(meta, f"X-{prefix}{ident}-S")
    if s is None:
        return None
    row = text(cbor2.loads(base64.b64decode(s)))
    if isinstance(row, list):
        # A row whose scalar fields run 1..n without a gap, and with no table fields, is stored as a CBOR array.
        row = {i + 1: v for i, v in enumerate(row) if v is not None}
    presence = row.pop("p", 0)
    fields = {k: v for k, v in row.items() if isinstance(k, int)}
    for index in table_fields:
        if presence >> (index - 1) & 1:
            value = stored(meta, f"X-{prefix}{ident}-{index}")
            if value is not None:
                fields[index] = text(cbor2.loads(base64.b64decode(value)))
    return fields


# --------------------------------------------------------------------------------------------------------------------
# Normalising shapes (lists with holes arrive either as lists or as {index: value} maps)
# --------------------------------------------------------------------------------------------------------------------


def positional(v, size):
    """A Questie positional group (objectives, startedBy...) as a list of exactly `size` slots, None for holes."""
    out = [None] * size
    if isinstance(v, list):
        for i, x in enumerate(v[:size]):
            out[i] = x
    elif isinstance(v, dict):
        for k, x in v.items():
            k = int(k)
            if 1 <= k <= size:
                out[k - 1] = x
    return out


def int_keys(d):
    """A Lua table keyed by numbers, as a Python dict with int keys. JSON object keys arrive as strings, and a Lua
    table whose keys happen to run 1..n arrives as a list (index 0 is key 1): area 1 is Dun Morogh, so a spawn list
    for Dun Morogh alone is a one-item list."""
    if isinstance(d, dict):
        return {int(k): v for k, v in d.items()}
    if isinstance(d, list):
        return {i + 1: v for i, v in enumerate(d) if v is not None}
    return d


def spawn_list(v):
    """{areaId: [[x, y], ...]} with int keys; empty -> None."""
    if not v:
        return None
    v = int_keys(v)
    return {k: c for k, c in v.items() if c} or None


def ids(v):
    return [x for x in v if x is not None] if v else None


def nonempty(v):
    if v in (None, [], {}, ""):
        return None
    return v


# --------------------------------------------------------------------------------------------------------------------
# BookFinder's rows (see SCHEMA.md). Each function takes Questie's {fieldIndex: value} and returns our positional row.
# --------------------------------------------------------------------------------------------------------------------


def quest_row(f, xp):
    starts = positional(f.get(2), 3)
    ends = positional(f.get(3), 2)
    obj = f.get(10)
    objectives = None
    if obj:
        o = positional(obj, 6)
        objectives = o if any(x for x in o) else None
    trigger = f.get(9)
    if trigger:
        trigger = [trigger[0] if len(trigger) > 0 else None, spawn_list(trigger[1] if len(trigger) > 1 else None)]
    extra = f.get(29)
    if extra:
        extra = [[spawn_list(e[0]) if len(e) > 0 else None] + list(e[1:]) for e in extra]
    row = [
        f.get(1),                       # 1 name
        f.get(5),                       # 2 quest level
        f.get(4),                       # 3 required level
        f.get(32),                      # 4 required max level
        f.get(6) or 0,                  # 5 races mask (0: every race)
        f.get(7) or 0,                  # 6 classes mask (0: every class)
        ids(starts[0]),                 # 7 started by NPCs
        ids(starts[1]),                 # 8 started by objects
        ids(starts[2]),                 # 9 started by items
        ids(ends[0]),                   # 10 finished by NPCs
        ids(ends[1]),                   # 11 finished by objects
        nonempty(f.get(8)),             # 12 objectives text (lines)
        objectives,                     # 13 objectives {creatures, objects, items, reputation, killCredit, spell}
        trigger,                        # 14 trigger {text, spawns}
        f.get(11),                      # 15 source item (given by the starter)
        nonempty(f.get(12)),            # 16 prerequisites: all of
        nonempty(f.get(13)),            # 17 prerequisites: one of
        nonempty(f.get(14)),            # 18 child quests
        nonempty(f.get(15)),            # 19 in group with
        nonempty(f.get(16)),            # 20 exclusive to
        f.get(17),                      # 21 zone (area ID) or sort (negative)
        nonempty(f.get(18)),            # 22 required skill {skill, value}
        nonempty(f.get(19)),            # 23 required min reputation {faction, value}
        nonempty(f.get(20)),            # 24 required max reputation {faction, value}
        nonempty(f.get(21)),            # 25 required source items
        f.get(22),                      # 26 next quest in chain
        f.get(23),                      # 27 quest flags
        f.get(24),                      # 28 special flags
        f.get(25),                      # 29 parent quest
        nonempty(f.get(26)),            # 30 reputation reward {{faction, value}, ...}
        f.get(27),                      # 31 breadcrumb for quest
        nonempty(f.get(28)),            # 32 breadcrumbs
        nonempty(extra),                # 33 extra objectives {spawns, icon, text, index, references}
        f.get(30),                      # 34 required spell
        f.get(31),                      # 35 required specialization
        f.get(33),                      # 36 available until completed
        f.get(34),                      # 37 available starting with
        nonempty(f.get(35)),            # 38 required ranks
        f.get(36),                      # 39 disabled by quest
        xp,                             # 40 XP {level it was measured at, xp}
    ]
    return row


def npc_row(f):
    waypoints = f.get(8)
    return [
        f.get(1),                       # 1 name
        f.get(4),                       # 2 min level
        f.get(5),                       # 3 max level
        f.get(6),                       # 4 rank (0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare)
        spawn_list(f.get(7)),           # 5 spawns {areaId: {{x, y}, ...}}
        spawn_list(waypoints),          # 6 patrol paths {areaId: {{{x, y}, ...}, ...}}
        f.get(9),                       # 7 zone (area ID)
        nonempty(f.get(10)),            # 8 quests it starts
        nonempty(f.get(11)),            # 9 quests it ends
        f.get(12),                      # 10 faction template
        f.get(13),                      # 11 friendly to: "A", "H", "AH" or nil
        f.get(14),                      # 12 sub name ("Innkeeper")
        f.get(15),                      # 13 NPC flags
    ]


def object_row(f):
    return [
        f.get(1),                       # 1 name
        nonempty(f.get(2)),             # 2 quests it starts
        nonempty(f.get(3)),             # 3 quests it ends
        spawn_list(f.get(4)),           # 4 spawns
        f.get(5),                       # 5 zone
        f.get(6),                       # 6 faction
        spawn_list(f.get(7)),           # 7 paths
    ]


def item_row(f):
    return [
        f.get(1),                       # 1 name
        nonempty(f.get(2)),             # 2 dropped by NPCs
        nonempty(f.get(3)),             # 3 dropped by / found in objects
        nonempty(f.get(4)),             # 4 found in items
        f.get(5),                       # 5 starts quest
        nonempty(f.get(6)),             # 6 reward of quests
        f.get(7),                       # 7 flags
        f.get(8),                       # 8 food type
        f.get(9),                       # 9 item level
        f.get(10),                      # 10 required level
        f.get(11),                      # 11 ammo type
        f.get(12),                      # 12 class
        f.get(13),                      # 13 sub class
        nonempty(f.get(14)),            # 14 sold by NPCs
        nonempty(f.get(15)),            # 15 related quests
        f.get(16),                      # 16 teaches spell
    ]


ENTITIES = {
    # name: (Questie metadata prefix, field count)
    "Quest": ("Quest-", 36),
    "Npc": ("Npc-", 15),
    "Object": ("Object-", 7),
    "Item": ("Item-", 16),
}


def table_fields(qdb, meta_name):
    """The table-typed field indexes of an entity, read from QuestieDB's meta file (data: field types)."""
    path = os.path.join(qdb, "src", "meta", f"{meta_name}Meta.lua")
    out = []
    in_types = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("types = {"):
                in_types = True
                continue
            if in_types:
                if line.strip().startswith("}"):
                    break
                for part in line.split(","):
                    part = part.strip()
                    if part.startswith("[") and "'table'" in part:
                        out.append(int(part[1:part.index("]")]))
    return out


# --------------------------------------------------------------------------------------------------------------------
# Lua output
# --------------------------------------------------------------------------------------------------------------------


def lua_number(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    r = repr(round(v, 4))
    return r[:-2] if r.endswith(".0") else r


def lua_string(s):
    out = ['"']
    for ch in s:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ord(ch) < 32:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def lua(v):
    """Python value -> compact Lua literal. Lists keep holes (None -> nil, trailing nils dropped)."""
    if v is None:
        return "nil"
    if isinstance(v, (bool, int, float)):
        return lua_number(v)
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, list):
        items = list(v)
        while items and items[-1] is None:
            items.pop()
        return "{" + ",".join(lua(x) for x in items) + "}"
    if isinstance(v, dict):
        parts = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), k)):
            key = f"[{lua_number(k)}]" if isinstance(k, (int, float)) else (k if k.isidentifier() else f"[{lua_string(k)}]")
            parts.append(f"{key}={lua(v[k])}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def long_string(s):
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[{s}]{eq}]"


HEADER = """-- GENERATED by tools/data/convert.py from QuestieDB's data. Do not edit by hand: change the converter and run it.
-- Data credit: QuestieDB and Questie's contributors, GPL-3.0 (see Data/CREDITS.md). Row layout: tools/data/SCHEMA.md.
"""


def write_rows(out_dir, file_name, table_name, rows):
    """Rows are stored as Lua source strings and decoded on first use (Data/Rows.lua), so the client only builds the
    tables it touches. One file can hold at most ~130k assignments (two constants each); we stay far below."""
    path = os.path.join(out_dir, file_name)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        f.write("local _, BF = ...\n")
        f.write(f"local R = BF.Data.{table_name}\n")
        for ident in sorted(rows):
            f.write(f"R[{ident}]={long_string(lua(rows[ident]))}\n")
    return os.path.getsize(path)


def write_table(out_dir, file_name, assignments):
    path = os.path.join(out_dir, file_name)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        f.write("local _, BF = ...\n")
        for target, value in assignments:
            f.write(f"{target} = {lua(value)}\n")
    return os.path.getsize(path)


# --------------------------------------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------------------------------------


def run_lists(qdb, questie):
    proc = subprocess.run(
        ["lua5.1", os.path.join(HERE, "questie_lists.lua"), questie, qdb],
        cwd=qdb, capture_output=True, check=True,
    )
    return json.loads(proc.stdout.decode("utf-8"))


def run_dynamic(qdb):
    proc = subprocess.run(
        ["lua5.1", os.path.join(HERE, "dynamic.lua"), qdb],
        cwd=qdb, capture_output=True, check=True,
    )
    return json.loads(proc.stdout.decode("utf-8"))


ROW_BUILDERS = {"Quest": quest_row, "Npc": npc_row, "Object": object_row, "Item": item_row}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    qdb = os.path.abspath(sys.argv[1])
    questie = os.path.abspath(sys.argv[2])
    out_dir = os.path.abspath(sys.argv[3]) if len(sys.argv) > 3 else os.path.join(REPO, "BookFinder", "Data")
    os.makedirs(out_dir, exist_ok=True)

    toc = os.path.join(qdb, "QuestieDB_Forever.toc")
    meta = read_metadata(toc)
    print(f"QuestieDB store: {len(meta)} metadata lines", file=sys.stderr)

    dyn = run_dynamic(qdb)
    support = dyn["support"]
    xp = {int(k): v for k, v in support["QuestXP"].items()}

    raw = {}
    for entity, meta_name in (("Quest", "quest"), ("Npc", "npc"), ("Object", "object"), ("Item", "item")):
        prefix, count = ENTITIES[entity]
        tf = table_fields(qdb, meta_name)
        entities = {}
        for ident in decode_ids(meta, prefix):
            fields = decode_entity(meta, prefix, ident, count, tf)
            if fields is not None:
                entities[ident] = fields
        raw[entity] = entities
        print(f"{entity}: {len(entities)} rows", file=sys.stderr)

    # Dynamic corrections, factored into layers: everyone / per faction / per faction and class.
    combos = list(dyn["dynamic"].keys())
    factions = sorted({c.split("/")[0] for c in combos})
    layers = {"all": {}, "faction": {f: {} for f in factions}, "class": {c: {} for c in combos}}
    for entity in ("Quest", "Npc", "Object", "Item"):
        touched = set()
        for c in combos:
            for ident, fields in dyn["dynamic"][c].get(entity, {}).items() if isinstance(dyn["dynamic"][c].get(entity), dict) else []:
                for field in fields:
                    touched.add((int(ident), int(field)))
        for ident, field in sorted(touched):
            def value_for(c):
                rows = dyn["dynamic"][c].get(entity)
                if not isinstance(rows, dict):
                    return None
                row = rows.get(str(ident))
                if not isinstance(row, dict):
                    return None
                return row.get(str(field))
            values = {c: value_for(c) for c in combos}
            dumps = {c: json.dumps(v, sort_keys=True) for c, v in values.items()}
            if len(set(dumps.values())) == 1:
                layers["all"].setdefault(entity, {}).setdefault(ident, {})[field] = values[combos[0]]
                continue
            for fac in factions:
                mine = [c for c in combos if c.startswith(fac + "/")]
                if len({dumps[c] for c in mine}) == 1:
                    if values[mine[0]] is not None:
                        layers["faction"][fac].setdefault(entity, {}).setdefault(ident, {})[field] = values[mine[0]]
                    else:
                        layers["faction"][fac].setdefault(entity, {}).setdefault(ident, {})[field] = "__BASE__"
                else:
                    for c in mine:
                        val = values[c] if values[c] is not None else "__BASE__"
                        layers["class"][c].setdefault(entity, {}).setdefault(ident, {})[field] = val

    # Corrections that apply to everyone are folded straight into the rows.
    for entity, rows in layers["all"].items():
        for ident, fields in rows.items():
            target = raw[entity].setdefault(ident, {})
            for field, value in fields.items():
                if value is None:
                    target.pop(field, None)
                else:
                    target[field] = text(value)

    def build(entity, ident, fields):
        if entity == "Quest":
            return quest_row(fields, xp.get(ident))
        return ROW_BUILDERS[entity](fields)

    sizes = {}
    names = {"Quest": ("Quests.lua", "quests"), "Npc": ("Npcs.lua", "npcs"),
             "Object": ("Objects.lua", "objects"), "Item": ("Items.lua", "items")}
    for entity, (file_name, table_name) in names.items():
        rows = {ident: build(entity, ident, fields) for ident, fields in raw[entity].items()}
        sizes[file_name] = write_rows(out_dir, file_name, table_name, rows)

    # Faction and class layers: whole rows (our layout) for the entities they touch, so the runtime only swaps rows.
    overrides = {}
    for scope, per in (("faction", layers["faction"]), ("class", layers["class"])):
        for key, by_entity in per.items():
            for entity, rows in by_entity.items():
                for ident, fields in rows.items():
                    base = dict(raw[entity].get(ident, {}))
                    fac = key.split("/")[0]
                    if scope == "class":
                        for f2, v2 in layers["faction"].get(fac, {}).get(entity, {}).get(ident, {}).items():
                            if v2 != "__BASE__":
                                base[f2] = text(v2)
                    for field, value in fields.items():
                        if value == "__BASE__":
                            continue
                        if value is None:
                            base.pop(field, None)
                        else:
                            base[field] = text(value)
                    overrides.setdefault(scope, {}).setdefault(key, {}).setdefault(entity, {})[ident] = build(entity, ident, base)
    lines = []
    for scope in ("faction", "class"):
        for key, by_entity in sorted(overrides.get(scope, {}).items()):
            for entity, rows in sorted(by_entity.items()):
                lines.append((f'BF.Data.override["{key}"].{names[entity][1]}', rows))
    path = os.path.join(out_dir, "Overrides.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        f.write("-- Rows that differ by faction (\"Horde\") or by faction and class (\"Horde/SHAMAN\"): whole rows in our layout,\n")
        f.write("-- swapped in by Data/Rows.lua at login. A class row wins over a faction row.\n")
        f.write("local _, BF = ...\n")
        f.write("local O = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function(t2, k2) local v2 = {} t2[k2] = v2 return v2 end }) t[k] = v return v end })\n")
        f.write("BF.Data.override = O\n")
        for target, rows in lines:
            target = target.replace("BF.Data.override", "O")
            for ident in sorted(rows):
                f.write(f"{target}[{ident}] = {long_string(lua(rows[ident]))}\n")
    sizes["Overrides.lua"] = os.path.getsize(path)

    # Objective ordering hints.
    flags = {k: sorted(int(i) for i in v.keys()) if isinstance(v, dict) else [] for k, v in dyn["flags"].items()}

    # Drop rates: corrections > Wowhead > server data. {itemId: {npcId: percent}}
    drops_src = support.get("drops") or {}
    wowhead = {int(k): int_keys(v) for k, v in (drops_src.get("wowheadData") or {}).items()}
    server = {int(k): int_keys(v) for k, v in (drops_src.get("cmangosData") or {}).items()}
    corrections = {}
    for _, table in (support.get("dropCorrections") or {}).items():
        if isinstance(table, dict):
            for item, npcs in table.items():
                corrections.setdefault(int(item), {}).update(int_keys(npcs))
    wow_key = dyn["enums"].get("dropCorrectionKeys", {}) if isinstance(dyn["enums"].get("dropCorrectionKeys"), dict) else {}
    drops = {}
    for item in set(wowhead) | set(server) | set(corrections):
        rates = dict(server.get(item, {}))
        rates.update(wowhead.get(item, {}))
        for npc, value in corrections.get(item, {}).items():
            if isinstance(value, (int, float)) and value >= 0:
                rates[npc] = value
            elif npc in wowhead.get(item, {}):
                rates[npc] = wowhead[item][npc]
        drops[item] = {npc: round(r, 2) for npc, r in rates.items() if isinstance(r, (int, float))}

    zone = support["ZoneDB"]
    private = zone.get("private", {})

    def merged(name):
        m = int_keys(private.get(name) or {})
        m.update(int_keys(private.get(name + "Override") or {}))
        return m

    dungeons = {}
    for area, entry in int_keys(private.get("dungeons") or {}).items():
        entry = positional(entry, 4)
        dungeons[area] = [entry[0], entry[1], entry[2], entry[3]]

    sizes["Zones.lua"] = write_table(out_dir, "Zones.lua", [
        ("BF.Data.areaToUiMap", merged("areaIdToUiMapId")),
        ("BF.Data.uiMapToArea", merged("uiMapIdToAreaId")),
        ("BF.Data.subZoneToParent", merged("subZoneToParentZone")),
        ("BF.Data.instanceToArea", int_keys(zone.get("instanceIdToAreaId") or {})),
        ("BF.Data.dungeons", dungeons),
    ])
    sizes["Drops.lua"] = write_table(out_dir, "Drops.lua", [("BF.Data.drops", drops)])
    enums = dyn["enums"]
    sizes["Enums.lua"] = write_table(out_dir, "Enums.lua", [
        ("BF.Data.objectiveFirst", {k: {i: True for i in v} for k, v in flags.items()}),
        ("BF.Data.factionTemplate", int_keys(support.get("factionTemplate") or {})),
        ("BF.Data.zoneIDs", enums["zoneIDs"]),
        ("BF.Data.sortKeys", enums["sortKeys"]),
        ("BF.Data.factionIDs", enums["factionIDs"]),
        ("BF.Data.professionKeys", enums["professionKeys"]),
        ("BF.Data.specializationKeys", enums["specializationKeys"]),
        ("BF.Data.raceKeys", enums["raceKeys"]),
        ("BF.Data.classKeys", enums["classKeys"]),
        ("BF.Data.npcFlags", enums["npcFlags"]),
        ("BF.Data.questFlags", enums["questFlags"]),
        ("BF.Data.specialFlags", enums["specialFlags"]),
        ("BF.Data.raceMaskById", int_keys(enums["raceMaskById"])),
    ])
    # Questie's lists: hidden quests/NPCs/items, holidays, Darkmoon Faire's two places (NPC rows in our layout).
    lists = run_lists(qdb, questie)
    darkmoon = {}
    for place, fixes in lists["darkmoon"].items():
        rows = {}
        for ident, fields in fixes.items():
            ident = int(ident)
            base = dict(raw["Npc"].get(ident, {}))
            for field, value in fields.items():
                base[int(field)] = text(value)
            rows[ident] = npc_row(base)
        darkmoon[place] = rows
    events = []
    for e in lists["eventQuests"]:
        events.append(e)
    sizes["Lists.lua"] = write_table(out_dir, "Lists.lua", [
        ("BF.Data.hiddenQuests", {int(k): v for k, v in lists["hiddenQuests"].items()}),
        ("BF.Data.hiddenNpcs", {int(k): v for k, v in lists["hiddenNpcs"].items()}),
        ("BF.Data.hiddenItems", {int(k): v for k, v in lists["hiddenItems"].items()}),
        ("BF.Data.eventQuests", events),
        ("BF.Data.eventDates", lists["eventDates"]),
        ("BF.Data.lunarFestival", {int(k): v for k, v in lists["lunarFestival"].items()}),
        ("BF.Data.darkmoonNpcs", darkmoon),
        ("BF.Data.autoNever", {
            "npcs": {int(k): True for k, v in lists["autoNever"]["npcs"].items() if v},
            "accept": {int(k): True for k, v in lists["autoNever"]["accept"].items() if v},
            "turnIn": {int(k): True for k, v in lists["autoNever"]["turnIn"].items() if v},
        }),
        ("BF.Data.townsfolk", {
            "classTrainers": lists["townsfolk"]["classTrainers"],
            "mailboxes": lists["townsfolk"]["mailboxes"],
            "weaponTrainers": lists["townsfolk"]["weaponTrainers"],
            "professionTrainers": {int(k): v for k, v in lists["townsfolk"]["professionTrainers"].items()},
        }),
    ])
    sizes["BUILD"] = meta.get("X-BUILD-COMMIT")

    for k, v in sizes.items():
        print(f"{k}: {v}", file=sys.stderr)
    with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("Generated by tools/data/convert.py.\n")
        f.write(f"QuestieDB build commit: {meta.get("X-BUILD-COMMIT")}\n")
        f.write(f"QuestieDB build time: {meta.get("X-BUILD-TIME")}\n")
        for entity in raw:
            f.write(f"{entity}: {len(raw[entity])} rows\n")


if __name__ == "__main__":
    main()
