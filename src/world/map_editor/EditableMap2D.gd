@tool
extends Node2D
class_name EditableMap2D

@export var map_id: StringName
@export var display_name: String
@export var size_in_tiles: Vector2i = Vector2i(50, 35)
@export var tile_size: Vector2i = Vector2i(64, 64)
@export var profile: MapProfile
@export_range(1.0, 512.0, 1.0) var world_boundary_thickness: float = 48.0


func get_layer(layer_id: StringName) -> Node:
	for child in get_children():
		if child is MapTileLayer and child.layer_id == layer_id:
			return child
		if child is MapLayer2D and child.layer_id == layer_id:
			return child
	return null


func get_layer_spec(layer_id: StringName) -> MapLayerSpec:
	if profile != null:
		var profile_spec := profile.get_layer_spec(layer_id)
		if profile_spec != null:
			return profile_spec
	var layer := get_layer(layer_id)
	if layer == null:
		return null
	var spec := MapLayerSpec.new()
	spec.layer_id = layer_id
	spec.display_name = str(layer_id).to_pascal_case()
	spec.required = false
	if layer is MapTileLayer:
		spec.kind = MapLayerSpec.LayerKind.TILE
	else:
		spec.kind = (layer as MapLayer2D).layer_kind
	spec.default_z_index = layer.z_index
	spec.y_sort = layer.y_sort_enabled
	return spec


func get_marker(marker_id: StringName) -> MapMarker2D:
	var marker_layer := _get_marker_layer()
	if marker_layer == null:
		return null
	for child in marker_layer.get_children():
		if child is MapMarker2D and child.marker_id == marker_id:
			return child
	return null


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_in_tiles * tile_size))


func get_global_world_rect() -> Rect2:
	var local_rect := get_world_rect()
	var corners := [
		to_global(local_rect.position),
		to_global(Vector2(local_rect.end.x, local_rect.position.y)),
		to_global(local_rect.end),
		to_global(Vector2(local_rect.position.x, local_rect.end.y)),
	]
	var result := Rect2(corners[0], Vector2.ZERO)
	for index in range(1, corners.size()):
		result = result.expand(corners[index])
	return result


func apply_camera_limits(camera: Camera2D) -> void:
	if camera == null:
		return
	var bounds := get_global_world_rect()
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()


func camera_limits_match(camera: Camera2D) -> bool:
	if camera == null:
		return false
	var bounds := get_global_world_rect()
	return (
		camera.limit_left == floori(bounds.position.x)
		and camera.limit_top == floori(bounds.position.y)
		and camera.limit_right == ceili(bounds.end.x)
		and camera.limit_bottom == ceili(bounds.end.y)
	)


func rebuild_world_boundaries() -> bool:
	var collision_layer := get_layer(&"collision") as MapLayer2D
	if collision_layer == null or world_boundary_thickness <= 0.0:
		return false
	var by_side := {}
	var duplicates: Array[MapCollisionBody2D] = []
	for child in collision_layer.get_children():
		if not child is MapCollisionBody2D or not child.is_world_boundary:
			continue
		var side := _boundary_side_for(child)
		if side == MapCollisionBody2D.BoundarySide.NONE or by_side.has(side):
			duplicates.append(child)
		else:
			by_side[side] = child
	for duplicate in duplicates:
		collision_layer.remove_child(duplicate)
		duplicate.free()

	var preset := profile.get_collision_preset(&"world_solid") if profile != null else null
	for side in [
		MapCollisionBody2D.BoundarySide.NORTH,
		MapCollisionBody2D.BoundarySide.SOUTH,
		MapCollisionBody2D.BoundarySide.WEST,
		MapCollisionBody2D.BoundarySide.EAST,
	]:
		var body: MapCollisionBody2D = by_side.get(side) as MapCollisionBody2D
		if body == null:
			body = MapCollisionBody2D.new()
			collision_layer.add_child(body)
		body.name = _boundary_name(side)
		body.is_world_boundary = true
		body.boundary_side = side
		body.preset = preset
		var geometry := _expected_boundary_geometry(side)
		body.position = geometry.position
		var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			shape_node = CollisionShape2D.new()
			shape_node.name = "CollisionShape2D"
			body.add_child(shape_node)
		var rectangle := shape_node.shape as RectangleShape2D
		if rectangle == null:
			rectangle = RectangleShape2D.new()
			shape_node.shape = rectangle
		rectangle.size = geometry.size
		body.apply_preset()
		body.owner = self
		shape_node.owner = self
	return true


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	if map_id.is_empty():
		issues.append(_issue(&"map_id_missing", "地图缺少 map_id", self))
	if size_in_tiles.x <= 0 or size_in_tiles.y <= 0:
		issues.append(_issue(&"map_size_invalid", "地图格子尺寸必须为正数", self))
	if tile_size.x <= 0 or tile_size.y <= 0:
		issues.append(_issue(&"tile_size_invalid", "瓦片尺寸必须为正数", self))
	if world_boundary_thickness <= 0.0:
		issues.append(_issue(&"world_boundary_thickness_invalid", "World boundary thickness must be positive", self))
	if profile == null:
		issues.append(_issue(&"profile_missing", "地图未配置 MapProfile", self))
		return issues

	_validate_profile_layers(issues)
	_validate_assets(issues)
	_validate_markers(issues)
	_validate_collisions(issues)
	return issues


