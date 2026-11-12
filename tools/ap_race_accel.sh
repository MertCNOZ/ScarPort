#!/usr/bin/env bash
# From TRACK SELECTION (tools/ap_to_tracksel.sh) into the race with the first car, then full throttle for 5 s from
# the green light; prints the race timer crops for reading speed and time: out/ap/snaps/acc_*.png
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ap() { bash "$ROOT/tools/ap.sh" "$@" > /dev/null; }
ap press a; sleep 6        # track -> car selection
ap press a; sleep 9        # car -> race, countdown over
ap shot acc_0
ap hold rt 5; sleep 5.1
ap shot acc_1
powershell -ExecutionPolicy Bypass -File "$ROOT/tools/crop_hud.ps1" acc_0 acc_1 > /dev/null
echo "race acceleration shots taken"
