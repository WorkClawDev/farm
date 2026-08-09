extends SceneTree

const TILESET_PATH := "res://assets/tiles/farm_tileset.tres"
const LIBRARY_PATH := "res://data/maps/farm/farm_asset_library.tres"
const PROFILE_PATH := "res://data/maps/farm/farm_profile.tres"
const MAP_PATH := "res://src/world/maps/content/FarmMap.tscn"
const LEGACY_TILE_PATH := "res://data/maps/farm_layout.json"
const LEGACY_OBJECT_PATH := "res://data/farm_layout.json"

const OBJECT_SCENES := {
	"shipping_bin": "res://src/world/objects/ShippingBin.tscn",
	"player_house_exterior": "res://src/world/objects/HouseExterior.tscn",
	"workbench": "res://src/world/objects/Workbench.tscn",
	"fishing_spot": "res://src/world/objects/FishingSpot.tscn",
	"coop": "res://src/world/objects/Coop.tscn",
	"barn": "res://src/world/objects/Barn.tscn",
	"ore": "res://src/world/objects/Ore.tscn",
}

var EXPOSED_PROPERTIES := {
	"shipping_bin": PackedStringArray(["interaction_prompt", "is_interactable"]),
	"player_house_exterior": PackedStringArray(),
	"workbench": PackedStringArray(["workbench_type", "workbench_name", "interaction_prompt", "is_interactable"]),
	"fishing_spot": PackedStringArray(["location_type"]),
	"coop": PackedStringArray(["building_name", "max_animals"]),
	"barn": PackedStringArray(["building_name", "max_animals"]),
	"ore": PackedStringArray(["ore_type", "max_health", "base_quantity", "quality_modifier"]),
}


func _initialize() -> void:
	var errors: Array[String] = []
	_ensure_directories(errors)
	var tile_set := _build_tileset(errors)
	if tile_set != null:
		_save_resource(tile_set, TILESET_PATH, errors)
	var persisted_tileset := load(TILESET_PATH) as TileSet
	if persisted_tileset == null:
		errors.append("Saved TileSet could not be reloaded")
	var library := _build_asset_library(errors)
	_save_resource(library, LIBRARY_PATH, errors)
	var persisted_library := load(LIBRARY_PATH) as MapAssetLibrary
	if persisted_library == null:
		errors.append("Saved asset library could not be reloaded")
	var profile := _build_profile(persisted_tileset, persisted_library)
	_save_resource(profile, PROFILE_PATH, errors)
	if errors.is_empty():
		_build_map_scene(profile, persisted_tileset, errors)
	if errors.is_empty():
		print("[MapMigration] Farm map generated: ", MAP_PATH)
		quit(0)
	else:
		for message in errors:
			push_error("[MapMigration] " + message)
		quit(1)


func _ensure_directories(errors: Array[String]) -> void:
	for path in [
		"res://data/maps/farm",
		"res://src/world/maps/content",
	]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		if error != OK and error != ERR_ALREADY_EXISTS:
			errors.append("Cannot create %s: %s" % [path, error_string(error)])


func _build_tileset(errors: Array[String]) -> TileSet:
	var texture := load("res://assets/tiles/farm_ground_atlas.svg") as Texture2D
	if texture == null:
		errors.append("Farm atlas could not be loaded as an imported Texture2D")
		return null
	var tile_set := TileSet.new()
	tile_set.resource_name = "farm_tiles"
	tile_set.tile_size = Vector2i(64, 64)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1 << 0)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(64, 64)
	for atlas_id in range(26):
		atlas.create_tile(Vector2i(atlas_id, 0))
	tile_set.add_source(atlas)
	for atlas_id in range(26):
		_apply_tile_collision(atlas, atlas_id)
	_add_terrain_metadata(tile_set)
	return tile_set


