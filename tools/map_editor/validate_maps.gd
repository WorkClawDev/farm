extends SceneTree

const FARM_MAP_PATH := "res://src/world/maps/content/FarmMap.tscn"
const EXAMPLE_MAP_PATH := "res://src/world/maps/content/PastoralValleyMap.tscn"
const FARM_PROFILE_PATH := "res://data/maps/farm/farm_profile.tres"
const FARM_LIBRARY_PATH := "res://data/maps/farm/farm_asset_library.tres"
const FARM_TILESET_PATH := "res://assets/tiles/farm_tileset.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_map := load(FARM_MAP_PATH) as PackedScene
	_expect(packed_map != null, "FarmMap scene can be loaded")
	if packed_map == null:
		_finish()
		return

	var map := packed_map.instantiate() as EditableMap2D
	_expect(map != null, "FarmMap root is EditableMap2D")
	if map == null:
		_finish()
		return

	root.add_child(map)
	_expect(map.map_id == &"farm_main", "FarmMap has the stable map id")
	_expect(map.size_in_tiles == Vector2i(50, 35), "FarmMap is 50 x 35 tiles")
	_expect(map.tile_size == Vector2i(64, 64), "FarmMap uses 64 x 64 tiles")

	for layer_id in [&"ground", &"terrain_overlay", &"decoration", &"objects", &"collision", &"markers"]:
		_expect(map.get_layer(layer_id) != null, "Required layer exists: %s" % layer_id)

	var ground := map.get_layer(&"ground") as TileMapLayer
	_expect(ground != null and ground.get_used_cells().size() == 50 * 35, "Ground covers the complete map")

	var objects := map.get_layer(&"objects")
	_expect(objects != null and objects.get_child_count() == 8, "Eight migrated farm objects exist")
	_expect(map.get_marker(&"player_spawn") != null, "Player spawn marker exists")
	_expect(map.get_marker(&"from_village") != null, "Village return marker exists")

	var collisions := map.get_layer(&"collision")
	_expect(collisions != null and collisions.get_child_count() == 5, "Farm collision layer contains four bounds and the signpost")

	var errors := 0
	for issue in map.validate():
		if issue.severity == 2:
			errors += 1
			_failures.append("Map validation %s at %s: %s" % [issue.code, issue.node_path, issue.message])
	_expect(errors == 0, "FarmMap has no validation errors")

	var profile := load(FARM_PROFILE_PATH) as MapProfile
	var library := load(FARM_LIBRARY_PATH) as MapAssetLibrary
	var tile_set := load(FARM_TILESET_PATH) as TileSet
	_expect(profile != null and profile.layer_specs.size() == 6, "Farm profile serializes six layer specifications")
	_expect(profile != null and profile.collision_presets.size() == 3, "Farm profile serializes three collision presets")
	_expect(library != null and library.entries.size() == 8, "Farm asset library serializes the initial asset set")
	_expect(tile_set != null and tile_set.get_physics_layers_count() >= 1, "Farm TileSet contains tile collision data")
	_expect(tile_set != null and tile_set.get_terrain_sets_count() >= 3, "Farm TileSet contains terrain definitions")

	if library != null:
		var copy := library.duplicate(true) as MapAssetLibrary
		var source_path := copy.entries[0].resource.resource_path
		var asset_id := copy.entries[0].asset_id
		_expect(copy.unregister(asset_id), "Asset entries can be unregistered")
		_expect(ResourceLoader.exists(source_path), "Unregistering an asset never deletes its source file")

	_validate_example_map()
	_validate_secondary_maps()

	map.queue_free()
	_finish()


func _validate_secondary_maps() -> void:
	var expected := {
		"Forest": &"forest_main",
		"Mine": &"mine_main",
		"Beach": &"beach_main",
		"Village": &"village_main",
		"PlayerHouse": &"player_house",
	}
	for map_name in expected:
		var path := "res://src/world/maps/content/%sMap.tscn" % map_name
		var packed := load(path) as PackedScene
		_expect(packed != null, "%s authored map can be loaded" % map_name)
		if packed == null:
			continue
		var map := packed.instantiate() as EditableMap2D
		_expect(map != null, "%s root is EditableMap2D" % map_name)
		if map == null:
			continue
		root.add_child(map)
		_expect(map.map_id == expected[map_name], "%s has a stable map id" % map_name)
		for layer_id in [&"ground", &"terrain_overlay", &"decoration", &"objects", &"collision", &"markers"]:
			_expect(map.get_layer(layer_id) != null, "%s layer exists: %s" % [map_name, layer_id])
		var ground := map.get_layer(&"ground") as MapTileLayer
		_expect(
			ground != null and ground.get_used_cells().size() == map.size_in_tiles.x * map.size_in_tiles.y,
			"%s ground covers its declared bounds" % map_name
		)
		_expect(map.get_marker(&"player_spawn") != null, "%s player spawn is authored" % map_name)
		var error_count := 0
		for issue in map.validate():
			if issue.severity == MapValidationIssue.Severity.ERROR:
				error_count += 1
				_failures.append("%s validation %s at %s: %s" % [map_name, issue.code, issue.node_path, issue.message])
		_expect(error_count == 0, "%s has no validation errors" % map_name)
		map.queue_free()


func _validate_example_map() -> void:
	var packed := load(EXAMPLE_MAP_PATH) as PackedScene
	_expect(packed != null, "Pastoral Valley example scene can be loaded")
	if packed == null:
		return
	var map := packed.instantiate() as EditableMap2D
	_expect(map != null, "Pastoral Valley root is EditableMap2D")
	if map == null:
		return
	root.add_child(map)
	_expect(map.map_id == &"pastoral_valley", "Pastoral Valley has its own stable map id")
	_expect(map.size_in_tiles == Vector2i(50, 35), "Pastoral Valley is 50 x 35 tiles")
	_expect(map.get_layer(&"ground").get_used_cells().size() == 1750, "Pastoral Valley ground covers the map")
	_expect(map.get_layer(&"objects").get_child_count() == 10, "Pastoral Valley contains ten placed objects")
	_expect(map.get_layer(&"markers").get_child_count() == 5, "Pastoral Valley contains spawn and design anchors")
	var water_data := (map.get_layer(&"terrain_overlay") as MapTileLayer).get_cell_tile_data(Vector2i(39, 27))
	_expect(water_data != null and water_data.get_collision_polygons_count(0) > 0, "Pastoral Valley pond uses collidable water tiles")
	var error_count := 0
	for issue in map.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			error_count += 1
			_failures.append("Example validation %s at %s: %s" % [issue.code, issue.node_path, issue.message])
	_expect(error_count == 0, "Pastoral Valley has no validation errors")
	map.queue_free()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[MAP PASS] %s" % description)
	else:
		_failures.append(description)
		push_error("[MAP FAIL] %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("MAP VALIDATION PASSED")
		quit(0)
		return
	print("MAP VALIDATION FAILED (%d)" % _failures.size())
	for failure in _failures:
		print("  - %s" % failure)
	quit(1)
