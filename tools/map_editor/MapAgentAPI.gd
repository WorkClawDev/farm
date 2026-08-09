@tool
extends RefCounted
class_name MapAgentAPI

const API_VERSION := 1

var _map: EditableMap2D
var _scene_path := ""
var _allowed_region := Rect2i()
var _has_allowed_region := false
var _allow_locked_layers := false
var _errors: Array[String] = []
var _changes: Array[Dictionary] = []


func schema() -> Dictionary:
	return {
		"api_version": API_VERSION,
		"recipe": {
			"version": API_VERSION,
			"expected_map_id": "optional map id",
			"expected_scene_sha256": "optional hash returned by inspect",
			"allowed_region": {"x": 0, "y": 0, "width": 10, "height": 10},
			"allow_locked_layers": false,
			"operations": [],
		},
		"operations": {
			"set_map_metadata": {"map_id": "new_map_id", "display_name": "New Map"},
			"resize_map": {"size": [50, 35], "ground_layer": "ground", "fill": {"source": 0, "atlas": [0, 0], "alternative": 0}},
			"paint_rect": {"layer": "ground", "from": [0, 0], "to": [4, 4], "tile": {"source": 0, "atlas": [0, 0], "alternative": 0}},
			"paint_cells": {"layer": "ground", "cells": [[0, 0], [1, 0]], "tile": {"source": 0, "atlas": [0, 0]}},
			"erase_rect": {"layer": "terrain_overlay", "from": [0, 0], "to": [4, 4]},
			"terrain_connect": {"layer": "terrain_overlay", "cells": [[0, 0], [1, 0]], "terrain_set": 0, "terrain": 0},
			"place_asset": {"asset": "ore", "at": [640, 640], "space": "world", "name": "CopperOre", "properties": {}},
			"move_node": {"path": "Objects/CopperOre", "to": [704, 640], "space": "world"},
			"remove_node": {"path": "Objects/CopperOre"},
			"collision_rect": {"at": [640, 640], "size": [128, 64], "preset": "world_solid", "name": "RockWall"},
			"collision_circle": {"at": [640, 640], "radius": 64, "preset": "world_solid"},
			"collision_polygon": {"points": [[0, 0], [128, 0], [64, 64]], "preset": "world_solid"},
			"marker": {"id": "spawn", "at": [5, 5], "space": "tile", "kind": "spawn", "replace": false},
			"set_layer": {"layer": "objects", "visible": true, "locked": false, "opacity": 1.0, "y_sort": true, "z_index": 2},
		},
	}


func inspect_map(scene_path: String) -> Dictionary:
	var loaded := _load_map(scene_path)
	if not loaded.ok:
		return loaded
	var layers: Array[Dictionary] = []
	for child in _map.get_children():
		if child is MapTileLayer:
			layers.append({
				"id": str(child.layer_id),
				"kind": "tile",
				"node_path": str(_map.get_path_to(child)),
				"locked": child.locked,
				"visible": child.visible,
				"used_cells": child.get_used_cells().size(),
			})
		elif child is MapLayer2D:
			layers.append({
				"id": str(child.layer_id),
				"kind": MapLayerSpec.LayerKind.keys()[child.layer_kind].to_lower(),
				"node_path": str(_map.get_path_to(child)),
				"locked": child.locked,
				"visible": child.visible,
				"children": child.get_child_count(),
			})
	var result := _base_result(true)
	result["map"] = {
		"scene_path": scene_path,
		"scene_sha256": FileAccess.get_sha256(scene_path),
		"map_id": str(_map.map_id),
		"display_name": _map.display_name,
		"size_in_tiles": [_map.size_in_tiles.x, _map.size_in_tiles.y],
		"tile_size": [_map.tile_size.x, _map.tile_size.y],
		"profile": _map.profile.resource_path if _map.profile != null else "",
		"layers": layers,
	}
	result["catalog"] = _catalog()
	result["validation"] = _validation_dictionaries()
	_free_map()
	return result


