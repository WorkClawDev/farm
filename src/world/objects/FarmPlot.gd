extends Area2D
class_name FarmPlot

const SIZE := 60.0

var grid_coord := Vector2i.ZERO
var _ground: Polygon2D
var _outline: Line2D
var _crop_sprite: Sprite2D
var _label: Label


func setup(coord: Vector2i) -> void:
	grid_coord = coord
	name = "FarmPlot_%d_%d" % [coord.x, coord.y]
	# Let the crop sprite join the Farm Y-sort with the player.
	y_sort_enabled = true
	collision_layer = 2
	collision_mask = 0

	_ground = Polygon2D.new()
	_ground.polygon = PackedVector2Array([
		Vector2(-SIZE / 2.0, -SIZE / 2.0),
		Vector2(SIZE / 2.0, -SIZE / 2.0),
		Vector2(SIZE / 2.0, SIZE / 2.0),
		Vector2(-SIZE / 2.0, SIZE / 2.0),
	])
	# Soil inherits TilledArea z (-1): above grass/paths (-3/-2), below the player (0).
	_ground.z_index = 0
	add_child(_ground)
	_outline = Line2D.new()
	_outline.points = PackedVector2Array([
		Vector2(-SIZE / 2.0, -SIZE / 2.0),
		Vector2(SIZE / 2.0, -SIZE / 2.0),
		Vector2(SIZE / 2.0, SIZE / 2.0),
		Vector2(-SIZE / 2.0, SIZE / 2.0),
		Vector2(-SIZE / 2.0, -SIZE / 2.0),
	])
	_outline.width = 2.0
	_outline.default_color = Color(0.25, 0.16, 0.1, 0.65)
	_outline.z_index = 0
	add_child(_outline)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	collision.shape = shape
	add_child(collision)

	_crop_sprite = Sprite2D.new()
	_crop_sprite.centered = true
	# TilledArea z -1 + 1 = 0, same as the player, so they Y-sort by feet position.
	_crop_sprite.z_index = 1
	# Origin near the plot bottom edge so the Y-sort compares "feet".
	_crop_sprite.position = Vector2(0, SIZE * 0.42)
	add_child(_crop_sprite)

	_label = Label.new()
	_label.position = Vector2(-28, -12)
	_label.size = Vector2(56, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.z_index = 3
	add_child(_label)
	refresh()


func refresh() -> void:
	if _ground == null:
		return
	var cell := FarmState.get_cell(grid_coord)
	match int(cell.get("state", FarmState.UNTILLED)):
		FarmState.UNTILLED:
			_ground.color = Color(0.38, 0.60, 0.27, 0.12)
			_outline.visible = false
		FarmState.TILLED:
			_ground.color = Color("#765238")
			_outline.visible = true
		FarmState.WATERED:
			_ground.color = Color("#49382f")
			_outline.visible = true

	var crop: Dictionary = cell.get("crop", {})
	_crop_sprite.texture = null
	_crop_sprite.scale = Vector2.ONE
	_crop_sprite.offset = Vector2.ZERO
	_label.text = ""
	if crop.is_empty():
		return
	var crop_data = GrowthSystem.get_crop_data(str(crop.get("crop_id", "")))
	if crop_data == null:
		return
	var stage := int(crop.get("stage", 0))
	var sprite_path := ""
	if not crop_data.stage_sprites.is_empty():
		sprite_path = crop_data.stage_sprites[mini(stage, crop_data.stage_sprites.size() - 1)]
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_crop_sprite.texture = load(sprite_path)
		if _crop_sprite.texture != null:
			var tex_size: Vector2 = _crop_sprite.texture.get_size()
			var max_dim := maxf(tex_size.x, tex_size.y)
			if max_dim > 0.0:
				# Fit inside the plot: 1024px -> ~0.05, 32px -> ~1.59.
				var fitted := (SIZE * 0.85) / max_dim
				_crop_sprite.scale = Vector2(fitted, fitted)
				# Bottom-align the texture on the sprite origin (offset is in texture px).
				_crop_sprite.offset = Vector2(0, -tex_size.y / 2.0)
	else:
		_label.text = str(crop_data.crop_name).substr(0, 1)
	if bool(crop.get("mature", false)):
		_label.text = "★" if _label.text.is_empty() else _label.text + "★"
