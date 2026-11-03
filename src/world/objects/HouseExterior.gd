extends StaticBody2D
class_name HouseExterior

const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const PrivateBuildingArt := preload("res://src/world/objects/PrivateBuildingArt.gd")
const FOOTPRINT_WIDTH_RATIO := 0.88
const FOOTPRINT_HEIGHT_RATIO := 0.16
const FOOTPRINT_Y_RATIO := 0.39

const HOUSE_TEXTURES := {
	0: "res://assets/sprites/houses/house_lv1_test.png",
	1: "res://assets/sprites/houses/house_lv2.png",
	2: "res://assets/sprites/houses/house_lv3.png",
}
# B06 farmhouse body; height 512 stops above the detached roof piece below it.
const PRIVATE_HOUSE_REGION := Rect2(1108, 64, 504, 512)  # B06 farmhouse lv0
# Bottom of the porch steps, relative to the region centre (atlas px).
const PRIVATE_HOUSE_DOOR := Vector2(-18, 256)
## BUG-58 check: B06 walls span atlas x 4..463 of 504 at the base, so the
## footprint is 0.91 wide and centred 18.5 atlas px left of the region centre.
const PRIVATE_FOOTPRINT_WIDTH_RATIO := 0.91
const PRIVATE_FOOTPRINT_CENTER_X := -18.5
## Region-local atlas pixels of the B06 roof and upper walls. The foundation
## rectangle only covers the bottom strip, so without this outline the player
## walks through the peak, eaves and side walls. The bottom edge stops where
## the porch begins (the door steps stay open). The right edge stays at x=472
## so the east "beyond the artwork" probe still misses.
static func _private_roof_outline() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(228, 0),
		Vector2(112, 112),
		Vector2(0, 124),
		Vector2(0, 448),
		Vector2(472, 448),
		Vector2(472, 120),
		Vector2(424, 116),
		Vector2(360, 112),
		Vector2(272, 16),
		Vector2(244, 0),
	])

const HOUSE_SIZES := {
	0: Vector2(220, 168),
	1: Vector2(252, 188),
	2: Vector2(284, 208),
}

# Door positions are measured from the centered source artwork. They are kept
# separate from the footprint because every house illustration places its door
# left of the texture center.
const HOUSE_DOOR_OFFSETS := {
	0: Vector2(-44, 98),
	1: Vector2(-52, 82),
	2: Vector2(-52, 82),
}

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
var current_level: int = 0
var _depth_anchor_offset := 0.0
# Root y relative to the authored position (anchor + any private-art shift).
var _root_offset_y := 0.0
var _display_size := Vector2.ZERO
# Private art only: moves the drawing so its door lands on the lv0 fallback door
# point (the farm road), keeping the root/footprint maths identical.
var _visual_shift := Vector2.ZERO
var _uses_private_art := false

func _ready() -> void:
	_apply_current_level()
	if HouseUpgradeSystem:
		HouseUpgradeSystem.house_upgraded.connect(_on_house_upgraded)

func _on_house_upgraded(new_level: int, _level_name: String) -> void:
	_apply_level_visual(new_level)

func _apply_current_level() -> void:
	var level := 0
	if HouseUpgradeSystem:
		level = HouseUpgradeSystem.get_house_level()
	_apply_level_visual(level)