func validate_map(scene_path: String) -> Dictionary:
	var loaded := _load_map(scene_path)
	if not loaded.ok:
		return loaded
	var issues := _validation_dictionaries()
	var error_count := 0
	for issue in issues:
		if int(issue.severity) == MapValidationIssue.Severity.ERROR:
			error_count += 1
	var result := _base_result(error_count == 0)
	result["scene_path"] = scene_path
	result["issues"] = issues
	result["error_count"] = error_count
	_free_map()
	return result


func create_map(profile_path: String, output_path: String, map_id: StringName, display_name: String = "", overwrite: bool = false) -> Dictionary:
	_reset()
	if not overwrite and (ResourceLoader.exists(output_path) or FileAccess.file_exists(output_path)):
		return _failure("Output map already exists; pass --force to replace it: %s" % output_path)
	var profile := load(profile_path) as MapProfile
	if profile == null:
		return _failure("Cannot load MapProfile: %s" % profile_path)
	if map_id.is_empty():
		return _failure("map_id cannot be empty")
	_map = EditableMap2D.new()
	_map.name = str(map_id).to_pascal_case()
	_map.map_id = map_id
	_map.display_name = display_name if not display_name.is_empty() else str(map_id).capitalize()
	_map.size_in_tiles = profile.default_size
	_map.tile_size = profile.tile_size
	_map.profile = profile
	for spec in profile.layer_specs:
		if spec == null:
			continue
		var layer: Node2D
		if spec.kind == MapLayerSpec.LayerKind.TILE:
			var tile_layer := MapTileLayer.new()
			tile_layer.configure_from_spec(spec)
			tile_layer.tile_set = profile.primary_tileset
			layer = tile_layer
		else:
			var node_layer := MapLayer2D.new()
			node_layer.configure_from_spec(spec)
			layer = node_layer
		_map.add_child(layer)
		_set_owner_recursive(layer, _map)
	_map.rebuild_world_boundaries()
	_changes.append({"op": "create_map", "path": output_path})
	var saved := _save_map(output_path)
	_free_map()
	return saved


func apply_recipe(scene_path: String, recipe: Dictionary, output_path: String = "", dry_run: bool = false) -> Dictionary:
	var loaded := _load_map(scene_path)
	if not loaded.ok:
		return loaded
	if int(recipe.get("version", -1)) != API_VERSION:
		_errors.append("Recipe version must be %d" % API_VERSION)
	var expected_map_id := str(recipe.get("expected_map_id", ""))
	if not expected_map_id.is_empty() and expected_map_id != str(_map.map_id):
		_errors.append("Map id mismatch: expected %s, got %s" % [expected_map_id, _map.map_id])
	var expected_hash := str(recipe.get("expected_scene_sha256", ""))
	if not expected_hash.is_empty() and expected_hash != FileAccess.get_sha256(scene_path):
		_errors.append("Scene hash mismatch; inspect the current map before applying this recipe")
	_allow_locked_layers = bool(recipe.get("allow_locked_layers", false))
	_configure_allowed_region(recipe.get("allowed_region", null))
	var operations: Variant = recipe.get("operations", [])
	if not operations is Array:
		_errors.append("operations must be an array")
	else:
		for index in range(operations.size()):
			if not operations[index] is Dictionary:
				_errors.append("Operation %d must be an object" % index)
				continue
			_apply_operation(operations[index], index)
	if not _errors.is_empty():
		var failed := _base_result(false)
		failed["scene_path"] = scene_path
		failed["errors"] = _errors.duplicate()
		failed["changes"] = _changes.duplicate(true)
		_free_map()
		return failed

	var issues := _validation_dictionaries()
	for issue in issues:
		if int(issue.severity) == MapValidationIssue.Severity.ERROR:
			_errors.append("Validation %s at %s: %s" % [issue.code, issue.node_path, issue.message])
	if not _errors.is_empty():
		var invalid := _base_result(false)
		invalid["scene_path"] = scene_path
		invalid["errors"] = _errors.duplicate()
		invalid["changes"] = _changes.duplicate(true)
		invalid["issues"] = issues
		_free_map()
		return invalid

	var target_path := output_path if not output_path.is_empty() else scene_path
	var result := _base_result(true)
	if not dry_run:
		result = _save_map(target_path)
	result["dry_run"] = dry_run
	result["source_path"] = scene_path
	result["output_path"] = target_path
	result["changes"] = _changes.duplicate(true)
	result["issues"] = issues
	_free_map()
	return result


