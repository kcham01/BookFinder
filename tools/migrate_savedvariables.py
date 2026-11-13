#!/usr/bin/env python3
"""Carry your OpenMap, Shortest Path Forever and Books on map settings over to BookFinder.

    python3 tools/migrate_savedvariables.py "<game folder>/_forever_/WTF" [--force] [--dry-run]

Close the game first: it rewrites these files when it exits. The game keeps saved variables per addon folder,
so BookFinder can't read the old files itself. For the account and for every character, this copies each of
OpenMapDB, OpenMapCharDB, ShortestPathForeverDB, ShortestPathForeverCharDB, BooksOnMapForeverGlobal and
BooksOnMapForeverDB from the old addon's file into BookFinder.lua beside it. A variable BookFinder.lua already has
is kept unless --force. BookFinder.lua is backed up to BookFinder.lua.bak before it changes; the old files are
left as they are.
"""
import argparse
import os
import re
import shutil
import sys

OLD = {
    "OpenMap.lua": ["OpenMapDB", "OpenMapCharDB"],
    "ShortestPathForever.lua": ["ShortestPathForeverDB", "ShortestPathForeverCharDB"],
    "Books_on_map_Forever.lua": ["BooksOnMapForeverGlobal", "BooksOnMapForeverDB"],
}
NEW = "BookFinder.lua"
TOP = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=", re.M)


def assignments(text):
    """Top-level `Name = ...` blocks of a saved-variables file, by name (the game writes each from column 0)."""
    found = list(TOP.finditer(text))
    out = {}
    for i, m in enumerate(found):
        end = found[i + 1].start() if i + 1 < len(found) else len(text)
        out[m.group(1)] = text[m.start():end].rstrip() + "\n"
    return out


def migrate_dir(folder, force, dry):
    target = os.path.join(folder, NEW)
    current = open(target, encoding="utf-8").read() if os.path.exists(target) else ""
    have = assignments(current)
    order = [m.group(1) for m in TOP.finditer(current)]
    changed = []
    for old, names in OLD.items():
        path = os.path.join(folder, old)
        if not os.path.exists(path):
            continue
        blocks = assignments(open(path, encoding="utf-8").read())
        for name in names:
            if name not in blocks or (name in have and not force):
                continue
            if name not in order:
                order.append(name)
            have[name] = blocks[name]
            changed.append(f"{name} (from {old})")
    if not changed:
        return []
    if not dry:
        if os.path.exists(target):
            shutil.copy2(target, target + ".bak")
        with open(target, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(have[n].rstrip() for n in order) + "\n")
    return changed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("wtf", help="the client's WTF folder")
    ap.add_argument("--force", action="store_true", help="replace variables BookFinder.lua already has")
    ap.add_argument("--dry-run", action="store_true", help="say what would change, change nothing")
    a = ap.parse_args()
    if not os.path.isdir(os.path.join(a.wtf, "Account")):
        sys.exit(f"{a.wtf} has no Account folder: point this at the WTF folder")
    total = 0
    for dirpath, dirs, _ in os.walk(os.path.join(a.wtf, "Account")):
        if os.path.basename(dirpath) != "SavedVariables":
            continue
        for item in migrate_dir(dirpath, a.force, a.dry_run):
            print(("would copy " if a.dry_run else "copied ") + item + " in " + os.path.relpath(dirpath, a.wtf))
            total += 1
    print(f"{total} variable(s) {'to copy' if a.dry_run else 'copied'}." + ("" if total else " Nothing to do."))


if __name__ == "__main__":
    main()
