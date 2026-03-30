extends CharacterBody2D
class_name Enemy

## Enemy - 敌人基类
## 处理敌人AI、移动、攻击、碰撞检测和掉落物

# 敌人配置
@export var enemy_id: String = "enemy_001"
@export var enemy_name: String = "Slime"
@export var max_health: int = 30
@export var attack_damage: int = 5
@export var move_speed: float = 60.0
@export var detection_range: float = 150.0
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.5
@export var knockback_resistance: float = 0.5  # 0-1, higher = more resistant
@export var experience_value: int = 10

# 状态枚举
enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

# 方向枚举
enum Direction { DOWN, UP, LEFT, RIGHT }
var current_direction: Direction = Direction.DOWN

# 战斗属性
var current_health: int
var last_attack_time: float = 0.0
var is_attacking: bool = false
var is_hurt: bool = false
var target: Node2D = null

# 巡逻相关
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var patrol_wait_time: float = 2.0
var patrol_timer: float = 0.0

# 掉落物配置
@export var loot_table: Array[Dictionary] = []  # [{"item_id": "slime_gel", "chance": 0.5, "min": 1, "max": 3}]

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar

# 信号
signal died(enemy: Enemy)
signal health_changed(current: int, maximum: int)
signal state_changed(new_state: State)

# 方向对应的静止帧
const IDLE_FRAMES = {
	Direction.DOWN: 0,
	Direction.UP: 4,
	Direction.LEFT: 2,
	Direction.RIGHT: 6
}

func _ready() -> void:
	current_health = max_health
	_setup_areas()
	_setup_health_bar()
	_setup_patrol_points()
	get_node("/root/EventBus").enemy_spawned.emit(self)
	print("[Enemy] %s initialized with %d health" % [enemy_name, max_health])

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	_update_state(delta)
	_update_behavior(delta)
	_update_animation()
	move_and_slide()

## 设置检测区域
func _setup_areas() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

## 设置血条
func _setup_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = false  # 默认隐藏，受伤后显示

## 设置巡逻点
func _setup_patrol_points() -> void:
	# 默认在当前位置周围生成巡逻点
	if patrol_points.is_empty():
		var base_pos = global_position
		patrol_points = [
			base_pos + Vector2(50, 0),
			base_pos + Vector2(0, 50),
			base_pos + Vector2(-50, 0),
			base_pos + Vector2(0, -50)
		]

## 更新状态
func _update_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_check_for_player()
		State.PATROL:
			_check_for_player()
			_update_patrol(delta)
		State.CHASE:
			if target == null or not is_instance_valid(target):
				change_state(State.IDLE)
				return
			_chase_target()
		State.ATTACK:
			if is_attacking:
				return
			_try_attack()
		State.HURT:
			pass  # 受伤动画结束后自动恢复

## 检测玩家
func _check_for_player() -> void:
	if target != null and is_instance_valid(target):
		return

	# 查找范围内的玩家
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player is Player:
			var distance = global_position.distance_to(player.global_position)
			if distance <= detection_range:
				target = player
				change_state(State.CHASE)
				get_node("/root/EventBus").combat_started.emit()
				return

## 更新巡逻行为
func _update_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return

	var target_pos = patrol_points[current_patrol_index]
	var direction = (target_pos - global_position).normalized()

	if global_position.distance_to(target_pos) < 5.0:
		patrol_timer += delta
		if patrol_timer >= patrol_wait_time:
			patrol_timer = 0.0
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		velocity = Vector2.ZERO
	else:
		velocity = direction * move_speed * 0.5  # 巡逻速度较慢
		_update_direction_from_velocity(direction)

## 追击目标
func _chase_target() -> void:
	if target == null:
		change_state(State.IDLE)
		return

	var distance = global_position.distance_to(target.global_position)

	if distance > detection_range * 1.5:  # 超出追击范围
		target = null
		change_state(State.IDLE)
		get_node("/root/EventBus").combat_ended.emit()
		return

	if distance <= attack_range:
		change_state(State.ATTACK)
		return

	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	_update_direction_from_velocity(direction)

## 尝试攻击
func _try_attack() -> void:
	if is_attacking or is_hurt:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time < attack_cooldown:
		change_state(State.CHASE)
		return

	if target == null or not is_instance_valid(target):
		change_state(State.IDLE)
		return

	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range * 1.5:
		change_state(State.CHASE)
		return

	is_attacking = true
	last_attack_time = current_time
	velocity = Vector2.ZERO

	# 播放攻击动画
	_play_attack_animation()

	# 延迟造成伤害（等待攻击动画）
	await get_tree().create_timer(0.3).timeout

	if current_state != State.DEAD and target != null:
		_deal_damage_to_target()

	await get_tree().create_timer(0.3).timeout
	is_attacking = false

	if current_state != State.DEAD:
		change_state(State.CHASE if target != null else State.IDLE)

## 对目标造成伤害
func _deal_damage_to_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		get_node("/root/EventBus").player_attacked.emit(enemy_name, attack_damage)

