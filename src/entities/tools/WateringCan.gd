extends Node2D
class_name WateringCan

## WateringCan - 水壶工具
## 用于给土壤浇水，消耗水量

signal water_changed(current: int, maximum: int)
signal water_depleted
signal watering_started(position: Vector2)
signal watering_finished

# 水量配置
@export var max_water: int = 100
@export var water_per_use: int = 5

# 当前水量
var current_water: int:
	set(value):
		current_water = clampi(value, 0, max_water)
		water_changed.emit(current_water, max_water)
		if current_water == 0:
			water_depleted.emit()

# 是否正在浇水
var is_watering: bool = false

# 浇水范围（格子）
@export var water_range: int = 1

# 浇水持续时间
@export var water_duration: float = 0.3

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var water_particles: GPUParticles2D = $WaterParticles if has_node("WaterParticles") else null
@onready var audio_stream: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

func _ready() -> void:
	current_water = max_water
	print("[WateringCan] Initialized with ", max_water, " water capacity")

## 使用水壶浇水
func use(target_position: Vector2) -> bool:
	if not can_water():
		print("[WateringCan] Cannot water: empty or already watering")
		return false

	_start_watering(target_position)
	return true

## 检查是否可以浇水
func can_water() -> bool:
	return current_water >= water_per_use and not is_watering

## 开始浇水动画和效果
func _start_watering(target_position: Vector2) -> void:
	is_watering = true
	current_water -= water_per_use
	watering_started.emit(target_position)

	# 播放音效
	if audio_stream:
		audio_stream.play()

	# 启动粒子效果
	if water_particles:
		water_particles.emitting = true
		water_particles.global_position = target_position

	# 发射浇水事件
	get_node("/root/EventBus").farm.soil_watered.emit(target_position)
	
	# 等待浇水完成
	get_tree().create_timer(water_duration).timeout.connect(_finish_watering, CONNECT_ONE_SHOT)

## 完成浇水
func _finish_watering() -> void:
	is_watering = false

	if water_particles:
		water_particles.emitting = false

	watering_finished.emit()

## 补充水量
func refill(amount: int = -1) -> void:
	if amount < 0:
		current_water = max_water
	else:
		current_water += amount
	print("[WateringCan] Refilled, current water: ", current_water, "/", max_water)

## 获取水量百分比
func get_water_percentage() -> float:
	return float(current_water) / float(max_water)

## 检查是否需要补充
func needs_refill() -> bool:
	return current_water < max_water

## 获取剩余浇水次数
func get_remaining_uses() -> int:
	return current_water / water_per_use

## 保存状态
func save_state() -> Dictionary:
	return {
		"current_water": current_water,
		"max_water": max_water,
		"water_per_use": water_per_use
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	current_water = data.get("current_water", max_water)
	max_water = data.get("max_water", 100)
	water_per_use = data.get("water_per_use", 5)
