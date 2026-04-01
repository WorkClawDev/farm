extends Animal
class_name Sheep

## Sheep - 绵羊
## 产出：羊毛(wool)，每2天产一次

func _ready() -> void:
	super._ready()
	animal_type = "sheep"
	animal_name = "绵羊"
	animal_id = "sheep_001"
	move_speed = 25.0
	max_friendship = 1000
	production_interval = 2
	days_until_production = 2
	is_outside = true

func get_product_id() -> String:
	return "wool"

func get_product_name() -> String:
	return "羊毛"