func _validate_profile_layers(issues: Array[MapValidationIssue]) -> void:
	var seen_ids := {}
	for child in get_children():
		var child_layer_id: StringName
		var actual_kind := -1
		if child is MapTileLayer:
			child_layer_id = child.layer_id
			actual_kind = MapLayerSpec.LayerKind.TILE
		elif child is MapLayer2D:
			child_layer_id = child.layer_id
			actual_kind = child.layer_kind
		else:
			continue
		if child_layer_id.is_empty():
			issues.append(_issue(&"layer_id_missing", "图层缺少 layer_id", child))
			continue
		if seen_ids.has(child_layer_id):
			issues.append(_issue(&"layer_id_duplicate", "图层 ID 重复: %s" % child_layer_id, child))
		seen_ids[child_layer_id] = true
		var spec := profile.get_layer_spec(child_layer_id)
		if spec == null:
			issues.append(_issue(&"layer_not_in_profile", "Profile 未声明图层: %s" % child_layer_id, child, MapValidationIssue.Severity.WARNING))
		elif spec.kind != actual_kind:
			issues.append(_issue(&"layer_kind_mismatch", "图层 %s 的节点类型与 Profile 不符" % child_layer_id, child))
		if child is MapTileLayer:
			_validate_tile_layer(child, issues)

	for spec in profile.layer_specs:
		if spec != null and spec.required and not seen_ids.has(spec.layer_id):
			issues.append(_issue(&"required_layer_missing", "缺少必需图层: %s" % spec.layer_id, self))


func _validate_tile_layer(layer: MapTileLayer, issues: Array[MapValidationIssue]) -> void:
	if layer.tile_set == null:
		issues.append(_issue(&"tileset_missing", "瓦片图层 %s 未配置 TileSet" % layer.layer_id, layer))
		return
	for cell in layer.get_used_cells():
		if cell.x < 0 or cell.y < 0 or cell.x >= size_in_tiles.x or cell.y >= size_in_tiles.y:
			issues.append(_issue(&"tile_out_of_bounds", "瓦片超出地图边界: %s" % cell, layer))
			break
		if layer.get_cell_source_id(cell) < 0:
			issues.append(_issue(&"tile_source_invalid", "瓦片引用了无效 source: %s" % cell, layer))
			break


func _validate_assets(issues: Array[MapValidationIssue]) -> void:
	if profile.asset_library == null:
		issues.append(_issue(&"asset_library_missing", "Profile 未配置地图资源库", self))
		return
	var seen_ids := {}
	for entry in profile.asset_library.entries:
		if entry == null or not entry.is_valid_entry():
			issues.append(_issue(&"asset_entry_invalid", "资源库存在无效条目", self))
			continue
		if seen_ids.has(entry.asset_id):
			issues.append(_issue(&"asset_id_duplicate", "资源 ID 重复: %s" % entry.asset_id, self))
		seen_ids[entry.asset_id] = true


