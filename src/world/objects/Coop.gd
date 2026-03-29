extends Node2D
class_name Coop

## Coop - 鸡舍
## 可以容纳最多4只鸡的建筑

@export var building_name: String = "鸡舍"
@export var max_animals: int = 4

var animals: Array[Animal] = []

# 节点引用
@onready var animal_container: Node2D = $AnimalContainer
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	print("[Coop] Chicken coop initialized")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("[Coop] 按 E 键进入鸡舍")

func _on_body_exited(body: Node2D) -> void:
	pass

func _input(event: InputEvent) -> void:
	# 如果玩家在范围内按E，进入建筑
	pass

## 添加动物到鸡舍
func add_animal(animal: Animal) -> bool:
	if animals.size() >= max_animals:
		print("[Coop] 鸡舍已满")
		return false
	
	animals.append(animal)
	if animal_container:
		animal.get_parent().remove_child(animal)
		animal_container.add_child(animal)
	
	print("[Coop] 添加动物: ", animal.animal_name)
	return true

## 移除动物
func remove_animal(animal: Animal) -> void:
	animals.erase(animal)

## 获取当前动物数量
func get_animal_count() -> int:
	return animals.size()

## 获取所有产品
func collect_all_products() -> Dictionary:
	var collected = {}
	for animal in animals:
		if animal.has_product:
			var product = animal.collect_product()
			if not product.is_empty():
				var product_id = product.get("product_id", "")
				var quality = product.get("quality", 0)
				if not collected.has(product_id):
					collected[product_id] = {"count": 0, "qualities": []}
				collected[product_id]["count"] += 1
				collected[product_id]["qualities"].append(quality)
	
	return collected