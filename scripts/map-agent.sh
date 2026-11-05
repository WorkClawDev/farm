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

exec "$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" \
    --script res://tools/map_editor/map_agent.gd -- "$@"
