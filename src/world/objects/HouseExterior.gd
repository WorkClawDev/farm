extends StaticBody2D
class_name HouseExterior

const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const FOOTPRINT_WIDTH_RATIO := 0.88
const FOOTPRINT_HEIGHT_RATIO := 0.16
const FOOTPRINT_Y_RATIO := 0.39

const HOUSE_TEXTURES := {
	0: "res://assets/sprites/houses/house_lv1_test.png",
	1: "res://assets/sprites/houses/house_lv2.png",
	2: "res://assets/sprites/houses/house_lv3.png",
}

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

	var texture_path: String = HOUSE_TEXTURES.get(current_level, HOUSE_TEXTURES[0])
	var texture := TextureLoader.load_texture(texture_path)
	if texture == null:
		push_warning("[HouseExterior] Could not load texture: " + texture_path)
		return

	var display_size: Vector2 = HOUSE_SIZES.get(current_level, HOUSE_SIZES[0])
	var texture_size := Vector2(texture.get_size())

	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2(
		display_size.x / texture_size.x,
		display_size.y / texture_size.y
	)
	_update_collision_shape(display_size)

func _update_collision_shape(display_size: Vector2) -> void:
	if collision_shape == null:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	shape.size = Vector2(
		display_size.x * FOOTPRINT_WIDTH_RATIO,
		display_size.y * FOOTPRINT_HEIGHT_RATIO
	)
	var collision_center_y := display_size.y * FOOTPRINT_Y_RATIO
	var new_depth_anchor := collision_center_y + shape.size.y * 0.5

	# Node2D has no configurable Y-sort origin. Keep the visible artwork at the
	# same world position while moving this root to the foundation's bottom edge,
	# which makes native Y sorting compare the house against actors' ground
	# positions instead of against the center of the roof.
	position.y += new_depth_anchor - _depth_anchor_offset
	_depth_anchor_offset = new_depth_anchor
	sprite.position = Vector2(0, -_depth_anchor_offset)
	collision_shape.position = Vector2(
		0,
		collision_center_y - _depth_anchor_offset
	)

func get_door_offset() -> Vector2:
	return (
		HOUSE_DOOR_OFFSETS.get(current_level, HOUSE_DOOR_OFFSETS[0])
		- Vector2(0, _depth_anchor_offset)
	)

func get_door_global_position() -> Vector2:
	return global_position + get_door_offset()

func get_display_size() -> Vector2:
	return HOUSE_SIZES.get(current_level, HOUSE_SIZES[0])

func get_visual_center_global_position() -> Vector2:
	return global_position - Vector2(0, _depth_anchor_offset)

func get_depth_anchor_offset() -> float:
	return _depth_anchor_offset
