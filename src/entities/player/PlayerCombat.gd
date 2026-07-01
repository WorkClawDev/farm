extends Node
class_name PlayerCombat

## PlayerCombat - 玩家战斗系统
## 处理玩家攻击、武器系统、伤害计算和战斗状态

# 武器类型枚举
enum WeaponType { SWORD, AXE, PICKAXE, HOE, FIST }

# 当前武器配置
@export var current_weapon: WeaponType = WeaponType.FIST
@export var base_damage: int = 10
@export var attack_cooldown: float = 0.5
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 2.0

# 战斗属性
var current_health: int = 100
var max_health: int = 100
var defense: int = 0
var last_attack_time: float = 0.0
var is_attacking: bool = false
var is_invincible: bool = false
var invincibility_duration: float = 1.0

# 武器数据
var weapon_data: Dictionary = {
	WeaponType.FIST: {
		"name": "Fist",
		"damage": 5,
		"range": 30.0,
		"cooldown": 0.4,
		"energy_cost": 0
	},
	WeaponType.SWORD: {
		"name": "Sword",
		"damage": 15,
		"range": 50.0,
		"cooldown": 0.5,
		"energy_cost": 2
	},
	WeaponType.AXE: {
		"name": "Axe",
		"damage": 20,
		"range": 45.0,
		"cooldown": 0.7,
		"energy_cost": 3
	},
	WeaponType.PICKAXE: {
		"name": "Pickaxe",
		"damage": 12,
		"range": 40.0,
		"cooldown": 0.6,
		"energy_cost": 2
	},
	WeaponType.HOE: {
		"name": "Hoe",
		"damage": 8,
		"range": 40.0,
		"cooldown": 0.5,
		"energy_cost": 1
	}
}

# 节点引用
var player: CharacterBody2D
var attack_area: Area2D
var hitbox: Area2D

# 信号
signal attacked(weapon: WeaponType, damage: int)
signal damaged(damage: int, source: Node)
signal healed(amount: int)
signal health_changed(current: int, maximum: int)
signal weapon_changed(weapon: WeaponType)
signal invincibility_started
signal invincibility_ended

func _ready() -> void:
	_setup_signals()

func _setup_signals() -> void:
	if EventBus:
		EventBus.player.health_changed.connect(_on_health_changed)

func _exit_tree() -> void:
	if EventBus and EventBus.player.health_changed.is_connected(_on_health_changed):
		EventBus.player.health_changed.disconnect(_on_health_changed)

## 初始化战斗系统
func initialize(player_node: CharacterBody2D) -> void:
	player = player_node
	_create_attack_area()
	_create_hitbox()
	print("[PlayerCombat] Initialized with %d health" % max_health)

## 创建攻击区域
func _create_attack_area() -> void:
	attack_area = Area2D.new()
	attack_area.name = "AttackArea"
	attack_area.collision_layer = 0
	attack_area.collision_mask = 8  # Enemy hurtbox layer
	attack_area.add_to_group("player_attack")

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = get_current_weapon_range()
	collision.shape = shape
	attack_area.add_child(collision)

	player.add_child(attack_area)

	# 连接信号
	attack_area.area_entered.connect(_on_attack_area_entered)

## 创建受伤区域
func _create_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 1  # Player layer
	hitbox.collision_mask = 8  # Enemy attack layer

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	hitbox.add_child(collision)

	player.add_child(hitbox)

	# 连接信号
	hitbox.area_entered.connect(_on_hitbox_area_entered)

## 攻击
func attack(direction: Vector2 = Vector2.ZERO) -> bool:
	if is_attacking:
		return false

	var current_time = Time.get_ticks_msec() / 1000.0
	var cooldown = get_current_weapon_cooldown()

	if current_time - last_attack_time < cooldown:
		return false

	is_attacking = true
	last_attack_time = current_time

	# 更新攻击区域位置
	_update_attack_area_position(direction)

	# 计算伤害
	var damage = calculate_damage()

	# 消耗体力
	var energy_cost = get_current_weapon_energy_cost()
	var stamina_manager = get_node_or_null("/root/StaminaManager")
	if energy_cost > 0 and stamina_manager:
		if not stamina_manager.use_stamina(energy_cost):
			is_attacking = false
			return false

	# 发射攻击信号
	attacked.emit(current_weapon, damage)
	get_node("/root/EventBus").combat.player_attacked.emit(get_weapon_name(), damage)

	# 检测攻击范围内的敌人
	_check_attack_hits(damage)

	# 重置攻击状态
	await get_tree().create_timer(cooldown).timeout
	is_attacking = false

	return true

## 更新攻击区域位置
func _update_attack_area_position(direction: Vector2) -> void:
	if attack_area == null:
		return

	var attack_range = get_current_weapon_range()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN  # 默认向下

	attack_area.position = direction.normalized() * attack_range * 0.5

## 检测攻击命中
func _check_attack_hits(damage: int) -> void:
	if attack_area == null:
		return

	var overlapping_areas = attack_area.get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("hurtbox") or area.name == "Hurtbox":
			var enemy = area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				enemy.take_damage(damage, player)

