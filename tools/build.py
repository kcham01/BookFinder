#!/usr/bin/env python3
"""Assemble the BookFinder superaddon from the three addons in src/.

    python3 tools/build.py                 # build/BookFinder + build/ForeverCore
    python3 tools/build.py --no-textures   # skip OpenMap's 335 MB of textures (checks only)
    python3 tools/build.py --zip           # also dist/BookFinder-<version>.zip
    python3 tools/build.py --out AddOns    # refresh the ready-to-install copy kept in git

What it does, in order (docs/INVENTORY.md explains why each is needed):
  1. copies each component into its own subfolder of BookFinder/
  2. rewrites each file's private-table line so the component gets its own table (merge/Namespaces.lua)
  3. points every texture/sound path at the component's new folder
  4. applies the few patches a merge needs (versions, "is X loaded" checks)
  5. writes one .toc from the three, in load order OpenMap -> Shortest Path -> Books, and one Bindings.xml
  6. fetches OpenMap's Forever textures from the pinned upstream commit (cached in .cache/)
ForeverCore is copied unchanged beside it: it's a shared library other Forever addons need by name.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
MERGE = os.path.join(ROOT, "merge")
NAME = "BookFinder"
VERSION = "1.3.0"

OPENMAP_REPO = "https://github.com/openmap-world/openmap.git"
OPENMAP_COMMIT = "91c84b3bf633f3ae4840309e4620d63b249f626e"
OPENMAP_VERSION = "v0.8.7"  # Data/Forever/Changelog.lua's newest entry at that commit

# key in the private table, folder, its toc, the version its own code should report
COMPONENTS = [
    # (Questie's database first, then Questie: the map and journeys find both already loaded, as their standalone
    # tocs' OptionalDeps had it)
    ("QuestieDB", "QuestieDB", "QuestieDB_Forever.toc", None),
    ("Questie", "Questie", "Questie_Forever.toc", None),
    ("OpenMap", "OpenMap", "OpenMap.toc", OPENMAP_VERSION),
    ("SPF", "ShortestPathForever", "ShortestPathForever.toc", None),
    ("Books", "Books_on_map_Forever", "Books_on_map_Forever.toc", None),
]
SKIP_FILES = {"OpenMap.toc", "OpenMap_Mainline.toc", "LICENSE.repo", "ShortestPathForever.toc",
              "Books_on_map_Forever.toc", "Bindings.xml", "README.md"}
LIB_DIRS = ("Libs",)
# Parts whose files mostly never read their private table: each file gets a first-line guard instead, so the part
# stands aside when its standalone addon runs (Questie and its database stand aside together)
INJECT_GUARD = {"QuestieDB": "Questie", "Questie": "Questie"}
# QuestieDB's database is its toc's metadata (its "baked" mode), read by the addon's name: BookFinder's toc carries
# it. Not these: they'd clash with or say nothing about BookFinder
DATA_META_SKIP = re.compile(r"^X-(BUILD-|Curse|Wago)")

errors = []


def fail(msg):
    errors.append(msg)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def toc_meta(toc_text):
    meta = {}
    for line in toc_text.splitlines():
        m = re.match(r"##\s*([^:]+):\s*(.*)", line)
        if m:
            meta[m.group(1).strip()] = m.group(2).strip()
    return meta


def toc_files(toc_text):
    """The toc's file lines, each with its trailing [conditions] kept."""
    out = []
    for line in toc_text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s)
    return out


# --- 2. private tables ---------------------------------------------------------------------------
CAPTURES = [
    # local _, ns = ...        local ADDON, ns = ...      local _, LibQuestieDB = ...  (any name for the table)
    (re.compile(r"^(local\s+\w+\s*,\s*(\w+)\s*=\s*\.\.\.)[ \t]*$", re.M), r"\1; \2 = \2.{key}; if \2.__skip then return end"),
    # local ns = select(2, ...)
    (re.compile(r"^(local\s+ns\s*=\s*select\(2,\s*\.\.\.\))[ \t]*$", re.M), r"\1.{key}; if ns.__skip then return end"),
]


def rewrite_namespace(path, rel, key):
    text = read(path)
    n = 0
    for pattern, repl in CAPTURES:
        text, k = pattern.subn(repl.replace("{key}", key), text)
        n += k
    if n > 1:
        fail(f"{rel}: {n} private-table lines (expected one)")
    elif n == 0 and re.search(r"\bns\b", text) and re.search(r"^[^-\n]*=\s*\.\.\.", text, re.M):
        fail(f"{rel}: reads the private table in a form the build doesn't know")
    write(path, text)
    return n


