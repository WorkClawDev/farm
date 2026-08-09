extends Node2D
class_name Hoe

## Hoe - 锄头工具
## 用于耕地，将普通地面变成可种植的土壤

# 工具属性
@export var tool_name: String = "锄头"
@export var energy_cost: int = 2  # 每次使用消耗体力

# 信号
signal tool_used(success: bool, position: Vector2)

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 使用动画状态
var is_using: bool = false


func _ready() -> void:
	print("[Hoe] Tool initialized: ", tool_name)


## 使用锄头
## target: 目标节点（通常是Soil节点）
## 返回是否成功使用
func use(target: Node) -> bool:
	if is_using:
		print("[Hoe] Already in use")
		return false

	# 检查目标是否为Soil
	var soil: Soil = target as Soil
	if soil == null:
		push_warning("[Hoe] Invalid target - not a Soil node")
		return false

	# 检查是否可以耕地
	if not soil.can_till():
		print("[Hoe] Cannot till this soil")
		return false

	var stamina_manager = get_node_or_null("/root/StaminaManager")
	if stamina_manager and not stamina_manager.use_stamina(energy_cost):
		print("[Hoe] Not enough stamina")
		return false

	# 执行耕地
	is_using = true
	_play_use_animation()

	var success := soil.till()

	if success:
		print("[Hoe] Successfully tilled soil at ", soil.global_position)

	tool_used.emit(success, soil.global_position)
	
	# 延迟重置动画状态
	get_tree().create_timer(0.3).timeout.connect(_reset_use_state, CONNECT_ONE_SHOT)
	
	return success

func _reset_use_state() -> void:
	is_using = false


## 播放使用动画
func _play_use_animation() -> void:
	if animation_player and animation_player.has_animation("use"):
		animation_player.play("use")
	else:
		# 简单的旋转动画作为后备
		var tween := create_tween()
		tween.tween_property(self, "rotation", PI / 4, 0.15)
		tween.tween_property(self, "rotation", 0.0, 0.15)


## 获取工具信息
func get_tool_info() -> Dictionary:
	return {
		"name": tool_name,
		"type": "hoe",
		"energy_cost": energy_cost,
		"description": "用于耕地，将普通地面变成可种植的土壤"
	}
