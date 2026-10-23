extends Node
class_name BeachTilesetBuilder

## BeachTilesetBuilder - 海滩 TileSet 构建器
## Kenney Roguelike/RPG CC0 sheet: roguelikeSheet_transparent.png
## 16px cells, 1px separation. Pure sand is col 8 rows 0-1; pure sea is col 0 rows 0-1.
## Sand-edged pool 3x3 (corners / edges / center): cols 10-12, rows 7-9.
## beach_tiles.png stays in the project; it is no longer the sand or sea source.

const TILESET_NAME := "beach_tiles"
const ATLAS_PATH := "res://assets/tiles/kenney/roguelikeSheet_transparent.png"
const TILE_SIZE := Vector2i(16, 16)
const SEPARATION := Vector2i(1, 1)
const COLUMNS := 57
const ROWS := 31
const SAND_A := Vector2i(8, 0)
const SAND_B := Vector2i(8, 1)
const SEA_A := Vector2i(0, 0)
const SEA_B := Vector2i(0, 1)
const POOL_TL := Vector2i(10, 7)
const POOL_T := Vector2i(11, 7)
const POOL_TR := Vector2i(12, 7)
const POOL_L := Vector2i(10, 8)
const POOL_C := Vector2i(11, 8)
const POOL_R := Vector2i(12, 8)
const POOL_BL := Vector2i(10, 9)
const POOL_B := Vector2i(11, 9)
const POOL_BR := Vector2i(12, 9)

enum TileCoord {
	SAND_PLAIN = 0,
	SAND_WET = 1,
	BEACH_PATH = 2,
	PEBBLES = 3,
	SHALLOW_WATER = 4,
	DEEP_WATER = 5,
	WATER_SURFACE = 6,
	WATER_EDGE_SAND_L = 7,
	WATER_EDGE_SAND_R = 8,
	WATER_EDGE_SAND_T = 9,
	PIER_WOOD = 10,
	SEASHELL = 11,
	STARFISH = 12,
	DRIFTWOOD = 13,
	BEACH_GRASS = 14,
	ROCK_POOL = 15,
	CORAL = 16,
	SEAWEED = 17,
	SANDCASTLE = 18,
	WATER_EDGE_SAND_B = 19,
	WATER_EDGE_SAND_TL = 20,
	WATER_EDGE_SAND_TR = 21,
	WATER_EDGE_SAND_BL = 22,
	WATER_EDGE_SAND_BR = 23
}

const TILE_PROPERTIES := {
	TileCoord.SAND_PLAIN: {"tile_id": 8, "passable": true, "layer": 0, "name": "沙滩"},
	TileCoord.SAND_WET: {"tile_id": 65, "passable": true, "layer": 0, "name": "湿沙滩"},
	TileCoord.BEACH_PATH: {"tile_id": 8, "passable": true, "layer": 0, "name": "沙滩路"},
	TileCoord.PEBBLES: {"tile_id": 65, "passable": true, "layer": 0, "name": "鹅卵石"},
	TileCoord.SHALLOW_WATER: {"tile_id": 0, "passable": false, "layer": 1, "name": "浅水"},
	TileCoord.DEEP_WATER: {"tile_id": 57, "passable": false, "layer": 1, "name": "深水"},
	TileCoord.WATER_SURFACE: {"tile_id": 467, "passable": false, "layer": 1, "name": "水面"},
	TileCoord.WATER_EDGE_SAND_L: {"tile_id": 466, "passable": false, "layer": 1, "name": "水边左"},
	TileCoord.WATER_EDGE_SAND_R: {"tile_id": 468, "passable": false, "layer": 1, "name": "水边右"},
	TileCoord.WATER_EDGE_SAND_T: {"tile_id": 410, "passable": false, "layer": 1, "name": "水边上"},
	TileCoord.PIER_WOOD: {"tile_id": 10, "passable": true, "layer": 1, "name": "码头木板"},
	TileCoord.SEASHELL: {"tile_id": 11, "passable": true, "layer": 2, "name": "贝壳"},
	TileCoord.STARFISH: {"tile_id": 12, "passable": true, "layer": 2, "name": "海星"},
	TileCoord.DRIFTWOOD: {"tile_id": 13, "passable": false, "layer": 2, "name": "浮木"},
	TileCoord.BEACH_GRASS: {"tile_id": 14, "passable": false, "layer": 2, "name": "海滩草"},
	TileCoord.ROCK_POOL: {"tile_id": 15, "passable": false, "layer": 2, "name": "岩石池"},
	TileCoord.CORAL: {"tile_id": 16, "passable": true, "layer": 2, "name": "珊瑚"},
	TileCoord.SEAWEED: {"tile_id": 17, "passable": false, "layer": 2, "name": "海草"},
	TileCoord.SANDCASTLE: {"tile_id": 18, "passable": false, "layer": 2, "name": "沙堡"},
	TileCoord.WATER_EDGE_SAND_B: {"tile_id": 524, "passable": false, "layer": 1, "name": "水边下"},
	TileCoord.WATER_EDGE_SAND_TL: {"tile_id": 409, "passable": false, "layer": 1, "name": "水边左上"},
	TileCoord.WATER_EDGE_SAND_TR: {"tile_id": 411, "passable": false, "layer": 1, "name": "水边右上"},
	TileCoord.WATER_EDGE_SAND_BL: {"tile_id": 523, "passable": false, "layer": 1, "name": "水边左下"},
	TileCoord.WATER_EDGE_SAND_BR: {"tile_id": 525, "passable": false, "layer": 1, "name": "水边右下"},
}

static func get_coord(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % COLUMNS, tile_id / COLUMNS)

static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.resource_name = TILESET_NAME

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = load(ATLAS_PATH)
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.separation = SEPARATION

	for tile_id in TileCoord.values():
		var props = TILE_PROPERTIES.get(tile_id, {"passable": true, "layer": 0})
		var actual_tile_id: int = props.get("tile_id", tile_id)
		var atlas_coords := get_coord(actual_tile_id)
		if not atlas_source.has_tile(atlas_coords):
			atlas_source.create_tile(atlas_coords)

	tile_set.add_source(atlas_source)
	return tile_set

static func _pack_tile_data(tile_id: int) -> PackedInt32Array:
	var data := PackedInt32Array()
	data.append(tile_id & 0xFFFFF)
	return data

static func get_tile_name(tile_id: int) -> String:
	var props = TILE_PROPERTIES.get(tile_id, {"name": "未知"})
	return props.get("name", "未知")
