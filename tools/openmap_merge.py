#!/usr/bin/env python3
"""Folds OpenMap (MIT) into the staged BookFinder folder, so the download is ONE addon (the owner: "it's still all
supposed to be one addon").

Usage: python3 -I tools/openmap_merge.py <OpenMap folder (holds OpenMap.toc)> <staged BookFinder folder>

What it does, mechanically (OpenMap's code is otherwise unchanged; it is not kept in this repository):
  * copies OpenMap's files to BookFinder/OpenMap/ (not the Retail art, nor its own .toc files);
  * in every OpenMap Lua file its TOC loads, its one "local <name>, ns = ..." line is rewritten so the file still gets
    its own private namespace (BookFinder's namespace's .openMap) and "addon name" (BookFinder\\OpenMap: OpenMap
    builds its media path from it, Interface\\AddOns\\BookFinder\\OpenMap\\Media\\). Nothing else moves, so line
    numbers in error reports stay OpenMap's own;
  * its few hard-coded paths and its own-name checks point at BookFinder; its chat prefix reads BookFinder; its page
    in the game's AddOns settings is not made (BookFinder's panel holds its settings);
  * its key bindings join BookFinder's (Bindings.xml at BookFinder's root, category BookFinder);
  * BookFinder.toc gets OpenMap's files first (BookFinder's map code reads OpenMapAPI as it loads) and its saved
    variables.
"""
import os
import re
import shutil
import sys

SKIP_DIRS = {os.path.join("Media", "Textures", "Retail"), os.path.join("Data", "Retail"), ".git", ".github", "tools", "docs"}
SKIP_FILES = {"OpenMap.toc", "OpenMap_Mainline.toc", "Bindings.xml"}


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def must_sub(text, old, new, what, count=1):
    if old not in text:
        sys.exit("openmap_merge: cannot find %s (OpenMap changed?)" % what)
    return text.replace(old, new, count)


def main():
    src, stage = sys.argv[1], sys.argv[2]
    dst = os.path.join(stage, "OpenMap")
    toc_lines = read(os.path.join(src, "OpenMap.toc")).splitlines()

    # 1. Files.
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        dirs[:] = [d for d in dirs if os.path.normpath(os.path.join(rel, d)) not in SKIP_DIRS and d not in SKIP_DIRS]
        for name in files:
            if rel == "." and name in SKIP_FILES:
                continue
            out = os.path.join(dst, rel, name)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            shutil.copy2(os.path.join(root, name), out)

    # 2. The files the TOC loads.
    loads = []
    for line in toc_lines:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        loads.append(s)
    for entry in loads:
        path = entry.split(" [")[0].strip()
        if not path.lower().endswith(".lua"):
            continue
        full = os.path.join(dst, *path.split("\\"))
        text = read(full)
        if text.startswith("﻿"):
            text = text[1:]
        text = text.replace("AddOns\\\\OpenMap\\\\", "AddOns\\\\BookFinder\\\\OpenMap\\\\")
        pattern = re.compile(r"^local (\w+), ns = \.\.\.[ \t]*$", re.M)
        found = pattern.findall(text)
        if len(found) != 1:
            sys.exit("openmap_merge: %s: expected one 'local <name>, ns = ...' line, found %d" % (path, len(found)))
        text = pattern.sub(lambda m: "local %s, ns = \"BookFinder\\\\OpenMap\", (function(b) b.openMap = b.openMap or {} "
                           "return b.openMap end)(select(2, ...))" % m.group(1), text)
        write(full, text)

    # 3. Its own name: settings load at BookFinder's ADDON_LOADED; no page of its own in the game's settings; the chat
    #    prefix is BookFinder's.
    init = os.path.join(dst, "Init.lua")
    t = read(init)
    t = must_sub(t, 'name == ADDON then', 'name == "BookFinder" then', "Init.lua's ADDON_LOADED check")
    t = must_sub(t, "if Settings and Settings.RegisterCanvasLayoutCategory then",
                 "if false and Settings and Settings.RegisterCanvasLayoutCategory then", "Init.lua's settings page")
    write(init, t)
    core = os.path.join(dst, "Core.lua")
    t = read(core)
    t = must_sub(t, '"|cff" .. ns.ACCENT .. "OpenMap|r: "', '"|cffffd100BookFinder:|r "', "Core.lua's chat prefix")
    write(core, t)

    # 4. Key bindings.
    b = read(os.path.join(src, "Bindings.xml"))
    b = b.replace('category="OpenMap"', 'category="BookFinder"')
    write(os.path.join(stage, "Bindings.xml"), b)

    # 5. The TOC.
    toc_path = os.path.join(stage, "BookFinder.toc")
    toc = read(toc_path).splitlines()
    out, inserted = [], False
    for line in toc:
        if line.startswith("## SavedVariables:"):
            line += ", OpenMapDB"
        elif line.startswith("## SavedVariablesPerCharacter:"):
            line += ", OpenMapCharDB"
        elif line.startswith("## OptionalDeps:"):
            line = "## OptionalDeps: Questie, Leatrix_Maps, BetterMaps, HighFidelityWorldMap, HiddenMaps, Mapster, Magnify"
        if not inserted and line.strip() and not line.startswith("#"):
            out.append("# The map: OpenMap (MIT, OpenMap contributors: OpenMap\\LICENSE.txt), part of BookFinder")
            for entry in loads:
                out.append("OpenMap\\" + entry)
            out.append("")
            inserted = True
        out.append(line)
    write(toc_path, "\n".join(out) + "\n")
    print("openmap_merge: %d OpenMap files folded into BookFinder" % len(loads))


if __name__ == "__main__":
    main()