func _apply_operation(operation: Dictionary, index: int) -> void:
	var op := str(operation.get("op", ""))
	match op:
		"set_map_metadata":
			_set_map_metadata(operation, index)
		"resize_map":
			_resize_map(operation, index)
		"paint_rect":
			_paint_rect(operation, false, index)
		"erase_rect":
			_paint_rect(operation, true, index)
		"paint_cells":
			_paint_cells(operation, index)
		"terrain_connect":
			_terrain_connect(operation, index)
		"place_asset":
			_place_asset(operation, index)
		"move_node":
			_move_node(operation, index)
		"remove_node":
			_remove_node(operation, index)
		"collision_rect", "collision_circle", "collision_polygon":
			_add_collision(operation, op, index)
		"marker":
			_add_marker(operation, index)
		"set_layer":
			_set_layer(operation, index)
		_:
			_errors.append("Operation %d has unknown op: %s" % [index, op])


func _set_map_metadata(operation: Dictionary, index: int) -> void:
	var new_map_id := StringName(str(operation.get("map_id", _map.map_id)).strip_edges())
	var new_display_name := str(operation.get("display_name", _map.display_name)).strip_edges()
	if new_map_id.is_empty() or new_display_name.is_empty():
		_errors.append("Operation %d map_id and display_name cannot be empty" % index)
		return
	_map.map_id = new_map_id
	_map.display_name = new_display_name
	_changes.append({"op": "set_map_metadata", "map_id": str(new_map_id), "display_name": new_display_name})


func _resize_map(operation: Dictionary, index: int) -> void:
	if _has_allowed_region:
		_errors.append("Operation %d cannot resize a map while allowed_region is active" % index)
		return
	var size_value: Variant = _vector2i(operation.get("size", null), "operation %d size" % index)
	if size_value == null:
		return
	var new_size: Vector2i = size_value
	if new_size.x <= 0 or new_size.y <= 0:
		_errors.append("Operation %d map size must be positive" % index)
		return
	var old_size := _map.size_in_tiles
	if new_size.x < old_size.x or new_size.y < old_size.y:
		var new_world_rect := Rect2(Vector2.ZERO, Vector2(new_size * _map.tile_size))
		for layer_node in _map.get_children():
			if layer_node is MapTileLayer:
				for cell in layer_node.get_used_cells():
					if cell.x >= new_size.x or cell.y >= new_size.y:
						_errors.append("Operation %d resize would remove tile %s from layer %s" % [index, cell, layer_node.layer_id])
						return
			elif layer_node is MapLayer2D:
				for child in layer_node.get_children():
					if child is MapCollisionBody2D and child.is_world_boundary:
						continue
					if child is Node2D and not new_world_rect.has_point(child.position):
						_errors.append("Operation %d resize would place %s outside the map" % [index, _map.get_path_to(child)])
						return

	var fill_value: Variant = operation.get("fill", null)
	var fill_layer: MapTileLayer
	var fill_tile := {}
	if fill_value != null and (new_size.x > old_size.x or new_size.y > old_size.y):
		fill_layer = _map.get_layer(StringName(str(operation.get("ground_layer", "ground")))) as MapTileLayer
		if fill_layer == null or not _layer_editable(fill_layer, index):
			_errors.append("Operation %d resize fill requires an editable tile layer" % index)
			return
		fill_tile = _tile_state(fill_value, index)
		if fill_tile.is_empty() or not _tile_exists(fill_layer, fill_tile, index):
			return

	_map.size_in_tiles = new_size
	if not fill_tile.is_empty():
		for y in range(new_size.y):
			for x in range(new_size.x):
				if x >= old_size.x or y >= old_size.y:
					fill_layer.set_cell(Vector2i(x, y), fill_tile.source, fill_tile.atlas, fill_tile.alternative)
	if not _map.rebuild_world_boundaries():
		_errors.append("Operation %d could not rebuild world boundaries" % index)
		return
	_changes.append({"op": "resize_map", "from": [old_size.x, old_size.y], "to": [new_size.x, new_size.y]})


