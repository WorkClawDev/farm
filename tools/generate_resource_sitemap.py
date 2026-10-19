#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ImportError:  # pragma: no cover - Pillow is optional for CLI use
    Image = None


DEFAULT_SITEMAP_RELATIVE_PATH = Path("data") / "resource_sitemap.json"
SKIP_SUFFIXES = {".import", ".uid"}

# Mirrors the current web map editor palette and FarmTilesetBuilder legacy IDs.
FARM_TILE_DEFS = [
    {"id": 0, "col": 0, "row": 0, "name": "grass", "walkable": True},
    {"id": 1, "col": 1, "row": 0, "name": "dark_grass", "walkable": True},
    {"id": 2, "col": 2, "row": 0, "name": "medium_grass", "walkable": True},
    {"id": 3, "col": 3, "row": 0, "name": "light_grass", "walkable": True},
    {"id": 4, "col": 4, "row": 0, "name": "dry_grass", "walkable": True},
    {"id": 5, "col": 5, "row": 0, "name": "flower_grass", "walkable": True},
    {"id": 6, "col": 6, "row": 0, "name": "path", "walkable": True},
    {"id": 7, "col": 7, "row": 0, "name": "dirt", "walkable": True},
    {"id": 8, "col": 0, "row": 1, "name": "water", "walkable": False},
    {"id": 9, "col": 1, "row": 1, "name": "shallow_water", "walkable": False},
    {"id": 10, "col": 2, "row": 1, "name": "sand", "walkable": True},
    {"id": 11, "col": 3, "row": 1, "name": "fence", "walkable": False},
    {"id": 12, "col": 4, "row": 1, "name": "gate", "walkable": True},
    {"id": 13, "col": 5, "row": 1, "name": "wood_floor", "walkable": True},
    {"id": 14, "col": 6, "row": 1, "name": "stone_floor", "walkable": True},
    {"id": 15, "col": 7, "row": 1, "name": "farmland", "walkable": True},
]

FARM_TILE_SIZE = 16
FARM_ATLAS_COLUMNS = 64

OBJECT_SCENE_REGISTRY = {
    "shipping_bin": "res://src/world/objects/ShippingBin.tscn",
    "workbench": "res://src/world/objects/Workbench.tscn",
    "fishing_spot": "res://src/world/objects/FishingSpot.tscn",
    "player_house_exterior": "res://src/world/objects/HouseExterior.tscn",
    "coop": "res://src/world/objects/Coop.tscn",
    "barn": "res://src/world/objects/Barn.tscn",
    "ore": "res://src/world/objects/Ore.tscn",
}