## 计算伤害
func calculate_damage() -> int:
	var weapon_damage = get_current_weapon_damage()
	var total_damage = base_damage + weapon_damage

	# 暴击检测
	if randf() < critical_chance:
		total_damage = int(total_damage * critical_multiplier)
		print("[PlayerCombat] Critical hit! Damage: %d" % total_damage)

	return total_damage

## 受到伤害
func take_damage(damage: int, source: Node = null) -> void:
	if is_invincible or current_health <= 0:
		return

	# 计算实际伤害（扣除防御）
	var actual_damage = max(1, damage - defense)
	current_health = max(0, current_health - actual_damage)

	damaged.emit(actual_damage, source)
	get_node("/root/EventBus").combat.player_damaged.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	get_node("/root/EventBus").player.health_changed.emit(current_health, max_health)

	# 播放受伤效果
	_play_damage_effect()

	# 开始无敌时间
	start_invincibility()

	if current_health <= 0:
		die()

## 播放受伤效果
func _play_damage_effect() -> void:
	if player == null:
		return

	var sprite = player.get_node_or_null("Sprite2D")
	if sprite == null:
		return

	# 闪烁效果
	for i in range(3):
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout

## 开始无敌时间
func start_invincibility() -> void:
	is_invincible = true
	invincibility_started.emit()

	# 闪烁效果
	if player:
		var sprite = player.get_node_or_null("Sprite2D")
		if sprite:
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(sprite, "modulate:a", 0.3, 0.1)
			tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

	await get_tree().create_timer(invincibility_duration).timeout

	is_invincible = false
	invincibility_ended.emit()

	# 停止闪烁
	if player:
		var sprite = player.get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate.a = 1.0

## 治疗
func heal(amount: int) -> void:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	var actual_heal = current_health - old_health

	if actual_heal > 0:
		healed.emit(actual_heal)
		health_changed.emit(current_health, max_health)
		get_node("/root/EventBus").player.health_changed.emit(current_health, max_health)
		print("[PlayerCombat] Healed %d HP" % actual_heal)

## 死亡
func die() -> void:
	print("[PlayerCombat] Player died!")
	# 这里可以触发死亡事件、显示游戏结束画面等
	get_node("/root/EventBus").combat.combat_ended.emit()

## 切换武器
func switch_weapon(weapon: WeaponType) -> void:
	current_weapon = weapon
	weapon_changed.emit(weapon)

	# 更新攻击区域范围
	if attack_area:
		var collision = attack_area.get_child(0)
		if collision and collision.shape:
			collision.shape.radius = get_current_weapon_range()

	print("[PlayerCombat] Switched to %s" % get_weapon_name())

## 获取当前武器数据
func get_current_weapon_data() -> Dictionary:
	return weapon_data.get(current_weapon, weapon_data[WeaponType.FIST])

## 获取当前武器伤害
func get_current_weapon_damage() -> int:
	return get_current_weapon_data().get("damage", 5)

## 获取当前武器范围
func get_current_weapon_range() -> float:
	return get_current_weapon_data().get("range", 30.0)

## 获取当前武器冷却时间
func get_current_weapon_cooldown() -> float:
	return get_current_weapon_data().get("cooldown", 0.5)

## 获取当前武器体力消耗
func get_current_weapon_energy_cost() -> int:
	return get_current_weapon_data().get("energy_cost", 0)

## 获取武器名称
func get_weapon_name() -> String:
	return get_current_weapon_data().get("name", "Fist")

## 设置最大生命值
func set_max_health(value: int) -> void:
	max_health = value
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health, max_health)

## 设置防御力
func set_defense(value: int) -> void:
	defense = value

## 获取生命值百分比
func get_health_percent() -> float:
	return float(current_health) / float(max_health) * 100.0

## 攻击区域进入回调
func _on_attack_area_entered(area: Area2D) -> void:
	if is_attacking and area.is_in_group("hurtbox"):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			var damage = calculate_damage()
			enemy.take_damage(damage, player)

## 受伤区域进入回调
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_attack"):
		var damage: int = 5
		if area.has_meta("damage"):
			damage = area.get_meta("damage")
		var source = area.get_parent()
		take_damage(damage, source)

## 血量变化回调
func _on_health_changed(current: int, maximum: int) -> void:
	current_health = current
	max_health = maximum

## 保存状态
func save_state() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"defense": defense,
		"current_weapon": current_weapon,
		"critical_chance": critical_chance
	}

## 加载状态
func load_state(state: Dictionary) -> void:
	if state.has("current_health"):
		current_health = state.current_health
	if state.has("max_health"):
		max_health = state.max_health
	if state.has("defense"):
		defense = state.defense
	if state.has("current_weapon"):
		current_weapon = state.current_weapon
	if state.has("critical_chance"):
		critical_chance = state.critical_chance

	health_changed.emit(current_health, max_health)
