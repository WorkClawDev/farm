extends Node
class_name FarmTilesetBuilder

## FarmTilesetBuilder - 农场 TileSet 构建器
## 将 farm_tiles.png 图集（1024x1024, 16x16 tiles, 64x64 grid）转换为可用的 TileSet

const TILESET_NAME := "farm_tiles"
const ATLAS_PATH := "res://assets/tiles/farm_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

enum TileCoord {
	GRASS_PLAIN = 0,
	GRASS_2 = 1,
	WATER_POND = 2,
	WATER_EDGE_TL = 3,
	WATER_EDGE_TR = 4,
	WATER_EDGE_BL = 5,
	WATER_EDGE_BR = 6,
	PATH_DIRT = 7,
	PATH_GRASS = 8,
	TILLED_SOIL = 9,
	GROWING_CROPS = 10,
	MATURE_CROPS = 11,
	FENCE_H = 12,
	FENCE_V = 13,
	FENCE_POST = 14,
	WOOD_PLANKS = 15,
	STONE_WALL = 16,
	WOOD_WALL = 17,
	GATE_OPEN = 18,
	GATE_CLOSED = 19,
	WELL = 20,
	SCARECROW = 21,
	FLOWER_PATCH = 22,
	RAISED_BED = 23,
	DENSE_CROPS = 24,
	HAYSTACK = 25,
	FERTILE_SOIL = 26
}

const TILE_PROPERTIES := {
	TileCoord.GRASS_PLAIN: {"tile_id": 0, "passable": true, "layer": 0, "name": "草地"},
	TileCoord.GRASS_2: {"tile_id": 1, "passable": true, "layer": 0, "name": "草地变体"},
	TileCoord.WATER_POND: {"tile_id": 1387, "passable": false, "layer": 1, "name": "池塘水"},
	TileCoord.WATER_EDGE_TL: {"tile_id": 1124, "passable": false, "layer": 1, "name": "水边上"},
	TileCoord.WATER_EDGE_TR: {"tile_id": 1178, "passable": false, "layer": 1, "name": "水边右"},
	TileCoord.WATER_EDGE_BL: {"tile_id": 1592, "passable": false, "layer": 1, "name": "水边左"},
	TileCoord.WATER_EDGE_BR: {"tile_id": 1741, "passable": false, "layer": 1, "name": "水边右下"},
	TileCoord.PATH_DIRT: {"tile_id": 658, "passable": true, "layer": 0, "name": "泥土路"},
	TileCoord.PATH_GRASS: {"tile_id": 3, "passable": true, "layer": 0, "name": "草地路"},
	TileCoord.TILLED_SOIL: {"tile_id": 4, "passable": true, "layer": 0, "name": "耕地"},
	TileCoord.GROWING_CROPS: {"tile_id": 5, "passable": true, "layer": 0, "name": "生长中"},
	TileCoord.MATURE_CROPS: {"tile_id": 6, "passable": true, "layer": 0, "name": "成熟作物"},
	TileCoord.FENCE_H: {"tile_id": 85, "passable": false, "layer": 1, "name": "篱笆"},
	TileCoord.FENCE_V: {"tile_id": 85, "passable": false, "layer": 1, "name": "篱笆柱"},
	TileCoord.FENCE_POST: {"tile_id": 3169, "passable": false, "layer": 2, "name": "栅栏柱"},
	TileCoord.WOOD_PLANKS: {"tile_id": 1090, "passable": true, "layer": 0, "name": "木板地"},
	TileCoord.STONE_WALL: {"tile_id": 960, "passable": false, "layer": 1, "name": "石墙"},
	TileCoord.WOOD_WALL: {"tile_id": 13, "passable": false, "layer": 1, "name": "木墙"},
	TileCoord.GATE_OPEN: {"tile_id": 10, "passable": true, "layer": 1, "name": "开门"},
	TileCoord.GATE_CLOSED: {"tile_id": 11, "passable": false, "layer": 1, "name": "关门"},
	TileCoord.WELL: {"tile_id": 14, "passable": false, "layer": 2, "name": "水井"},
	TileCoord.SCARECROW: {"tile_id": 15, "passable": false, "layer": 2, "name": "稻草人"},
	TileCoord.FLOWER_PATCH: {"tile_id": 16, "passable": true, "layer": 0, "name": "花丛"},
	TileCoord.RAISED_BED: {"tile_id": 17, "passable": true, "layer": 0, "name": "raised_bed"},
	TileCoord.DENSE_CROPS: {"tile_id": 18, "passable": true, "layer": 0, "name": "茂盛作物"},
	TileCoord.HAYSTACK: {"tile_id": 20, "passable": false, "layer": 2, "name": "草堆"},
	TileCoord.FERTILE_SOIL: {"tile_id": 26, "passable": true, "layer": 0, "name": "肥沃土壤"},
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
		var props = TILE_PROPERTIES.get(tile_id, {"tile_id": tile_id, "passable": true, "layer": 0})
		var actual_tile_id: int = props.get("tile_id", tile_id)
		var atlas_coords := get_coord(actual_tile_id)
		if not atlas_source.has_tile(atlas_coords):
			atlas_source.create_tile(atlas_coords)

	tile_set.add_source(atlas_source)
	return tile_set

static func get_tile_name(tile_id: int) -> String:
	for enum_key in TileCoord.keys():
		var props = TILE_PROPERTIES.get(enum_key, {})
		if props.get("tile_id", -1) == tile_id:
			return props.get("name", "未知")
	return "未知"