PLACEMENT_RULES = [
    {
        "resource_kind": "tile_map_layout",
        "description": "Map editor ground tile layout for Farm.gd / MapLoader.gd",
        "target_path_pattern": "data/maps/{map_id}.json",
        "godot_path_pattern": "res://data/maps/{map_id}.json",
        "schema": "legacy_tile_layout_v1",
        "required_fields": ["name", "width", "height", "tile_size", "tiles"],
    },
    {
        "resource_kind": "scene_object_layout",
        "description": "Scene/object placement layout consumed by Farm.gd",
        "target_path_pattern": "data/{layout_id}.json",
        "godot_path_pattern": "res://data/{layout_id}.json",
        "schema": "legacy_object_layout_v1",
        "required_fields": ["grid_size", "objects"],
    },
    {
        "resource_kind": "npc_sprite_sheet",
        "description": "Eight-frame horizontal NPC sheet",
        "target_path_pattern": "assets/sprites/characters/npc_sheets/{npc_id}_sheet.png",
        "godot_path_pattern": "res://assets/sprites/characters/npc_sheets/{npc_id}_sheet.png",
        "runtime_spec": {"width": 256, "height": 32, "frame_width": 32, "frame_height": 32, "frames": 8},
        "data_bindings": [
            {"file": "data/npcs.json", "field": "npcs[].sprite"},
        ],
    },
    {
        "resource_kind": "npc_portrait",
        "description": "NPC dialogue portrait",
        "target_path_pattern": "assets/sprites/portraits/{npc_id}.png",
        "godot_path_pattern": "res://assets/sprites/portraits/{npc_id}.png",
        "runtime_spec": {"width": 64, "height": 64},
        "data_bindings": [
            {"file": "data/npcs.json", "field": "npcs[].portrait"},
            {"file": "data/dialogues.json", "field": "npcs.<npc_id>.portrait"},
        ],
    },
    {
        "resource_kind": "player_sprite_sheet",
        "description": "Player eight-frame horizontal sprite sheet",
        "target_path_pattern": "assets/sprites/characters/{file_name}.png",
        "godot_path_pattern": "res://assets/sprites/characters/{file_name}.png",
        "runtime_spec": {"width": 256, "height": 32, "frame_width": 32, "frame_height": 32, "frames": 8},
        "data_bindings": [
            {"file": "src/entities/player/Player.tscn", "field": "Sprite2D.texture"},
        ],
    },
    {
        "resource_kind": "crop_stage_sprite",
        "description": "Crop growth stage sprite",
        "target_path_pattern": "assets/sprites/crops/{crop_id}_stage{stage}.png",
        "godot_path_pattern": "res://assets/sprites/crops/{crop_id}_stage{stage}.png",
        "data_bindings": [
            {"file": "data/crops.json", "field": "crops[].stages_sprites[]"},
        ],
    },
    {
        "resource_kind": "item_icon",
        "description": "Inventory/item icon",
        "target_path_pattern": "assets/sprites/items/{item_id}.png",
        "godot_path_pattern": "res://assets/sprites/items/{item_id}.png",
        "data_bindings": [
            {"file": "data/items.json", "field": "items[].icon"},
            {"file": "data/fish.json", "field": "fish[].icon"},
        ],
    },
    {
        "resource_kind": "animal_sprite",
        "description": "Current runtime animal sprite slot",
        "target_path_pattern": "assets/sprites/animals/{animal_name}.png",
        "godot_path_pattern": "res://assets/sprites/animals/{animal_name}.png",
        "runtime_spec": {"width": 64, "height": 64},
    },
    {
        "resource_kind": "building_sprite",
        "description": "Building runtime sprite",
        "target_path_pattern": "assets/sprites/houses/{file_name}.png",
        "godot_path_pattern": "res://assets/sprites/houses/{file_name}.png",
    },
    {
        "resource_kind": "source_art_archive",
        "description": "Source art archive slot for generated material",
        "target_path_pattern": "assets/source_art/generated/{category}/{entity}/{version}/{file_name}",
        "godot_path_pattern": "res://assets/source_art/generated/{category}/{entity}/{version}/{file_name}",
    },
]


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _project_relative(path: Path, project_root: Path) -> str:
    return path.relative_to(project_root).as_posix()


def _to_godot_path(path: Path, project_root: Path) -> str:
    return "res://" + _project_relative(path, project_root)


def _res_to_path(project_root: Path, res_path: str | None) -> Path | None:
    if not res_path or not isinstance(res_path, str):
        return None
    if not res_path.startswith("res://"):
        return None
    return project_root / res_path.removeprefix("res://")


def _image_metadata(path: Path) -> dict[str, Any]:
    if Image is None:
        return {}
    try:
        with Image.open(path) as image:
            width, height = image.size
            return {
                "width": width,
                "height": height,
                "mode": image.mode,
            }
    except Exception:
        return {}


def _media_metadata(path: Path) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
        image_meta = _image_metadata(path)
        if image_meta:
            metadata["image"] = image_meta
    return metadata


def _infer_asset_category(path: Path, project_root: Path) -> str:
    rel_parts = path.relative_to(project_root / "assets").parts
    if not rel_parts:
        return "assets"
    if len(rel_parts) == 1:
        return rel_parts[0]
    return "/".join(rel_parts[:-1])


def _build_path_ref(project_root: Path, path_value: str | None) -> dict[str, Any] | None:
    if not path_value:
        return None
    ref_path = _res_to_path(project_root, path_value)
    repo_path = _project_relative(ref_path, project_root) if ref_path and ref_path.exists() else None
    return {
        "godot_path": path_value,
        "repo_path": repo_path,
        "exists": bool(ref_path and ref_path.exists()),
    }


