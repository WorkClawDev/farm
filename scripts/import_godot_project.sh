#!/bin/bash
# Generate the gitignored editor artifacts a clean checkout does not have.
# .godot/ and *.translation are not in git. Headless --script / --export runs
# do not build them, so the project theme, font, and class_name cache are
# missing and SceneTree tools such as map_agent.gd never reach quit().
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
CACHE="$PROJECT_DIR/.godot/global_script_class_cache.cfg"
EN_TRANSLATION="$PROJECT_DIR/assets/i18n/ui.en.translation"
ZH_TRANSLATION="$PROJECT_DIR/assets/i18n/ui.zh_CN.translation"

import_ready() {
    local font_data
    [ -s "$CACHE" ] || return 1
    [ -s "$EN_TRANSLATION" ] || return 1
    [ -s "$ZH_TRANSLATION" ] || return 1
    grep -q 'EditableMap2D' "$CACHE" || return 1
    font_data="$(find "$PROJECT_DIR/.godot/imported" -name 'NotoSansSC-VF.ttf-*.fontdata' -type f -size +0c -print -quit 2>/dev/null || true)"
    [ -n "$font_data" ]
}

if import_ready; then
    echo "Godot import cache present"
    exit 0
fi

if ! command -v timeout >/dev/null 2>&1; then
    echo "ERROR: timeout(1) missing; cannot limit Godot import." >&2
    exit 1
fi

echo "Importing Godot project resources (translations, fonts, global class cache)..."
echo "Godot reports those generated files as missing until this import pass finishes."
IMPORT_TIMEOUT="${GODOT_IMPORT_TIMEOUT:-600}"
status=0
if [[ "$GODOT" == *.exe ]]; then
    project_arg="$PROJECT_DIR"
    if command -v wslpath >/dev/null 2>&1; then
        project_arg="$(wslpath -w "$PROJECT_DIR")"
    fi
    timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$project_arg" --import || status=$?
else
    timeout --foreground "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --import || status=$?
fi

if [ "$status" -eq 124 ]; then
    echo "ERROR: Godot import timed out after ${IMPORT_TIMEOUT}s" >&2
    exit 1
fi
if [ "$status" -ne 0 ]; then
    echo "ERROR: Godot import exited ${status}" >&2
    exit 1
fi
if ! import_ready; then
    echo "ERROR: Godot import finished without translations, Noto Sans SC font data, or the global class cache." >&2
    exit 1
fi
echo "Godot import complete"
