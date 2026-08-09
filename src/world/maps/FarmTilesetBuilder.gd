extends Node
class_name FarmTilesetBuilder

## Builds the farm's native 64px vector TileSet. The former 16px placeholder
## atlas contained random green blocks; scaling it by four made every cell seam
## visible and left paths almost indistinguishable from grass.

const TILESET_NAME := "farm_tiles"
const ATLAS_PATH := "res://assets/tiles/farm_ground_atlas.svg"
const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const TILE_SIZE := Vector2i(64, 64)
const COLUMNS := 26
const ROWS := 1
const ATLAS_TILE_COUNT := 26

const PATH_HORIZONTAL := 3
const PATH_VERTICAL := 4
const PATH_CROSS := 5
const PATH_NE := 6
const PATH_NW := 7
const PATH_SE := 8
const PATH_SW := 9
const WATER_CENTER := 10
const WATER_TOP := 11
const WATER_BOTTOM := 12
const WATER_LEFT := 13
const WATER_RIGHT := 14
const WATER_TOP_LEFT := 15
const WATER_TOP_RIGHT := 16
const WATER_BOTTOM_LEFT := 17
const WATER_BOTTOM_RIGHT := 18
const FENCE_HORIZONTAL := 19
const FENCE_VERTICAL := 20
const GATE := 21
const WOOD_DECK := 22
const FARM_SOIL := 23
const STONE_FLOOR := 24
const HAY_DECORATION := 25

const CONNECT_LEFT := 1
const CONNECT_RIGHT := 2
const CONNECT_UP := 4
const CONNECT_DOWN := 8

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
	FERTILE_SOIL = 26,
}

const TILE_PROPERTIES := {
	TileCoord.GRASS_PLAIN: {"tile_id": 0, "passable": true, "layer": 0, "name": "草地"},
	TileCoord.GRASS_2: {"tile_id": 1, "passable": true, "layer": 0, "name": "草地变体"},
	TileCoord.WATER_POND: {"tile_id": WATER_CENTER, "passable": false, "layer": 1, "name": "池塘水"},
	TileCoord.WATER_EDGE_TL: {"tile_id": WATER_TOP_LEFT, "passable": false, "layer": 1, "name": "水边左上"},
	TileCoord.WATER_EDGE_TR: {"tile_id": WATER_TOP_RIGHT, "passable": false, "layer": 1, "name": "水边右上"},
	TileCoord.WATER_EDGE_BL: {"tile_id": WATER_BOTTOM_LEFT, "passable": false, "layer": 1, "name": "水边左下"},
	TileCoord.WATER_EDGE_BR: {"tile_id": WATER_BOTTOM_RIGHT, "passable": false, "layer": 1, "name": "水边右下"},
	TileCoord.PATH_DIRT: {"tile_id": PATH_HORIZONTAL, "passable": true, "layer": 0, "name": "泥土路"},
	TileCoord.PATH_GRASS: {"tile_id": PATH_HORIZONTAL, "passable": true, "layer": 0, "name": "草地路"},
	TileCoord.TILLED_SOIL: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "耕地"},
	TileCoord.GROWING_CROPS: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "生长中"},
	TileCoord.MATURE_CROPS: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "成熟作物"},
	TileCoord.FENCE_H: {"tile_id": FENCE_HORIZONTAL, "passable": false, "layer": 1, "name": "横篱笆"},
	TileCoord.FENCE_V: {"tile_id": FENCE_VERTICAL, "passable": false, "layer": 1, "name": "竖篱笆"},
	TileCoord.FENCE_POST: {"tile_id": FENCE_HORIZONTAL, "passable": false, "layer": 2, "name": "栅栏柱"},
	TileCoord.WOOD_PLANKS: {"tile_id": WOOD_DECK, "passable": true, "layer": 0, "name": "木板地"},
	TileCoord.STONE_WALL: {"tile_id": STONE_FLOOR, "passable": false, "layer": 1, "name": "石墙"},
	TileCoord.WOOD_WALL: {"tile_id": WOOD_DECK, "passable": false, "layer": 1, "name": "木墙"},
	TileCoord.GATE_OPEN: {"tile_id": GATE, "passable": true, "layer": 1, "name": "开门"},
	TileCoord.GATE_CLOSED: {"tile_id": GATE, "passable": false, "layer": 1, "name": "关门"},
	TileCoord.WELL: {"tile_id": STONE_FLOOR, "passable": false, "layer": 2, "name": "水井"},
	TileCoord.SCARECROW: {"tile_id": HAY_DECORATION, "passable": false, "layer": 2, "name": "稻草人"},
	TileCoord.FLOWER_PATCH: {"tile_id": 2, "passable": true, "layer": 0, "name": "花丛"},
	TileCoord.RAISED_BED: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "种植床"},
	TileCoord.DENSE_CROPS: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "茂盛作物"},
	TileCoord.HAYSTACK: {"tile_id": HAY_DECORATION, "passable": false, "layer": 2, "name": "草堆"},
	TileCoord.FERTILE_SOIL: {"tile_id": FARM_SOIL, "passable": true, "layer": 0, "name": "肥沃土壤"},
}