func _apply_tile_collision(atlas: TileSetAtlasSource, atlas_id: int) -> void:
	var data := atlas.get_tile_data(Vector2i(atlas_id, 0), 0)
	if data == null:
		return
	var polygon := PackedVector2Array()
	if atlas_id >= 10 and atlas_id <= 18:
		polygon = PackedVector2Array([
			Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32),
		])
	elif atlas_id == 19:
		polygon = PackedVector2Array([
			Vector2(-32, -12), Vector2(32, -12), Vector2(32, 12), Vector2(-32, 12),
		])
	elif atlas_id == 20:
		polygon = PackedVector2Array([
			Vector2(-12, -32), Vector2(12, -32), Vector2(12, 32), Vector2(-12, 32),
		])
	if polygon.is_empty():
		return
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, polygon)


func _add_terrain_metadata(tile_set: TileSet) -> void:
	var terrain_definitions := [
		{"name": "Path", "tiles": [3, 4, 5, 6, 7, 8, 9]},
		{"name": "Water", "tiles": [10, 11, 12, 13, 14, 15, 16, 17, 18]},
		{"name": "Fence", "tiles": [19, 20]},
	]
	for set_index in range(terrain_definitions.size()):
		tile_set.add_terrain_set()
		tile_set.set_terrain_set_mode(set_index, TileSet.TERRAIN_MODE_MATCH_SIDES)
		tile_set.add_terrain(set_index)
		tile_set.set_terrain_name(set_index, 0, terrain_definitions[set_index].name)
		for atlas_id in terrain_definitions[set_index].tiles:
			var data := _get_atlas_tile_data(tile_set, atlas_id)
			if data == null:
				continue
			data.terrain_set = set_index
			data.terrain = 0
			for neighbor in [
				TileSet.CELL_NEIGHBOR_LEFT_SIDE,
				TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
				TileSet.CELL_NEIGHBOR_TOP_SIDE,
				TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
			]:
				data.set_terrain_peering_bit(neighbor, 0)


func _get_atlas_tile_data(tile_set: TileSet, atlas_id: int) -> TileData:
	if tile_set.get_source_count() == 0:
		return null
	var source_id := tile_set.get_source_id(0)
	var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
	return atlas.get_tile_data(Vector2i(atlas_id, 0), 0) if atlas != null else null


func _build_asset_library(errors: Array[String]) -> MapAssetLibrary:
	var library := MapAssetLibrary.new()
	var tileset_entry := MapAssetEntry.new()
	tileset_entry.asset_id = &"farm_tileset"
	tileset_entry.display_name = "农场 TileSet"
	tileset_entry.kind = MapAssetEntry.AssetKind.TILE_SET
	tileset_entry.resource = load(TILESET_PATH)
	tileset_entry.default_layer_id = &"ground"
	tileset_entry.tags = PackedStringArray(["farm", "tiles", "terrain"])
	if tileset_entry.resource == null:
		errors.append("Saved TileSet could not be loaded")
	else:
		library.entries.append(tileset_entry)

	for scene_key in OBJECT_SCENES:
		var packed := load(OBJECT_SCENES[scene_key]) as PackedScene
		if packed == null:
			errors.append("Object scene could not be loaded: %s" % OBJECT_SCENES[scene_key])
			continue
		var entry := MapAssetEntry.new()
		entry.asset_id = StringName(scene_key)
		entry.display_name = _object_display_name(scene_key)
		entry.kind = MapAssetEntry.AssetKind.SCENE
		entry.resource = packed
		entry.default_layer_id = &"objects"
		entry.tags = PackedStringArray(["farm", "object", scene_key])
		entry.exposed_properties = EXPOSED_PROPERTIES[scene_key]
		library.entries.append(entry)
	return library


func _object_display_name(scene_key: String) -> String:
	return {
		"shipping_bin": "出货箱",
		"player_house_exterior": "玩家房屋",
		"workbench": "工作台",
		"fishing_spot": "钓鱼点",
		"coop": "鸡舍",
		"barn": "牛棚",
		"ore": "矿石",
	}.get(scene_key, scene_key.capitalize())