# --- 3. paths ------------------------------------------------------------------------------------
# Interface\AddOns\<Folder>\  ->  Interface\AddOns\BookFinder\<Folder>\  (escaped Lua and plain XML/toc)
PARTS_RE = "QuestieDB|Questie|OpenMap|ShortestPathForever|Books_on_map_Forever"
PATH_RE = re.compile(r"(AddOns)(\\\\|\\|/)(" + PARTS_RE + r")(?=\\\\|\\|/)", re.I)


# "Is Questie loaded?" and Questie's or QuestieDB's version, asked by name: answered by BookFinder for the built-in
# ones (BookFinder.Loaded, and its toc's X-Questie-Version, X-QuestieDB-Version, X-QuestieDB-Contract)
NAME_RULES = [
    (re.compile(r'(?:C_AddOns\s*\.\s*)?IsAddOnLoaded\(\s*"(Questie|QuestieDB)"\s*\)'), r'BookFinder.Loaded("\1")'),
    (re.compile(r'\bloaded\(\s*"(Questie|QuestieDB)"\s*\)'), r'BookFinder.Loaded("\1")'),
    (re.compile(r'\(\s*"Questie"\s*,\s*"Version"\s*\)'), r'("BookFinder", "X-Questie-Version")'),
    (re.compile(r'\(\s*"Questie"\s*,\s*"X-QuestieDB-Contract"\s*\)'), r'("BookFinder", "X-QuestieDB-Contract")'),
    (re.compile(r'\(\s*"QuestieDB"\s*,\s*"Version"\s*\)'), r'("BookFinder", "X-QuestieDB-Version")'),
]


def rewrite_names(text):
    for pattern, repl in NAME_RULES:
        text = pattern.sub(repl, text)
    return text


def inject_guard(path, skip_key):
    text = read(path)
    bom = text.startswith("\ufeff")
    if bom:
        text = text[1:]
    # (on the first line, so every line number still matches upstream's)
    text = f'if BookFinder and BookFinder.Skip and BookFinder.Skip("{skip_key}") then return end ' + text
    write(path, ("\ufeff" if bom else "") + text)


def rewrite_paths(text):
    return PATH_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}{NAME}{m.group(2)}{m.group(3)}", text)


# --- 4. patches ----------------------------------------------------------------------------------
# (file, old, new): each old must occur exactly once. They keep each part's own version where its code
# reports or compares it (What's new windows, group sync), and answer "is it loaded" for a built-in part.
PATCHES = [
    ("OpenMap/Core.lua",
     'ns.Media = { path = "Interface\\\\AddOns\\\\" .. ADDON .. "\\\\Media\\\\" }',
     'ns.Media = { path = "Interface\\\\AddOns\\\\" .. ADDON .. "\\\\OpenMap\\\\Media\\\\" }'),
    ("OpenMap/Core.lua",
     '(ADDON, "Version")',
     '(ADDON, "X-OpenMap-Version")'),
    # (Books built in draws its pins above the art itself: OpenMap's scan of the whole canvas for them, on every map
    # change and zoom step, is work for nothing while dragging. A standalone Books still gets it)
    ("OpenMap/Map/Compat.lua",
     'if loaded and loaded("Books_on_map_Forever") then',
     'if not (BookFinder and BookFinder.Active("Books")) and loaded and loaded("Books_on_map_Forever") then'),
    ("ShortestPathForever/UI/CompanionMaps.lua",
     'C_AddOns.IsAddOnLoaded("OpenMap")',
     'BookFinder.Loaded("OpenMap")'),
    ("ShortestPathForever/UI/WhatsNew.lua",
     'C_AddOns.GetAddOnMetadata(addonName, "Version")',
     'C_AddOns.GetAddOnMetadata(addonName, "X-SPF-Version")'),
    ("Books_on_map_Forever/Core/Skin.lua",
     'local MEDIA = "Interface\\\\AddOns\\\\" .. ADDON .. "\\\\adds\\\\UI\\\\"',
     'local MEDIA = "Interface\\\\AddOns\\\\" .. ADDON .. "\\\\Books_on_map_Forever\\\\adds\\\\UI\\\\"'),
    ("Books_on_map_Forever/modules/Group.lua",
     'getMeta(ADDON, "Version")', 'getMeta(ADDON, "X-Books-Version")'),
    ("Books_on_map_Forever/modules/Welcome.lua",
     'getMeta(ADDON, "Version")', 'getMeta(ADDON, "X-Books-Version")'),
    ("Books_on_map_Forever/modules/Options.lua",
     'getMeta(ADDON, "Version")', 'getMeta(ADDON, "X-Books-Version")'),
]


