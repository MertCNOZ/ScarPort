#!/usr/bin/env bash
# Copies the game's saves (hdd/E/UDATA/4c530002 beside the exe) to out/save_backups/<date>_<time>[_label] before a
# test, and keeps the newest 20 backups. Usage: bash tools/backup_saves.sh [label]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/out/build/release/hdd/E/UDATA/4c530002"
DST="$ROOT/out/save_backups"
[ -d "$SRC" ] || { echo "no saves at $SRC" >&2; exit 1; }
mkdir -p "$DST"
name="$(date +%Y%m%d_%H%M%S)${1:+_$1}"
cp -r "$SRC" "$DST/$name"
# the oldest beyond 20 go (only folders this script made: date-named)
ls -1d "$DST"/20[0-9][0-9][01][0-9][0-3][0-9]_* 2>/dev/null | sort | head -n -20 | while read -r old; do rm -r -- "$old"; done
echo "$DST/$name"
