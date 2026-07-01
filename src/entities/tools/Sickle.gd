extends Node2D
class_name Sickle

## Sickle - 镰刀工具
## 用于收割作物和割草

# 工具属性
@export var tool_name: String = "镰刀"
@export var energy_cost: int = 2

# 信号
signal tool_used(success: bool, target: Node)

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 使用动画状态
var is_using: bool = false

func _ready() -> void:
	print("[Sickle] Tool initialized: ", tool_name)

## 使用镰刀
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
	
	# 检查目标是否为作物
	if target is Crop:
		var crop = target as Crop
		if crop.can_harvest():
			var result = crop.harvest()
			if not result.is_empty():
				if Inventory:
					Inventory.add_item(result.crop_id, result.quantity)
				success = true
				print("[Sickle] Harvested ", result.quantity, "x ", result.crop_id)
	
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
		# 简单的挥动动画
		var tween = create_tween()
		tween.tween_property(self, "rotation", -PI / 3, 0.1)
		tween.tween_property(self, "rotation", PI / 3, 0.1)
		tween.tween_property(self, "rotation", 0.0, 0.1)
