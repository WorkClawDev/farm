extends Animal
class_name Sheep

## Sheep - 绵羊
## 产出：羊毛(wool)，每2天产一次

func _ready() -> void:
	animal_type = "sheep"
	animal_name = "绵羊"
	animal_id = "sheep_001"
	move_speed = 25.0
	max_friendship = 1000
	production_interval = 2
	days_until_production = 2
	is_outside = true
	# BUG-56: CraftPix sheep sheet from the private submodule, loaded at runtime
	# (ResourceLoader.exists in Animal); falls back to Sheep_transparent.png.
	private_sheet_path = "animals/x4/sheep_sheet_x4.png"
	frame_px = 128
	idle_frames = 4
	walk_frames = 6
	sprite_offset = Vector2(0, -8)  # feet 32px below origin, same as Player/NPC
	private_sprite_scale = 0.8
	super._ready()

func get_product_id() -> String:
	return "wool"

func get_product_name() -> String:
	return "羊毛"
