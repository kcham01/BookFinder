#!/bin/sh
# Builds the download: BookFinder plus OpenMap (the map, MIT, shipped unchanged beside it; the owner's decision).
# Usage: tools/package.sh <OpenMap source folder (the one holding OpenMap.toc)> <output zip>
set -e
cd "$(dirname "$0")/.."
OPENMAP="$1"
OUT="$2"
[ -f "$OPENMAP/OpenMap.toc" ] || { echo "usage: tools/package.sh <OpenMap folder> <out.zip>"; exit 2; }
STAGE=$(mktemp -d)
cp -r BookFinder "$STAGE/BookFinder"
# OpenMap as it is, without the art for other WoW versions (Retail) it never loads on WoW: Forever.
mkdir -p "$STAGE/OpenMap"
( cd "$OPENMAP" && tar cf - --exclude='./Media/Textures/Retail' --exclude='./OpenMap_Mainline.toc' . ) | ( cd "$STAGE/OpenMap" && tar xf - )
rm -f "$OUT"
( cd "$STAGE" && zip -qr "$OUT" BookFinder OpenMap )
rm -rf "$STAGE"
ls -la "$OUT"