func _validate_markers(issues: Array[MapValidationIssue]) -> void:
	var marker_layer := _get_marker_layer()
	var seen_ids := {}
	if marker_layer != null:
		for child in marker_layer.get_children():
			if not child is MapMarker2D:
				continue
			if child.marker_id.is_empty():
				issues.append(_issue(&"marker_id_missing", "标记缺少 marker_id", child))
			elif seen_ids.has(child.marker_id):
				issues.append(_issue(&"marker_id_duplicate", "标记 ID 重复: %s" % child.marker_id, child))
			else:
				seen_ids[child.marker_id] = true
			if not get_world_rect().has_point(child.position):
				issues.append(_issue(&"marker_out_of_bounds", "标记超出地图边界: %s" % child.marker_id, child, MapValidationIssue.Severity.WARNING))
	for required_id in profile.required_marker_ids:
		if not seen_ids.has(StringName(required_id)):
			issues.append(_issue(&"required_marker_missing", "缺少必需标记: %s" % required_id, self))


func _validate_collisions(issues: Array[MapValidationIssue]) -> void:
	var collision_layer := get_layer(&"collision")
	if collision_layer == null:
		return
	var boundary_sides := {}
	var signatures := {}
	for child in collision_layer.get_children():
		if not child is MapCollisionBody2D:
			continue
		if child.is_world_boundary:
			var side := _boundary_side_for(child)
			if side == MapCollisionBody2D.BoundarySide.NONE:
				issues.append(_issue(&"world_boundary_side_missing", "World boundary has no recognized side", child))
			elif boundary_sides.has(side):
				issues.append(_issue(&"world_boundary_duplicate", "Duplicate world boundary: %s" % _boundary_name(side), child))
			else:
				boundary_sides[side] = child
				_validate_boundary_geometry(child, side, issues)
		if child.collision_layer == 0 and child.collision_mask == 0:
			issues.append(_issue(&"collision_bits_empty", "碰撞体的 layer 和 mask 均为 0", child))
		var valid_shape_count := 0
		for shape_node in child.get_children():
			if shape_node is CollisionShape2D:
				if shape_node.shape == null:
					issues.append(_issue(&"collision_shape_empty", "CollisionShape2D 未配置 Shape", shape_node))
				else:
					valid_shape_count += 1
					if not _shape_intersects_map(child, shape_node):
						issues.append(_issue(&"collision_out_of_bounds", "碰撞形状完全位于地图边界之外", child))
					var signature := "%s|%s|%s" % [child.position, shape_node.shape.get_class(), _shape_signature(shape_node.shape)]
					if signatures.has(signature):
						issues.append(_issue(&"collision_duplicate", "发现重复碰撞形状", child, MapValidationIssue.Severity.WARNING))
					signatures[signature] = true
			elif shape_node is CollisionPolygon2D:
				if shape_node.polygon.size() < 3 or _polygon_self_intersects(shape_node.polygon):
					issues.append(_issue(&"collision_polygon_invalid", "碰撞多边形至少需要 3 个点且不能自相交", shape_node))
				else:
					valid_shape_count += 1
					if not _polygon_intersects_map(child, shape_node):
						issues.append(_issue(&"collision_out_of_bounds", "碰撞多边形完全位于地图边界之外", child))
		if valid_shape_count == 0:
			issues.append(_issue(&"collision_body_empty", "碰撞体不包含有效形状", child))
	for side in [
		MapCollisionBody2D.BoundarySide.NORTH,
		MapCollisionBody2D.BoundarySide.SOUTH,
		MapCollisionBody2D.BoundarySide.WEST,
		MapCollisionBody2D.BoundarySide.EAST,
	]:
		if not boundary_sides.has(side):
			issues.append(_issue(&"world_boundary_missing", "Missing world boundary: %s" % _boundary_name(side), collision_layer))


func _validate_boundary_geometry(
	body: MapCollisionBody2D,
	side: MapCollisionBody2D.BoundarySide,
	issues: Array[MapValidationIssue]
) -> void:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := shape_node.shape as RectangleShape2D if shape_node != null else null
	if rectangle == null:
		issues.append(_issue(&"world_boundary_geometry", "World boundary must use a RectangleShape2D", body))
		return
	var expected := _expected_boundary_geometry(side)
	if not body.position.is_equal_approx(expected.position) or not rectangle.size.is_equal_approx(expected.size):
		issues.append(_issue(
			&"world_boundary_geometry",
			"World boundary %s does not match map size" % _boundary_name(side),
			body
		))


