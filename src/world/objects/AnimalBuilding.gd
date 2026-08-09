extends StaticBody2D
class_name AnimalBuilding

## AnimalBuilding - 动物建筑基类
## 用于容纳动物的建筑，如鸡舍、牛棚

# 建筑配置
@export var building_name: String = "动物建筑"
@export var building_type: String = "generic"  # coop, barn, etc.
@export var max_animals: int = 4
@export var building_level: int = 1

# 动物列表
var animals: Array[Animal] = []

# 节点引用
@onready var animal_container: Node2D = $AnimalContainer if has_node("AnimalContainer") else null
@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# 信号
signal animal_added(animal: Animal)
signal animal_removed(animal: Animal)
signal building_interacted(building: AnimalBuilding)

func _ready() -> void:
	_setup_interaction()
	print("[AnimalBuilding] %s initialized (capacity: %d)" % [building_name, max_animals])

## 设置交互
func _setup_interaction() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

## 添加动物
func add_animal(animal: Animal) -> bool:
	if animals.size() >= max_animals:
		print("[AnimalBuilding] %s is full!" % building_name)
		return false

	animals.append(animal)
	animal.set_home_position(_get_animal_spawn_position(animals.size() - 1))

	if animal_container:
		animal.get_parent().remove_child(animal)
		animal_container.add_child(animal)

	animal_added.emit(animal)
	print("[AnimalBuilding] Added %s to %s" % [animal.animal_name, building_name])
	return true

## 移除动物
func remove_animal(animal: Animal) -> bool:
	var index := animals.find(animal)
	if index == -1:
		return false

	animals.remove_at(index)
	animal_removed.emit(animal)
	print("[AnimalBuilding] Removed %s from %s" % [animal.animal_name, building_name])
	return true

## 获取动物生成位置
func _get_animal_spawn_position(index: int) -> Vector2:
	var base_pos := global_position
	var row := index / 2
	var col := index % 2
	return base_pos + Vector2(col * 32, row * 32)

## 获取所有有产品的动物
func get_animals_with_products() -> Array[Animal]:
	var result: Array[Animal] = []
	for animal in animals:
		if animal.has_product:
			result.append(animal)
	return result

## 收集所有产品
func collect_all_products() -> Dictionary:
	var collected := {}
	for animal in animals:
		if animal.has_product:
			var product := animal.collect_product()
			if not product.is_empty():
				var item_id: String = product["item_id"]
				if not collected.has(item_id):
					collected[item_id] = 0
				collected[item_id] += product["quantity"]
	return collected

## 喂养所有动物
func feed_all_animals(food_item_id: String) -> int:
	var fed_count := 0
	for animal in animals:
		if animal.hunger < animal.max_hunger:
			if animal.feed(food_item_id):
				fed_count += 1
	return fed_count

## 每日更新
func on_new_day() -> void:
	for animal in animals:
		animal.on_new_day()

## 检查是否有饥饿的动物
func has_hungry_animals() -> bool:
	for animal in animals:
		if animal.hunger < 50:
			return true
	return false

## 获取动物数量
func get_animal_count() -> int:
	return animals.size()

## 是否已满
func is_full() -> bool:
	return animals.size() >= max_animals

## 升级建筑
func upgrade() -> bool:
	if building_level >= 3:
		return false
	building_level += 1
	max_animals += 4
	print("[AnimalBuilding] %s upgraded to level %d" % [building_name, building_level])
	return true

## 玩家进入交互区域
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.building_in_range = self

## 玩家离开交互区域
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		if body.building_in_range == self:
			body.building_in_range = null

## 获取交互文本
func get_interaction_text() -> String:
	var product_count := get_animals_with_products().size()
	if product_count > 0:
		return "收集产品 (%d)" % product_count
	elif has_hungry_animals():
		return "喂养动物"
	else:
		return "查看%s (%d/%d)" % [building_name, animals.size(), max_animals]

## 保存状态
func save_state() -> Dictionary:
	var animals_data := []
	for animal in animals:
		animals_data.append(animal.save_state())

	return {
		"building_name": building_name,
		"building_type": building_type,
		"building_level": building_level,
		"max_animals": max_animals,
		"animals": animals_data,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		}
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	building_level = data.get("building_level", 1)
	max_animals = data.get("max_animals", 4)

	# 动物数据需要由外部系统重建
	print("[AnimalBuilding] %s state loaded" % building_name)