def _build_farm_tileset(project_root: Path) -> dict[str, Any]:
    atlas_path = project_root / "assets" / "tiles" / "farm_tiles.png"
    atlas_image = _image_metadata(atlas_path)
    atlas_rows = 0
    if atlas_image:
        atlas_rows = atlas_image["height"] // FARM_TILE_SIZE

    elements = []
    for tile in FARM_TILE_DEFS:
        pixel_x = tile["col"] * FARM_TILE_SIZE
        pixel_y = tile["row"] * FARM_TILE_SIZE
        elements.append(
            {
                "tile_id": tile["id"],
                "name": tile["name"],
                "walkable": tile["walkable"],
                "atlas_position": {"col": tile["col"], "row": tile["row"]},
                "pixel_rect": {
                    "x": pixel_x,
                    "y": pixel_y,
                    "width": FARM_TILE_SIZE,
                    "height": FARM_TILE_SIZE,
                },
            }
        )

    return {
        "id": "farm_tiles",
        "path": _project_relative(atlas_path, project_root),
        "godot_path": _to_godot_path(atlas_path, project_root),
        "exists": atlas_path.exists(),
        "tile_size": {"width": FARM_TILE_SIZE, "height": FARM_TILE_SIZE},
        "atlas_grid": {"columns": FARM_ATLAS_COLUMNS, "rows": atlas_rows},
        "image": atlas_image or None,
        "elements": elements,
    }


def _build_map_entries(project_root: Path) -> list[dict[str, Any]]:
    tile_lookup = {tile["id"]: tile["name"] for tile in FARM_TILE_DEFS}
    maps_dir = project_root / "data" / "maps"
    entries: list[dict[str, Any]] = []

    if not maps_dir.exists():
        return entries

    for path in sorted(maps_dir.glob("*.json")):
        try:
            data = _read_json(path)
        except Exception as exc:
            entries.append(
                {
                    "id": path.stem,
                    "path": _project_relative(path, project_root),
                    "parse_error": str(exc),
                }
            )
            continue

        tiles = data.get("tiles", [])
        tile_size = int(data.get("tile_size", FARM_TILE_SIZE))
        positions_by_id: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for row_index, row in enumerate(tiles):
            if not isinstance(row, list):
                continue
            for col_index, raw_tile_id in enumerate(row):
                try:
                    tile_id = int(raw_tile_id)
                except (TypeError, ValueError):
                    tile_id = 0
                positions_by_id[tile_id].append(
                    {
                        "grid": {"x": col_index, "y": row_index},
                        "pixel": {"x": col_index * tile_size, "y": row_index * tile_size},
                    }
                )

        tile_usages = []
        for tile_id in sorted(positions_by_id):
            tile_usages.append(
                {
                    "tile_id": tile_id,
                    "tile_name": tile_lookup.get(tile_id, f"tile_{tile_id}"),
                    "count": len(positions_by_id[tile_id]),
                    "positions": positions_by_id[tile_id],
                }
            )

        width = int(data.get("width", len(tiles[0]) if tiles else 0))
        height = int(data.get("height", len(tiles)))
        entries.append(
            {
                "id": path.stem,
                "name": data.get("name", path.stem),
                "path": _project_relative(path, project_root),
                "godot_path": _to_godot_path(path, project_root),
                "width": width,
                "height": height,
                "tile_size": tile_size,
                "used_tile_ids": sorted(positions_by_id.keys()),
                "tile_usages": tile_usages,
            }
        )

    return entries


