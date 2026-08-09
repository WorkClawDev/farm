#!/usr/bin/env python3
"""Verify the architecture and map-delivery boundaries that keep releases small."""

from __future__ import annotations

import configparser
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
MAPS = ("Farm", "Forest", "Mine", "Beach", "Village", "PlayerHouse")
LAYERS = ("ground", "terrain_overlay", "decoration", "objects", "collision", "markers")


def fail(message: str) -> None:
    print(f"[DELIVERY FAIL] {message}")
    raise SystemExit(1)


def main() -> int:
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    autoload_block = project_text.split("[autoload]", 1)[1].split("\n[", 1)[0]
    autoloads = [line for line in autoload_block.splitlines() if "=" in line]
    if len(autoloads) > 33:
        fail(f"Autoload budget exceeded: {len(autoloads)} > 33")
    if 'GameSession="*res://src/core/session/GameSession.gd"' not in autoload_block:
        fail("GameSession is not the session boundary")
    if "SeasonSystem=" in autoload_block or "WeatherSystem=" in autoload_block:
        fail("Season or weather regressed to a standalone Autoload")

    if not (ROOT / "export_presets.cfg").is_file():
        fail("Versioned export_presets.cfg is missing")
    workflow = ROOT / ".github/workflows/validate-and-export.yml"
    if not workflow.is_file():
        fail("Continuous export workflow is missing")

    for name in MAPS:
        runtime_path = ROOT / f"src/world/maps/{name}.tscn"
        content_path = ROOT / f"src/world/maps/content/{name}Map.tscn"
        if not runtime_path.is_file() or not content_path.is_file():
            fail(f"{name} delivery is incomplete")
        runtime = runtime_path.read_text(encoding="utf-8")
        content = content_path.read_text(encoding="utf-8")
        expected_reference = f"res://src/world/maps/content/{name}Map.tscn"
        if expected_reference not in runtime:
            fail(f"{name} runtime scene does not instance its authored map")
        if 'type="TileMap"' in runtime:
            fail(f"{name} runtime scene still contains deprecated TileMap")
        if "EditableMap2D.gd" not in content:
            fail(f"{name} content root is not EditableMap2D")
        for layer_id in LAYERS:
            if f'layer_id = &"{layer_id}"' not in content:
                fail(f"{name} is missing layer {layer_id}")

    print(f"DELIVERY CONTRACT PASSED ({len(autoloads)} Autoloads, {len(MAPS)} maps)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