func _paint_rect(operation: Dictionary, erase: bool, index: int) -> void:
	var layer := _tile_layer(operation, index)
	if layer == null:
		return
	var from_value: Variant = _vector2i(operation.get("from", null), "operation %d from" % index)
	var to_value: Variant = _vector2i(operation.get("to", null), "operation %d to" % index)
	if from_value == null or to_value == null:
		return
	var from_cell: Vector2i = from_value
	var to_cell: Vector2i = to_value
	var minimum := Vector2i(mini(from_cell.x, to_cell.x), mini(from_cell.y, to_cell.y))
	var maximum := Vector2i(maxi(from_cell.x, to_cell.x), maxi(from_cell.y, to_cell.y))
	var tile := {} if erase else _tile_state(operation.get("tile", null), index)
	if not erase and tile.is_empty():
		return
	if not _cell_allowed(minimum, index) or not _cell_allowed(maximum, index):
		return
	if not erase and not _tile_exists(layer, tile, index):
		return
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell := Vector2i(x, y)
			if erase:
				layer.erase_cell(cell)
			else:
				layer.set_cell(cell, tile.source, tile.atlas, tile.alternative)
	_changes.append({"op": "erase_rect" if erase else "paint_rect", "layer": str(layer.layer_id), "from": [minimum.x, minimum.y], "to": [maximum.x, maximum.y]})


func _paint_cells(operation: Dictionary, index: int) -> void:
	var layer := _tile_layer(operation, index)
	var tile := _tile_state(operation.get("tile", null), index)
	if layer == null or tile.is_empty():
		return
	if not _tile_exists(layer, tile, index):
		return
	var cells: Variant = operation.get("cells", [])
	if not cells is Array:
		_errors.append("Operation %d cells must be an array" % index)
		return
	var count := 0
	for value in cells:
		var cell_value: Variant = _vector2i(value, "operation %d cell" % index)
		if cell_value != null:
			var cell: Vector2i = cell_value
			if not _cell_allowed(cell, index):
				continue
			layer.set_cell(cell, tile.source, tile.atlas, tile.alternative)
			count += 1
	_changes.append({"op": "paint_cells", "layer": str(layer.layer_id), "count": count})


func _terrain_connect(operation: Dictionary, index: int) -> void:
	var layer := _tile_layer(operation, index)
	if layer == null:
		return
	var cells: Array[Vector2i] = []
	for value in operation.get("cells", []):
		var cell_value: Variant = _vector2i(value, "operation %d cell" % index)
		if cell_value != null:
			var cell: Vector2i = cell_value
			if not _cell_allowed(cell, index):
				continue
			cells.append(cell)
	var terrain_set := int(operation.get("terrain_set", 0))
	var terrain := int(operation.get("terrain", 0))
	if layer.tile_set == null or terrain_set < 0 or terrain_set >= layer.tile_set.get_terrain_sets_count():
		_errors.append("Operation %d references an invalid terrain set" % index)
		return
	if terrain < 0 or terrain >= layer.tile_set.get_terrains_count(terrain_set):
		_errors.append("Operation %d references an invalid terrain" % index)
		return
	layer.set_cells_terrain_connect(cells, terrain_set, terrain)
	_changes.append({"op": "terrain_connect", "layer": str(layer.layer_id), "count": cells.size(), "terrain_set": terrain_set, "terrain": terrain})


