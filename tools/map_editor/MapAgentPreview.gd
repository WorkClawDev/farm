extends RefCounted
class_name MapAgentPreview


func render_map(scene_path: String, output_path: String, width: int = 1280, height: int = 896) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {"ok": false, "errors": ["Cannot load map scene: %s" % scene_path]}
	var map := packed.instantiate() as EditableMap2D
	if map == null:
		return {"ok": false, "errors": ["Scene root is not EditableMap2D: %s" % scene_path]}
	width = clampi(width, 64, 4096)
	height = clampi(height, 64, 4096)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color("18221b"))
	var map_pixels := Vector2(map.size_in_tiles * map.tile_size)
	var scale_factor := minf(float(width) / map_pixels.x, float(height) / map_pixels.y)
	var offset := (Vector2(width, height) - map_pixels * scale_factor) / 2.0
	_draw_tile_layers(image, map, scale_factor, offset)
	_draw_node_layers(image, map, scale_factor, offset)
	_draw_grid(image, map, scale_factor, offset)
	var absolute_path := ProjectSettings.globalize_path(output_path) if output_path.begins_with("res://") or output_path.begins_with("user://") else output_path
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		map.free()
		return {"ok": false, "errors": ["Cannot create preview directory: %s" % error_string(directory_error)]}
	var save_error := image.save_png(absolute_path)
	map.free()
	return {
		"ok": save_error == OK,
		"preview_type": "semantic",
		"output_path": output_path,
		"size": [width, height],
		"errors": [] if save_error == OK else ["Cannot save preview: %s" % error_string(save_error)],
	}


func _draw_tile_layers(image: Image, map: EditableMap2D, scale_factor: float, offset: Vector2) -> void:
	for child in map.get_children():
		if not child is MapTileLayer or not child.visible:
			continue
		var tile_layer := child as MapTileLayer
		for cell in tile_layer.get_used_cells():
			var atlas: Vector2i = tile_layer.get_cell_atlas_coords(cell)
			var color := _tile_color(tile_layer.layer_id, tile_layer.get_cell_source_id(cell), atlas)
			var rect := _cell_rect(map, cell, scale_factor, offset)
			image.fill_rect(rect, color)


func _draw_node_layers(image: Image, map: EditableMap2D, scale_factor: float, offset: Vector2) -> void:
	for child in map.get_children():
		if not child is MapLayer2D or not child.visible:
			continue
		match child.layer_kind:
			MapLayerSpec.LayerKind.OBJECT, MapLayerSpec.LayerKind.DECORATION:
				for node in child.get_children():
					if node is Node2D and node.visible:
						var position := _screen_point(node.position, scale_factor, offset)
						var radius := maxi(3, int(18.0 * scale_factor))
						image.fill_rect(Rect2i(Vector2i(position) - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2)), Color("f1a34b"))
			MapLayerSpec.LayerKind.COLLISION:
				_draw_collisions(image, child, scale_factor, offset)
			MapLayerSpec.LayerKind.MARKER:
				for node in child.get_children():
					if node is MapMarker2D:
						var position := Vector2i(_screen_point(node.position, scale_factor, offset))
						_draw_cross(image, position, Color("5de7e7"), 5)


func _draw_collisions(image: Image, layer: MapLayer2D, scale_factor: float, offset: Vector2) -> void:
	for body in layer.get_children():
		if not body is MapCollisionBody2D:
			continue
		var collision_body := body as MapCollisionBody2D
		for shape_node in collision_body.get_children():
			var bounds := Rect2(collision_body.position, Vector2.ZERO)
			if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
				bounds = Rect2(collision_body.position + shape_node.position - shape_node.shape.size / 2.0, shape_node.shape.size)
			elif shape_node is CollisionShape2D and shape_node.shape is CircleShape2D:
				var radius: float = shape_node.shape.radius
				bounds = Rect2(collision_body.position + shape_node.position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			elif shape_node is CollisionPolygon2D and not shape_node.polygon.is_empty():
				for point_index in range(shape_node.polygon.size()):
					var point: Vector2 = collision_body.position + shape_node.position + shape_node.polygon[point_index]
					bounds = Rect2(point, Vector2.ZERO) if point_index == 0 else bounds.expand(point)
			else:
				continue
			var screen_rect := Rect2i(
				Vector2i(_screen_point(bounds.position, scale_factor, offset)),
				Vector2i(maxf(1.0, bounds.size.x * scale_factor), maxf(1.0, bounds.size.y * scale_factor))
			)
			_draw_rect_outline(image, screen_rect, Color("e85151"))


func _draw_grid(image: Image, map: EditableMap2D, scale_factor: float, offset: Vector2) -> void:
	var cell_width := float(map.tile_size.x) * scale_factor
	var cell_height := float(map.tile_size.y) * scale_factor
	if cell_width < 6.0 or cell_height < 6.0:
		return
	var color := Color("49614d")
	for x in range(map.size_in_tiles.x + 1):
		var screen_x := int(offset.x + x * cell_width)
		if screen_x >= 0 and screen_x < image.get_width():
			image.fill_rect(Rect2i(screen_x, maxi(0, int(offset.y)), 1, mini(image.get_height(), int(map.size_in_tiles.y * cell_height))), color)
	for y in range(map.size_in_tiles.y + 1):
		var screen_y := int(offset.y + y * cell_height)
		if screen_y >= 0 and screen_y < image.get_height():
			image.fill_rect(Rect2i(maxi(0, int(offset.x)), screen_y, mini(image.get_width(), int(map.size_in_tiles.x * cell_width)), 1), color)


func _tile_color(layer_id: StringName, source_id: int, atlas: Vector2i) -> Color:
	if layer_id == &"ground":
		match atlas.x:
			22: return Color("b98b52")
			23: return Color("8b5b37")
			24: return Color("7d7767")
			1, 2: return Color("68a950")
			_: return Color("74b85c")
	if atlas.x >= 10 and atlas.x <= 18:
		return Color("3b8fc4")
	if atlas.x >= 19 and atlas.x <= 21:
		return Color("8f6238")
	if atlas.x >= 3 and atlas.x <= 9:
		return Color("c49a61")
	var seed: int = absi(source_id * 37 + atlas.x * 17 + atlas.y * 13)
	return Color.from_hsv(float(seed % 360) / 360.0, 0.45, 0.75)


func _cell_rect(map: EditableMap2D, cell: Vector2i, scale_factor: float, offset: Vector2) -> Rect2i:
	var position := offset + Vector2(cell * map.tile_size) * scale_factor
	var size := Vector2(map.tile_size) * scale_factor + Vector2.ONE
	return Rect2i(Vector2i(position), Vector2i(maxf(1.0, size.x), maxf(1.0, size.y)))


func _screen_point(world: Vector2, scale_factor: float, offset: Vector2) -> Vector2:
	return offset + world * scale_factor


func _draw_cross(image: Image, center: Vector2i, color: Color, radius: int) -> void:
	image.fill_rect(Rect2i(center.x - radius, center.y, radius * 2 + 1, 1), color)
	image.fill_rect(Rect2i(center.x, center.y - radius, 1, radius * 2 + 1), color)


func _draw_rect_outline(image: Image, rect: Rect2i, color: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	image.fill_rect(Rect2i(rect.position + Vector2i(0, rect.size.y - 1), Vector2i(rect.size.x, 1)), color)
	image.fill_rect(Rect2i(rect.position, Vector2i(1, rect.size.y)), color)
	image.fill_rect(Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y)), color)