def apply_patches(out):
    for rel, old, new in PATCHES:
        path = os.path.join(out, rel)
        text = read(path)
        if text.count(old) != 1:
            fail(f"patch {rel}: expected 1 match of {old!r}, found {text.count(old)}")
            continue
        write(path, text.replace(old, new))


# --- 6. textures ---------------------------------------------------------------------------------
def openmap_textures():
    cache = os.path.join(ROOT, ".cache", "openmap")
    marker = os.path.join(cache, ".commit")
    tex = os.path.join(cache, "OpenMap", "Media", "Textures", "Forever")
    if os.path.isdir(tex) and os.path.exists(marker) and read(marker).strip() == OPENMAP_COMMIT:
        return tex
    shutil.rmtree(cache, ignore_errors=True)
    os.makedirs(cache)
    git = ["git", "-C", cache]
    subprocess.check_call(["git", "init", "-q", cache])
    subprocess.check_call(git + ["remote", "add", "origin", OPENMAP_REPO])
    subprocess.check_call(git + ["sparse-checkout", "set", "--no-cone", "OpenMap/Media/Textures/Forever/"])
    subprocess.check_call(git + ["fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", OPENMAP_COMMIT])
    subprocess.check_call(git + ["checkout", "-q", "FETCH_HEAD"])
    write(marker, OPENMAP_COMMIT + "\n")
    return tex


