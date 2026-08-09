extends SceneTree

const MAPS := [
	{
		"name": "Forest", "id": "forest_main", "style": "forest",
		"display": "Forest", "origin": Vector2(-80, -100), "size": Vector2i(19, 16),
		"spawn": Vector2(400, 360), "builder": "res://src/world/maps/ForestTilesetBuilder.gd",
		"markers": [
			{"id": "to_village", "position": Vector2(50, 360), "target": "res://src/world/maps/Village.tscn", "target_marker": "from_forest"},
		],
	},
	{
		"name": "Mine", "id": "mine_main", "style": "mine",
		"display": "Mine", "origin": Vector2(-105, 20), "size": Vector2i(16, 11),
		"spawn": Vector2(400, 300), "builder": "res://src/world/maps/MineTilesetBuilder.gd",
		"markers": [
			{"id": "ladder_up", "position": Vector2(100, 300)},
			{"id": "ladder_down", "position": Vector2(700, 300)},
			{"id": "to_village", "position": Vector2(50, 300), "target": "res://src/world/maps/Village.tscn", "target_marker": "from_mine"},
		],
	},
	{
		"name": "Beach", "id": "beach_main", "style": "beach",
		"display": "Beach", "origin": Vector2(-980, -760), "size": Vector2i(31, 15),
		"spawn": Vector2(0, -100), "builder": "res://src/world/maps/BeachTilesetBuilder.gd",
		"markers": [
			{"id": "to_village", "position": Vector2(0, -200), "target": "res://src/world/maps/Village.tscn", "target_marker": "from_beach"},
			{"id": "fishing_west", "position": Vector2(-150, 150)},
			{"id": "fishing_center", "position": Vector2(0, 180)},
			{"id": "fishing_east", "position": Vector2(150, 150)},
		],
	},
	{
		"name": "Village", "id": "village_main", "style": "village",
		"display": "Village", "origin": Vector2(-120, -120), "size": Vector2i(21, 17),
		"spawn": Vector2(420, 500), "builder": "res://src/world/maps/VillageTilesetBuilder.gd",
		"markers": [
			{"id": "to_farm", "position": Vector2(100, 300), "target": "res://src/world/maps/Farm.tscn", "target_marker": "from_village"},
			{"id": "to_house", "position": Vector2(400, 580), "target": "res://src/world/maps/PlayerHouse.tscn", "target_marker": "player_spawn"},
			{"id": "to_beach", "position": Vector2(1100, 700), "target": "res://src/world/maps/Beach.tscn", "target_marker": "player_spawn"},
			{"id": "to_forest", "position": Vector2(640, 60), "target": "res://src/world/maps/Forest.tscn", "target_marker": "player_spawn"},
			{"id": "to_mine", "position": Vector2(180, 820), "target": "res://src/world/maps/Mine.tscn", "target_marker": "player_spawn"},
		],
	},
	{
		"name": "PlayerHouse", "id": "player_house", "style": "house",
		"display": "Player House", "origin": Vector2(45, 50), "size": Vector2i(12, 7),
		"spawn": Vector2(400, 300), "builder": "res://src/world/maps/IndoorTilesetBuilder.gd",
		"markers": [
			{"id": "to_farm", "position": Vector2(400, 450), "target": "res://src/world/maps/Farm.tscn", "target_marker": "player_spawn"},
			{"id": "bed", "position": Vector2(200, 200)},
			{"id": "kitchen", "position": Vector2(200, 350)},
		],
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/maps/world"))
	for spec in MAPS:
		var error := _generate_map(spec)
		if error != OK:
			push_error("Failed to migrate %s: %s" % [spec.name, error_string(error)])
			quit(1)
			return
		print("[MIGRATE MAP] %s" % spec.name)
	print("SECONDARY MAP MIGRATION PASSED")
	quit(0)


func _generate_map(spec: Dictionary) -> Error:
	var key := String(spec.name).to_snake_case()
	var tile_set_path := "res://assets/tiles/%s_tileset.tres" % key
	var builder: Script = load(spec.builder)
	var tile_set: TileSet = builder.build_tileset()
	var error := ResourceSaver.save(tile_set, tile_set_path)
	if error != OK:
		return error

	var library := MapAssetLibrary.new()
	var library_path := "res://data/maps/world/%s_asset_library.tres" % key
	error = ResourceSaver.save(library, library_path)
	if error != OK:
		return error

	var profile := _create_profile(spec, tile_set, library)
	var profile_path := "res://data/maps/world/%s_profile.tres" % key
	error = ResourceSaver.save(profile, profile_path)
	if error != OK:
		return error

	var map := EditableMap2D.new()
	map.name = "%sMap" % spec.name
	map.map_id = StringName(spec.id)
	map.display_name = spec.display
	map.position = spec.origin
	map.size_in_tiles = spec.size
	map.tile_size = Vector2i(64, 64)
	map.profile = profile

	var ground := MapTileLayer.new()
	ground.name = "Ground"
	ground.layer_id = &"ground"
	ground.tile_set = tile_set
	ground.scale = Vector2.ONE * 4.0
	ground.visible = false
	map.add_child(ground)
	_fill_ground(ground, spec.size, tile_set)

	var terrain := MapTileLayer.new()
	terrain.name = "TerrainOverlay"
	terrain.layer_id = &"terrain_overlay"
	terrain.tile_set = tile_set
	terrain.scale = Vector2.ONE * 4.0
	terrain.visible = false
	terrain.z_index = 1
	map.add_child(terrain)

	var decoration := _layer("Decoration", &"decoration", MapLayerSpec.LayerKind.DECORATION, 2)
	map.add_child(decoration)
	var backdrop := IllustratedMapBackdrop.new()
	backdrop.name = "IllustratedBackdrop"
	backdrop.map_style = spec.style
	backdrop.position = -Vector2(spec.origin)
	backdrop.z_index = -100
	decoration.add_child(backdrop)

	var objects := _layer("Objects", &"objects", MapLayerSpec.LayerKind.OBJECT, 10)
	objects.y_sort_enabled = true
	map.add_child(objects)

	var collisions := _layer("Collision", &"collision", MapLayerSpec.LayerKind.COLLISION, 0)
	map.add_child(collisions)
	_copy_authored_collisions(spec, collisions, profile.get_collision_preset(&"world_solid"))

	var markers := _layer("Markers", &"markers", MapLayerSpec.LayerKind.MARKER, 0)
	map.add_child(markers)
	_add_marker(markers, &"player_spawn", spec.spawn, spec.origin)
	for marker_spec in spec.markers:
		_add_marker(markers, StringName(marker_spec.id), marker_spec.position, spec.origin, marker_spec)

	map.rebuild_world_boundaries()
	_set_owners(map, map)
	var packed := PackedScene.new()
	error = packed.pack(map)
	if error != OK:
		map.free()
		return error
	error = ResourceSaver.save(packed, "res://src/world/maps/content/%sMap.tscn" % spec.name)
	map.free()
	return error


func _create_profile(spec: Dictionary, tile_set: TileSet, library: MapAssetLibrary) -> MapProfile:
	var profile := MapProfile.new()
	profile.profile_id = StringName(spec.id)
	profile.display_name = spec.display
	profile.default_size = spec.size
	profile.tile_size = Vector2i(64, 64)
	profile.primary_tileset = tile_set
	profile.asset_library = library
	profile.required_marker_ids = PackedStringArray(["player_spawn"])
	for data in [
		[&"ground", "Ground", MapLayerSpec.LayerKind.TILE, true, 0, false],
		[&"terrain_overlay", "Terrain Overlay", MapLayerSpec.LayerKind.TILE, false, 1, false],
		[&"decoration", "Decoration", MapLayerSpec.LayerKind.DECORATION, false, 2, false],
		[&"objects", "Objects", MapLayerSpec.LayerKind.OBJECT, true, 10, true],
		[&"collision", "Collision", MapLayerSpec.LayerKind.COLLISION, true, 0, false],
		[&"markers", "Markers", MapLayerSpec.LayerKind.MARKER, true, 0, false],
	]:
		var layer_spec := MapLayerSpec.new()
		layer_spec.layer_id = data[0]
		layer_spec.display_name = data[1]
		layer_spec.kind = data[2]
		layer_spec.required = data[3]
		layer_spec.default_z_index = data[4]
		layer_spec.y_sort = data[5]
		profile.layer_specs.append(layer_spec)
	var solid := CollisionPreset.new()
	solid.preset_id = &"world_solid"
	solid.display_name = "World Solid"
	solid.collision_layer = 1
	solid.collision_mask = 0
	profile.collision_presets.append(solid)
	return profile


func _layer(node_name: String, id: StringName, kind: MapLayerSpec.LayerKind, z: int) -> MapLayer2D:
	var layer := MapLayer2D.new()
	layer.name = node_name
	layer.layer_id = id
	layer.layer_kind = kind
	layer.z_index = z
	return layer


func _fill_ground(layer: MapTileLayer, size: Vector2i, tile_set: TileSet) -> void:
	if tile_set.get_source_count() == 0:
		return
	var source_id := tile_set.get_source_id(0)
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null or source.get_tiles_count() == 0:
		return
	var atlas := source.get_tile_id(0)
	for y in range(size.y):
		for x in range(size.x):
			layer.set_cell(Vector2i(x, y), source_id, atlas)


func _copy_authored_collisions(spec: Dictionary, target: MapLayer2D, preset: CollisionPreset) -> void:
	var legacy := WorldCollisionLayout.new()
	legacy.setup(spec.style)
	for source in legacy.get_children():
		if not source is StaticBody2D or String(source.name).contains("Boundary"):
			continue
		if not _legacy_body_intersects(source, Rect2(spec.origin, Vector2(spec.size * Vector2i(64, 64)))):
			continue
		var body := MapCollisionBody2D.new()
		body.name = source.name
		body.position = source.position - Vector2(spec.origin)
		body.rotation = source.rotation
		body.preset = preset
		target.add_child(body)
		for source_shape in source.get_children():
			if source_shape is CollisionShape2D:
				var shape := CollisionShape2D.new()
				shape.name = source_shape.name
				shape.position = source_shape.position
				shape.rotation = source_shape.rotation
				shape.shape = source_shape.shape.duplicate(true)
				body.add_child(shape)
		body.apply_preset()
	legacy.free()


func _legacy_body_intersects(body: StaticBody2D, map_rect: Rect2) -> bool:
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var center: Vector2 = body.position + child.position
			var bounds: Rect2 = Rect2(center - child.shape.size / 2.0, child.shape.size)
			if map_rect.intersects(bounds, true):
				return true
		elif child is CollisionShape2D and child.shape is CircleShape2D:
			var radius: float = child.shape.radius
			var bounds: Rect2 = Rect2(body.position + child.position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			if map_rect.intersects(bounds, true):
				return true
	return false


func _add_marker(layer: MapLayer2D, id: StringName, world_position: Vector2, origin: Vector2, data := {}) -> void:
	var marker := MapMarker2D.new()
	marker.name = String(id).to_pascal_case()
	marker.marker_id = id
	marker.position = world_position - origin
	if data.has("target"):
		marker.marker_kind = MapMarker2D.MarkerKind.TRANSITION
		marker.target_scene = data.target
		marker.target_marker = StringName(data.get("target_marker", ""))
	else:
		marker.marker_kind = MapMarker2D.MarkerKind.SPAWN if id == &"player_spawn" else MapMarker2D.MarkerKind.ANCHOR
	layer.add_child(marker)


func _set_owners(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owners(child, scene_owner)
