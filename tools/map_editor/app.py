"""
Pastoral Tales Map Editor - Flask Server
Serves the web-based tile map editor and handles save/load API.
"""
import os
import json
from flask import Flask, render_template, request, jsonify, send_from_directory
from PIL import Image
import io
import base64

app = Flask(__name__)

# Paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)  # pastoral-tales/
DATA_DIR = os.path.join(PROJECT_DIR, "data", "maps")
TILESET_PATH = os.path.join(PROJECT_DIR, "assets", "tiles", "farm_tiles.png")
DEFAULT_MAP_PATH = os.path.join(DATA_DIR, "farm_layout.json")

# Ensure data/maps exists
os.makedirs(DATA_DIR, exist_ok=True)

# Tile definitions (matches FarmTilesetBuilder legacy tile IDs)
TILE_DEFS = [
    {"id": 0,  "col": 0, "row": 0, "name": "grass",        "walkable": True},
    {"id": 1,  "col": 1, "row": 0, "name": "dark_grass",   "walkable": True},
    {"id": 2,  "col": 2, "row": 0, "name": "medium_grass", "walkable": True},
    {"id": 3,  "col": 3, "row": 0, "name": "light_grass",  "walkable": True},
    {"id": 4,  "col": 4, "row": 0, "name": "dry_grass",    "walkable": True},
    {"id": 5,  "col": 5, "row": 0, "name": "flower_grass", "walkable": True},
    {"id": 6,  "col": 6, "row": 0, "name": "path",         "walkable": True},
    {"id": 7,  "col": 7, "row": 0, "name": "dirt",         "walkable": True},
    {"id": 8,  "col": 0, "row": 1, "name": "water",        "walkable": False},
    {"id": 9,  "col": 1, "row": 1, "name": "shallow_water","walkable": False},
    {"id": 10, "col": 2, "row": 1, "name": "sand",         "walkable": True},
    {"id": 11, "col": 3, "row": 1, "name": "fence",        "walkable": False},
    {"id": 12, "col": 4, "row": 1, "name": "gate",         "walkable": True},
    {"id": 13, "col": 5, "row": 1, "name": "wood_floor",   "walkable": True},
    {"id": 14, "col": 6, "row": 1, "name": "stone_floor",  "walkable": True},
    {"id": 15, "col": 7, "row": 1, "name": "farmland",     "walkable": True},
]

TILE_SIZE = 16
ATLAS_COLS = 64  # farm_tiles.png is 64x64 grid


def get_default_layout() -> list:
    """Generate a default 30x20 grass layout."""
    return [[0] * 30 for _ in range(20)]


def load_map() -> dict:
    """Load map from JSON file, or return default."""
    if os.path.exists(DEFAULT_MAP_PATH):
        try:
            with open(DEFAULT_MAP_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "name": "farm_layout",
        "width": 30,
        "height": 20,
        "tiles": get_default_layout(),
        "tile_size": TILE_SIZE,
    }


def save_map(data: dict) -> bool:
    """Save map to JSON file."""
    try:
        with open(DEFAULT_MAP_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Save error: {e}")
        return False


@app.route("/")
def index():
    return render_template("editor.html")


@app.route("/api/tiles")
def api_tiles():
    """Return tile definitions and base64 tile thumbnails."""
    if not os.path.exists(TILESET_PATH):
        return jsonify({"error": "Tileset not found", "tiles": TILE_DEFS, "thumbnails": {}})

    try:
        atlas = Image.open(TILESET_PATH).convert("RGBA")
        thumbs = {}
        for tile in TILE_DEFS:
            x = tile["col"] * TILE_SIZE
            y = tile["row"] * TILE_SIZE
            thumb = atlas.crop((x, y, x + TILE_SIZE, y + TILE_SIZE))
            buf = io.BytesIO()
            thumb.save(buf, format="PNG")
            buf.seek(0)
            thumbs[str(tile["id"])] = base64.b64encode(buf.read()).decode("utf-8")

        return jsonify({"tiles": TILE_DEFS, "thumbnails": thumbs})
    except Exception as e:
        return jsonify({"error": str(e), "tiles": TILE_DEFS, "thumbnails": {}})


@app.route("/api/map", methods=["GET"])
def api_get_map():
    """Load the current map from JSON."""
    return jsonify(load_map())


@app.route("/api/map", methods=["POST"])
def api_save_map():
    """Save the map to JSON."""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    name = data.get("name", "farm_layout")
    tiles = data.get("tiles")
    if tiles is None:
        return jsonify({"error": "No tiles provided"}), 400

    map_data = {
        "name": name,
        "width": len(tiles[0]) if tiles else 30,
        "height": len(tiles),
        "tiles": tiles,
        "tile_size": TILE_SIZE,
        "tile_properties": {
            str(t["id"]): {"name": t["name"], "walkable": t["walkable"]}
            for t in TILE_DEFS
        }
    }

    if save_map(map_data):
        return jsonify({"success": True, "path": DEFAULT_MAP_PATH})
    else:
        return jsonify({"error": "Failed to save map"}), 500


@app.route("/api/export/gdscript")
def api_export_gdscript():
    """Export the current map as a GDScript 2D array."""
    data = load_map()
    tiles = data.get("tiles", get_default_layout())

    lines = ["# GDScript array exported from Map Editor"]
    lines.append("# 2D array: " + str(len(tiles)) + " rows x " + str(len(tiles[0]) if tiles else 0) + " cols")
    lines.append("const EXPORTED_LAYOUT := [")
    for row in tiles:
        lines.append("\t" + str(row) + ",")
    lines.append("]")

    code = "\n".join(lines)
    return jsonify({"code": code})


if __name__ == "__main__":
    print("=" * 50)
    print("Pastoral Tales Map Editor")
    print("=" * 50)
    print(f"Tileset: {TILESET_PATH}")
    print(f"Map file: {DEFAULT_MAP_PATH}")
    print("Open http://localhost:5000 in your browser")
    print("=" * 50)
    app.run(host="0.0.0.0", port=5000, debug=True)
