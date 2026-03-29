extends Node
class_name ForestTilesetBuilder

## ForestTilesetBuilder - 森林 TileSet 构建器
## forest_tiles.png 分析结果（2026-03-25）：
## 森林地面Tiles (dark green): atlas (0,0) = tile_id 0
## 草地Tiles (green): atlas (1,0) = tile_id 1
## 幽暗森林Tiles: atlas (28,0) = tile_id 28
## 树木Tiles: atlas (27,0) = tile_id 27

const TILESET_NAME := "forest_tiles"
const ATLAS_PATH := "res://assets/tiles/forest_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

enum TileCoord {
	FOREST_FLOOR = 0,
	DIRT_PATH = 1,
	FALLEN_LEAVES = 2,
	GRASS_NATURAL = 3,
	GRASS_SHORT = 4,
	FERN = 5,
	ROCK_SMALL = 6,
	OAK_TREE = 7,
	PINE_TREE = 8,
	TREE_STUMP = 9,
	MUSHROOM = 10,
	FALLEN_LOG = 11,
	ROCK_BOULDER = 12,
	BERRY_BUSH = 13,
	WILD_FLOWER = 14,
	FOREST_ENTRANCE = 15,
	HOLLOW_LOG = 16,
	TREE_ROOTS = 17,
	MOSS_STONE = 18,
	DARK_FOREST = 19,
	ACORN = 20,
	PINE_NEEDLES = 21
}

const TILE_PROPERTIES := {
	TileCoord.FOREST_FLOOR: {"tile_id": 0, "passable": true, "layer": 0, "name": "森林地面"},
	TileCoord.DIRT_PATH: {"tile_id": 0, "passable": true, "layer": 0, "name": "泥土路"},
	TileCoord.FALLEN_LEAVES: {"tile_id": 0, "passable": true, "layer": 0, "name": "落叶"},
	TileCoord.GRASS_NATURAL: {"tile_id": 0, "passable": true, "layer": 0, "name": "野草"},
	TileCoord.GRASS_SHORT: {"tile_id": 0, "passable": true, "layer": 0, "name": "短草"},
	TileCoord.FERN: {"tile_id": 0, "passable": true, "layer": 0, "name": "蕨类"},
	TileCoord.ROCK_SMALL: {"tile_id": 0, "passable": false, "layer": 1, "name": "小石"},
	TileCoord.OAK_TREE: {"tile_id": 0, "passable": false, "layer": 2, "name": "橡树"},
	TileCoord.PINE_TREE: {"tile_id": 0, "passable": false, "layer": 2, "name": "松树"},
	TileCoord.TREE_STUMP: {"tile_id": 0, "passable": false, "layer": 2, "name": "树桩"},
	TileCoord.MUSHROOM: {"tile_id": 0, "passable": true, "layer": 2, "name": "蘑菇"},
	TileCoord.FALLEN_LOG: {"tile_id": 0, "passable": false, "layer": 2, "name": "倒木"},
	TileCoord.ROCK_BOULDER: {"tile_id": 0, "passable": false, "layer": 2, "name": "巨石"},
	TileCoord.BERRY_BUSH: {"tile_id": 0, "passable": false, "layer": 2, "name": "浆果丛"},
	TileCoord.WILD_FLOWER: {"tile_id": 0, "passable": true, "layer": 2, "name": "野花"},
	TileCoord.FOREST_ENTRANCE: {"tile_id": 0, "passable": true, "layer": 0, "name": "森林入口"},
	TileCoord.HOLLOW_LOG: {"tile_id": 0, "passable": false, "layer": 2, "name": "空洞木头"},
	TileCoord.TREE_ROOTS: {"tile_id": 0, "passable": false, "layer": 2, "name": "树根"},
	TileCoord.MOSS_STONE: {"tile_id": 0, "passable": false, "layer": 1, "name": "苔藓石"},
	TileCoord.DARK_FOREST: {"tile_id": 0, "passable": true, "layer": 0, "name": "幽暗森林"},
	TileCoord.ACORN: {"tile_id": 0, "passable": true, "layer": 2, "name": "橡子"},
	TileCoord.PINE_NEEDLES: {"tile_id": 0, "passable": true, "layer": 0, "name": "松针地面"},
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