func _apply_level_visual(level: int) -> void:
	if sprite == null:
		return
	current_level = clampi(level, 0, 2)

	var texture: Texture2D = null
	if current_level == 0:
		texture = _try_private_house_texture()
	var use_nearest := texture != null
	var texture_path: String = HOUSE_TEXTURES.get(current_level, HOUSE_TEXTURES[0])
	if texture == null:
		texture = TextureLoader.load_texture(texture_path)
	if texture == null:
		push_warning("[HouseExterior] Could not load texture: " + texture_path)
		return

	var display_size: Vector2 = HOUSE_SIZES.get(current_level, HOUSE_SIZES[0])
	_uses_private_art = use_nearest
	_visual_shift = Vector2.ZERO
	if use_nearest:
		display_size = PrivateBuildingArt.display_size(PRIVATE_HOUSE_REGION)
		_visual_shift = (
			HOUSE_DOOR_OFFSETS[0]
			- PRIVATE_HOUSE_DOOR * PrivateBuildingArt.DISPLAY_SCALE
		)
	_display_size = display_size
	var texture_size := Vector2(texture.get_size())

	sprite.texture = texture
	sprite.centered = true
	if use_nearest:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2(
		display_size.x / texture_size.x,
		display_size.y / texture_size.y
	)
	_update_collision_shape(display_size)


func _try_private_house_texture() -> Texture2D:
	return PrivateBuildingArt.load_region(PRIVATE_HOUSE_REGION)

func _update_collision_shape(display_size: Vector2) -> void:
	if collision_shape == null:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	var width_ratio := FOOTPRINT_WIDTH_RATIO
	var footprint_x := _visual_shift.x
	if _uses_private_art:
		width_ratio = PRIVATE_FOOTPRINT_WIDTH_RATIO
		footprint_x += PRIVATE_FOOTPRINT_CENTER_X * PrivateBuildingArt.DISPLAY_SCALE
	shape.size = Vector2(
		display_size.x * width_ratio,
		display_size.y * FOOTPRINT_HEIGHT_RATIO
	)
	var collision_center_y := display_size.y * FOOTPRINT_Y_RATIO
	var new_depth_anchor := collision_center_y + shape.size.y * 0.5

	# Node2D has no configurable Y-sort origin. Keep the visible artwork at the
	# same world position while moving this root to the foundation's bottom edge,
	# which makes native Y sorting compare the house against actors' ground
	# positions instead of against the center of the roof.
	var new_root_offset_y := _visual_shift.y + new_depth_anchor
	position.y += new_root_offset_y - _root_offset_y
	_root_offset_y = new_root_offset_y
	_depth_anchor_offset = new_depth_anchor
	sprite.position = Vector2(_visual_shift.x, -_depth_anchor_offset)
	collision_shape.position = Vector2(
		footprint_x,
		collision_center_y - _depth_anchor_offset
	)
	_sync_roof_collision()

func _sync_roof_collision() -> void:
	var existing := get_node_or_null("RoofCollision") as CollisionPolygon2D
	if not _uses_private_art:
		if existing != null:
			existing.queue_free()
		return
	var poly := existing
	if poly == null:
		poly = CollisionPolygon2D.new()
		poly.name = "RoofCollision"
		add_child(poly)
	var points := PackedVector2Array()
	var center := PRIVATE_HOUSE_REGION.size * 0.5
	for atlas_px in _private_roof_outline():
		var centered := (atlas_px - center) * PrivateBuildingArt.DISPLAY_SCALE
		points.append(sprite.position + centered)
	poly.polygon = points

func get_door_offset() -> Vector2:
	if _uses_private_art:
		var door := PRIVATE_HOUSE_DOOR * PrivateBuildingArt.DISPLAY_SCALE
		return Vector2(_visual_shift.x + door.x, door.y - _depth_anchor_offset)
	return (
		HOUSE_DOOR_OFFSETS.get(current_level, HOUSE_DOOR_OFFSETS[0])
		- Vector2(0, _depth_anchor_offset)
	)

func get_door_global_position() -> Vector2:
	return global_position + get_door_offset()

func get_display_size() -> Vector2:
	if _display_size != Vector2.ZERO:
		return _display_size
	return HOUSE_SIZES.get(current_level, HOUSE_SIZES[0])

func get_visual_center_global_position() -> Vector2:
	return global_position - Vector2(-_visual_shift.x, _depth_anchor_offset)

func get_depth_anchor_offset() -> float:
	return _depth_anchor_offset
