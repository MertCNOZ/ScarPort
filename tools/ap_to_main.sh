#!/usr/bin/env bash
# From the title screen (tools/ap_to_title.sh) to the main menu with the first saved profile loaded:
# START, the language choice (English must be lit), PROFILE MANAGEMENT (the cursor starts on no visible line: up,
# up = New Profile, down = Load Profile), the first slot. Every A is pressed only after a pixel check.
# Usage: bash tools/ap_to_main.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
px() { powershell -ExecutionPolicy Bypass -File "$ROOT/tools/checkpx.ps1" -Src "$ROOT/out/ap/snaps/$1.png" -X "$2" -Y "$3" -W "$4" -H "$5" -Mode yellow; }
ap() { bash "$ROOT/tools/ap.sh" "$@" > /dev/null; }
lit() { awk "BEGIN{exit !($1 > 0.1)}"; }
fail() { echo "$1" >&2; exit 1; }

ap press start; sleep 4; ap shot main1
if lit "$(px main1 620 465 130 40)"; then ap press a; sleep 4; fi   # language: English
ap press up; sleep 1.5; ap press up; sleep 1.5; ap press down; sleep 1.5; ap shot main2
lit "$(px main2 168 265 240 45)" || fail "Load Profile is not lit"
ap press a; sleep 3; ap shot main3
lit "$(px main3 110 245 140 35)" || fail "no saved profile in the first slot"
ap press a; sleep 4; ap shot main4
lit "$(px main4 168 180 290 45)" || fail "main menu (Dynasty Mode lit) not reached"
echo "main menu"
