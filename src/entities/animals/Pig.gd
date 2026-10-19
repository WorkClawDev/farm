extends Animal
class_name Pig

## Pig - 猪
## 产出：猪肉(pork)，每天可产出

func _ready() -> void:
	animal_type = "pig"
	animal_name = "猪"
	animal_id = "pig_001"
	move_speed = 35.0
	max_friendship = 1000
	production_interval = 1
	days_until_production = 1
	is_outside = true
	private_sheet_path = "animals/x4/pig_sheet_x4.png"
	frame_px = 128
	idle_frames = 4
	walk_frames = 6
	sprite_offset = Vector2(0, -32)
	private_body_radius = 22.0
	private_interaction_radius = 56.0
	private_sprite_scale = 0.8
	super._ready()

func get_product_id() -> String:
	return "pork"

func get_product_name() -> String:
	return "猪肉"
