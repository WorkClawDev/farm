extends Enemy
class_name Bat

## Bat - 蝙蝠敌人
## 空中敌人，具有飞行能力和俯冲攻击

# 蝙蝠特有属性
@export var fly_amplitude: float = 10.0
@export var fly_frequency: float = 2.0
@export var dive_attack_range: float = 100.0
@export var dive_speed_multiplier: float = 2.0

var fly_time: float = 0.0
var base_y: float
var is_diving: bool = false

func _ready() -> void:
	super._ready()
	base_y = position.y
	_setup_bat_animation()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	fly_time += delta

	if not is_diving and current_state not in [State.ATTACK, State.HURT]:
		_apply_flying_movement(delta)

	super._physics_process(delta)

func _setup_bat_animation() -> void:
	if sprite:
		sprite.modulate = Color(0.3, 0.2, 0.4, 1)  # 紫色蝙蝠

## 应用飞行运动
func _apply_flying_movement(_delta: float) -> void:
	# 上下浮动
	var float_offset = sin(fly_time * fly_frequency) * fly_amplitude
	position.y = base_y + float_offset

## 重写追击行为
func _chase_target() -> void:
	if target == null:
		change_state(State.IDLE)
		return

	var distance = global_position.distance_to(target.global_position)

	# 俯冲攻击
	if distance <= dive_attack_range and not is_diving:
		_start_dive_attack()
		return

	if distance > detection_range * 1.5:
		target = null
		change_state(State.IDLE)
		get_node("/root/EventBus").combat.combat_ended.emit()
		return

	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	_update_direction_from_velocity(direction)

## 开始俯冲攻击
func _start_dive_attack() -> void:
	if is_diving or target == null:
		return

	is_diving = true
	change_state(State.ATTACK)

	var dive_direction = (target.global_position - global_position).normalized()

	# 俯冲动画
	var dive_tween = create_tween()

	# 快速俯冲
	dive_tween.tween_property(self, "velocity", dive_direction * move_speed * dive_speed_multiplier, 0.1)

	await get_tree().create_timer(0.3).timeout

	# 造成伤害
	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage, self)
				get_node("/root/EventBus").combat.player_attacked.emit(enemy_name, attack_damage)

	# 恢复
	await get_tree().create_timer(0.5).timeout
	is_diving = false
	base_y = position.y

	if current_state != State.DEAD:
		change_state(State.CHASE if target != null else State.PATROL)

## 重写攻击动画
func _play_attack_animation() -> void:
	if sprite:
		# 蝙蝠攻击时的旋转
		var attack_tween = create_tween()
		attack_tween.tween_property(sprite, "rotation", PI * 0.25, 0.15)
		attack_tween.tween_property(sprite, "rotation", 0.0, 0.15)

## 重写动画更新
func _get_animation_name() -> String:
	if is_diving:
		return "dive" if animation_player and animation_player.has_animation("dive") else "attack"
	return super._get_animation_name()

## 重写受伤效果
func _play_hurt_effect() -> void:
	if sprite:
		var hurt_tween = create_tween()
		hurt_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
		hurt_tween.tween_property(sprite, "modulate", Color(0.3, 0.2, 0.4, 1), 0.1)

## 重写死亡
func die() -> void:
	# 蝙蝠死亡时下落
	if sprite:
		var fall_tween = create_tween()
		fall_tween.tween_property(sprite, "rotation", PI * 0.5, 0.3)
		fall_tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)

	super.die()