# --- build ---------------------------------------------------------------------------------------
def build(textures, make_zip, out_root):
    out = os.path.join(out_root, NAME)
    # (only the two folders this writes: --out may be a folder with other things in it)
    for top in (NAME, "ForeverCore"):
        shutil.rmtree(os.path.join(out_root, top), ignore_errors=True)
    os.makedirs(out)

    metas, files, bindings = {}, [], []
    for key, folder, toc, own_version in COMPONENTS:
        src = os.path.join(SRC, folder)
        dst = os.path.join(out, folder)
        toc_text = read(os.path.join(src, toc))
        meta = toc_meta(toc_text)
        if own_version:
            meta["Version"] = own_version
        metas[key] = meta
        for dirpath, _, names in os.walk(src):
            for fn in names:
                if dirpath == src and (fn in SKIP_FILES or fn.endswith(".toc")):
                    continue
                s = os.path.join(dirpath, fn)
                rel = os.path.relpath(s, src)
                d = os.path.join(dst, rel)
                os.makedirs(os.path.dirname(d), exist_ok=True)
                if fn.endswith((".lua", ".xml")):
                    text = rewrite_paths(read(s))
                    if fn.endswith(".lua"):
                        text = rewrite_names(text)
                    write(d, text)
                    if fn.endswith(".lua") and not rel.startswith(LIB_DIRS):
                        rewrite_namespace(d, f"{folder}/{rel}", key)
                        if key in INJECT_GUARD:
                            inject_guard(d, INJECT_GUARD[key])
                else:
                    shutil.copy2(s, d)
        for line in toc_files(toc_text):
            files.append(folder + "\\" + line)
            if not os.path.exists(os.path.join(src, line.split(" [")[0].replace("\\", os.sep))):
                fail(f"{folder}: toc names a missing file {line}")
        bind = os.path.join(src, "Bindings.xml")
        if os.path.exists(bind):
            bindings += re.findall(r"^\s*<Binding\b.*?(?:/>|</Binding>)\s*$", read(bind), re.M | re.S)

    apply_patches(out)

    # every listed path rewritten; none left pointing at a standalone folder
    stale = re.compile(r"AddOns(\\\\|\\|/)(" + PARTS_RE + r")(\\\\|\\|/)", re.I)
    for dirpath, _, names in os.walk(out):
        for fn in names:
            if fn.endswith((".lua", ".xml")):
                p = os.path.join(dirpath, fn)
                if stale.search(read(p)):
                    fail(f"{os.path.relpath(p, out)}: a path still points at a standalone addon folder")

    os.makedirs(os.path.join(out, "Merge"), exist_ok=True)
    for fn in ("Namespaces.lua", "Bridge.lua", "Panel.lua"):
        shutil.copy2(os.path.join(MERGE, fn), os.path.join(out, "Merge", fn))

    om, spf, books = metas["OpenMap"], metas["SPF"], metas["Books"]
    questie, questiedb = metas["Questie"], metas["QuestieDB"]
    # QuestieDB's database: every X- field of its toc but the build stamps
    data_lines = [f"## {k}: {v}" for k, v in questiedb.items() if k.startswith("X-") and not DATA_META_SKIP.match(k)]
    optional = []
    for meta in metas.values():
        for dep in re.split(r"[,\s]+", meta.get("OptionalDeps", "")):
            if dep and dep not in optional and dep not in ("OpenMap", "ShortestPathForever", "ForeverCore", "Questie", "QuestieDB"):
                optional.append(dep)
    saved, saved_char = ["BookFinderDB"], []
    for meta in metas.values():
        saved += [v.strip() for v in meta.get("SavedVariables", "").split(",") if v.strip()]
        saved_char += [v.strip() for v in meta.get("SavedVariablesPerCharacter", "").split(",") if v.strip()]

    header = f"""## Interface: 16001
## Title: |cff33ff99Book|rFinder
## Notes: One addon for the world: a seamless map, journeys anywhere, every quest and the library books. /bookfinder
## Author: {om.get("Author")}; {spf.get("Author")}; {books.get("Author")}; Questie: {questie.get("Author")}; merged as BookFinder
## Version: {VERSION}
## X-OpenMap-Version: {om["Version"]}
## X-SPF-Version: {spf["Version"]}
## X-Books-Version: {books["Version"]}
## X-Questie-Version: {questie["Version"]}
## X-QuestieDB-Version: {questiedb["Version"]}
## X-QuestieDB-Contract: {questie["X-QuestieDB-Contract"]}
## LoadSavedVariablesFirst: 1
## Category: Map
## X-Category: Map
## X-License: GPL-3.0-or-later (Shortest Path Forever's licence; OpenMap's code is MIT; Books on map's is its author's); map art is Blizzard's
## IconTexture: Interface\\AddOns\\{NAME}\\OpenMap\\Media\\Textures\\OpenMapIconRound
## AddonCompartmentFunc: BookFinder_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: BookFinder_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: BookFinder_OnAddonCompartmentLeave
## Dependencies: ForeverCore
## OptionalDeps: {", ".join(optional)}
## X-Forever-Core: {spf["X-Forever-Core"]}
## X-Forever-Icon: {spf["X-Forever-Icon"]}
## SavedVariables: {", ".join(saved)}
## SavedVariablesPerCharacter: {", ".join(saved_char)}
"""
    # (QuestieDB's database after BookFinder's own fields, before any file)
    header += "\n".join(data_lines) + """

# Generated by tools/build.py from src/: edit those and rebuild.
Merge\\Namespaces.lua
"""
    body, last = [], None
    for line in files:
        folder = line.split("\\")[0]
        if folder != last:
            body.append(f"\n# {folder}")
            last = folder
        body.append(line)
    write(os.path.join(out, NAME + ".toc"), header + "\n".join(body) + "\n\n# Ties the parts together, and the map panel\nMerge\\Bridge.lua\nMerge\\Panel.lua\n")

    write(os.path.join(out, "Bindings.xml"),
          "<!-- Generated by tools/build.py: every part's key bindings -->\n<Bindings>\n"
          + "\n".join("\t" + b.strip() for b in bindings) + "\n</Bindings>\n")

    if textures:
        tex = openmap_textures()
        shutil.copytree(tex, os.path.join(out, "OpenMap", "Media", "Textures", "Forever"))
    else:
        print("note: --no-textures: OpenMap's map art is missing from this build; don't install it")

    shutil.copytree(os.path.join(SRC, "ForeverCore"), os.path.join(out_root, "ForeverCore"))

    if errors:
        for e in errors:
            print("error:", e, file=sys.stderr)
        sys.exit(1)

    print(f"built {out} ({len(files) + 2} files in its toc)")
    if make_zip:
        dist = os.path.join(ROOT, "dist")
        os.makedirs(dist, exist_ok=True)
        zpath = os.path.join(dist, f"{NAME}-{VERSION}.zip")
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for top in (NAME, "ForeverCore"):
                for dirpath, _, names in os.walk(os.path.join(out_root, top)):
                    for fn in names:
                        p = os.path.join(dirpath, fn)
                        z.write(p, os.path.relpath(p, out_root))
        print("zipped", zpath)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-textures", action="store_true")
    ap.add_argument("--zip", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "build"),
                    help="folder to write BookFinder/ and ForeverCore/ into (default build/; AddOns/ is the copy kept in git)")
    a = ap.parse_args()
    build(not a.no_textures, a.zip, os.path.abspath(a.out))
