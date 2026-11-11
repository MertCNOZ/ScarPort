#!/usr/bin/env bash
# Drives a game started with tools/ap_start.ps1 past the intro movies (A skips one) to the title screen
# ("Please press START to begin", yellow text at the bottom), checked by pixels before every press.
# Usage: bash tools/ap_to_title.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
px() { powershell -ExecutionPolicy Bypass -File "$ROOT/tools/checkpx.ps1" -Src "$ROOT/out/ap/snaps/$1.png" -X "$2" -Y "$3" -W "$4" -H "$5" -Mode "$6"; }
for i in $(seq 1 40); do
    bash "$ROOT/tools/ap.sh" shot title > /dev/null
    v=$(px title 330 790 620 45 yellow)
    if awk "BEGIN{exit !($v > 0.03)}"; then echo "title screen"; exit 0; fi
    bash "$ROOT/tools/ap.sh" press a > /dev/null
    sleep 4
done
echo "no title screen" >&2
exit 1
