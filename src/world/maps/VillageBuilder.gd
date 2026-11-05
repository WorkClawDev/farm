extends Node2D
class_name VillageBuilder

const VillageConstants = preload("res://src/core/constants/VillageConstants.gd")

const TID_GRASS: int = 2
const TID_PATH: int = 11
const TID_PATH_GRASS: int = 1

const TID_STONE_WALL: int = 0
const TID_WOOD_WALL: int = 10
const TID_BRICK_WALL: int = 4
const TID_DOOR: int = 22
const TID_ROOF_DARK: int = 3
const TID_ROOF_RED: int = 14
const TID_ROOF_GRAY: int = 13

const TID_TREE: int = 21
const TID_WELL: int = 30
const TID_SIGN: int = 31
const TID_BENCH: int = 44
const TID_FLOWER: int = 32
const TID_FENCE: int = 42

const COLOR_EXIT: Color = Color(0.85, 0.25, 0.20, 0.7)

const TRANSITIONS := {
	"to_farm": {
		"position": Vector2(60, 300),
		"target": "res://src/world/maps/Farm.tscn",
		"spawn": "from_village"
	},
	"to_player_house": {
		"position": Vector2(400, 580),
		"target": "res://src/world/maps/PlayerHouse.tscn",
		"spawn": "house_entrance"
	},
	"to_beach": {
		"position": Vector2(1100, 700),
		"target": "res://src/world/maps/Beach.tscn",
		"spawn": "from_village"
	},
	"to_forest": {
		"position": Vector2(640, 60),
		"target": "res://src/world/maps/Forest.tscn",
		"spawn": "from_village"
	},
	"to_mine": {
		"position": Vector2(180, 820),
		"target": "res://src/world/maps/Mine.tscn",
		"spawn": "from_village"
	}
}

var tilemap: TileMap

func _ready() -> void:
	print("========== VillageBuilder start ==========")

	var village := get_parent()
	if village == null or not village.has_method("add_child"):
		push_error("[VillageBuilder] Must be added as a child of Village")
		return

	tilemap = village.get_node_or_null("TileMap")
	if tilemap == null:
		push_error("[VillageBuilder] TileMap node not found")
		return

	_setup_tileset()
	_fill_ground_layer()
	_fill_roads()
	_fill_buildings()
	_fill_trees_boundaries()
	_add_decoration_tiles()
	_add_transition_zones(village)
	_clean_placeholder_layer()

	print("========== VillageBuilder complete ==========")

func _setup_tileset() -> void:
	var tile_set = VillageTilesetBuilder.build_tileset()
	tilemap.tile_set = tile_set
	print("[VillageBuilder] TileSet ready")

func _fill_ground_layer() -> void:
	for y in range(VillageConstants.MAP_TILES_Y):
		for x in range(VillageConstants.MAP_TILES_X):
			tilemap.set_cell(0, Vector2i(x, y), 0, VillageTilesetBuilder.get_coord(TID_GRASS))

	for x in range(VillageConstants.MAP_TILES_X):
		_set_tile_safe(0, Vector2i(x, 4), TID_PATH)
		_set_tile_safe(0, Vector2i(x, 3), TID_PATH_GRASS)
		_set_tile_safe(0, Vector2i(x, 5), TID_PATH_GRASS)

	for y in range(VillageConstants.MAP_TILES_Y):
		_set_tile_safe(0, Vector2i(6, y), TID_PATH)
		_set_tile_safe(0, Vector2i(5, y), TID_PATH_GRASS)
		_set_tile_safe(0, Vector2i(7, y), TID_PATH_GRASS)

	for y in range(2):
		_set_tile_safe(0, Vector2i(10, y), TID_PATH)

	for y in range(7, 10):
		_set_tile_safe(0, Vector2i(6, y), TID_PATH)

	for x in range(8, 18):
		_set_tile_safe(0, Vector2i(x, 7), TID_PATH)

	for y in range(9, 13):
		_set_tile_safe(0, Vector2i(3, y), TID_PATH)

	print("[VillageBuilder] Ground layer filled")

