#!/usr/bin/env bash
# One command from nothing to driving: backs up the saves, starts the game with the autopilot (tools/ap_start.ps1),
# skips the intro, loads the first saved profile, Instant Action, Laguna Seca, the first car, and waits for the
# green light. Every A is pressed after a pixel check (the other ap_to_*.sh scripts). Ends with out/ap/snaps/race.png.
# Extra environment (XBE_LOG=info, SCAR_*) passes through to the game.
# Usage: bash tools/ap_to_race.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if tasklist //FI "IMAGENAME eq SCAR.exe" 2>/dev/null | grep -q SCAR.exe; then
    echo "SCAR.exe is already running; close it first (this script starts its own)" >&2
    exit 1
fi
bash "$ROOT/tools/backup_saves.sh" before_test > /dev/null
powershell -ExecutionPolicy Bypass -File "$ROOT/tools/ap_start.ps1" | tail -1
bash "$ROOT/tools/ap_to_title.sh"
bash "$ROOT/tools/ap_to_main.sh"
bash "$ROOT/tools/ap_to_tracksel.sh"
ap() { bash "$ROOT/tools/ap.sh" "$@" > /dev/null; }
px() { powershell -ExecutionPolicy Bypass -File "$ROOT/tools/checkpx.ps1" -Src "$ROOT/out/ap/snaps/$1.png" -X "$2" -Y "$3" -W "$4" -H "$5" -Mode yellow; }
lit() { awk "BEGIN{exit !($1 > 0.05)}"; }
ap press a; sleep 6; ap shot car
lit "$(px car 185 345 200 105)" || { echo "car selection (first car lit) not reached" >&2; exit 1; }
ap press a; sleep 9; ap shot race
echo "in the race: $ROOT/out/ap/snaps/race.png"
