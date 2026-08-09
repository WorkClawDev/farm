#!/bin/bash
set -euo pipefail

GODOT="${GODOT:-/home/admin/tools/bin/godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-pack}"
PRESET="${2:-Windows Desktop}"

case "$MODE" in
  pack) FLAG="--export-pack"; OUTPUT="build/validation/PastoralTales.pck" ;;
  debug) FLAG="--export-debug"; OUTPUT="build/windows/PastoralTales.debug.exe" ;;
  release) FLAG="--export-release"; OUTPUT="build/windows/PastoralTales.exe" ;;
  *) echo "Usage: bash scripts/export.sh [pack|debug|release] [preset]" >&2; exit 2 ;;
esac

mkdir -p "$PROJECT_DIR/$(dirname "$OUTPUT")"
LOG_FILE="${TMPDIR:-/tmp}/pastoral_export_$$.log"
trap 'rm -f "$LOG_FILE"' EXIT
"$GODOT" --headless --path "$PROJECT_DIR" "$FLAG" "$PRESET" "$PROJECT_DIR/$OUTPUT" 2>&1 | tee "$LOG_FILE"
if grep -qE '^(SCRIPT ERROR|ERROR:|FATAL)|Compile Error|Parse Error|Nonexistent function|Invalid call|Failed to load script' "$LOG_FILE"; then
  echo "Export emitted script/runtime errors" >&2
  exit 1
fi
test -f "$PROJECT_DIR/$OUTPUT"
echo "Export OK: $OUTPUT"
