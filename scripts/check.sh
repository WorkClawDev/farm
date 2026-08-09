#!/bin/bash
# =====================================================================
# Pastoral Tales - project check script
# Usage: bash scripts/check.sh
# =====================================================================

GODOT="${GODOT:-/home/admin/tools/bin/godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

log() { echo -e "${BLUE}[check]${NC} $*"; }
ok()  { echo -e "${GREEN}  OK${NC} $*"; PASS=$((PASS + 1)); }
err() { echo -e "${RED}  FAIL${NC} $*"; FAIL=$((FAIL + 1)); }
warn(){ echo -e "${YELLOW}  WARN${NC} $*"; }

normalize_log() {
    local path="$1"
    local tmp="${path}.normalized"

    if [ ! -f "$path" ]; then
        return
    fi

    # Windows Godot binaries invoked through WSL may emit UTF-16LE/NUL bytes.
    if LC_ALL=C grep -q $'\000' "$path" 2>/dev/null; then
        tr -d '\000' < "$path" > "$tmp" && mv "$tmp" "$path"
    fi

    sed -i 's/\r$//' "$path" 2>/dev/null || true
}

run_godot() {
    local log_path="$1"
    shift
    if [[ "$GODOT" == *.exe ]]; then
        local converted_args=()
        local argument
        for argument in "$@"; do
            if [ "$argument" = "$PROJECT_DIR" ] && command -v wslpath >/dev/null 2>&1; then
                converted_args+=("$(wslpath -w "$argument")")
            else
                converted_args+=("$argument")
            fi
        done
        "$GODOT" "${converted_args[@]}" 2>&1 | tr -d '\000' | sed 's/\r$//' > "$log_path" || true
    else
        "$GODOT" "$@" > "$log_path" 2>&1 || true
        normalize_log "$log_path"
    fi
}

REQUIRED_SYSTEMS=(
    "GameManager"
    "TimeManager"
    "SaveManager"
    "EventBus"
    "AudioManager"
    "InputManager"
    "MoneySystem"
    "ShippingSystem"
    "SceneTransition"
    "GrowthSystem"
    "GiftSystem"
    "ForagingSystem"
    "QuestSystem"
    "NPCManager"
    "HouseUpgradeSystem"
    "FestivalSystem"
    "AchievementSystem"
	"GameSession"
)

VERSION="$("$GODOT" --version 2>&1 | head -1)"
log "Godot: ${VERSION}"
log "Project: $PROJECT_DIR"
echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Resource sitemap${NC}"
echo -e "${CYAN}========================================${NC}"

SITEMAP_LOG="/tmp/resource_sitemap_$$.log"
SITEMAP_PATH="$PROJECT_DIR/data/resource_sitemap.json"
PYTHON_BIN=""
for PYTHON_CANDIDATE in python3 python; do
    PYTHON_PATH="$(command -v "$PYTHON_CANDIDATE" 2>/dev/null || true)"
    if [ -n "$PYTHON_PATH" ] && "$PYTHON_PATH" --version >/dev/null 2>&1; then
        PYTHON_BIN="$PYTHON_PATH"
        break
    fi
done
if [ -n "$PYTHON_BIN" ] && "$PYTHON_BIN" "$PROJECT_DIR/tools/generate_resource_sitemap.py" \
    --project-root "$PROJECT_DIR" --output "$SITEMAP_PATH" > "$SITEMAP_LOG" 2>&1; then
    ok "Resource sitemap ($(realpath --relative-to="$PROJECT_DIR" "$SITEMAP_PATH" 2>/dev/null || echo "data/resource_sitemap.json"))"
else
    SITEMAP_STATUS=$?
    err "Resource sitemap generation failed (python: ${PYTHON_BIN:-missing}, exit: ${SITEMAP_STATUS})"
    sed 's/^/    /' "$SITEMAP_LOG" | head -20
fi

echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Delivery contract${NC}"
echo -e "${CYAN}========================================${NC}"

if [ -n "$PYTHON_BIN" ] && "$PYTHON_BIN" "$PROJECT_DIR/tools/verify_delivery_contract.py"; then
    ok "Architecture and map delivery contract"
