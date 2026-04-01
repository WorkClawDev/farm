extends Node2D
class_name Crop

## Crop - 作物实例
## 代表场景中种植的单个作物，处理生长、收获和可视化

signal growth_stage_changed(new_stage: int)
signal crop_harvested(crop_id: String, quality: int, quantity: int)
signal crop_died(crop_id: String)

## 作物状态枚举
enum State {
	SEED,       # 种子阶段
	GROWING,    # 生长中
	MATURE,     # 成熟可收获
	DEAD        # 枯萎
}

## 作物数据
var crop_data: CropData = null
## 作物ID
var crop_id: String = ""

## 当前生长阶段 (0-最后阶段)
var current_stage: int = 0
## 当前阶段已生长天数
var days_in_stage: int = 0
## 总生长天数
var total_days_grown: int = 0

## 品质
var quality: CropData.Quality = CropData.Quality.NORMAL

## 当前状态
var current_state: State = State.SEED

## 是否已浇水（今天）
var is_watered: bool = false
## 使用了肥料类型 (0=无, 1=基础, 2=高级, 3=顶级)
var fertilizer_type: int = 0

## 土地位置（用于引用）
var soil_position: Vector2 = Vector2.ZERO

## 精灵节点
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("crops")


func setup(data: CropData, pos: Vector2, fertilizer: int = 0) -> void:
	crop_data = data
	crop_id = data.crop_id
	soil_position = pos
	fertilizer_type = fertilizer
	current_stage = 0
	days_in_stage = 0
	total_days_grown = 0
	current_state = State.SEED

	# 计算初始品质（基于肥料）
	_calculate_initial_quality()

	# 更新视觉效果
	_update_sprite()
	print("[Crop] Planted: ", crop_id, " at ", soil_position)


## 每日更新（由 GrowthSystem 调用）
func on_day_passed() -> void:
	if current_state == State.DEAD:
		return

	# 检查是否在正确季节
	if crop_data and crop_data.dies_out_of_season:
		var time_manager = get_node_or_null("/root/TimeManager")
		if time_manager and not crop_data.can_grow_in_season(time_manager.get_season_name()):
			_die()
			return

	# 检查是否需要浇水
	if crop_data and crop_data.requires_water and not is_watered:
		# 不浇水可能会导致品质下降或生长停滞
		# 这里简化处理：不浇水不生长
		is_watered = false  # 重置浇水状态
		return

	# 生长
	_grow()

	# 重置浇水状态（新的一天）
	is_watered = false


## 浇水
func water() -> void:
	is_watered = true
	_update_sprite()  # 更新视觉效果显示浇水状态
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.farm:
		event_bus.farm.soil_watered.emit(soil_position)


## 生长逻辑
func _grow() -> void:
	if crop_data == null:
		return

	total_days_grown += 1
	days_in_stage += 1

	# 检查是否进入下一阶段
	if days_in_stage >= crop_data.growth_days[current_stage]:
		_advance_stage()


## 进入下一生长阶段
func _advance_stage() -> void:
	days_in_stage = 0

	if current_stage < crop_data.growth_days.size() - 1:
		# 还有更多阶段
		current_stage += 1
		current_state = State.GROWING
		growth_stage_changed.emit(current_stage)
		print("[Crop] ", crop_id, " grew to stage ", current_stage)
	else:
		# 成熟
		current_state = State.MATURE
		# 最终品质计算
		_calculate_final_quality()
		growth_stage_changed.emit(current_stage)
		print("[Crop] ", crop_id, " is now mature!")

	_update_sprite()


## 计算初始品质（基于肥料）
func _calculate_initial_quality() -> void:
	# 肥料影响基础品质
	match fertilizer_type:
		0:  # 无肥料
			quality = CropData.Quality.NORMAL
		1:  # 基础肥料
			quality = CropData.Quality.NORMAL
		2:  # 高级肥料
			if randf() < 0.3:
				quality = CropData.Quality.SILVER
		3:  # 顶级肥料
			if randf() < 0.5:
				quality = CropData.Quality.SILVER
			elif randf() < 0.3:
				quality = CropData.Quality.GOLD


