#!/bin/bash
# Renders icon-{light,dark,tinted}.svg to flat 1024x1024 RGB PNGs in the AppIcon asset set.
# Needs Google Chrome (headless) for the Telugu/Tamil letters and Python Pillow to drop the alpha channel.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../BLTApp/BLTApp/Assets.xcassets/AppIcon.appiconset"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$OUT"
for v in light dark tinted; do
  tmp="$(mktemp -d)"
  printf '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:#fff}svg{display:block}</style>' > "$tmp/p.html"
  cat "$HERE/icon-$v.svg" >> "$tmp/p.html"
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1024,1024 --screenshot="$tmp/raw.png" "file://$tmp/p.html" >/dev/null 2>&1
  python3 - "$tmp/raw.png" "$OUT/icon-$v.png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB").crop((0, 0, 1024, 1024))
im.save(sys.argv[2], "PNG")
PY
  rm -rf "$tmp"
done
echo "icons written to $OUT"