func _fill_roads() -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			_set_tile_safe(0, Vector2i(6 + dx, 4 + dy), TID_PATH)

func _fill_buildings() -> void:
	for dx in range(-2, 3):
		for dy in range(-1, 2):
			_set_tile_safe(0, Vector2i(8 + dx, 2 + dy), TID_PATH)
	_set_tile_safe(2, Vector2i(8, 2), TID_SIGN)

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			_set_tile_safe(0, Vector2i(11 + dx, 3 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(11, 2), 0, VillageTilesetBuilder.get_coord(TID_ROOF_RED))
	tilemap.set_cell(1, Vector2i(10, 3), 0, VillageTilesetBuilder.get_coord(TID_BRICK_WALL))
	tilemap.set_cell(1, Vector2i(12, 3), 0, VillageTilesetBuilder.get_coord(TID_BRICK_WALL))
	tilemap.set_cell(1, Vector2i(11, 4), 0, VillageTilesetBuilder.get_coord(TID_DOOR))

	for dx in range(-1, 2):
		for dy in range(-1, 1):
			_set_tile_safe(0, Vector2i(6 + dx, 1 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(6, 0), 0, VillageTilesetBuilder.get_coord(TID_ROOF_GRAY))
	tilemap.set_cell(1, Vector2i(5, 1), 0, VillageTilesetBuilder.get_coord(TID_STONE_WALL))
	tilemap.set_cell(1, Vector2i(7, 1), 0, VillageTilesetBuilder.get_coord(TID_STONE_WALL))

	for dx in range(-1, 2):
		for dy in range(-1, 1):
			_set_tile_safe(0, Vector2i(2 + dx, 5 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(2, 4), 0, VillageTilesetBuilder.get_coord(TID_ROOF_DARK))
	tilemap.set_cell(1, Vector2i(1, 5), 0, VillageTilesetBuilder.get_coord(TID_WOOD_WALL))
	tilemap.set_cell(1, Vector2i(3, 5), 0, VillageTilesetBuilder.get_coord(TID_WOOD_WALL))

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			_set_tile_safe(0, Vector2i(13 + dx, 6 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(13, 5), 0, VillageTilesetBuilder.get_coord(TID_ROOF_RED))
	tilemap.set_cell(1, Vector2i(12, 6), 0, VillageTilesetBuilder.get_coord(TID_STONE_WALL))
	tilemap.set_cell(1, Vector2i(14, 6), 0, VillageTilesetBuilder.get_coord(TID_STONE_WALL))

	for dx in range(-1, 1):
		for dy in range(-1, 1):
			_set_tile_safe(0, Vector2i(9 + dx, 1 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(9, 0), 0, VillageTilesetBuilder.get_coord(TID_ROOF_GRAY))
	tilemap.set_cell(1, Vector2i(10, 1), 0, VillageTilesetBuilder.get_coord(TID_WOOD_WALL))

	for dx in range(-1, 2):
		for dy in range(-1, 1):
			_set_tile_safe(0, Vector2i(6 + dx, 9 + dy), TID_PATH)
	tilemap.set_cell(1, Vector2i(6, 8), 0, VillageTilesetBuilder.get_coord(TID_ROOF_DARK))
	tilemap.set_cell(1, Vector2i(5, 9), 0, VillageTilesetBuilder.get_coord(TID_BRICK_WALL))
	tilemap.set_cell(1, Vector2i(7, 9), 0, VillageTilesetBuilder.get_coord(TID_BRICK_WALL))
	tilemap.set_cell(1, Vector2i(6, 10), 0, VillageTilesetBuilder.get_coord(TID_DOOR))

	print("[VillageBuilder] Buildings filled")

func _fill_trees_boundaries() -> void:
	for x in range(VillageConstants.MAP_TILES_X):
		_set_tile_safe(2, Vector2i(x, 0), TID_TREE)

	for y in range(1, 6):
		_set_tile_safe(2, Vector2i(0, y), TID_TREE)
		_set_tile_safe(2, Vector2i(1, y), TID_TREE)

	for x in range(15, VillageConstants.MAP_TILES_X):
		for y in range(1, 4):
			_set_tile_safe(2, Vector2i(x, y), TID_TREE)

	for x in range(16, 19):
		for y in range(9, 12):
			_set_tile_safe(2, Vector2i(x, y), TID_TREE)

	for x in range(1, 3):
		_set_tile_safe(2, Vector2i(x, 12), TID_TREE)
		_set_tile_safe(2, Vector2i(x, 13), TID_TREE)

	print("[VillageBuilder] Boundary trees filled")

func _add_decoration_tiles() -> void:
	_set_tile_safe(2, Vector2i(8, 3), TID_WELL)
	_set_tile_safe(2, Vector2i(10, 4), TID_BENCH)
	_set_tile_safe(2, Vector2i(13, 4), TID_FLOWER)
	_set_tile_safe(2, Vector2i(14, 3), TID_FLOWER)
	_set_tile_safe(2, Vector2i(1, 4), TID_FENCE)
	_set_tile_safe(2, Vector2i(2, 4), TID_FENCE)

func _add_transition_zones(village: Node) -> void:
	var existing = village.get_node_or_null("TransitionAreas")
	if existing == null:
		existing = Node2D.new()
		existing.name = "TransitionAreas"
		village.add_child(existing)

	var new_transitions: Array[Dictionary] = [
		{"name": "ToPlayerHouseArea", "pos": TRANSITIONS["to_player_house"]["position"]},
		{"name": "ToBeachArea", "pos": TRANSITIONS["to_beach"]["position"]},
		{"name": "ToForestArea", "pos": TRANSITIONS["to_forest"]["position"]},
		{"name": "ToMineArea", "pos": TRANSITIONS["to_mine"]["position"]},
	]

	for transition_data in new_transitions:
		var area_name: String = transition_data["name"]
		if existing.has_node(area_name):
			print("[VillageBuilder] Transition already exists: ", area_name)
			continue

		var area := Area2D.new()
		area.name = area_name
		area.position = transition_data["pos"]
		existing.add_child(area)

		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(48, 48)
		area.add_child(shape)

		area.body_entered.connect(_on_transition_body_entered.bind(area_name))

	print("[VillageBuilder] Transition zones ready")

func _on_transition_body_entered(body: Node, area_name: String) -> void:
	if body is Player:
		print("[VillageBuilder] Player entered: ", area_name)

		var target := ""
		var spawn_point := ""
		match area_name:
			"ToPlayerHouseArea":
				target = TRANSITIONS["to_player_house"]["target"]
				spawn_point = TRANSITIONS["to_player_house"]["spawn"]
			"ToBeachArea":
				target = TRANSITIONS["to_beach"]["target"]
				spawn_point = TRANSITIONS["to_beach"]["spawn"]
			"ToForestArea":
				target = TRANSITIONS["to_forest"]["target"]
				spawn_point = TRANSITIONS["to_forest"]["spawn"]
			"ToMineArea":
				target = TRANSITIONS["to_mine"]["target"]
				spawn_point = TRANSITIONS["to_mine"]["spawn"]
			"ToFarmArea":
				target = TRANSITIONS["to_farm"]["target"]
				spawn_point = TRANSITIONS["to_farm"]["spawn"]

		if target != "":
			SceneTransition.transition_to(target, spawn_point)

func _set_tile_safe(layer: int, coord: Vector2i, tile_id: int) -> void:
	if layer == 0 or tilemap.get_cell_source_id(layer, coord) == -1:
		tilemap.set_cell(layer, coord, 0, VillageTilesetBuilder.get_coord(tile_id))

func _clean_placeholder_layer() -> void:
	var village := get_parent()
	if village == null:
		return

	var old_layers := ["GroundLayer", "RoadLayer", "BuildingLayer", "DecorationLayer"]
	for layer_name in old_layers:
		var layer = village.get_node_or_null(layer_name)
		if layer != null:
			# Village.add_child(self) is still on the stack, so this parent is busy.
			village.call_deferred("remove_child", layer)
			layer.queue_free()
			print("[VillageBuilder] Removed legacy layer: ", layer_name)

	print("[VillageBuilder] Legacy placeholder cleanup complete")
