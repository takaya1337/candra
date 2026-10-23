#!/bin/bash
# Makes the manual's exhibits (lib/menu/manual_screen.dart): every
# feature's screen as the app draws it, with the showcase journal, in
# English and Indonesian, dark and light, and where each part the manual
# names stands on it. Run it again whenever a screen changes.
#
# test/manual_pictures_test.dart lays the screens out and keeps PNGs and
# marks.json; this turns them into app/assets/manual/<lang>-<side>/
# <feature>.webp (two pixels a point, lossy) and assets/manual/marks.json.
# Needs cwebp (brew install webp).
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

flutter test test/manual_pictures_test.dart --dart-define=MANUAL_PICTURES="$WORK"

OUT=assets/manual
rm -rf "$OUT"
mkdir -p "$OUT"
for dir in "$WORK"/*/; do
  version=$(basename "$dir")
  mkdir -p "$OUT/$version"
  for png in "$dir"*.png; do
    name=$(basename "$png" .png)
    # Drawn at three pixels a point (1320 wide); kept at two (880).
    cwebp -quiet -q 78 -resize 880 0 "$png" -o "$OUT/$version/$name.webp"
  done
done
cp "$WORK/marks.json" "$OUT/marks.json"
du -sh "$OUT"
ls "$OUT"