func _expected_boundary_geometry(side: MapCollisionBody2D.BoundarySide) -> Dictionary:
	var map_size := get_world_rect().size
	var half := world_boundary_thickness / 2.0
	match side:
		MapCollisionBody2D.BoundarySide.NORTH:
			return {"position": Vector2(map_size.x / 2.0, -half), "size": Vector2(map_size.x, world_boundary_thickness)}
		MapCollisionBody2D.BoundarySide.SOUTH:
			return {"position": Vector2(map_size.x / 2.0, map_size.y + half), "size": Vector2(map_size.x, world_boundary_thickness)}
		MapCollisionBody2D.BoundarySide.WEST:
			return {"position": Vector2(-half, map_size.y / 2.0), "size": Vector2(world_boundary_thickness, map_size.y)}
		MapCollisionBody2D.BoundarySide.EAST:
			return {"position": Vector2(map_size.x + half, map_size.y / 2.0), "size": Vector2(world_boundary_thickness, map_size.y)}
	return {"position": Vector2.ZERO, "size": Vector2.ZERO}


func _boundary_side_for(body: MapCollisionBody2D) -> MapCollisionBody2D.BoundarySide:
	if body.boundary_side != MapCollisionBody2D.BoundarySide.NONE:
		return body.boundary_side
	return {
		"NorthBoundary": MapCollisionBody2D.BoundarySide.NORTH,
		"SouthBoundary": MapCollisionBody2D.BoundarySide.SOUTH,
		"WestBoundary": MapCollisionBody2D.BoundarySide.WEST,
		"EastBoundary": MapCollisionBody2D.BoundarySide.EAST,
	}.get(body.name, MapCollisionBody2D.BoundarySide.NONE)


func _boundary_name(side: MapCollisionBody2D.BoundarySide) -> String:
	return {
		MapCollisionBody2D.BoundarySide.NORTH: "NorthBoundary",
		MapCollisionBody2D.BoundarySide.SOUTH: "SouthBoundary",
		MapCollisionBody2D.BoundarySide.WEST: "WestBoundary",
		MapCollisionBody2D.BoundarySide.EAST: "EastBoundary",
	}.get(side, "WorldBoundary")


func _shape_signature(shape: Shape2D) -> String:
	if shape is RectangleShape2D:
		return str(shape.size)
	if shape is CircleShape2D:
		return str(shape.radius)
	if shape is CapsuleShape2D:
		return "%s|%s" % [shape.radius, shape.height]
	return shape.get_class()


func _shape_intersects_map(body: MapCollisionBody2D, shape_node: CollisionShape2D) -> bool:
	var center := body.position + shape_node.position
	var bounds := Rect2(center - Vector2.ONE, Vector2.ONE * 2.0)
	if shape_node.shape is RectangleShape2D:
		bounds = Rect2(center - shape_node.shape.size / 2.0, shape_node.shape.size)
	elif shape_node.shape is CircleShape2D:
		var radius: float = shape_node.shape.radius
		bounds = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	elif shape_node.shape is CapsuleShape2D:
		var capsule_size := Vector2(shape_node.shape.radius * 2.0, shape_node.shape.height)
		bounds = Rect2(center - capsule_size / 2.0, capsule_size)
	return get_world_rect().intersects(bounds, true)


func _polygon_intersects_map(body: MapCollisionBody2D, polygon_node: CollisionPolygon2D) -> bool:
	var bounds := Rect2()
	for index in range(polygon_node.polygon.size()):
		var point := body.position + polygon_node.position + polygon_node.polygon[index]
		if index == 0:
			bounds = Rect2(point, Vector2.ZERO)
		else:
			bounds = bounds.expand(point)
	return get_world_rect().intersects(bounds, true) or get_world_rect().has_point(bounds.position)


func _polygon_self_intersects(points: PackedVector2Array) -> bool:
	var count := points.size()
	for first in range(count):
		var first_next := (first + 1) % count
		for second in range(first + 1, count):
			var second_next := (second + 1) % count
			if first == second or first_next == second or second_next == first:
				continue
			if Geometry2D.segment_intersects_segment(
				points[first], points[first_next], points[second], points[second_next]
			) != null:
				return true
	return false


func _get_marker_layer() -> MapLayer2D:
	var layer := get_layer(&"markers")
	return layer as MapLayer2D


func _issue(
	code: StringName,
	message: String,
	node: Node,
	severity: MapValidationIssue.Severity = MapValidationIssue.Severity.ERROR
) -> MapValidationIssue:
	var path := get_path_to(node) if node != self else NodePath(".")
	return MapValidationIssue.new(code, severity, message, path)
