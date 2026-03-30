extends Node2D
class_name Soil

## Soil - 土壤地块类
## 管理单个土壤地块的状态和作物

# 土壤状态
enum State { UNTILLED, TILLED, WATERED }

# 信号
signal soil_tilled(soil: Soil)
signal soil_watered(soil: Soil)
signal soil_dried(soil: Soil)
signal crop_planted(soil: Soil, crop_id: String)
signal moisture_changed(soil: Soil, current: int, maximum: int)

# 当前状态
@export var current_state: State = State.UNTILLED:
	set(value):
		current_state = value
		_update_visual()

# 水分系统
@export var max_moisture: int = 100
@export var moisture_consumption_per_day: int = 30  # 每日水分消耗
@export var moisture_threshold: int = 40  # 作物生长所需最低水分

var moisture: int = 0:
	set(value):
		var old_moisture = moisture
		moisture = clampi(value, 0, max_moisture)
		if old_moisture != moisture:
			moisture_changed.emit(self, moisture, max_moisture)
			_update_visual()

# 种植的作物引用
var crop: Node2D = null

# 肥料类型 (0: 无, 1: 基础肥料, 2: 高级肥料)
var fertilizer_type: int = 0

# 土地块位置（网格坐标）
var grid_position: Vector2i = Vector2i.ZERO

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var moisture_indicator: Sprite2D = $MoistureIndicator if has_node("MoistureIndicator") else null

# 土壤视觉颜色
const COLOR_UNTILLED = Color(0.4, 0.25, 0.1)  # 棕色
const COLOR_TILLED = Color(0.3, 0.2, 0.1)     # 深棕色
const COLOR_WATERED = Color(0.2, 0.15, 0.1)   # 湿润深色


func _ready() -> void:
	_setup_interaction()
	_connect_signals()
	_update_visual()


func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.day_changed.connect(_on_day_changed)


func _setup_interaction() -> void:
	if interaction_area:
		interaction_area.input_event.connect(_on_interaction_area_input_event)
		interaction_area.mouse_entered.connect(_on_mouse_entered)
		interaction_area.mouse_exited.connect(_on_mouse_exited)


func _update_visual() -> void:
	if sprite == null:
		return

	match current_state:
		State.UNTILLED:
			sprite.modulate = COLOR_UNTILLED
		State.TILLED:
			sprite.modulate = COLOR_TILLED
		State.WATERED:
			sprite.modulate = COLOR_WATERED

	# 更新水分指示器
	if moisture_indicator:
		var alpha = float(moisture) / float(max_moisture) * 0.6
		moisture_indicator.modulate = Color(0.2, 0.5, 0.9, alpha)
		moisture_indicator.visible = moisture > 0


## 耕地 - 使用锄头
func till() -> bool:
	if current_state != State.UNTILLED:
		print("[Soil] Cannot till - already tilled or watered")
		return false

	current_state = State.TILLED
	soil_tilled.emit(self)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.crop_planted.emit("soil_tilled", global_position)  # 复用信号
	print("[Soil] Tilled at ", grid_position)
	return true


## 浇水
func water(amount: int = 50) -> bool:
	if current_state == State.UNTILLED:
		print("[Soil] Cannot water - untilled soil")
		return false

	# 增加水分
	moisture += amount

	# 更新状态为已浇水
	if current_state == State.TILLED:
		current_state = State.WATERED

	soil_watered.emit(self)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.soil_watered.emit(global_position)
	print("[Soil] Watered at ", grid_position, ", moisture: ", moisture, "/", max_moisture)
	return true


## 每日更新 - 由TimeManager调用
func _on_day_changed(_new_day: int) -> void:
	_process_daily_moisture()


## 处理每日水分消耗
func _process_daily_moisture() -> void:
	if current_state == State.UNTILLED:
		return

	# 消耗水分
	moisture -= moisture_consumption_per_day

	# 检查是否干旱
	if moisture <= 0:
		moisture = 0
		if current_state == State.WATERED:
			current_state = State.TILLED
			soil_dried.emit(self)
			var event_bus = get_node_or_null("/root/EventBus")
			if event_bus:
				event_bus.soil_dried.emit(global_position)
			print("[Soil] Dried at ", grid_position)

	_update_visual()


## 检查水分是否充足
func has_sufficient_moisture() -> bool:
	return moisture >= moisture_threshold


## 获取水分百分比
func get_moisture_percentage() -> float:
	return float(moisture) / float(max_moisture) * 100.0


## 干燥 - 由每日水分消耗自动处理
func dry() -> void:
	if current_state == State.WATERED:
		current_state = State.TILLED
		moisture = 0
		soil_dried.emit(self)
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus:
			event_bus.soil_dried.emit(global_position)
		print("[Soil] Dried at ", grid_position)


## 种植作物
func plant_crop(crop_scene: PackedScene, crop_id: String) -> bool:
	if current_state == State.UNTILLED:
		print("[Soil] Cannot plant - untilled soil")
		return false

	if crop != null:
		print("[Soil] Cannot plant - already has crop")
		return false

	var new_crop := crop_scene.instantiate()
	new_crop.global_position = global_position
	get_parent().add_child(new_crop)
	crop = new_crop

	crop_planted.emit(self, crop_id)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.crop_planted.emit(crop_id, global_position)
	print("[Soil] Planted ", crop_id, " at ", grid_position)
	return true


## 收获作物
func harvest_crop() -> Node2D:
	if crop == null:
		print("[Soil] No crop to harvest")
		return null

	var harvested_crop := crop
	crop = null
	print("[Soil] Harvested crop at ", grid_position)
	return harvested_crop


## 移除作物（枯萎等）
func remove_crop() -> void:
	if crop:
		crop.queue_free()
		crop = null
		print("[Soil] Removed crop at ", grid_position)


## 检查是否可以种植
func can_plant() -> bool:
	return current_state != State.UNTILLED and crop == null


## 检查是否可以耕地
func can_till() -> bool:
	return current_state == State.UNTILLED


## 检查是否可以浇水
func can_water() -> bool:
	return current_state != State.UNTILLED and moisture < max_moisture


## 获取土壤数据（用于存档）
func get_save_data() -> Dictionary:
	return {
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"state": current_state,
		"fertilizer_type": fertilizer_type,
		"has_crop": crop != null,
		"moisture": moisture,
		"max_moisture": max_moisture
	}


## 加载土壤数据（从存档）
func load_save_data(data: Dictionary) -> void:
	grid_position = Vector2i(data.grid_position.x, data.grid_position.y)
	current_state = data.state
	fertilizer_type = data.fertilizer_type
	moisture = data.get("moisture", 0)
	max_moisture = data.get("max_moisture", 100)


# 交互事件处理
func _on_interaction_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 由工具系统处理交互
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus:
			event_bus.player_interacted.emit(self)


func _on_mouse_entered() -> void:
	modulate = Color(1.2, 1.2, 1.2)  # 高亮效果


func _on_mouse_exited() -> void:
	modulate = Color(1.0, 1.0, 1.0)  # 恢复正常