func _build_profile(tile_set: TileSet, library: MapAssetLibrary) -> MapProfile:
	var profile := MapProfile.new()
	profile.profile_id = &"farm"
	profile.display_name = "农场"
	profile.default_size = Vector2i(50, 35)
	profile.tile_size = Vector2i(64, 64)
	profile.primary_tileset = tile_set
	profile.asset_library = library
	profile.required_marker_ids = PackedStringArray(["player_spawn", "from_village"])
	profile.layer_specs = [
		_layer_spec(&"ground", "地面", MapLayerSpec.LayerKind.TILE, true, 0, false),
		_layer_spec(&"terrain_overlay", "地形覆盖", MapLayerSpec.LayerKind.TILE, false, 1, false),
		_layer_spec(&"decoration", "装饰", MapLayerSpec.LayerKind.DECORATION, false, 2, false),
		_layer_spec(&"objects", "对象", MapLayerSpec.LayerKind.OBJECT, true, 10, true),
		_layer_spec(&"collision", "碰撞", MapLayerSpec.LayerKind.COLLISION, true, 0, false),
		_layer_spec(&"markers", "标记", MapLayerSpec.LayerKind.MARKER, true, 0, false),
	]
	profile.collision_presets = [
		_collision_preset(&"world_solid", "世界实体", 1 << 0, 0, Color(0.95, 0.25, 0.2, 0.35)),
		_collision_preset(&"player_trigger", "玩家触发区", 0, 1 << 1, Color(0.2, 0.75, 1.0, 0.3)),
		_collision_preset(&"npc_trigger", "NPC 触发区", 0, 1 << 2, Color(0.75, 0.3, 1.0, 0.3)),
	]
	return profile


func _layer_spec(
	id: StringName,
	name: String,
	kind: MapLayerSpec.LayerKind,
	required: bool,
	z_index: int,
	y_sort: bool
) -> MapLayerSpec:
	var spec := MapLayerSpec.new()
	spec.layer_id = id
	spec.display_name = name
	spec.kind = kind
	spec.required = required
	spec.default_z_index = z_index
	spec.y_sort = y_sort
	return spec


func _collision_preset(id: StringName, name: String, layer: int, mask: int, color: Color) -> CollisionPreset:
	var preset := CollisionPreset.new()
	preset.preset_id = id
	preset.display_name = name
	preset.collision_layer = layer
	preset.collision_mask = mask
	preset.editor_color = color
	return preset


func _build_map_scene(profile: MapProfile, tile_set: TileSet, errors: Array[String]) -> void:
	var root := EditableMap2D.new()
	root.name = "FarmMap"
	root.map_id = &"farm_main"
	root.display_name = "农场主地图"
	root.size_in_tiles = Vector2i(50, 35)
	root.tile_size = Vector2i(64, 64)
	root.profile = load(PROFILE_PATH) as MapProfile

	var ground := _new_tile_layer(profile.get_layer_spec(&"ground"), tile_set)
	var overlay := _new_tile_layer(profile.get_layer_spec(&"terrain_overlay"), tile_set)
	var decoration := _new_node_layer(profile.get_layer_spec(&"decoration"))
	var objects := _new_node_layer(profile.get_layer_spec(&"objects"))
	var collisions := _new_node_layer(profile.get_layer_spec(&"collision"))
	var markers := _new_node_layer(profile.get_layer_spec(&"markers"))
	for layer in [ground, overlay, decoration, objects, collisions, markers]:
		root.add_child(layer)
		layer.owner = root

	_paint_ground_and_legacy(ground, overlay, errors)
	_load_legacy_objects(objects, root, errors)
	_add_world_collisions(collisions, root, profile.get_collision_preset(&"world_solid"))
	_add_marker(markers, root, "PlayerSpawn", &"player_spawn", Vector2(841, 358), MapMarker2D.MarkerKind.SPAWN)
	_add_marker(markers, root, "FromVillage", &"from_village", Vector2(1320, 608), MapMarker2D.MarkerKind.SPAWN)

	var issues := root.validate()
	for issue in issues:
		if issue.is_error():
			errors.append("Generated map validation failed [%s]: %s" % [issue.code, issue.message])
	if not errors.is_empty():
		root.free()
		return
	var scene := PackedScene.new()
	var pack_error := scene.pack(root)
	if pack_error != OK:
		errors.append("FarmMap pack failed: %s" % error_string(pack_error))
		root.free()
		return
	var save_error := ResourceSaver.save(scene, MAP_PATH)
	if save_error != OK:
		errors.append("FarmMap save failed: %s" % error_string(save_error))
	root.free()


