#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$PROJECT_DIR/data/resource_sitemap.json}"

if [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="$PROJECT_DIR/$OUTPUT_PATH"
fi

PYTHON_BIN=""
for PYTHON_CANDIDATE in python3 python; do
    PYTHON_PATH="$(command -v "$PYTHON_CANDIDATE" 2>/dev/null || true)"
    if [[ -n "$PYTHON_PATH" ]] && "$PYTHON_PATH" --version >/dev/null 2>&1; then
        PYTHON_BIN="$PYTHON_PATH"
        break
    fi
done
if [[ -z "$PYTHON_BIN" ]]; then
    echo "Python 3 is required to generate the resource sitemap." >&2
    exit 1
fi

"$PYTHON_BIN" "$PROJECT_DIR/tools/generate_resource_sitemap.py" \
    --project-root "$PROJECT_DIR" \
    --output "$OUTPUT_PATH"