def _build_object_layout_entries(project_root: Path) -> list[dict[str, Any]]:
    data_dir = project_root / "data"
    entries: list[dict[str, Any]] = []

    for path in sorted(data_dir.glob("*layout*.json")):
        if path.parent.name == "maps":
            continue

        try:
            data = _read_json(path)
        except Exception as exc:
            entries.append(
                {
                    "id": path.stem,
                    "path": _project_relative(path, project_root),
                    "parse_error": str(exc),
                }
            )
            continue

        objects = []
        for index, obj in enumerate(data.get("objects", [])):
            scene_key = obj.get("scene_key", "")
            objects.append(
                {
                    "index": index,
                    "name": obj.get("name", f"object_{index}"),
                    "scene_key": scene_key,
                    "scene_path": OBJECT_SCENE_REGISTRY.get(scene_key),
                    "kind": obj.get("kind", ""),
                    "position": obj.get("position", {}),
                    "properties": obj.get("properties", {}),
                }
            )

        entries.append(
            {
                "id": path.stem,
                "path": _project_relative(path, project_root),
                "godot_path": _to_godot_path(path, project_root),
                "grid_size": data.get("grid_size"),
                "object_count": len(objects),
                "objects": objects,
            }
        )

    return entries


def _build_bindings(project_root: Path) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]]]:
    path_links: dict[str, list[dict[str, Any]]] = defaultdict(list)
    bindings: dict[str, Any] = {
        "npcs": [],
        "dialogue_portraits": [],
        "crops": [],
        "items": [],
    }

    def register_link(godot_path: str | None, link: dict[str, Any]) -> None:
        if godot_path:
            path_links[godot_path].append(link)

    npcs_path = project_root / "data" / "npcs.json"
    if npcs_path.exists():
        npcs_data = _read_json(npcs_path)
        for npc in npcs_data.get("npcs", []):
            portrait_path = npc.get("portrait")
            sprite_path = npc.get("sprite")
            npc_entry = {
                "id": npc.get("id"),
                "name": npc.get("name"),
                "portrait": _build_path_ref(project_root, portrait_path),
                "sprite": _build_path_ref(project_root, sprite_path),
            }
            bindings["npcs"].append(npc_entry)
            register_link(portrait_path, {"binding_type": "npc_portrait", "id": npc.get("id"), "field": "portrait"})
            register_link(sprite_path, {"binding_type": "npc_sprite", "id": npc.get("id"), "field": "sprite"})

    dialogues_path = project_root / "data" / "dialogues.json"
    if dialogues_path.exists():
        dialogues_data = _read_json(dialogues_path)
        for npc_id, npc_data in dialogues_data.get("npcs", {}).items():
            portrait_path = npc_data.get("portrait")
            entry = {
                "id": npc_id,
                "name": npc_data.get("name"),
                "portrait": _build_path_ref(project_root, portrait_path),
            }
            bindings["dialogue_portraits"].append(entry)
            register_link(portrait_path, {"binding_type": "dialogue_portrait", "id": npc_id, "field": "portrait"})

    crops_path = project_root / "data" / "crops.json"
    if crops_path.exists():
        crops_data = _read_json(crops_path)
        for crop in crops_data.get("crops", []):
            stage_refs = []
            for stage_index, stage_path in enumerate(crop.get("stages_sprites", [])):
                stage_ref = _build_path_ref(project_root, stage_path)
                stage_refs.append({"stage": stage_index, "path": stage_ref})
                register_link(
                    stage_path,
                    {
                        "binding_type": "crop_stage_sprite",
                        "id": crop.get("id"),
                        "field": f"stages_sprites[{stage_index}]",
                    },
                )

            harvest_path = crop.get("harvest_sprite")
            bindings["crops"].append(
                {
                    "id": crop.get("id"),
                    "name": crop.get("name"),
                    "stage_sprites": stage_refs,
                    "harvest_sprite": _build_path_ref(project_root, harvest_path),
                }
            )
            register_link(harvest_path, {"binding_type": "crop_harvest_sprite", "id": crop.get("id"), "field": "harvest_sprite"})

    items_path = project_root / "data" / "items.json"
    if items_path.exists():
        items_data = _read_json(items_path)
        for item in items_data.get("items", []):
            icon_path = item.get("icon")
            if not icon_path:
                continue
            entry = {
                "id": item.get("id"),
                "name": item.get("name"),
                "icon": _build_path_ref(project_root, icon_path),
            }
            bindings["items"].append(entry)
            register_link(icon_path, {"binding_type": "item_icon", "id": item.get("id"), "field": "icon"})

    return bindings, path_links