## 播放攻击动画
func _play_attack_animation() -> void:
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
	else:
		# 简单的前进动画作为后备
		var tween = create_tween()
		var attack_offset = Vector2(10, 0) * _get_direction_vector()
		tween.tween_property(self, "position", position + attack_offset, 0.15)
		tween.tween_property(self, "position", position, 0.15)

## 更新行为
func _update_behavior(_delta: float) -> void:
	pass  # 子类可以重写

## 更新动画
func _update_animation() -> void:
	if not animation_player:
		return

	var anim_name = _get_animation_name()

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	elif sprite and IDLE_FRAMES.has(current_direction):
		sprite.frame = IDLE_FRAMES[current_direction]

## 获取动画名称
func _get_animation_name() -> String:
	match current_state:
		State.IDLE, State.PATROL:
			return "idle" if velocity == Vector2.ZERO else "walk"
		State.CHASE:
			return "chase" if animation_player.has_animation("chase") else "walk"
		State.ATTACK:
			return "attack"
		State.HURT:
			return "hurt"
		State.DEAD:
			return "death"
		_:
			return "idle"

## 更新方向
func _update_direction_from_velocity(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	var new_direction: Direction
	if abs(dir.x) > abs(dir.y):
		new_direction = Direction.LEFT if dir.x < 0 else Direction.RIGHT
	else:
		new_direction = Direction.UP if dir.y < 0 else Direction.DOWN

	if new_direction != current_direction:
		current_direction = new_direction

## 获取方向向量
func _get_direction_vector() -> Vector2:
	match current_direction:
		Direction.DOWN: return Vector2.DOWN
		Direction.UP: return Vector2.UP
		Direction.LEFT: return Vector2.LEFT
		Direction.RIGHT: return Vector2.RIGHT
		_: return Vector2.DOWN

## 切换状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_changed.emit(new_state)

## 受到伤害
func take_damage(damage: int, source: Node = null) -> void:
	if current_state == State.DEAD:
		return

	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, max_health)
	get_node("/root/EventBus").enemy_damaged.emit(self, damage)

	# 显示血条
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health

	# 播放受伤效果
	_play_hurt_effect()

	if current_health <= 0:
		die()
	else:
		# 应用击退
		if source:
			_apply_knockback(source)

		change_state(State.HURT)
		await get_tree().create_timer(0.3).timeout

		if current_state != State.DEAD:
			change_state(State.CHASE if target != null else State.IDLE)

## 播放受伤效果
func _play_hurt_effect() -> void:
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

## 应用击退
func _apply_knockback(source: Node) -> void:
	if source == null:
		return

	var knockback_direction = (global_position - source.global_position).normalized()
	var knockback_force = 100.0 * (1.0 - knockback_resistance)

	velocity = knockback_direction * knockback_force
	move_and_slide()

## 死亡
func die() -> void:
	change_state(State.DEAD)
	velocity = Vector2.ZERO

	# 播放死亡动画
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	else:
		# 简单的消失效果
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
			await tween.finished

	# 生成掉落物
	var loot = _generate_loot()
	get_node("/root/EventBus").enemy_died.emit(self, loot)
	died.emit(self)

	# 禁用碰撞和区域
	if collision_shape:
		collision_shape.disabled = true
	if detection_area:
		detection_area.monitoring = false
	if attack_area:
		attack_area.monitoring = false

	queue_free()

## 生成掉落物
func _generate_loot() -> Dictionary:
	var loot = {}

	for item in loot_table:
		if randf() <= item.get("chance", 1.0):
			var quantity = randi_range(item.get("min", 1), item.get("max", 1))
			loot[item.item_id] = quantity

	return loot

## 检测区域回调
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player and current_state != State.DEAD:
		target = body
		change_state(State.CHASE)
		get_node("/root/EventBus").combat_started.emit()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		# 保持追踪一段时间后再放弃追击

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body is Player and current_state in [State.CHASE, State.IDLE]:
		change_state(State.ATTACK)

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body == target and current_state == State.ATTACK:
		change_state(State.CHASE)

## 受伤区域回调
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		# 从攻击区域获取伤害值（通过 metadata 或属性）
		var damage_val: int = 5
		var source_node: Node = null
		if area.has_meta("damage"):
			damage_val = area.get_meta("damage")
		if area.has_meta("owner"):
			source_node = area.get_meta("owner")
		take_damage(damage_val, source_node)

## 获取敌人信息
func get_enemy_info() -> Dictionary:
	return {
		"id": enemy_id,
		"name": enemy_name,
		"health": current_health,
		"max_health": max_health,
		"damage": attack_damage,
		"state": current_state,
		"position": global_position
	}

## 保存状态
func save_state() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"position": {"x": global_position.x, "y": global_position.y},
		"health": current_health,
		"state": current_state,
		"direction": current_direction
	}

## 加载状态
func load_state(state: Dictionary) -> void:
	if state.has("position"):
		global_position = Vector2(state.position.x, state.position.y)
	if state.has("health"):
		current_health = state.health
		if health_bar:
			health_bar.value = current_health
	if state.has("state"):
		change_state(state.state)
	if state.has("direction"):
		current_direction = state.direction