## 计算最终品质（收获时）
func _calculate_final_quality() -> void:
	# 品质有机会提升
	var quality_chance: float = randf()

	# 肥料加成
	var bonus: float = fertilizer_type * 0.1

	# 如果生长期间每天都浇水，额外加成
	# 这里简化处理，只基于肥料

	match fertilizer_type:
		0:
			if quality_chance < 0.05 + bonus:
				quality = CropData.Quality.SILVER
		1:
			if quality_chance < 0.15 + bonus:
				quality = CropData.Quality.SILVER
		2:
			if quality_chance < 0.4 + bonus:
				quality = CropData.Quality.SILVER
			elif quality_chance < 0.15 + bonus:
				quality = CropData.Quality.GOLD
		3:
			if quality_chance < 0.5 + bonus:
				quality = CropData.Quality.SILVER
			elif quality_chance < 0.25 + bonus:
				quality = CropData.Quality.GOLD
			elif quality_chance < 0.05:
				quality = CropData.Quality.IRIDIUM


## 收获
func harvest() -> Dictionary:
	if current_state != State.MATURE:
		return {}

	# 计算收获数量
	var quantity: int = randi_range(crop_data.min_harvest, crop_data.max_harvest)

	# 发射信号
	crop_harvested.emit(crop_id, quality, quantity)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.farm:
		event_bus.farm.crop_harvested.emit(crop_id, quality, quantity)

	# 检查是否可以重复收获
	if crop_data.regrow:
		# 重置到再生阶段
		current_stage = crop_data.growth_days.size() - 2  # 回到倒数第二阶段
		days_in_stage = 0
		current_state = State.GROWING
		_update_sprite()
		print("[Crop] ", crop_id, " will regrow in ", crop_data.regrow_days, " days")
	else:
		# 作物被移除
		queue_free()

	return {
		"crop_id": crop_id,
		"quality": quality,
		"quantity": quantity,
		"exp": crop_data.base_exp
	}


## 作物枯萎
func _die() -> void:
	current_state = State.DEAD
	crop_died.emit(crop_id)
	print("[Crop] ", crop_id, " has died")
	_update_sprite()


## 更新精灵显示
func _update_sprite() -> void:
	if sprite == null or crop_data == null:
		return

	# 根据状态和阶段选择精灵
	var sprite_path: String = ""

	if current_state == State.DEAD:
		# 枯萎的作物显示特殊精灵
		sprite_path = "res://assets/sprites/crops/crop_dead.png"
	elif current_state == State.MATURE:
		# 成熟作物
		if crop_data.stage_sprites.size() > 0:
			sprite_path = crop_data.stage_sprites[-1]
	else:
		# 生长中
		if current_stage < crop_data.stage_sprites.size():
			sprite_path = crop_data.stage_sprites[current_stage]

	# 加载精灵（如果路径有效）
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	# 如果有浇水效果，可以在这里添加调制颜色
	if is_watered:
		sprite.modulate = Color(0.8, 0.9, 1.0)  # 略微蓝色表示湿润
	else:
		sprite.modulate = Color.WHITE


## 检查是否可以收获
func can_harvest() -> bool:
	return current_state == State.MATURE


## 检查已枯萎
func is_dead() -> bool:
	return current_state == State.DEAD


## 获取当前状态
func get_state() -> State:
	return current_state


## 保存状态
func save_state() -> Dictionary:
	return {
		"crop_id": crop_id,
		"soil_position_x": soil_position.x,
		"soil_position_y": soil_position.y,
		"current_stage": current_stage,
		"days_in_stage": days_in_stage,
		"total_days_grown": total_days_grown,
		"quality": quality,
		"current_state": current_state,
		"is_watered": is_watered,
		"fertilizer_type": fertilizer_type
	}


## 加载状态
func load_state(data: Dictionary) -> void:
	crop_id = data.get("crop_id", "")
	soil_position = Vector2(
		data.get("soil_position_x", 0),
		data.get("soil_position_y", 0)
	)
	current_stage = data.get("current_stage", 0)
	days_in_stage = data.get("days_in_stage", 0)
	total_days_grown = data.get("total_days_grown", 0)
	quality = data.get("quality", CropData.Quality.NORMAL)
	current_state = data.get("current_state", State.SEED)
	is_watered = data.get("is_watered", false)
	fertilizer_type = data.get("fertilizer_type", 0)

	# 加载作物数据
	_load_crop_data()
	_update_sprite()


## 从数据库加载作物数据
func _load_crop_data() -> void:
	var growth_system = get_node_or_null("/root/GrowthSystem")
	if growth_system:
		crop_data = growth_system.get_crop_data(crop_id)