func _place_asset(operation: Dictionary, index: int) -> void:
	if _map.profile == null or _map.profile.asset_library == null:
		_errors.append("Operation %d cannot place assets without a library" % index)
		return
	var asset_id := StringName(str(operation.get("asset", "")))
	var entry := _map.profile.asset_library.get_entry(asset_id)
	if entry == null:
		_errors.append("Operation %d references unknown asset: %s" % [index, asset_id])
		return
	var layer_id := StringName(str(operation.get("layer", entry.default_layer_id)))
	var layer := _map.get_layer(layer_id) as Node2D
	var spec := _map.get_layer_spec(layer_id)
	if layer == null or spec == null or not spec.accepts_asset_kind(entry.kind):
		_errors.append("Operation %d asset %s is not allowed on layer %s" % [index, asset_id, layer_id])
		return
	if not _layer_editable(layer, index):
		return
	var position_value: Variant = _position(operation.get("at", null), str(operation.get("space", "world")), index)
	if position_value == null:
		return
	var position: Vector2 = position_value
	if not _world_allowed(position, index):
		return
	var node: Node2D
	if entry.kind == MapAssetEntry.AssetKind.DECORATION:
		node = MapDecoration2D.new()
		node.configure(entry)
	elif entry.kind == MapAssetEntry.AssetKind.SCENE:
		node = (entry.resource as PackedScene).instantiate() as Node2D
	else:
		_errors.append("Operation %d cannot place a TileSet as a node" % index)
		return
	if node == null:
		_errors.append("Operation %d asset is not a Node2D scene" % index)
		return
	node.name = _unique_child_name(layer, str(operation.get("name", str(asset_id).to_pascal_case())))
	node.position = position
	node.set_meta("map_asset_id", asset_id)
	var properties: Variant = operation.get("properties", {})
	if not properties is Dictionary:
		_errors.append("Operation %d properties must be an object" % index)
		node.free()
		return
	for property_name in properties:
		if str(property_name) not in entry.exposed_properties:
			_errors.append("Operation %d property is not whitelisted for %s: %s" % [index, asset_id, property_name])
			continue
		node.set(property_name, properties[property_name])
	layer.add_child(node)
	# Keep PackedScene internals owned by their original scene so the saved map
	# stores an instance plus overrides instead of flattening the full subtree.
	node.owner = _map
	_changes.append({"op": "place_asset", "asset": str(asset_id), "path": str(_map.get_path_to(node)), "position": [position.x, position.y]})


func _move_node(operation: Dictionary, index: int) -> void:
	var node := _editable_child(operation, index)
	if node == null:
		return
	var position_value: Variant = _position(operation.get("to", null), str(operation.get("space", "world")), index)
	if position_value == null:
		return
	var position: Vector2 = position_value
	if not _world_allowed(position, index):
		return
	node.position = position
	_changes.append({"op": "move_node", "path": str(_map.get_path_to(node)), "position": [position.x, position.y]})


func _remove_node(operation: Dictionary, index: int) -> void:
	var node := _editable_child(operation, index)
	if node == null:
		return
	if not _world_allowed(node.position, index):
		return
	var path := str(_map.get_path_to(node))
	node.get_parent().remove_child(node)
	node.free()
	_changes.append({"op": "remove_node", "path": path})


func _add_collision(operation: Dictionary, op: String, index: int) -> void:
	var layer := _map.get_layer(&"collision") as MapLayer2D
	if layer == null or not _layer_editable(layer, index):
		_errors.append("Operation %d requires a collision layer" % index)
		return
	var preset_id := StringName(str(operation.get("preset", "world_solid")))
	var preset := _map.profile.get_collision_preset(preset_id) if _map.profile != null else null
	if preset == null:
		_errors.append("Operation %d references unknown collision preset: %s" % [index, preset_id])
		return
	var body := MapCollisionBody2D.new()
	body.name = _unique_child_name(layer, str(operation.get("name", "AgentCollision")))
	body.preset = preset
	if op == "collision_polygon":
		var points := PackedVector2Array()
		for value in operation.get("points", []):
			var point_value: Variant = _position(value, str(operation.get("space", "world")), index)
			if point_value != null:
				points.append(point_value as Vector2)
		if points.size() < 3:
			_errors.append("Operation %d collision polygon needs at least three points" % index)
			body.free()
			return
		for point in points:
			if not _world_allowed(point, index):
				body.free()
				return
		var center := Vector2.ZERO
		for point in points:
			center += point
		center /= points.size()
		body.position = center
		var polygon := CollisionPolygon2D.new()
		polygon.name = "CollisionPolygon2D"
		for point in points:
			polygon.polygon.append(point - center)
		body.add_child(polygon)
	else:
		var position_value: Variant = _position(operation.get("at", null), str(operation.get("space", "world")), index)
		if position_value == null:
			body.free()
			return
		var position: Vector2 = position_value
		if not _world_allowed(position, index):
			body.free()
			return
		body.position = position
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		if op == "collision_circle":
			var circle := CircleShape2D.new()
			circle.radius = float(operation.get("radius", 0.0))
			if circle.radius <= 0.0:
				_errors.append("Operation %d collision radius must be positive" % index)
				body.free()
				return
			if not _world_rect_allowed(Rect2(position - Vector2.ONE * circle.radius, Vector2.ONE * circle.radius * 2.0), index):
				body.free()
				return
			shape_node.shape = circle
		else:
			var size_value: Variant = _vector2(operation.get("size", null), "operation %d size" % index)
			if size_value == null:
				body.free()
				return
			var size: Vector2 = size_value
			if size.x <= 0.0 or size.y <= 0.0:
				_errors.append("Operation %d collision size must be positive" % index)
				body.free()
				return
			if not _world_rect_allowed(Rect2(position - size / 2.0, size), index):
				body.free()
				return
			var rectangle := RectangleShape2D.new()
			rectangle.size = size
			shape_node.shape = rectangle
		body.add_child(shape_node)
	body.apply_preset()
	layer.add_child(body)
	_set_owner_recursive(body, _map)
	_changes.append({"op": op, "path": str(_map.get_path_to(body)), "preset": str(preset_id)})


