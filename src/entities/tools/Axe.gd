extends Node2D
class_name Axe

## Axe - 斧头工具
## 用于砍伐树木和破坏木制品

# 工具属性
@export var tool_name: String = "斧头"
@export var energy_cost: int = 3
@export var damage: int = 10

# 信号
signal tool_used(success: bool, target: Node)

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 使用动画状态
var is_using: bool = false

func _ready() -> void:
	print("[Axe] Tool initialized: ", tool_name)

## 使用斧头
func use(target: Node) -> bool:
	if is_using:
		return false
	
	is_using = true
	_play_use_animation()
	
	var success = false
	var stamina_manager = get_node_or_null("/root/StaminaManager")
	if stamina_manager and not stamina_manager.use_stamina(energy_cost):
		is_using = false
		return false
	
	# 这里可以添加对树木的伤害逻辑
	# 例如：if target.has_method("take_damage"): target.take_damage(damage)
	
	tool_used.emit(success, target)
	
	# 延迟重置
	get_tree().create_timer(0.3).timeout.connect(_reset_use_state, CONNECT_ONE_SHOT)
	
	return success

func _reset_use_state() -> void:
	is_using = false

## 播放使用动画
func _play_use_animation() -> void:
	if animation_player and animation_player.has_animation("use"):
		animation_player.play("use")
	else:
		# 简单的挥砍动画
		var tween = create_tween()
		tween.tween_property(self, "rotation", PI / 2, 0.15)
		tween.tween_property(self, "rotation", 0.0, 0.15)