else
    err "Architecture and map delivery contract"
fi

echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Authored map validation${NC}"
echo -e "${CYAN}========================================${NC}"

MAP_TEST_LOG="/tmp/godot_maps_$$.log"
run_godot "$MAP_TEST_LOG" --headless --path "$PROJECT_DIR" --script res://tools/map_editor/validate_maps.gd

MAP_SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$MAP_TEST_LOG" 2>/dev/null || true)
MAP_RUNTIME_ERRORS=$(grep -cE "^ERROR:|FATAL|failed to load|Failed to" "$MAP_TEST_LOG" 2>/dev/null || true)
if [ "${MAP_SCRIPT_ERRORS:-0}" -gt 0 ] || [ "${MAP_RUNTIME_ERRORS:-0}" -gt 0 ]; then
    err "Map validation emitted $((MAP_SCRIPT_ERRORS + MAP_RUNTIME_ERRORS)) script/runtime errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL|failed to load|Failed to" \
        "$MAP_TEST_LOG" | sed 's/^/    /' | head -30
elif grep -q "MAP VALIDATION PASSED" "$MAP_TEST_LOG"; then
    ok "Authored maps"
else
    err "Map validation failed"
    grep -E "\[MAP FAIL\]|MAP VALIDATION FAILED" "$MAP_TEST_LOG" | sed 's/^/    /' | head -30
fi

echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Agent map API dry run${NC}"
echo -e "${CYAN}========================================${NC}"

AGENT_MAP_LOG="/tmp/godot_map_agent_$$.log"
run_godot "$AGENT_MAP_LOG" --headless --path "$PROJECT_DIR" \
    --script res://tools/map_editor/map_agent.gd -- apply \
    res://src/world/maps/content/FarmMap.tscn \
    res://tools/map_editor/examples/farm_orchard_recipe.json --dry-run

AGENT_MAP_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL" "$AGENT_MAP_LOG" 2>/dev/null || true)
if [ "${AGENT_MAP_ERRORS:-0}" -gt 0 ]; then
    err "Agent map API emitted ${AGENT_MAP_ERRORS} script/runtime errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL" \
        "$AGENT_MAP_LOG" | sed 's/^/    /' | head -30
elif grep -q 'MAP_AGENT_RESULT=.*"ok":true' "$AGENT_MAP_LOG"; then
    ok "Agent map API dry run"
else
    err "Agent map API dry run failed"
    grep "MAP_AGENT_RESULT=" "$AGENT_MAP_LOG" | sed 's/^/    /' | head -5
fi

echo ""

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Map editor workflow test${NC}"
echo -e "${CYAN}========================================${NC}"

EDITOR_MAP_LOG="/tmp/godot_map_editor_$$.log"
run_godot "$EDITOR_MAP_LOG" --headless --editor --path "$PROJECT_DIR" -- --map-editor-smoke-test

EDITOR_MAP_SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$EDITOR_MAP_LOG" 2>/dev/null || true)
EDITOR_MAP_RUNTIME_ERRORS=$(grep -cE "^ERROR:|FATAL|failed to load|Failed to" "$EDITOR_MAP_LOG" 2>/dev/null || true)
if [ "${EDITOR_MAP_SCRIPT_ERRORS:-0}" -gt 0 ] || [ "${EDITOR_MAP_RUNTIME_ERRORS:-0}" -gt 0 ]; then
    err "Map editor workflow emitted $((EDITOR_MAP_SCRIPT_ERRORS + EDITOR_MAP_RUNTIME_ERRORS)) script/runtime errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL|failed to load|Failed to" \
        "$EDITOR_MAP_LOG" | sed 's/^/    /' | head -30
elif grep -q "MAP EDITOR SMOKE TEST PASSED" "$EDITOR_MAP_LOG"; then
    EDITOR_MAP_PASSED=$(grep -c "\[EDITOR PASS\]" "$EDITOR_MAP_LOG" 2>/dev/null || true)
    ok "Map editor workflow (${EDITOR_MAP_PASSED} assertions)"
