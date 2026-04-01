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
        "$GODOT" "$@" 2>&1 | tr -d '\000' | sed 's/\r$//' > "$log_path" || true
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
if bash "$PROJECT_DIR/scripts/generate_resource_sitemap.sh" "$SITEMAP_PATH" > "$SITEMAP_LOG" 2>&1; then
    ok "Resource sitemap ($(realpath --relative-to="$PROJECT_DIR" "$SITEMAP_PATH" 2>/dev/null || echo "data/resource_sitemap.json"))"
else
    err "Resource sitemap generation failed"
    sed 's/^/    /' "$SITEMAP_LOG" | head -20
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

    rm -f "$RUN_LOG"
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
    UNIT_PASSED=$(grep -oP "RESULTS: \K\d+" "$UNIT_TEST_LOG" | head -1)
    ok "Unit tests passed (${UNIT_PASSED}/${UNIT_PASSED})"
else
    err "Unit tests failed"
    grep -E "\[FAIL\]|FAILED:" "$UNIT_TEST_LOG" | sed 's/^/    /' | head -20
fi

echo ""
echo -e "${BLUE}========================================${NC}"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}  All checks passed (${PASS}/${PASS})${NC}"
    echo -e "${BLUE}========================================${NC}"
    rm -f "$RUN_LOG" "$UNIT_TEST_LOG" "$SITEMAP_LOG"
    exit 0
else
    echo -e "${RED}  ${FAIL} checks failed${NC}"
    echo -e "${BLUE}========================================${NC}"
    rm -f "$RUN_LOG" "$UNIT_TEST_LOG" "$SITEMAP_LOG"
    exit 1
fi
