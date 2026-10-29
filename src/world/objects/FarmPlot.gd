extends Area2D
class_name FarmPlot

const SIZE := 60.0
const STUMP_BLOCK_OFFSET := Vector2(0, 6)
## Stage 0 on a canvas larger than the cell is mostly padding. Nudge it so the
## seed reads on tilled soil, and keep the sprite inside the cell.
const EARLY_SPRITE_BOOST := 1.12
const EARLY_SPRITE_CAP := 0.95
const PRIVATE_ROOT := "res://assets/private/topdown_farm/"
const FALLBACK_ITEM := {
	"weed": "res://assets/sprites/items/fiber.png",
	"stone": "res://assets/sprites/items/stone.png",
	"twig": "res://assets/sprites/items/wood.png",
	"stump": "res://assets/sprites/items/wood.png",
}

var grid_coord := Vector2i.ZERO
var _ground: Polygon2D
var _outline: Line2D
var _crop_sprite: Sprite2D
var _label: Label
var _debris_sprite: Sprite2D
var _debris_collision: CollisionShape2D


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

	# Stump artwork is 128px, but it only blocks the one plot cell.
	var debris_block := StaticBody2D.new()
	debris_block.name = "DebrisBlock"
	debris_block.collision_layer = 1
	debris_block.collision_mask = 0
	var debris_shape := RectangleShape2D.new()
	debris_shape.size = Vector2(SIZE, SIZE)
	_debris_collision = CollisionShape2D.new()
	_debris_collision.name = "CollisionShape2D"
	_debris_collision.shape = debris_shape
	# North-row top stays at the field-fence line (y=376), clear of Joe's tavern stand.
	_debris_collision.position = STUMP_BLOCK_OFFSET
	_debris_collision.disabled = true
	debris_block.add_child(_debris_collision)
	add_child(debris_block)

	_debris_sprite = Sprite2D.new()
	_debris_sprite.name = "DebrisSprite"
	_debris_sprite.centered = true
	_debris_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# TilledArea is z -1. Absolute z 0 matches the player, so Farm's Y-sort
	# compares feet instead of always painting the stump over the actor.
	# The origin itself is moved onto the visible foot in _apply_debris.
	_debris_sprite.z_as_relative = false
	_debris_sprite.z_index = 0
	_debris_sprite.position = Vector2(0, SIZE * 0.5)
	_debris_sprite.visible = false
	add_child(_debris_sprite)

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

	var debris := str(cell.get("debris", ""))
	_apply_debris(debris, int(cell.get("debris_variant", 0)))

	var crop: Dictionary = cell.get("crop", {})
	_crop_sprite.texture = null
	_crop_sprite.scale = Vector2.ONE
	_crop_sprite.offset = Vector2.ZERO
	_crop_sprite.position = Vector2(0, SIZE * 0.42)
	_label.text = ""
	if debris != "" or crop.is_empty():
		return
	var dead := bool(crop.get("dead", false))
	var crop_id := str(crop.get("crop_id", ""))
	var crop_data = GrowthSystem.get_crop_data(crop_id)
	if crop_data == null and not dead:
		return
	var sprite_path := ""
	var stage := int(crop.get("stage", 0))
	if dead:
		sprite_path = FarmState.dead_crop_sprite_path(crop_id)
	elif crop_data != null:
		sprite_path = FarmState.crop_stage_sprite_path(crop_id, stage, crop_data.stage_sprites)
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		_crop_sprite.texture = load(sprite_path)
		if _crop_sprite.texture != null:
			var tex_size: Vector2 = _crop_sprite.texture.get_size()
			var max_dim := maxf(tex_size.x, tex_size.y)
			if max_dim > 0.0:
				# Fit inside the plot: 1024px -> ~0.05, 32px -> ~1.59.
				var fitted := (SIZE * 0.85) / max_dim
				if not dead and stage <= 0 and max_dim > SIZE:
					fitted = minf(fitted * EARLY_SPRITE_BOOST, (SIZE * EARLY_SPRITE_CAP) / max_dim)
					_crop_sprite.position = Vector2(0, SIZE * 0.48)
				_crop_sprite.scale = Vector2(fitted, fitted)
				# Bottom-align the texture on the sprite origin (offset is in texture px).
				_crop_sprite.offset = Vector2(0, -tex_size.y / 2.0)
	elif not dead and crop_data != null:
		_label.text = str(crop_data.crop_name).substr(0, 1)
	if not dead and bool(crop.get("mature", false)):
		_label.text = "★" if _label.text.is_empty() else _label.text + "★"


## Private art at scale 1. A missing submodule falls back to item icons.
static func resolve_debris_texture_path(kind: String, variant: int) -> String:
	for relative in _debris_art_candidates(kind, variant):
		var full := PRIVATE_ROOT + relative
		if ResourceLoader.exists(full):
			return full
	return str(FALLBACK_ITEM.get(kind, ""))


