#!/usr/bin/env bash
# Packages the Web export of game/ for the portfolio case study ("play/" folder).
#
#   GODOT=~/godot/godot tools/portfolio_play/build_portfolio_play.sh <out-dir>
#
# Exports the existing "Web" preset from a temporary copy of game/ (game/ itself
# is never modified), then packages it the way the portfolio page loads it:
# index.wasm is gzipped (engine.gz.wasm) and index.pck is split into chunks under
# 14 MB (data.partN.wasm); play-shim.js reassembles both in the browser, so the
# game Godot runs is byte-identical to the export. patch_play_html.py adds the
# loader shim, styling and progress/ready messages to Godot's index.html.
# Used by .github/workflows/publish-portfolio-game.yml.
set -euo pipefail
GODOT="${GODOT:-$HOME/godot/godot}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:?usage: build_portfolio_play.sh <out-dir>}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -r "$ROOT/game" "$TMP/game"
mkdir -p "$TMP/web"
"$GODOT" --headless --path "$TMP/game" --import || true
"$GODOT" --headless --path "$TMP/game" --export-release "Web" "$TMP/web/index.html"
test -f "$TMP/web/index.wasm" && test -f "$TMP/web/index.pck"

rm -rf "$OUT" && mkdir -p "$OUT"
cp "$TMP/web/index.js" "$TMP/web/index.audio.worklet.js" "$TMP/web/index.audio.position.worklet.js" "$OUT/"
gzip -9c "$TMP/web/index.wasm" > "$OUT/engine.gz.wasm"
split -b 14000000 -d -a 1 --additional-suffix=.wasm "$TMP/web/index.pck" "$OUT/data.part"
PARTS=$(ls "$OUT" | grep -c '^data.part')
cp "$HERE/play-shim.js" "$OUT/play-shim.js"
python3 "$HERE/patch_play_html.py" "$TMP/web/index.html" "$OUT/index.html" "$PARTS"
ls -la "$OUT"