func _new_tile_layer(spec: MapLayerSpec, tile_set: TileSet) -> MapTileLayer:
	var layer := MapTileLayer.new()
	layer.configure_from_spec(spec)
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


func _new_node_layer(spec: MapLayerSpec) -> MapLayer2D:
	var layer := MapLayer2D.new()
	layer.configure_from_spec(spec)
	return layer


func _paint_ground_and_legacy(ground: MapTileLayer, overlay: MapTileLayer, errors: Array[String]) -> void:
	for y in range(35):
		for x in range(50):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	var data := _load_json_dictionary(LEGACY_TILE_PATH, errors)
	if data.is_empty():
		return
	var rows: Array = data.get("tiles", [])
	for y in range(mini(rows.size(), 35)):
		if not rows[y] is Array:
			continue
		for x in range(mini(rows[y].size(), 50)):
			var editor_id := int(rows[y][x])
			var cell := Vector2i(x, y)
			if editor_id in [6, 7]:
				overlay.set_cell(cell, 0, _path_coord(rows, y, x))
			elif editor_id in [8, 9]:
				overlay.set_cell(cell, 0, _water_coord(rows, y, x))
			elif editor_id == 11:
				overlay.set_cell(cell, 0, _fence_coord(rows, y, x))
			elif editor_id == 12:
				overlay.set_cell(cell, 0, Vector2i(21, 0))
			else:
				ground.set_cell(cell, 0, _legacy_ground_coord(editor_id))


func _legacy_ground_coord(editor_id: int) -> Vector2i:
	return Vector2i({
		0: 0,
		1: 1,
		2: 0,
		3: 0,
		4: 0,
		5: 2,
		10: 0,
		13: 22,
		14: 24,
		15: 23,
	}.get(editor_id, 0), 0)


func _path_coord(rows: Array, y: int, x: int) -> Vector2i:
	var mask := _connection_mask(rows, y, x, [6, 7])
	var horizontal := (mask & 3) != 0
	var vertical := (mask & 12) != 0
	if mask == 6: return Vector2i(6, 0)
	if mask == 5: return Vector2i(7, 0)
	if mask == 10: return Vector2i(8, 0)
	if mask == 9: return Vector2i(9, 0)
	if horizontal and vertical: return Vector2i(5, 0)
	if vertical: return Vector2i(4, 0)
	return Vector2i(3, 0)


func _water_coord(rows: Array, y: int, x: int) -> Vector2i:
	var mask := _connection_mask(rows, y, x, [8, 9])
	var left := (mask & 1) != 0
	var right := (mask & 2) != 0
	var up := (mask & 4) != 0
	var down := (mask & 8) != 0
	if not up and not left: return Vector2i(15, 0)
	if not up and not right: return Vector2i(16, 0)
	if not down and not left: return Vector2i(17, 0)
	if not down and not right: return Vector2i(18, 0)
	if not up: return Vector2i(11, 0)
	if not down: return Vector2i(12, 0)
	if not left: return Vector2i(13, 0)
	if not right: return Vector2i(14, 0)
	return Vector2i(10, 0)


func _fence_coord(rows: Array, y: int, x: int) -> Vector2i:
	var mask := _connection_mask(rows, y, x, [11, 12])
	return Vector2i(19 if (mask & 3) != 0 else 20, 0)


func _connection_mask(rows: Array, y: int, x: int, ids: Array) -> int:
	var mask := 0
	if _legacy_matches(rows, y, x - 1, ids): mask |= 1
	if _legacy_matches(rows, y, x + 1, ids): mask |= 2
	if _legacy_matches(rows, y - 1, x, ids): mask |= 4
	if _legacy_matches(rows, y + 1, x, ids): mask |= 8
	return mask