static func get_coord(tile_type_or_id: int) -> Vector2i:
	var properties: Dictionary = TILE_PROPERTIES.get(tile_type_or_id, {})
	var atlas_id := int(properties.get("tile_id", tile_type_or_id))
	return Vector2i(atlas_id % COLUMNS, atlas_id / COLUMNS)


static func build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.resource_name = TILESET_NAME
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = TextureLoader.load_texture(ATLAS_PATH)
	if atlas_source.texture == null:
		push_error("[FarmTilesetBuilder] Could not load vector atlas: " + ATLAS_PATH)
		return tile_set
	atlas_source.texture_region_size = TILE_SIZE
	for atlas_id in range(ATLAS_TILE_COUNT):
		atlas_source.create_tile(Vector2i(atlas_id, 0))
	tile_set.add_source(atlas_source)
	for atlas_id in range(ATLAS_TILE_COUNT):
		_apply_collision(atlas_source, atlas_id)
	return tile_set


static func get_path_coord(connection_mask: int) -> Vector2i:
	var horizontal := (connection_mask & (CONNECT_LEFT | CONNECT_RIGHT)) != 0
	var vertical := (connection_mask & (CONNECT_UP | CONNECT_DOWN)) != 0
	if connection_mask == (CONNECT_UP | CONNECT_RIGHT):
		return Vector2i(PATH_NE, 0)
	if connection_mask == (CONNECT_UP | CONNECT_LEFT):
		return Vector2i(PATH_NW, 0)
	if connection_mask == (CONNECT_DOWN | CONNECT_RIGHT):
		return Vector2i(PATH_SE, 0)
	if connection_mask == (CONNECT_DOWN | CONNECT_LEFT):
		return Vector2i(PATH_SW, 0)
	if horizontal and vertical:
		return Vector2i(PATH_CROSS, 0)
	if vertical:
		return Vector2i(PATH_VERTICAL, 0)
	return Vector2i(PATH_HORIZONTAL, 0)


static func get_water_coord(connection_mask: int) -> Vector2i:
	var has_left := (connection_mask & CONNECT_LEFT) != 0
	var has_right := (connection_mask & CONNECT_RIGHT) != 0
	var has_up := (connection_mask & CONNECT_UP) != 0
	var has_down := (connection_mask & CONNECT_DOWN) != 0
	if not has_up and not has_left:
		return Vector2i(WATER_TOP_LEFT, 0)
	if not has_up and not has_right:
		return Vector2i(WATER_TOP_RIGHT, 0)
	if not has_down and not has_left:
		return Vector2i(WATER_BOTTOM_LEFT, 0)
	if not has_down and not has_right:
		return Vector2i(WATER_BOTTOM_RIGHT, 0)
	if not has_up:
		return Vector2i(WATER_TOP, 0)
	if not has_down:
		return Vector2i(WATER_BOTTOM, 0)
	if not has_left:
		return Vector2i(WATER_LEFT, 0)
	if not has_right:
		return Vector2i(WATER_RIGHT, 0)
	return Vector2i(WATER_CENTER, 0)


static func get_fence_coord(connection_mask: int) -> Vector2i:
	if (connection_mask & (CONNECT_LEFT | CONNECT_RIGHT)) != 0:
		return Vector2i(FENCE_HORIZONTAL, 0)
	return Vector2i(FENCE_VERTICAL, 0)


static func _apply_collision(atlas_source: TileSetAtlasSource, atlas_id: int) -> void:
	var tile_data := atlas_source.get_tile_data(Vector2i(atlas_id, 0), 0)
	if tile_data == null:
		return
	var polygon := PackedVector2Array()
	if atlas_id >= WATER_CENTER and atlas_id <= WATER_BOTTOM_RIGHT:
		polygon = PackedVector2Array([
			Vector2(-32, -32), Vector2(32, -32),
			Vector2(32, 32), Vector2(-32, 32),
		])
	elif atlas_id == FENCE_HORIZONTAL:
		polygon = PackedVector2Array([
			Vector2(-32, -12), Vector2(32, -12),
			Vector2(32, 12), Vector2(-32, 12),
		])
	elif atlas_id == FENCE_VERTICAL:
		polygon = PackedVector2Array([
			Vector2(-12, -32), Vector2(12, -32),
			Vector2(12, 32), Vector2(-12, 32),
		])
	if polygon.is_empty():
		return
	tile_data.set_collision_polygons_count(0, 1)
	tile_data.set_collision_polygon_points(0, 0, polygon)


static func get_tile_name(tile_id: int) -> String:
	for enum_key in TileCoord.keys():
		var props: Dictionary = TILE_PROPERTIES.get(enum_key, {})
		if int(props.get("tile_id", -1)) == tile_id:
			return str(props.get("name", "未知"))
	return "未知"