static func _debris_art_candidates(kind: String, variant: int) -> Array[String]:
	var out: Array[String] = []
	match kind:
		"weed":
			var weeds := [
				"bushes/x4/separately/Assets/Bush_simple1_3_x4.png",
				"bushes/x4/separately/Assets/Bush_simple2_3_x4.png",
				"bushes/x4/separately/Assets/Fern1_3_x4.png",
			]
			out.append(weeds[posmod(variant, weeds.size())])
		"stone":
			var n := posmod(variant, 7) + 1
			out.append("rocks/x4/separately/Rock%d_5_x4.png" % n)
			out.append("rocks/x4/separately/Rock%d_4_x4.png" % n)
		"twig":
			var twigs := [
				"bushes/x4/separately/Assets/Broken_tree1_x4.png",
				"bushes/x4/separately/Assets/Broken_tree2_x4.png",
			]
			out.append(twigs[posmod(variant, twigs.size())])
		"stump":
			out.append("trees/x4/separately/Trees/Broken_tree2_x4.png")
	return out


func _apply_debris(kind: String, variant: int) -> void:
	if _debris_sprite == null or _debris_collision == null:
		return
	var blocking := kind == "stump"
	_debris_collision.disabled = not blocking
	if kind.is_empty():
		_debris_sprite.visible = false
		_debris_sprite.texture = null
		return
	var path := resolve_debris_texture_path(kind, variant)
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_debris_sprite.texture = texture
	_debris_sprite.visible = texture != null
	if texture == null:
		return
	var tex_size := texture.get_size()
	# Private sheets stay at scale 1 (stump is 128px). Huge item-icon fallbacks fit the cell.
	var sprite_scale := 1.0
	if not path.begins_with(PRIVATE_ROOT) and tex_size.y > SIZE:
		sprite_scale = (SIZE * 0.85) / tex_size.y
	_debris_sprite.scale = Vector2(sprite_scale, sprite_scale)
	# Keep the texture's bottom on the cell's south edge, but put the node
	# origin on the visible foot. Empty padding under the stump was south of
	# that foot, so a player standing in front of the trunk still sorted behind.
	var placement := debris_sprite_placement(texture, sprite_scale, SIZE * 0.5)
	_debris_sprite.position = Vector2(0, float(placement.position_y))
	_debris_sprite.offset = Vector2(0, float(placement.offset_y))


## Greater foot Y draws in front. Same rule as the farmhouse foundation.
static func actor_draws_in_front_of_debris(actor_y: float, foot_y: float) -> bool:
	return actor_y > foot_y


## Sprite origin (Y-sort key) on the opaque foot; texture bottom stays on ground_y.
static func debris_sprite_placement(texture: Texture2D, sprite_scale: float, ground_y: float) -> Dictionary:
	var tex_h := 0.0
	if texture != null:
		tex_h = float(texture.get_height())
	var inset := debris_foot_inset_px(texture)
	return {
		"position_y": ground_y - inset * sprite_scale,
		"offset_y": -tex_h * 0.5 + inset,
		"inset_px": inset,
	}


## Pixels of transparent padding under each private debris sheet.
## Baked so gameplay never calls Texture2D.get_image() or Image.load, both of
## which leave an Image in the resource cache until process exit.
const DEBRIS_FOOT_INSET_PX := {
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock1_5_x4.png": 0,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock1_4_x4.png": 12,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock2_5_x4.png": 8,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock2_4_x4.png": 16,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock3_5_x4.png": 0,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock3_4_x4.png": 20,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock4_5_x4.png": 0,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock4_4_x4.png": 20,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock5_5_x4.png": 0,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock5_4_x4.png": 12,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock6_5_x4.png": 4,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock6_4_x4.png": 8,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock7_5_x4.png": 16,
	"res://assets/private/topdown_farm/rocks/x4/separately/Rock7_4_x4.png": 28,
	"res://assets/private/topdown_farm/bushes/x4/separately/Assets/Bush_simple1_3_x4.png": 12,
	"res://assets/private/topdown_farm/bushes/x4/separately/Assets/Bush_simple2_3_x4.png": 8,
	"res://assets/private/topdown_farm/bushes/x4/separately/Assets/Fern1_3_x4.png": 4,
	"res://assets/private/topdown_farm/bushes/x4/separately/Assets/Broken_tree1_x4.png": 8,
	"res://assets/private/topdown_farm/bushes/x4/separately/Assets/Broken_tree2_x4.png": 8,
	"res://assets/private/topdown_farm/trees/x4/separately/Trees/Broken_tree2_x4.png": 16,
}


## Texture pixels between the image bottom and the lowest opaque row.
static func debris_foot_inset_px(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var path := texture.resource_path
	if DEBRIS_FOOT_INSET_PX.has(path):
		return float(DEBRIS_FOOT_INSET_PX[path])
	if not path.is_empty():
		return 0.0
	return _measure_runtime_inset(texture)


## Unit-test textures have no file. Duplicate, measure, then drop the copy.
static func _measure_runtime_inset(texture: Texture2D) -> float:
	var owned := texture.get_image()
	if owned == null or owned.is_empty():
		return 0.0
	var copy := owned.duplicate() as Image
	owned = null
	if copy == null or copy.is_empty():
		return 0.0
	if copy.is_compressed():
		copy.decompress()
	var used := copy.get_used_rect()
	var height := copy.get_height()
	if not copy.resource_path.is_empty():
		copy.resource_path = ""
	copy = null
	if used.size.x <= 0 or used.size.y <= 0:
		return 0.0
	return float(height - used.position.y - used.size.y)
