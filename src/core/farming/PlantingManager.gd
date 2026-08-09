extends Node

## PlantingManager - 种植管理器
## 处理种子的种植逻辑

signal seed_planted(seed_id: String, soil: Soil, success: bool)
signal planting_failed(reason: String)

# 种子到作物的映射（从items.json中加载）
var seed_to_crop: Dictionary = {}

func _ready() -> void:
	_load_seed_data()

## 加载种子数据
func _load_seed_data() -> void:
	# 从ItemDatabase获取种子信息
	var item_database = get_node_or_null("/root/ItemDatabase")
	if item_database:
		for item_id in item_database.get_all_item_ids():
			var item_data = item_database.get_item(item_id)
			if item_data and item_data.type == 0:  # ItemType.SEED = 0
				var crop_id = item_data.crop_id
				if crop_id != "":
					seed_to_crop[item_id] = crop_id
					print("[PlantingManager] Registered seed: ", item_id, " -> ", crop_id)

## 尝试在土壤上种植
func try_plant(seed_id: String, soil: Soil) -> bool:
	# 检查是否是有效种子
	if not seed_to_crop.has(seed_id):
		planting_failed.emit("无效的种子")
		return false
	
	# 检查土壤是否可以种植
	if not soil.can_plant():
		planting_failed.emit("这块土地无法种植")
		return false
	
	var crop_id = seed_to_crop[seed_id]
	var growth_system = get_node_or_null("/root/GrowthSystem")
	
	# 检查当前季节是否适合
	if growth_system and not growth_system.can_plant_in_current_season(crop_id):
		var time_manager = get_node_or_null("/root/TimeManager")
		var current_season = time_manager.get_season_name() if time_manager else "未知"
		planting_failed.emit("当前季节(" + current_season + ")不适合种植这种作物")
		return false
	
	# 从背包中移除种子
	var inventory = get_node_or_null("/root/Inventory")
	if inventory:
		if not inventory.has_item(seed_id, 1):
			planting_failed.emit("背包中没有这个种子")
			return false
		
		inventory.remove_item(seed_id, 1)
	
	# 创建作物
	var crop = _create_crop(crop_id)
	if crop == null:
		planting_failed.emit("无法创建作物")
		return false
	
	# 在土壤上种植
	soil.crop = crop
	crop.global_position = soil.global_position
	soil.get_parent().add_child(crop)
	
	# 注册到生长系统
	if growth_system:
		growth_system.register_crop(crop)
	
	seed_planted.emit(seed_id, soil, true)
	print("[PlantingManager] Planted ", seed_id, " -> ", crop_id, " at ", soil.global_position)
	
	return true

## 创建作物实例
func _create_crop(crop_id: String) -> Crop:
	var growth_system = get_node_or_null("/root/GrowthSystem")
	if growth_system == null:
		return null
	
	var crop_data = growth_system.get_crop_data(crop_id)
	if crop_data == null:
		push_warning("[PlantingManager] Crop data not found: " + crop_id)
		return null
	
	# 创建作物节点
	var crop = Crop.new()
	
	# 创建精灵节点
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	crop.add_child(sprite)
	sprite.owner = crop
	
	# 设置作物数据
	crop.setup(crop_data, Vector2.ZERO, 0)
	
	return crop

## 获取种子对应的作物ID
func get_crop_id_for_seed(seed_id: String) -> String:
	return seed_to_crop.get(seed_id, "")

## 获取所有可用种子
func get_available_seeds() -> Array:
	return seed_to_crop.keys()

## 检查种子是否可以在当前季节种植
func can_plant_seed_now(seed_id: String) -> bool:
	if not seed_to_crop.has(seed_id):
		return false
	
	var growth_system = get_node_or_null("/root/GrowthSystem")
	if growth_system == null:
		return true
	
	var crop_id = seed_to_crop[seed_id]
	return growth_system.can_plant_in_current_season(crop_id)
