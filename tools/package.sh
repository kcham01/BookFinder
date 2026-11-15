#!/bin/sh
# Builds the download: ONE addon, BookFinder, with OpenMap's map (MIT, credited) folded inside it as BookFinder\OpenMap
# by tools/openmap_merge.py (the owner: "it's still all supposed to be one addon"). OpenMap's code is not kept in
# this repository; it is taken from the folder given here at packaging time.
# Usage: tools/package.sh <OpenMap source folder (the one holding OpenMap.toc)> <output zip (absolute path)>
set -e
cd "$(dirname "$0")/.."
OPENMAP="$1"
OUT="$2"
[ -f "$OPENMAP/OpenMap.toc" ] || { echo "usage: tools/package.sh <OpenMap folder> <out.zip>"; exit 2; }
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
STAGE=$(mktemp -d)
cp -r BookFinder "$STAGE/BookFinder"
python3 -I tools/openmap_merge.py "$OPENMAP" "$STAGE/BookFinder"
rm -f "$OUT"
( cd "$STAGE" && zip -qr "$OUT" BookFinder )
rm -rf "$STAGE"
ls -la "$OUT"
