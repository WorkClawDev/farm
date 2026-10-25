extends Node

## GrowthSystem - 生长系统
## 管理所有作物的生长、收获和数据

signal crop_registered(crop: Crop)
signal crop_removed(crop: Crop)
signal day_updated(crops_updated: int)

## 作物数据库路径
const CROP_DATA_PATH: String = "res://data/crops.json"

## 所有注册的作物实例
var _registered_crops: Array[Crop] = []

## 作物数据缓存
var _crop_data_cache: Dictionary = {}

## 是否已初始化
var _is_initialized: bool = false

func _ready() -> void:
	print("[GrowthSystem] Initialized")
	_load_crop_database()
	_connect_signals()

func _connect_signals() -> void:
	# 连接时间管理器信号
	if TimeManager:
		get_node("/root/TimeManager").day_changed.connect(_on_day_changed)
		get_node("/root/TimeManager").season_changed.connect(_on_season_changed)

## 加载作物数据库
func _load_crop_database() -> void:
	if not ResourceLoader.exists(CROP_DATA_PATH):
		push_warning("[GrowthSystem] Crop database not found, creating default data")
		_create_default_crop_database()
		return

	var file: FileAccess = FileAccess.open(CROP_DATA_PATH, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		file.close()

		var json: JSON = JSON.new()
		var error: int = json.parse(json_text)

		if error == OK:
			var data: Dictionary = json.data
			_parse_crop_database(data)
			print("[GrowthSystem] Loaded ", _crop_data_cache.size(), " crop types")
		else:
			push_error("[GrowthSystem] Failed to parse crop database: " + json.get_error_message())
	else:
		push_error("[GrowthSystem] Failed to open crop database")

## 解析作物数据库
func _parse_crop_database(data: Dictionary) -> void:
	_crop_data_cache.clear()

	var crops: Array = data.get("crops", [])
	for crop_data_dict in crops:
		var crop_data: CropData = CropData.new()
		crop_data.crop_id = crop_data_dict.get("id", "")
		crop_data.crop_name = crop_data_dict.get("name", "")
		crop_data.seed_id = crop_data_dict.get("seed_id", "")
		crop_data.description = crop_data_dict.get("description", "")

		# 解析生长天数
		var growth_days: Array = crop_data_dict.get("growth_days", [1, 1, 1, 1])
		crop_data.growth_days.clear()
		for days in growth_days:
			crop_data.growth_days.append(int(days))

		# 解析季节
		var seasons: Array = crop_data_dict.get("season", ["Spring"])
		crop_data.seasons.clear()
		for season in seasons:
			crop_data.seasons.append(str(season))

		crop_data.regrow = crop_data_dict.get("regrow", false)
		crop_data.regrow_days = crop_data_dict.get("regrow_days", 0)

		# 解析精灵路径
		var stage_sprites: Array = crop_data_dict.get("stages_sprites", [])
		crop_data.stage_sprites.clear()
		for sprite_path in stage_sprites:
			crop_data.stage_sprites.append(str(sprite_path))

		crop_data.harvest_sprite = crop_data_dict.get("harvest_sprite", "")
		crop_data.base_sell_price = crop_data_dict.get("sell_price", 50)
		crop_data.base_exp = crop_data_dict.get("exp", 10)
		crop_data.min_harvest = crop_data_dict.get("min_harvest", 1)
		crop_data.max_harvest = crop_data_dict.get("max_harvest", 1)

		_crop_data_cache[crop_data.crop_id] = crop_data

## 创建默认作物数据库
func _create_default_crop_database() -> void:
	var default_data: Dictionary = {
		"crops": [
			{
				"id": "turnip",
				"name": "防风草",
				"seed_id": "turnip_seed",
				"growth_days": [1, 1, 1, 1],
				"season": ["Spring"],
				"regrow": false,
				"stages_sprites": [
					"res://assets/sprites/crops/turnip_stage0.png",
					"res://assets/sprites/crops/turnip_stage1.png",
					"res://assets/sprites/crops/turnip_stage2.png",
					"res://assets/sprites/crops/turnip_stage3.png",
					"res://assets/sprites/crops/turnip_stage4.png"
				],
				"sell_price": 35,
				"exp": 8
			},
			{
				"id": "potato",
				"name": "土豆",
				"seed_id": "potato_seed",
				"growth_days": [1, 2, 2, 2],
				"season": ["Spring"],
				"regrow": false,
				"stages_sprites": [
					"res://assets/sprites/crops/potato_stage0.png",
					"res://assets/sprites/crops/potato_stage1.png",
					"res://assets/sprites/crops/potato_stage2.png",
					"res://assets/sprites/crops/potato_stage3.png",
					"res://assets/sprites/crops/potato_stage4.png"
				],
				"sell_price": 80,
				"exp": 14
			},
			{
				"id": "tomato",
				"name": "番茄",
				"seed_id": "tomato_seed",
				"growth_days": [2, 2, 2, 3],
				"season": ["Summer"],
				"regrow": true,
				"regrow_days": 4,
				"stages_sprites": [
					"res://assets/sprites/crops/tomato_stage0.png",
					"res://assets/sprites/crops/tomato_stage1.png",
					"res://assets/sprites/crops/tomato_stage2.png",
					"res://assets/sprites/crops/tomato_stage3.png",
					"res://assets/sprites/crops/tomato_stage4.png"
				],
				"sell_price": 60,
				"exp": 12
			},
			{
				"id": "corn",
				"name": "玉米",
				"seed_id": "corn_seed",
				"growth_days": [2, 3, 3, 4],
				"season": ["Summer", "Fall"],
				"regrow": true,
				"regrow_days": 4,
				"stages_sprites": [
					"res://assets/sprites/crops/corn_stage0.png",
					"res://assets/sprites/crops/corn_stage1.png",
					"res://assets/sprites/crops/corn_stage2.png",
					"res://assets/sprites/crops/corn_stage3.png",
					"res://assets/sprites/crops/corn_stage4.png"
				],
				"sell_price": 50,
				"exp": 10
			},
			{
				"id": "pumpkin",
				"name": "南瓜",
				"seed_id": "pumpkin_seed",
				"growth_days": [2, 3, 4, 4],
				"season": ["Fall"],
				"regrow": false,
				"stages_sprites": [
					"res://assets/sprites/crops/pumpkin_stage0.png",
					"res://assets/sprites/crops/pumpkin_stage1.png",
					"res://assets/sprites/crops/pumpkin_stage2.png",
					"res://assets/sprites/crops/pumpkin_stage3.png",
					"res://assets/sprites/crops/pumpkin_stage4.png"
				],
				"sell_price": 320,
				"exp": 30
			}
		]
	}

	# 保存默认数据库
	var dir: DirAccess = DirAccess.open("res://data")
	if dir == null:
		dir = DirAccess.open("res://")
		dir.make_dir("data")

	var file: FileAccess = FileAccess.open(CROP_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(default_data, "\t"))
		file.close()
		print("[GrowthSystem] Created default crop database")

	# 解析刚创建的数据
	_parse_crop_database(default_data)

## 获取作物数据
func get_crop_data(crop_id: String) -> CropData:
	return _crop_data_cache.get(crop_id, null)

## 获取所有作物ID
func get_all_crop_ids() -> Array:
	return _crop_data_cache.keys()

## 妫€鏌ヤ綔鐗╂槸鍚﹀瓨鍦?
func has_crop(crop_id: String) -> bool:
	return _crop_data_cache.has(crop_id)

## 注册作物
func register_crop(crop: Crop) -> void:
	if crop == null:
		return

	if crop not in _registered_crops:
		_registered_crops.append(crop)
		crop_registered.emit(crop)
		print("[GrowthSystem] Registered crop: ", crop.crop_id)

## 移除作物
func remove_crop(crop: Crop) -> void:
	if crop == null:
		return

	if crop in _registered_crops:
		_registered_crops.erase(crop)
		crop_removed.emit(crop)
		print("[GrowthSystem] Removed crop: ", crop.crop_id)

## 获取所有注册的作物
func get_all_crops() -> Array[Crop]:
	return _registered_crops.duplicate()

## 获取特定位置的作物
func get_crop_at_position(pos: Vector2) -> Crop:
	for crop in _registered_crops:
		if crop.soil_position.distance_to(pos) < 1.0:
			return crop
	return null

## 一天过去时的处理
func _on_day_changed(_new_day: int) -> void:
	update_all_crops()

## 季节变化时的处理
func _on_season_changed(_new_season: int, _season_name: String) -> void:
	# 季节变化时，检查作物是否会枯萎
	for crop in _registered_crops:
		if crop.crop_data and crop.crop_data.dies_out_of_season:
			if not crop.crop_data.can_grow_in_season(get_node("/root/TimeManager").get_season_name()):
				crop.on_day_passed()  # 这会触发枯萎检查

## 更新所有作物
func update_all_crops() -> int:
	var updated_count: int = 0

	for crop in _registered_crops:
		if crop and not crop.is_dead():
			crop.on_day_passed()
			updated_count += 1

	day_updated.emit(updated_count)
	print("[GrowthSystem] Updated ", updated_count, " crops")
	return updated_count

## 种植作物
func plant_crop(crop_id: String, position: Vector2, fertilizer: int = 0) -> Crop:
	var crop_data: CropData = get_crop_data(crop_id)
	if crop_data == null:
		push_error("[GrowthSystem] Unknown crop ID: " + crop_id)
		return null

	# 创建作物场景
	var crop_scene: PackedScene = PackedScene.new()
	var crop: Crop = Crop.new()

	# 创建精灵节点
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Sprite2D"
	crop.add_child(sprite)
	sprite.owner = crop

	# 设置作物
	crop.setup(crop_data, position, fertilizer)

	# 注册作物
	register_crop(crop)

	# 发射种植事件
	get_node("/root/EventBus").farm.crop_planted.emit(crop_id, position)

	return crop

## 收获作物
func harvest_crop(crop: Crop) -> Dictionary:
	if crop == null:
		return {}

	if not crop.can_harvest():
		print("[GrowthSystem] Crop cannot be harvested yet")
		return {}

	# 执行收获
	var harvest_result: Dictionary = crop.harvest()

	if not harvest_result.is_empty():
		# 添加到背包（如果有背包系统）
		_add_to_inventory(harvest_result)

		# 创建收获特效
		_spawn_harvest_effect(crop.global_position, harvest_result)

		# 如果作物被移除，从注册列表移除
		if crop.is_queued_for_deletion():
			remove_crop(crop)

	return harvest_result

## 添加收获物到背包
func _add_to_inventory(harvest_result: Dictionary) -> void:
	var crop_id: String = harvest_result.get("crop_id", "")
	var quantity: int = harvest_result.get("quantity", 1)

	# 发射添加物品事件
	get_node("/root/EventBus").inventory.item_added.emit(crop_id, quantity)

	print("[GrowthSystem] Added ", quantity, " ", crop_id, " to inventory")

## 创建收获特效
func _spawn_harvest_effect(pos: Vector2, harvest_result: Dictionary) -> void:
	# 检查是否有特效场景
	var effect_scene_path: String = "res://src/effects/HarvestEffect.tscn"

	if ResourceLoader.exists(effect_scene_path):
		var effect_scene: PackedScene = load(effect_scene_path)
		var effect: Node2D = effect_scene.instantiate()
		effect.global_position = pos

		# 设置特效参数
		if "setup" in effect:
			effect.setup(harvest_result)

		# 添加到场景树
		get_tree().current_scene.add_child(effect)
	else:
		print("[GrowthSystem] Harvest effect scene not found")

## 浇水作物
func water_crop(crop: Crop) -> bool:
	if crop == null:
		return false

	crop.water()
	return true

## 获取可收获的作物数量
func get_harvestable_count() -> int:
	var count: int = 0
	for crop in _registered_crops:
		if crop.can_harvest():
			count += 1
	return count

## 获取所有可收获的作物
func get_harvestable_crops() -> Array[Crop]:
	var harvestable: Array[Crop] = []
	for crop in _registered_crops:
		if crop.can_harvest():
			harvestable.append(crop)
	return harvestable

## 检查作物是否可以种植在当前季节
func can_plant_in_current_season(crop_id: String) -> bool:
	var crop_data: CropData = get_crop_data(crop_id)
	if crop_data == null:
		return false

	return crop_data.can_grow_in_season(get_node("/root/TimeManager").get_season_name())

## 获取当前季节可种植的作物列表
func get_seasonal_crops() -> Array:
	var seasonal_crops: Array = []
	var current_season: String = get_node("/root/TimeManager").get_season_name()

	for crop_id in _crop_data_cache.keys():
		var crop_data: CropData = _crop_data_cache[crop_id]
		if crop_data.can_grow_in_season(current_season):
			seasonal_crops.append(crop_id)

	return seasonal_crops

## 保存所有作物状态
func save_state() -> Dictionary:
	var crops_data: Array = []

	for crop in _registered_crops:
		if not crop.is_queued_for_deletion():
			crops_data.append(crop.save_state())

	return {
		"crops": crops_data
	}

## 加载作物状态
func load_state(data: Dictionary) -> void:
	# 清除现有作物
	for crop in _registered_crops.duplicate():
		crop.queue_free()
	_registered_crops.clear()

	# 加载作物
	var crops_data: Array = data.get("crops", [])
	for crop_data_dict in crops_data:
		var crop: Crop = Crop.new()

		# 创建精灵节点
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite2D"
		crop.add_child(sprite)
		sprite.owner = crop

		# 加载状态
		crop.load_state(crop_data_dict)

		# 注册作物
		register_crop(crop)

	print("[GrowthSystem] Loaded ", _registered_crops.size(), " crops")
