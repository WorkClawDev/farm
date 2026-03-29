extends Animal
class_name Horse

## Horse - 马
## 不可产出产物，可骑行（加速）

func _ready() -> void:
	super._ready()
	animal_type = "horse"
	animal_name = "马"
	animal_id = "horse_001"
	move_speed = 80.0
	max_friendship = 1500
	production_interval = -1  # 不产出
	days_until_production = -1
	is_outside = true
	if has_node("Sprite2D"):
		var tex = load("res://assets/sprites/animals/horse_sheet.png")
		if tex:
			$sprite.texture = tex
			$sprite.hframes = 8

func get_product_id() -> String:
	return ""

func get_product_name() -> String:
	return ""

