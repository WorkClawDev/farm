extends Node
class_name IndoorTilesetBuilder

## IndoorTilesetBuilder - 室内 TileSet 构建器
## indoors_tiles.png 分析结果（2026-03-25）：
## 木地板: atlas (1,0) = tile_id 1
## 石头地板: atlas (57,3) = tile_id 249
## 墙壁: atlas (18,0) = tile_id 18, (22,0) = tile_id 22 (蓝色壁纸)
## 门/桌子: atlas (44,1) = tile_id 108
## 壁炉: atlas (32,1) = tile_id 96
## 床: atlas (54,2) = tile_id 182

const TILESET_NAME := "indoors_tiles"
const ATLAS_PATH := "res://assets/tiles/indoors_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

enum TileCoord {
	WOOD_FLOOR = 0,
	WOOD_FLOOR_V2 = 1,
	STONE_FLOOR = 2,
	CARPET_RED = 3,
	RUG_OVAL = 4,
	WALLPAPER_CREAM = 5,
	WALLPAPER_BLUE = 6,
	WOODEN_DOOR = 7,
	DOOR_OPEN = 8,
	WINDOW_LIGHT = 9,
	STAIRS_UP = 10,
	FIREPLACE = 11,
	FIREPLACE_ACTIVE = 12,
	BED_SINGLE = 13,
	BED_DOUBLE = 14,
	TABLE = 15,
	CHAIR = 16,
	BOOKSHELF = 17,
	KITCHEN_COUNTER = 18,
	STOVE = 19,
	CHEST = 20,
	PLANT_POT = 21,
	LAMP = 22,
	CLOCK = 23
}

const TILE_PROPERTIES := {
	TileCoord.WOOD_FLOOR: {"tile_id": 0, "passable": true, "layer": 0, "name": "木地板"},
	TileCoord.WOOD_FLOOR_V2: {"tile_id": 0, "passable": true, "layer": 0, "name": "木地板"},
	TileCoord.STONE_FLOOR: {"tile_id": 0, "passable": true, "layer": 0, "name": "石地板"},
	TileCoord.CARPET_RED: {"tile_id": 0, "passable": true, "layer": 0, "name": "红色地毯"},
	TileCoord.RUG_OVAL: {"tile_id": 0, "passable": true, "layer": 0, "name": "椭圆形地毯"},
	TileCoord.WALLPAPER_CREAM: {"tile_id": 0, "passable": false, "layer": 1, "name": "奶油色壁纸"},
	TileCoord.WALLPAPER_BLUE: {"tile_id": 0, "passable": false, "layer": 1, "name": "蓝色壁纸"},
	TileCoord.WOODEN_DOOR: {"tile_id": 0, "passable": false, "layer": 2, "name": "木门"},
	TileCoord.DOOR_OPEN: {"tile_id": 0, "passable": true, "layer": 2, "name": "开着的门"},
	TileCoord.WINDOW_LIGHT: {"tile_id": 0, "passable": false, "layer": 1, "name": "窗户"},
	TileCoord.STAIRS_UP: {"tile_id": 0, "passable": true, "layer": 0, "name": "楼梯"},
	TileCoord.FIREPLACE: {"tile_id": 0, "passable": false, "layer": 2, "name": "壁炉"},
	TileCoord.FIREPLACE_ACTIVE: {"tile_id": 0, "passable": false, "layer": 2, "name": "燃烧的壁炉"},
	TileCoord.BED_SINGLE: {"tile_id": 0, "passable": false, "layer": 2, "name": "单人床"},
	TileCoord.BED_DOUBLE: {"tile_id": 0, "passable": false, "layer": 2, "name": "双人床"},
	TileCoord.TABLE: {"tile_id": 0, "passable": false, "layer": 2, "name": "桌子"},
	TileCoord.CHAIR: {"tile_id": 0, "passable": true, "layer": 2, "name": "椅子"},
	TileCoord.BOOKSHELF: {"tile_id": 0, "passable": false, "layer": 2, "name": "书架"},
	TileCoord.KITCHEN_COUNTER: {"tile_id": 0, "passable": false, "layer": 2, "name": "厨房台面"},
	TileCoord.STOVE: {"tile_id": 0, "passable": false, "layer": 2, "name": "炉子"},
	TileCoord.CHEST: {"tile_id": 0, "passable": false, "layer": 2, "name": "箱子"},
	TileCoord.PLANT_POT: {"tile_id": 0, "passable": false, "layer": 2, "name": "花盆"},
	TileCoord.LAMP: {"tile_id": 0, "passable": true, "layer": 2, "name": "灯"},
	TileCoord.CLOCK: {"tile_id": 0, "passable": false, "layer": 2, "name": "时钟"},
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