func _add_marker(operation: Dictionary, index: int) -> void:
	var layer := _map.get_layer(&"markers") as MapLayer2D
	if layer == null or not _layer_editable(layer, index):
		_errors.append("Operation %d requires a markers layer" % index)
		return
	var marker_id := StringName(str(operation.get("id", "")))
	if marker_id.is_empty():
		_errors.append("Operation %d marker id cannot be empty" % index)
		return
	var marker := _map.get_marker(marker_id)
	if marker != null and not bool(operation.get("replace", false)):
		_errors.append("Operation %d marker already exists: %s" % [index, marker_id])
		return
	var position_value: Variant = _position(operation.get("at", null), str(operation.get("space", "world")), index)
	if position_value == null:
		return
	var position: Vector2 = position_value
	if not _world_allowed(position, index):
		return
	if marker == null:
		marker = MapMarker2D.new()
		marker.name = _unique_child_name(layer, str(marker_id).to_pascal_case())
		marker.marker_id = marker_id
		layer.add_child(marker)
		_set_owner_recursive(marker, _map)
	marker.position = position
	var kind := str(operation.get("kind", "anchor")).to_lower()
	marker.marker_kind = {
		"spawn": MapMarker2D.MarkerKind.SPAWN,
		"transition": MapMarker2D.MarkerKind.TRANSITION,
		"anchor": MapMarker2D.MarkerKind.ANCHOR,
	}.get(kind, MapMarker2D.MarkerKind.ANCHOR)
	marker.target_scene = str(operation.get("target_scene", marker.target_scene))
	marker.target_marker = StringName(str(operation.get("target_marker", marker.target_marker)))
	_changes.append({"op": "marker", "id": str(marker_id), "path": str(_map.get_path_to(marker)), "position": [position.x, position.y]})


func _set_layer(operation: Dictionary, index: int) -> void:
	var layer_id := StringName(str(operation.get("layer", "")))
	var layer := _map.get_layer(layer_id) as Node2D
	if layer == null:
		_errors.append("Operation %d references unknown layer: %s" % [index, layer_id])
		return
	if operation.has("visible"):
		layer.visible = bool(operation.visible)
	if operation.has("locked"):
		layer.locked = bool(operation.locked)
	if operation.has("opacity"):
		var color := layer.modulate
		color.a = clampf(float(operation.opacity), 0.0, 1.0)
		layer.modulate = color
	if operation.has("y_sort"):
		layer.y_sort_enabled = bool(operation.y_sort)
	if operation.has("z_index"):
		layer.z_index = int(operation.z_index)
	_changes.append({"op": "set_layer", "layer": str(layer_id)})


func _load_map(scene_path: String) -> Dictionary:
	_reset()
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return _failure("Cannot load map scene: %s" % scene_path)
	_map = packed.instantiate() as EditableMap2D
	if _map == null:
		return _failure("Scene root is not EditableMap2D: %s" % scene_path)
	_scene_path = scene_path
	return _base_result(true)


