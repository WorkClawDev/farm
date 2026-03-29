extends Node
class_name BeachTilesetBuilder

## BeachTilesetBuilder - 海滩 TileSet 构建器
## beach_tiles.png 分析结果（2026-03-25）：
## 水体主要区域: rows 2-63, cols 32-63 (tile_id ~185-4095)
## 沙滩/草地区域: rows 3-14, cols 0-32
## 沙质Tiles (row 0): tile_ids 0-20
## 水边缘Tiles (row 3): tile_ids 246-255

const TILESET_NAME := "beach_tiles"
const ATLAS_PATH := "res://assets/tiles/beach_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

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
	SANDCASTLE = 18
}

const TILE_PROPERTIES := {
	TileCoord.SAND_PLAIN: {"tile_id": 0, "passable": true, "layer": 0, "name": "沙滩"},
	TileCoord.SAND_WET: {"tile_id": 0, "passable": true, "layer": 0, "name": "湿沙滩"},
	TileCoord.BEACH_PATH: {"tile_id": 0, "passable": true, "layer": 0, "name": "沙滩路"},
	TileCoord.PEBBLES: {"tile_id": 0, "passable": true, "layer": 0, "name": "鹅卵石"},
	TileCoord.SHALLOW_WATER: {"tile_id": 0, "passable": false, "layer": 1, "name": "浅水"},
	TileCoord.DEEP_WATER: {"tile_id": 0, "passable": false, "layer": 1, "name": "深水"},
	TileCoord.WATER_SURFACE: {"tile_id": 0, "passable": false, "layer": 1, "name": "水面"},
	TileCoord.WATER_EDGE_SAND_L: {"tile_id": 0, "passable": false, "layer": 1, "name": "水边左"},
	TileCoord.WATER_EDGE_SAND_R: {"tile_id": 0, "passable": false, "layer": 1, "name": "水边右"},
	TileCoord.WATER_EDGE_SAND_T: {"tile_id": 0, "passable": false, "layer": 1, "name": "水边上"},
	TileCoord.PIER_WOOD: {"tile_id": 0, "passable": true, "layer": 1, "name": "码头木板"},
	TileCoord.SEASHELL: {"tile_id": 0, "passable": true, "layer": 2, "name": "贝壳"},
	TileCoord.STARFISH: {"tile_id": 0, "passable": true, "layer": 2, "name": "海星"},
	TileCoord.DRIFTWOOD: {"tile_id": 0, "passable": false, "layer": 2, "name": "浮木"},
	TileCoord.BEACH_GRASS: {"tile_id": 0, "passable": false, "layer": 2, "name": "海滩草"},
	TileCoord.ROCK_POOL: {"tile_id": 0, "passable": false, "layer": 2, "name": "岩石池"},
	TileCoord.CORAL: {"tile_id": 0, "passable": true, "layer": 2, "name": "珊瑚"},
	TileCoord.SEAWEED: {"tile_id": 0, "passable": false, "layer": 2, "name": "海草"},
	TileCoord.SANDCASTLE: {"tile_id": 0, "passable": false, "layer": 2, "name": "沙堡"},
}

static func get_coord(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % COLUMNS, tile_id / COLUMNS)

static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.resource_name = TILESET_NAME

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = load(ATLAS_PATH)
	atlas_source.texture_region_size = TILE_SIZE

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
