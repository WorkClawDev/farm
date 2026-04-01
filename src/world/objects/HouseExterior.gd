extends StaticBody2D
class_name HouseExterior

const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const COLLISION_WIDTH_RATIO := 0.58
const COLLISION_HEIGHT_RATIO := 0.32
const COLLISION_Y_RATIO := 0.34

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

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

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

	var texture_path: String = HOUSE_TEXTURES.get(level, HOUSE_TEXTURES[0])
	var texture := TextureLoader.load_texture(texture_path)
	if texture == null:
		push_warning("[HouseExterior] Could not load texture: " + texture_path)
		return

	var display_size: Vector2 = HOUSE_SIZES.get(level, HOUSE_SIZES[0])
	var texture_size := Vector2(texture.get_size())

	sprite.texture = texture
	sprite.centered = true
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
		display_size.x * COLLISION_WIDTH_RATIO,
		display_size.y * COLLISION_HEIGHT_RATIO
	)
	collision_shape.position = Vector2(0, display_size.y * COLLISION_Y_RATIO)
