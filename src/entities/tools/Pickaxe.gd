extends Node2D
class_name Pickaxe

## Pickaxe - 镐子工具
## 用于挖掘矿石，获取矿物资源

# 工具属性
@export var tool_name: String = "镐子"
@export var base_damage: int = 1
@export var energy_cost: int = 3
@export var mining_speed: float = 1.0

# 工具等级 (影响伤害和效率)
@export var tool_level: int = 1:
	set(value):
		tool_level = clampi(value, 1, 5)
		_update_stats()

# 信号
signal mining_started(target: Node)
signal mining_finished(success: bool, ore_type: String, quantity: int)
signal tool_used(success: bool, position: Vector2)

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_particles: GPUParticles2D = $HitParticles if has_node("HitParticles") else null
@onready var audio_stream: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

# 状态
var is_mining: bool = false
var current_target: Ore = null
var mining_progress: float = 0.0


func _ready() -> void:
	_update_stats()
	print("[Pickaxe] Tool initialized: ", tool_name, " Level ", tool_level)


func _update_stats() -> void:
	# 根据等级更新属性
	base_damage = tool_level
	mining_speed = 0.8 + tool_level * 0.2
	energy_cost = 2 + tool_level


## 使用镐子挖掘
func use(target: Node) -> bool:
	if is_mining:
		print("[Pickaxe] Already mining")
		return false

	# 检查目标是否为Ore
	var ore: Ore = target as Ore
	if ore == null:
		push_warning("[Pickaxe] Invalid target - not an Ore node")
		return false

	# 检查是否可以挖掘
	if not ore.can_mine():
		print("[Pickaxe] Cannot mine this ore")
		return false

	var stamina_manager = get_node_or_null("/root/StaminaManager")
	if stamina_manager and not stamina_manager.use_stamina(energy_cost):
		print("[Pickaxe] Not enough stamina")
		return false

	# 开始挖掘
	current_target = ore
	is_mining = true
	mining_progress = 0.0

	_play_mining_animation()
	mining_started.emit(ore)

	# 执行挖掘
	var success := _do_mining(ore)

	if success:
		tool_used.emit(true, ore.global_position)

	# 等待动画完成
	get_tree().create_timer(0.3 / mining_speed).timeout.connect(_reset_mining_state, CONNECT_ONE_SHOT)

	return success

func _reset_mining_state() -> void:
	is_mining = false
	current_target = null


## 执行挖掘逻辑
func _do_mining(ore: Ore) -> bool:
	# 计算造成的伤害
	var damage := base_damage

	# 应用暴击（10%几率双倍伤害）
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < 0.1:
		damage *= 2
		print("[Pickaxe] Critical hit!")

	# 对矿石造成伤害
	var result := ore.take_damage(damage)

	if result.destroyed:
		print("[Pickaxe] Ore destroyed, obtained: ", result.item_id, " x", result.quantity)
		mining_finished.emit(true, result.item_id, result.quantity)

		# 播放粒子效果
		if hit_particles:
			hit_particles.emitting = true
			hit_particles.global_position = ore.global_position

		# 发射物品获取事件
		get_node("/root/EventBus").inventory.item_added.emit(result.item_id, result.quantity)
	else:
		print("[Pickaxe] Mining progress: ", result.current_health, "/", result.max_health)

	# 播放音效
	if audio_stream:
		audio_stream.play()

	return true


## 播放挖掘动画
func _play_mining_animation() -> void:
	if animation_player and animation_player.has_animation("mine"):
		animation_player.play("mine")
	else:
		# 简单的摆动动画作为后备
		var tween := create_tween()
		tween.tween_property(self, "rotation", -PI / 6, 0.1)
		tween.tween_property(self, "rotation", PI / 4, 0.1)
		tween.tween_property(self, "rotation", 0.0, 0.1)


## 升级工具
func upgrade() -> bool:
	if tool_level >= 5:
		print("[Pickaxe] Already at max level")
		return false

	tool_level += 1
	print("[Pickaxe] Upgraded to level ", tool_level)
	return true


## 获取工具信息
func get_tool_info() -> Dictionary:
	return {
		"name": tool_name,
		"type": "pickaxe",
		"level": tool_level,
		"damage": base_damage,
		"speed": mining_speed,
		"energy_cost": energy_cost,
		"description": "用于挖掘矿石，等级越高效率越高"
	}


## 计算挖掘特定矿石所需次数
func get_hits_needed(ore_max_health: int) -> int:
	return ceili(float(ore_max_health) / float(base_damage))


## 保存状态
func save_state() -> Dictionary:
	return {
		"tool_level": tool_level,
		"base_damage": base_damage,
		"mining_speed": mining_speed,
		"energy_cost": energy_cost
	}


## 加载状态
func load_state(data: Dictionary) -> void:
	tool_level = data.get("tool_level", 1)
	base_damage = data.get("base_damage", 1)
	mining_speed = data.get("mining_speed", 1.0)
	energy_cost = data.get("energy_cost", 3)
