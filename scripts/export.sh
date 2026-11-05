#!/bin/bash
set -euo pipefail

resolve_godot() {
    if [ -n "${GODOT:-}" ]; then
        if [ -x "$GODOT" ] || command -v "$GODOT" >/dev/null 2>&1; then return 0; fi
        echo "ERROR: GODOT is set to '$GODOT' but it is not executable." >&2
        exit 2
    fi
    if command -v godot >/dev/null 2>&1; then GODOT="$(command -v godot)"; return 0; fi
    if [ -x /home/box/.local/bin/godot ]; then GODOT=/home/box/.local/bin/godot; return 0; fi
    echo "ERROR: Godot binary not found (checked \$GODOT, 'godot' on PATH, /home/box/.local/bin/godot)." >&2
    echo "       Set it explicitly, e.g.: GODOT=/path/to/godot bash $0" >&2
    exit 2
}
resolve_godot
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