func _save_map(path: String) -> Dictionary:
	var packed := PackedScene.new()
	var pack_error := packed.pack(_map)
	if pack_error != OK:
		return _failure("Cannot pack map scene: %s" % error_string(pack_error))
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		return _failure("Cannot save map scene %s: %s" % [path, error_string(save_error)])
	var result := _base_result(true)
	result["output_path"] = path
	return result


func _catalog() -> Dictionary:
	var result := {"assets": [], "collision_presets": [], "tilesets": []}
	if _map.profile == null:
		return result
	if _map.profile.asset_library != null:
		for entry in _map.profile.asset_library.entries:
			if entry == null:
				continue
			result.assets.append({
				"id": str(entry.asset_id),
				"name": entry.display_name,
				"kind": MapAssetEntry.AssetKind.keys()[entry.kind].to_lower(),
				"resource": entry.resource.resource_path if entry.resource != null else "",
				"tags": Array(entry.tags),
				"default_layer": str(entry.default_layer_id),
				"footprint": [entry.footprint.x, entry.footprint.y],
				"editable_properties": Array(entry.exposed_properties),
			})
			if entry.kind == MapAssetEntry.AssetKind.TILE_SET:
				result.tilesets.append(_tileset_catalog(entry.asset_id, entry.resource as TileSet))
	for preset in _map.profile.collision_presets:
		if preset != null:
			result.collision_presets.append({
				"id": str(preset.preset_id),
				"name": preset.display_name,
				"layer": preset.collision_layer,
				"mask": preset.collision_mask,
				"one_way": preset.one_way,
			})
	return result


func _tileset_catalog(asset_id: StringName, tile_set: TileSet) -> Dictionary:
	var result := {"asset": str(asset_id), "tile_size": [], "sources": [], "terrain_sets": []}
	if tile_set == null:
		return result
	result.tile_size = [tile_set.tile_size.x, tile_set.tile_size.y]
	for source_index in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(source_index)
		var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
		var tiles: Array = []
		if atlas != null:
			for tile_index in range(atlas.get_tiles_count()):
				var coords := atlas.get_tile_id(tile_index)
				tiles.append([coords.x, coords.y])
		result.sources.append({"source": source_id, "tiles": tiles})
	for terrain_set in range(tile_set.get_terrain_sets_count()):
		var terrains: Array[String] = []
		for terrain in range(tile_set.get_terrains_count(terrain_set)):
			terrains.append(tile_set.get_terrain_name(terrain_set, terrain))
		result.terrain_sets.append({"index": terrain_set, "terrains": terrains})
	return result


func _validation_dictionaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue in _map.validate():
		result.append(issue.to_dictionary())
	return result


func _tile_layer(operation: Dictionary, index: int) -> MapTileLayer:
	var layer_id := StringName(str(operation.get("layer", "")))
	var layer := _map.get_layer(layer_id) as MapTileLayer
	if layer == null:
		_errors.append("Operation %d requires a tile layer: %s" % [index, layer_id])
		return null
	if not _layer_editable(layer, index):
		return null
	return layer


func _layer_editable(layer: Node, index: int) -> bool:
	if not _allow_locked_layers and bool(layer.get("locked")):
		_errors.append("Operation %d cannot edit locked layer: %s" % [index, layer.get("layer_id")])
		return false
	return true


func _tile_state(value: Variant, index: int) -> Dictionary:
	if not value is Dictionary:
		_errors.append("Operation %d tile must be an object" % index)
		return {}
	var atlas_value: Variant = _vector2i(value.get("atlas", null), "operation %d tile atlas" % index)
	if atlas_value == null:
		return {}
	return {"source": int(value.get("source", 0)), "atlas": atlas_value as Vector2i, "alternative": int(value.get("alternative", 0))}


func _editable_child(operation: Dictionary, index: int) -> Node2D:
	var path := NodePath(str(operation.get("path", "")))
	var node := _map.get_node_or_null(path) as Node2D
	if node == null or node == _map or node is MapTileLayer or node is MapLayer2D or not node.get_parent() is MapLayer2D:
		_errors.append("Operation %d path is not an editable map child: %s" % [index, path])
		return null
	if node.get_parent() != null and not _layer_editable(node.get_parent(), index):
		return null
	return node


