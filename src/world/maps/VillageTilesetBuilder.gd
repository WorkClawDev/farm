extends Node
class_name VillageTilesetBuilder

const TILESET_NAME := "village_tiles"
const ATLAS_PATH := "res://assets/tiles/village_tiles.png"
const TILE_SIZE := Vector2i(16, 16)
const COLUMNS := 64
const ROWS := 64

enum TileCoord {
	STONE_WALL = 0,
	PATH_GRASS_BORDER = 1,
	GRASS_PLAIN = 2,
	TILE_ROOF_DARK = 3,
	BRICK_WALL = 4,
	WOOD_WALL = 10,
	PATH_PLAIN = 11,
	STONE_WALL_CLEAN = 12,
	ROOF_GRAY = 13,
	ROOF_RED = 14,
	WOOD_WALL_V2 = 20,
	TREE_WALL = 21,
	STONE_DOOR = 22,
	WINDOW_A = 23,
	WINDOW_B = 24,
	WELL = 30,
	VILLAGE_SIGN = 31,
	POTTED_FLOWER = 32,
	BARREL = 33,
	CRATE = 34,
	BARREL_TOP = 40,
	BARREL_V2 = 41,
	FENCE = 42,
	CHEST_LOCKED = 43,
	BENCH = 44,
}

const TILE_PROPERTIES := {
	TileCoord.GRASS_PLAIN: {"passable": true, "layer": 0, "name": "Grass"},
	TileCoord.PATH_PLAIN: {"passable": true, "layer": 0, "name": "Path"},
	TileCoord.PATH_GRASS_BORDER: {"passable": true, "layer": 0, "name": "Path Border"},
	TileCoord.STONE_WALL: {"passable": false, "layer": 1, "name": "Stone Wall"},
	TileCoord.WOOD_WALL: {"passable": false, "layer": 1, "name": "Wood Wall"},
	TileCoord.WOOD_WALL_V2: {"passable": false, "layer": 1, "name": "Wood Wall 2"},
	TileCoord.BRICK_WALL: {"passable": false, "layer": 1, "name": "Brick Wall"},
	TileCoord.STONE_WALL_CLEAN: {"passable": false, "layer": 1, "name": "Clean Stone Wall"},
	TileCoord.TILE_ROOF_DARK: {"passable": false, "layer": 1, "name": "Dark Roof"},
	TileCoord.ROOF_GRAY: {"passable": false, "layer": 1, "name": "Gray Roof"},
	TileCoord.ROOF_RED: {"passable": false, "layer": 1, "name": "Red Roof"},
	TileCoord.TREE_WALL: {"passable": false, "layer": 2, "name": "Tree"},
	TileCoord.WELL: {"passable": false, "layer": 2, "name": "Well"},
	TileCoord.VILLAGE_SIGN: {"passable": false, "layer": 2, "name": "Village Sign"},
	TileCoord.POTTED_FLOWER: {"passable": true, "layer": 2, "name": "Flower"},
	TileCoord.BARREL: {"passable": false, "layer": 2, "name": "Barrel"},
	TileCoord.BARREL_TOP: {"passable": false, "layer": 2, "name": "Barrel Top"},
	TileCoord.BARREL_V2: {"passable": false, "layer": 2, "name": "Barrel 2"},
	TileCoord.CRATE: {"passable": false, "layer": 2, "name": "Crate"},
	TileCoord.CHEST_LOCKED: {"passable": false, "layer": 2, "name": "Chest"},
	TileCoord.BENCH: {"passable": false, "layer": 2, "name": "Bench"},
	TileCoord.STONE_DOOR: {"passable": false, "layer": 1, "name": "Door"},
	TileCoord.WINDOW_A: {"passable": false, "layer": 1, "name": "Window A"},
	TileCoord.WINDOW_B: {"passable": false, "layer": 1, "name": "Window B"},
	TileCoord.FENCE: {"passable": false, "layer": 2, "name": "Fence"},
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
		var coords := get_coord(tile_id)
		if not atlas_source.has_tile(coords):
			atlas_source.create_tile(coords)

	tile_set.add_source(atlas_source)
	return tile_set

static func get_tile_name(tile_id: int) -> String:
	var props = TILE_PROPERTIES.get(tile_id, {"name": "Unknown"})
	return props.get("name", "Unknown")

static func print_tileset_info() -> void:
	print("========== Village TileSet Info ==========")
	print("Atlas: ", ATLAS_PATH)
	print("Tile size: ", TILE_SIZE)
	print("Grid: ", COLUMNS, "x", ROWS)
	for tile_id in TileCoord.values():
		var coords := get_coord(tile_id)
		var name := get_tile_name(tile_id)
		print("  [%2d] (%d,%d) %s" % [tile_id, coords.x, coords.y, name])
	print("=========================================")
