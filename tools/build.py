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
VERSION = "1.0.0"

OPENMAP_REPO = "https://github.com/openmap-world/openmap.git"
OPENMAP_COMMIT = "91c84b3bf633f3ae4840309e4620d63b249f626e"
OPENMAP_VERSION = "v0.8.7"  # Data/Forever/Changelog.lua's newest entry at that commit

# key in the private table, folder, its toc, the version its own code should report
COMPONENTS = [
    ("OpenMap", "OpenMap", "OpenMap.toc", OPENMAP_VERSION),
    ("SPF", "ShortestPathForever", "ShortestPathForever.toc", None),
    ("Books", "Books_on_map_Forever", "Books_on_map_Forever.toc", None),
]
SKIP_FILES = {"OpenMap.toc", "OpenMap_Mainline.toc", "LICENSE.repo", "ShortestPathForever.toc",
              "Books_on_map_Forever.toc", "Bindings.xml", "README.md"}
LIB_DIRS = ("Libs",)

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
    # local _, ns = ...        local ADDON, ns = ...
    (re.compile(r"^(local\s+\w+\s*,\s*ns\s*=\s*\.\.\.)[ \t]*$", re.M), r"\1; ns = ns.{key}; if ns.__skip then return end"),
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
PATH_RE = re.compile(r"(AddOns)(\\\\|\\|/)(OpenMap|ShortestPathForever|Books_on_map_Forever)(?=\\\\|\\|/)",
                     re.I)


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
    ("OpenMap/Map/Compat.lua",
     'if loaded and loaded("Books_on_map_Forever") then',
     'if BookFinder and BookFinder.Loaded("Books_on_map_Forever") or loaded and loaded("Books_on_map_Forever") then'),
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
                if dirpath == src and fn in SKIP_FILES:
                    continue
                s = os.path.join(dirpath, fn)
                rel = os.path.relpath(s, src)
                d = os.path.join(dst, rel)
                os.makedirs(os.path.dirname(d), exist_ok=True)
                if fn.endswith((".lua", ".xml")):
                    text = rewrite_paths(read(s))
                    write(d, text)
                    if fn.endswith(".lua") and not rel.startswith(LIB_DIRS):
                        rewrite_namespace(d, f"{folder}/{rel}", key)
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
    stale = re.compile(r"AddOns(\\\\|\\|/)(OpenMap|ShortestPathForever|Books_on_map_Forever)(\\\\|\\|/)", re.I)
    for dirpath, _, names in os.walk(out):
        for fn in names:
            if fn.endswith((".lua", ".xml")):
                p = os.path.join(dirpath, fn)
                if stale.search(read(p)):
                    fail(f"{os.path.relpath(p, out)}: a path still points at a standalone addon folder")

    os.makedirs(os.path.join(out, "Merge"), exist_ok=True)
    for fn in ("Namespaces.lua", "Bridge.lua"):
        shutil.copy2(os.path.join(MERGE, fn), os.path.join(out, "Merge", fn))

    om, spf, books = metas["OpenMap"], metas["SPF"], metas["Books"]
    optional = []
    for meta in metas.values():
        for dep in re.split(r"[,\s]+", meta.get("OptionalDeps", "")):
            if dep and dep not in optional and dep not in ("OpenMap", "ShortestPathForever", "ForeverCore"):
                optional.append(dep)
    saved, saved_char = [], []
    for meta in metas.values():
        saved += [v.strip() for v in meta.get("SavedVariables", "").split(",") if v.strip()]
        saved_char += [v.strip() for v in meta.get("SavedVariablesPerCharacter", "").split(",") if v.strip()]

    header = f"""## Interface: 16001
## Title: |cff33ff99Book|rFinder
## Notes: OpenMap's seamless world map, Shortest Path Forever's journeys and Books on map's library books, in one addon. /bookfinder
## Author: {om.get("Author")}; {spf.get("Author")}; {books.get("Author")}; merged as BookFinder
## Version: {VERSION}
## X-OpenMap-Version: {om["Version"]}
## X-SPF-Version: {spf["Version"]}
## X-Books-Version: {books["Version"]}
## Category: Map
## X-Category: Map
## X-License: GPL-3.0-or-later (Shortest Path Forever's licence; OpenMap's code is MIT; Books on map's is its author's); map art is Blizzard's
## IconTexture: Interface\\AddOns\\{NAME}\\Books_on_map_Forever\\adds\\icon
## AddonCompartmentFunc: BookFinder_OnAddonCompartmentClick
## AddonCompartmentFuncOnEnter: BookFinder_OnAddonCompartmentEnter
## AddonCompartmentFuncOnLeave: BookFinder_OnAddonCompartmentLeave
## Dependencies: ForeverCore
## OptionalDeps: {", ".join(optional)}
## X-Forever-Core: {spf["X-Forever-Core"]}
## X-Forever-Icon: {spf["X-Forever-Icon"]}
## SavedVariables: {", ".join(saved)}
## SavedVariablesPerCharacter: {", ".join(saved_char)}

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
    write(os.path.join(out, NAME + ".toc"), header + "\n".join(body) + "\n\n# Ties the parts together\nMerge\\Bridge.lua\n")

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