else
    err "Map editor workflow failed"
    grep -E "\[EDITOR FAIL\]|MAP EDITOR SMOKE TEST FAILED" "$EDITOR_MAP_LOG" | sed 's/^/    /' | head -30
fi

echo ""

RUN_LOG="/tmp/godot_check_$$.log"
run_godot "$RUN_LOG" --no-window --headless --quit --path "$PROJECT_DIR"

SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function" "$RUN_LOG" 2>/dev/null || true)
RUNTIME_ERRORS=$(grep -cE "^ERROR:|FATAL|failed to load|Failed to" "$RUN_LOG" 2>/dev/null || true)

if [ "${SCRIPT_ERRORS:-0}" -gt 0 ] || [ "${RUNTIME_ERRORS:-0}" -gt 0 ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  Startup checks failed${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""

    if [ "${SCRIPT_ERRORS:-0}" -gt 0 ]; then
        echo -e "${RED}Script / compile errors (${SCRIPT_ERRORS}):${NC}"
        grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function" "$RUN_LOG" | sed 's/^/  /' | head -20
        echo ""
    fi

    if [ "${RUNTIME_ERRORS:-0}" -gt 0 ]; then
        echo -e "${RED}Runtime errors (${RUNTIME_ERRORS}):${NC}"
        grep -E "^ERROR:|FATAL|failed to load|Failed to" "$RUN_LOG" | sed 's/^/  /' | head -20
        echo ""
    fi

    rm -f "$RUN_LOG" "$MAP_TEST_LOG" "$AGENT_MAP_LOG" "$EDITOR_MAP_LOG" "$SITEMAP_LOG"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  System initialization check${NC}"
echo -e "${CYAN}========================================${NC}"

INIT_COUNT=$(grep -c "Initialized" "$RUN_LOG" 2>/dev/null || true)
echo "  Found ${INIT_COUNT} initialization messages"
echo ""

for sys in "${REQUIRED_SYSTEMS[@]}"; do
    if grep -qE "\[$sys\].*Initialized|$sys.*Initialized" "$RUN_LOG" 2>/dev/null; then
        ok "$sys"
    elif grep -qE "\[$sys\]" "$RUN_LOG" 2>/dev/null; then
        ok "$sys"
    else
        err "$sys (missing init log)"
    fi
done

if grep -q "ItemDatabase" "$RUN_LOG" 2>/dev/null; then
    ITEMS=$(grep -oE "Loaded [0-9]+" "$RUN_LOG" | head -1 | grep -oE "[0-9]+")
    if [ -n "$ITEMS" ]; then
        ok "ItemDatabase (${ITEMS} items)"
    else
        ok "ItemDatabase"
    fi
else
    err "ItemDatabase (missing load log)"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Unit tests${NC}"
echo -e "${CYAN}========================================${NC}"

UNIT_TEST_LOG="/tmp/godot_tests_$$.log"
run_godot "$UNIT_TEST_LOG" --headless --quit --path "$PROJECT_DIR" --scene tests/unit/test_core.tscn

UNIT_SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$UNIT_TEST_LOG" 2>/dev/null || true)
if [ "${UNIT_SCRIPT_ERRORS:-0}" -gt 0 ]; then
    err "Unit test runtime emitted ${UNIT_SCRIPT_ERRORS} script errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$UNIT_TEST_LOG" | sed 's/^/    /' | head -20
elif grep -q "ALL TESTS PASSED" "$UNIT_TEST_LOG"; then
    UNIT_PASSED=$(sed -n 's/.*RESULTS: \([0-9][0-9]*\)\/.*/\1/p' "$UNIT_TEST_LOG" | head -1)
    ok "Unit tests passed (${UNIT_PASSED}/${UNIT_PASSED})"
else
    err "Unit tests failed"
    grep -E "\[FAIL\]|FAILED:" "$UNIT_TEST_LOG" | sed 's/^/    /' | head -20
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Game flow integration test${NC}"
echo -e "${CYAN}========================================${NC}"

FLOW_TEST_LOG="/tmp/godot_flow_$$.log"
run_godot "$FLOW_TEST_LOG" --headless --path "$PROJECT_DIR" --scene tests/integration/test_game_flow.tscn

FLOW_SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$FLOW_TEST_LOG" 2>/dev/null || true)
FLOW_RUNTIME_ERRORS=$(grep -cE "^ERROR:|FATAL|failed to load|Failed to" "$FLOW_TEST_LOG" 2>/dev/null || true)
if [ "${FLOW_SCRIPT_ERRORS:-0}" -gt 0 ] || [ "${FLOW_RUNTIME_ERRORS:-0}" -gt 0 ]; then
    err "Game flow emitted $((FLOW_SCRIPT_ERRORS + FLOW_RUNTIME_ERRORS)) script/runtime errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL|failed to load|Failed to" \
        "$FLOW_TEST_LOG" | sed 's/^/    /' | head -30
elif grep -q "ALL INTEGRATION TESTS PASSED" "$FLOW_TEST_LOG"; then
    FLOW_PASSED=$(sed -n 's/.*RESULTS: \([0-9][0-9]*\)\/.*/\1/p' "$FLOW_TEST_LOG" | head -1)
    ok "Game flow passed (${FLOW_PASSED}/${FLOW_PASSED})"
else
    err "Game flow integration test failed"
    grep -E "\[FAIL\]|INTEGRATION TESTS FAILED" "$FLOW_TEST_LOG" | sed 's/^/    /' | head -30
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  UI system integration test${NC}"
echo -e "${CYAN}========================================${NC}"

UI_TEST_LOG="/tmp/godot_ui_$$.log"
run_godot "$UI_TEST_LOG" --headless --path "$PROJECT_DIR" --scene tests/integration/test_ui_system.tscn

UI_SCRIPT_ERRORS=$(grep -cE "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call" "$UI_TEST_LOG" 2>/dev/null || true)
UI_RUNTIME_ERRORS=$(grep -cE "^ERROR:|FATAL|failed to load|Failed to" "$UI_TEST_LOG" 2>/dev/null || true)
if [ "${UI_SCRIPT_ERRORS:-0}" -gt 0 ] || [ "${UI_RUNTIME_ERRORS:-0}" -gt 0 ]; then
    err "UI system emitted $((UI_SCRIPT_ERRORS + UI_RUNTIME_ERRORS)) script/runtime errors"
    grep -E "SCRIPT ERROR|Compile Error|Parse Error|Nonexistent function|Invalid call|^ERROR:|FATAL|failed to load|Failed to" \
        "$UI_TEST_LOG" | sed 's/^/    /' | head -30
elif grep -q "ALL UI TESTS PASSED" "$UI_TEST_LOG"; then
    UI_PASSED=$(sed -n 's/.*RESULTS: \([0-9][0-9]*\)\/.*/\1/p' "$UI_TEST_LOG" | head -1)
    ok "UI system passed (${UI_PASSED}/${UI_PASSED})"
else
    err "UI system integration test failed"
    grep -E "\[FAIL\]|UI TESTS FAILED" "$UI_TEST_LOG" | sed 's/^/    /' | head -30
fi

echo ""
echo -e "${BLUE}========================================${NC}"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}  All checks passed (${PASS}/${PASS})${NC}"
    echo -e "${BLUE}========================================${NC}"
    rm -f "$RUN_LOG" "$UNIT_TEST_LOG" "$FLOW_TEST_LOG" "$UI_TEST_LOG" "$MAP_TEST_LOG" "$AGENT_MAP_LOG" "$EDITOR_MAP_LOG" "$SITEMAP_LOG"
    exit 0
else
    echo -e "${RED}  ${FAIL} checks failed${NC}"
    echo -e "${BLUE}========================================${NC}"
    rm -f "$RUN_LOG" "$UNIT_TEST_LOG" "$FLOW_TEST_LOG" "$UI_TEST_LOG" "$MAP_TEST_LOG" "$AGENT_MAP_LOG" "$EDITOR_MAP_LOG" "$SITEMAP_LOG"
    exit 1
fi