func _configure_allowed_region(value: Variant) -> void:
	_has_allowed_region = false
	if value == null:
		return
	if not value is Dictionary:
		_errors.append("allowed_region must be an object in tile coordinates")
		return
	var position := Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	var size := Vector2i(int(value.get("width", 0)), int(value.get("height", 0)))
	if size.x <= 0 or size.y <= 0:
		_errors.append("allowed_region width and height must be positive")
		return
	_allowed_region = Rect2i(position, size)
	var map_rect := Rect2i(Vector2i.ZERO, _map.size_in_tiles)
	if not map_rect.encloses(_allowed_region):
		_errors.append("allowed_region must be fully inside the map")
		return
	_has_allowed_region = true


func _cell_allowed(cell: Vector2i, index: int) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _map.size_in_tiles.x or cell.y >= _map.size_in_tiles.y:
		_errors.append("Operation %d cell is outside the map: %s" % [index, cell])
		return false
	if _has_allowed_region and not _allowed_region.has_point(cell):
		_errors.append("Operation %d cell is outside allowed_region: %s" % [index, cell])
		return false
	return true


func _world_allowed(position: Vector2, index: int) -> bool:
	var cell := Vector2i(floori(position.x / _map.tile_size.x), floori(position.y / _map.tile_size.y))
	return _cell_allowed(cell, index)


func _world_rect_allowed(rect: Rect2, index: int) -> bool:
	var epsilon := Vector2(0.001, 0.001)
	return _world_allowed(rect.position, index) and _world_allowed(rect.end - epsilon, index)


func _tile_exists(layer: MapTileLayer, tile: Dictionary, index: int) -> bool:
	if layer.tile_set == null or not layer.tile_set.has_source(int(tile.source)):
		_errors.append("Operation %d tile source does not exist: %s" % [index, tile.source])
		return false
	var atlas := layer.tile_set.get_source(int(tile.source)) as TileSetAtlasSource
	if atlas == null or not atlas.has_tile(tile.atlas):
		_errors.append("Operation %d atlas tile does not exist: %s" % [index, tile.atlas])
		return false
	if int(tile.alternative) != 0 and not atlas.has_alternative_tile(tile.atlas, int(tile.alternative)):
		_errors.append("Operation %d alternative tile does not exist: %s" % [index, tile.alternative])
		return false
	return true


func _position(value: Variant, space: String, index: int) -> Variant:
	var position_value: Variant = _vector2(value, "operation %d position" % index)
	if position_value == null:
		return null
	var position: Vector2 = position_value
	if space == "tile":
		return Vector2(position.x * _map.tile_size.x + _map.tile_size.x / 2.0, position.y * _map.tile_size.y + _map.tile_size.y / 2.0)
	if space != "world":
		_errors.append("Operation %d space must be world or tile" % index)
		return null
	return position


func _vector2(value: Variant, label: String) -> Variant:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(float(value.x), float(value.y))
	_errors.append("%s must be [x, y] or {x, y}" % label)
	return null


func _vector2i(value: Variant, label: String) -> Variant:
	var vector_value: Variant = _vector2(value, label)
	if vector_value == null:
		return null
	var vector: Vector2 = vector_value
	return Vector2i(int(vector.x), int(vector.y))


func _unique_child_name(parent: Node, base: String) -> String:
	var safe_base := base.validate_node_name()
	if safe_base.is_empty():
		safe_base = "MapNode"
	var candidate := safe_base
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [safe_base, suffix]
		suffix += 1
	return candidate


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)


func _base_result(ok: bool) -> Dictionary:
	return {"ok": ok, "api_version": API_VERSION}


func _failure(message: String) -> Dictionary:
	var result := _base_result(false)
	result["errors"] = [message]
	return result


func _reset() -> void:
	_free_map()
	_scene_path = ""
	_allowed_region = Rect2i()
	_has_allowed_region = false
	_allow_locked_layers = false
	_errors.clear()
	_changes.clear()


func _free_map() -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	_map = null
