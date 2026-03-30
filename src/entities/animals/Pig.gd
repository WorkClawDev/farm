extends Animal
class_name Pig

## Pig - 猪
## 产出：猪肉(pork)，每天可产出

func _ready() -> void:
	super._ready()
	animal_type = "pig"
	animal_name = "猪"
	animal_id = "pig_001"
	move_speed = 35.0
	max_friendship = 1000
	production_interval = 1
	days_until_production = 1
	is_outside = true
	if has_node("Sprite2D"):
		var tex = load("res://assets/sprites/animals/pig_sheet.png")
		if tex:
			$sprite.texture = tex
			$sprite.hframes = 8

func get_product_id() -> String:
	return "pork"

func get_product_name() -> String:
	return "猪肉"
