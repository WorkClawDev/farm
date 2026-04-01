#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_PATH="${1:-$PROJECT_DIR/data/resource_sitemap.json}"

if [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="$PROJECT_DIR/$OUTPUT_PATH"
fi

python3 "$PROJECT_DIR/tools/generate_resource_sitemap.py" \
    --project-root "$PROJECT_DIR" \
    --output "$OUTPUT_PATH"
