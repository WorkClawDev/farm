#!/bin/bash
set -euo pipefail

GODOT="${GODOT:-/home/admin/tools/bin/godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

exec "$GODOT" --headless --audio-driver Dummy --path "$PROJECT_DIR" \
    --script res://tools/map_editor/map_agent.gd -- "$@"
