#!/usr/bin/env bash
# From the main menu (tools/ap_to_main.sh, Dynasty Mode lit) to Instant Action's TRACK SELECTION with Laguna Seca lit.
# Usage: bash tools/ap_to_tracksel.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
px() { powershell -ExecutionPolicy Bypass -File "$ROOT/tools/checkpx.ps1" -Src "$ROOT/out/ap/snaps/$1.png" -X "$2" -Y "$3" -W "$4" -H "$5" -Mode yellow; }
ap() { bash "$ROOT/tools/ap.sh" "$@" > /dev/null; }
lit() { awk "BEGIN{exit !($1 > 0.1)}"; }
ap press down; sleep 1.5; ap shot ts1
lit "$(px ts1 168 265 280 45)" || { echo "Instant Action is not lit" >&2; exit 1; }
ap press a; sleep 4; ap shot ts2
lit "$(px ts2 230 355 350 75)" || { echo "track selection (Laguna Seca lit) not reached" >&2; exit 1; }
echo "track selection"
