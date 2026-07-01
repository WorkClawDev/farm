extends Enemy
class_name Slime

## Slime - 史莱姆敌人
## 基础敌人类型，具有弹跳移动和简单AI

# 史莱姆特有属性
@export var bounce_height: float = 20.0
@export var bounce_interval: float = 0.8
@export var split_on_death: bool = false
@export var split_count: int = 2
@export var split_health_multiplier: float = 0.5

var bounce_timer: float = 0.0
var is_bouncing: bool = false
var original_y: float

func _ready() -> void:
	super._ready()
	_setup_slime_animation()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if current_state == State.IDLE or current_state == State.PATROL:
		_update_bounce(delta)

func _setup_slime_animation() -> void:
	# 史莱姆特有的弹跳动画
	if sprite:
		sprite.modulate = Color(0.4, 0.8, 0.4, 1)  # 绿色史莱姆

## 更新弹跳
func _update_bounce(delta: float) -> void:
	bounce_timer += delta

	if bounce_timer >= bounce_interval and not is_bouncing:
		_do_bounce()
		bounce_timer = 0.0

## 执行弹跳
func _do_bounce() -> void:
	is_bouncing = true
	original_y = position.y

	var tween = create_tween()
	tween.set_parallel(true)

	# 弹跳高度
	tween.tween_property(self, "position:y", original_y - bounce_height, bounce_interval * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 水平变形（压扁效果）
	if sprite:
		tween.parallel().tween_property(sprite, "scale:y", 0.7, bounce_interval * 0.15)
		tween.parallel().tween_property(sprite, "scale:x", 1.3, bounce_interval * 0.15)

	await get_tree().create_timer(bounce_interval * 0.3).timeout

	# 下落
	var fall_tween = create_tween()
	fall_tween.tween_property(self, "position:y", original_y, bounce_interval * 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 恢复形状
	if sprite:
		fall_tween.parallel().tween_property(sprite, "scale:y", 1.0, bounce_interval * 0.1)
		fall_tween.parallel().tween_property(sprite, "scale:x", 1.0, bounce_interval * 0.1)

	await get_tree().create_timer(bounce_interval * 0.2).timeout
	is_bouncing = false

## 重写攻击行为
func _play_attack_animation() -> void:
	# 史莱姆的攻击是跳跃撞击
	var attack_tween = create_tween()

	var attack_offset = Vector2(30, 0) * _get_direction_vector()

	# 准备攻击（压扁）
	if sprite:
		attack_tween.tween_property(sprite, "scale:y", 0.6, 0.1)
		attack_tween.tween_property(sprite, "scale:x", 1.4, 0.1)

	# 弹射攻击
	attack_tween.tween_property(self, "position", position + attack_offset, 0.15)

	# 恢复形状
	if sprite:
		attack_tween.tween_property(sprite, "scale:y", 1.0, 0.1)
		attack_tween.tween_property(sprite, "scale:x", 1.0, 0.1)

## 重写死亡行为
func die() -> void:
	# 如果可以分裂，在死亡前生成小史莱姆
	if split_on_death and max_health > 10:  # 只有足够大的史莱姆才能分裂
		_spawn_splits()

	super.die()

const SLIME_SCENE: PackedScene = preload("res://src/entities/enemies/Slime.tscn")

## 生成分裂体
func _spawn_splits() -> void:
	for i in range(split_count):
		var split: Slime = SLIME_SCENE.instantiate() as Slime
		if split == null:
			continue
		split.enemy_id = enemy_id + "_split_%d" % i
		split.enemy_name = "Small Slime"
		split.max_health = int(max_health * split_health_multiplier)
		split.current_health = split.max_health
		split.attack_damage = int(attack_damage * split_health_multiplier)
		split.move_speed = move_speed * 1.2  # 小史莱姆更快
		split.detection_range = detection_range * 0.8
		split.split_on_death = false  # 不能再分裂

		# 随机偏移位置
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		split.global_position = global_position + offset

		get_parent().add_child(split)

## 重写受伤效果
func _play_hurt_effect() -> void:
	if sprite:
		# 史莱姆受伤时的抖动效果
		var hurt_tween = create_tween()
		hurt_tween.tween_property(sprite, "modulate", Color.RED, 0.05)
		hurt_tween.tween_property(sprite, "modulate", Color(0.4, 0.8, 0.4, 1), 0.1)

		# 形变效果
		hurt_tween.parallel().tween_property(sprite, "scale:y", 1.3, 0.05)
		hurt_tween.parallel().tween_property(sprite, "scale:x", 0.7, 0.05)
		hurt_tween.tween_property(sprite, "scale", Vector2(1, 1), 0.1)