func _legacy_matches(rows: Array, y: int, x: int, ids: Array) -> bool:
	return y >= 0 and y < rows.size() and rows[y] is Array and x >= 0 and x < rows[y].size() and int(rows[y][x]) in ids


func _load_legacy_objects(layer: MapLayer2D, root: EditableMap2D, errors: Array[String]) -> void:
	var data := _load_json_dictionary(LEGACY_OBJECT_PATH, errors)
	for object_data in data.get("objects", []):
		if not object_data is Dictionary or object_data.get("kind", "") != "scene":
			continue
		var scene_key := str(object_data.get("scene_key", ""))
		var packed := load(OBJECT_SCENES.get(scene_key, "")) as PackedScene
		if packed == null:
			errors.append("Unknown legacy object scene_key: %s" % scene_key)
			continue
		var node := packed.instantiate() as Node2D
		if node == null:
			errors.append("Legacy object is not Node2D: %s" % scene_key)
			continue
		node.name = str(object_data.get("name", scene_key.to_pascal_case()))
		var pos: Dictionary = object_data.get("position", {})
		node.position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
		node.set_meta("map_asset_id", StringName(scene_key))
		for property_name in object_data.get("properties", {}):
			if property_name in EXPOSED_PROPERTIES.get(scene_key, PackedStringArray()):
				node.set(property_name, object_data.properties[property_name])
		layer.add_child(node)
		node.owner = root


func _add_world_collisions(layer: MapLayer2D, root: EditableMap2D, preset: CollisionPreset) -> void:
	var map_size := root.get_world_rect().size
	var thickness := root.world_boundary_thickness
	_add_rect_collision(layer, root, "NorthBoundary", Vector2(map_size.x / 2.0, -thickness / 2.0), Vector2(map_size.x, thickness), preset, MapCollisionBody2D.BoundarySide.NORTH)
	_add_rect_collision(layer, root, "SouthBoundary", Vector2(map_size.x / 2.0, map_size.y + thickness / 2.0), Vector2(map_size.x, thickness), preset, MapCollisionBody2D.BoundarySide.SOUTH)
	_add_rect_collision(layer, root, "WestBoundary", Vector2(-thickness / 2.0, map_size.y / 2.0), Vector2(thickness, map_size.y), preset, MapCollisionBody2D.BoundarySide.WEST)
	_add_rect_collision(layer, root, "EastBoundary", Vector2(map_size.x + thickness / 2.0, map_size.y / 2.0), Vector2(thickness, map_size.y), preset, MapCollisionBody2D.BoundarySide.EAST)
	_add_rect_collision(layer, root, "FarmSignpost", Vector2(720, 160), Vector2(32, 32), preset)


func _add_rect_collision(
	layer: MapLayer2D,
	root: EditableMap2D,
	name: String,
	position: Vector2,
	size: Vector2,
	preset: CollisionPreset,
	boundary_side: MapCollisionBody2D.BoundarySide = MapCollisionBody2D.BoundarySide.NONE
) -> void:
	var body := MapCollisionBody2D.new()
	body.name = name
	body.position = position
	body.preset = preset
	body.is_world_boundary = boundary_side != MapCollisionBody2D.BoundarySide.NONE
	body.boundary_side = boundary_side
	body.apply_preset()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	layer.add_child(body)
	body.owner = root
	collision.owner = root


func _add_marker(
	layer: MapLayer2D,
	root: EditableMap2D,
	name: String,
	id: StringName,
	position: Vector2,
	kind: MapMarker2D.MarkerKind
) -> void:
	var marker := MapMarker2D.new()
	marker.name = name
	marker.marker_id = id
	marker.marker_kind = kind
	marker.position = position
	layer.add_child(marker)
	marker.owner = root


func _load_json_dictionary(path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open legacy JSON: %s" % path)
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK or not json.data is Dictionary:
		errors.append("Invalid legacy JSON: %s" % path)
		return {}
	return json.data


func _save_resource(resource: Resource, path: String, errors: Array[String]) -> void:
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		errors.append("Cannot save %s: %s" % [path, error_string(error)])