def _build_asset_inventory(project_root: Path, path_links: dict[str, list[dict[str, Any]]]) -> tuple[list[dict[str, Any]], dict[str, int]]:
    assets_root = project_root / "assets"
    inventory: list[dict[str, Any]] = []
    category_counts: Counter[str] = Counter()

    if not assets_root.exists():
        return inventory, {}

    for path in sorted(assets_root.rglob("*")):
        if not path.is_file():
            continue
        # Optional private submodule (CraftPix); omit from public inventory.
        try:
            rel_to_assets = path.relative_to(assets_root)
        except ValueError:
            rel_to_assets = path
        if rel_to_assets.parts and rel_to_assets.parts[0] == "private":
            continue
        if path.suffix.lower() in SKIP_SUFFIXES:
            continue
        if path.name.startswith("."):
            continue

        rel_path = _project_relative(path, project_root)
        category = _infer_asset_category(path, project_root)
        entry = {
            "path": rel_path,
            "godot_path": _to_godot_path(path, project_root),
            "category": category,
            "size_bytes": path.stat().st_size,
        }
        media = _media_metadata(path)
        if media:
            entry["media"] = media
        linked_by = path_links.get(entry["godot_path"], [])
        if linked_by:
            entry["linked_by"] = linked_by

        inventory.append(entry)
        category_counts[category] += 1

    return inventory, dict(sorted(category_counts.items()))


def build_resource_sitemap(project_root: Path) -> dict[str, Any]:
    project_root = project_root.resolve()
    bindings, path_links = _build_bindings(project_root)
    tilesets = [_build_farm_tileset(project_root)]
    maps = _build_map_entries(project_root)
    object_layouts = _build_object_layout_entries(project_root)
    asset_inventory, category_counts = _build_asset_inventory(project_root, path_links)

    sitemap = {
        "schema_version": "1.0",
        "generated_at": _utc_now_iso(),
        "generator": {
            "name": "tools/generate_resource_sitemap.py",
            "description": "Builds a repo-wide resource sitemap for the web map editor and import/export tooling",
        },
        "project": {
            "name": project_root.name,
            "root": project_root.as_posix(),
            "godot_prefix": "res://",
        },
        "integration": {
            "sitemap_path": DEFAULT_SITEMAP_RELATIVE_PATH.as_posix(),
            "tile_map_layout_path": "data/maps/farm_layout.json",
            "scene_object_layout_path": "data/farm_layout.json",
            "tile_palette_source": "assets/tiles/farm_tiles.png",
            "intended_consumers": [
                "external farm editor",
                "resource import agent",
                "map import/export pipeline",
            ],
        },
        "placement_rules": PLACEMENT_RULES,
        "tilesets": tilesets,
        "maps": maps,
        "object_layouts": object_layouts,
        "bindings": bindings,
        "assets": {
            "inventory": asset_inventory,
            "counts_by_category": category_counts,
        },
    }
    sitemap["summary"] = {
        "tileset_count": len(tilesets),
        "map_count": len(maps),
        "object_layout_count": len(object_layouts),
        "npc_binding_count": len(bindings["npcs"]),
        "dialogue_portrait_count": len(bindings["dialogue_portraits"]),
        "crop_binding_count": len(bindings["crops"]),
        "item_binding_count": len(bindings["items"]),
        "asset_count": len(asset_inventory),
    }
    return sitemap


def generate_resource_sitemap(project_root: Path, output_path: Path | None = None) -> tuple[dict[str, Any], Path | None]:
    sitemap = build_resource_sitemap(project_root)
    if output_path is None:
        return sitemap, None

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(sitemap, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    return sitemap, output_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a resource sitemap for the Pastoral Tales map/resource editor.")
    parser.add_argument(
        "--project-root",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Project root directory. Defaults to the repo root inferred from this script.",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_SITEMAP_RELATIVE_PATH,
        type=Path,
        help="Output path for the sitemap JSON. Relative paths are resolved from project root.",
    )
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    output_path = args.output
    if not output_path.is_absolute():
        output_path = project_root / output_path

    sitemap, written_path = generate_resource_sitemap(project_root, output_path)
    result = {
        "success": True,
        "output_path": written_path.as_posix() if written_path else None,
        "summary": sitemap.get("summary", {}),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
