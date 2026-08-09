extends Node
class_name MineTilesetBuilder

## MineTilesetBuilder - 矿洞 TileSet 构建器
## mine_tiles.png 分析结果（2026-03-25）：
## 主要矿石分布: cols 17-63 区域
## 石砖地面: atlas (1,0) = tile_id 1
## 煤矿石: atlas (16,0) = tile_id 16
## 铁矿: atlas (19,1) = tile_id 83
## 铜矿: atlas (24,2) = tile_id 152
## 金矿: atlas (58,1) = tile_id 122
## 宝石: atlas (51,17) = tile_id 1139 (rows 17-22, cols 49-63)
## 发光矿石: atlas (56,5) = tile_id 376 (rows 5-8, cols 55-57)

const TILESET_NAME := "mine_tiles"
const ATLAS_PATH := "res://assets/tiles/mine_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

enum TileCoord {
	STONE_FLOOR = 0,
	DIRT_FLOOR = 1,
	CRACKED_FLOOR = 2,
	RUBBLE = 3,
	MINECART_TRACK = 4,
	STONE_WALL = 5,
	CRACKED_WALL = 6,
	DARK_STONE = 7,
	COPPER_ORE = 8,
	IRON_ORE = 9,
	GOLD_ORE = 10,
	COAL_ORE = 11,
	GEM_ORE = 12,
	GLOWING_ORE = 13,
	WOOD_SUPPORT = 14,
	LADDER_UP = 15,
	LADDER_DOWN = 16,
	TORCH_BRACKET = 17
}

const TILE_PROPERTIES := {
		TileCoord.STONE_FLOOR: {"tile_id": 1, "passable": true, "layer": 0, "name": "石砖地面"},
		TileCoord.DIRT_FLOOR: {"tile_id": 2, "passable": true, "layer": 0, "name": "泥土地面"},
		TileCoord.CRACKED_FLOOR: {"tile_id": 3, "passable": true, "layer": 0, "name": "裂缝地面"},
		TileCoord.RUBBLE: {"tile_id": 4, "passable": true, "layer": 0, "name": "碎石"},
		TileCoord.MINECART_TRACK: {"tile_id": 5, "passable": true, "layer": 0, "name": "矿车轨道"},
		TileCoord.STONE_WALL: {"tile_id": 6, "passable": false, "layer": 1, "name": "石墙"},
		TileCoord.CRACKED_WALL: {"tile_id": 7, "passable": false, "layer": 1, "name": "裂缝墙壁"},
		TileCoord.DARK_STONE: {"tile_id": 8, "passable": false, "layer": 1, "name": "深色石头"},
		TileCoord.COPPER_ORE: {"tile_id": 152, "passable": false, "layer": 2, "name": "铜矿"},
		TileCoord.IRON_ORE: {"tile_id": 83, "passable": false, "layer": 2, "name": "铁矿"},
		TileCoord.GOLD_ORE: {"tile_id": 122, "passable": false, "layer": 2, "name": "金矿"},
		TileCoord.COAL_ORE: {"tile_id": 16, "passable": false, "layer": 2, "name": "煤矿"},
		TileCoord.GEM_ORE: {"tile_id": 1139, "passable": false, "layer": 2, "name": "宝石矿"},
		TileCoord.GLOWING_ORE: {"tile_id": 376, "passable": false, "layer": 2, "name": "发光矿石"},
		TileCoord.WOOD_SUPPORT: {"tile_id": 14, "passable": false, "layer": 1, "name": "木支撑"},
		TileCoord.LADDER_UP: {"tile_id": 15, "passable": true, "layer": 1, "name": "向上梯子"},
		TileCoord.LADDER_DOWN: {"tile_id": 16, "passable": true, "layer": 1, "name": "向下梯子"},
		TileCoord.TORCH_BRACKET: {"tile_id": 17, "passable": true, "layer": 2, "name": "火把"},
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
