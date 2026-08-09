#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

git -C "$PROJECT_DIR" config core.hooksPath .githooks
chmod +x "$PROJECT_DIR/.githooks/pre-commit"

echo "Installed git hooks from .githooks/"
echo "Current hooksPath: .githooks"
