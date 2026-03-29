extends Node2D
class_name DeathEffect

## DeathEffect - 死亡特效
## 敌人死亡时显示的视觉特效

# 配置
@export var flash_count: int = 3
@export var flash_duration: float = 0.1
@export var fade_duration: float = 0.5
@export var shrink_scale: float = 0.1
@export var particle_burst_count: int = 12

# 颜色
@export var death_color: Color = Color(1, 0.5, 0.5)

# 目标精灵
var target_sprite: Sprite2D

func _ready() -> void:
	if target_sprite:
		_play_death_effect()
	else:
		_play_simple_effect()

	await get_tree().create_timer(flash_duration * flash_count + fade_duration).timeout
	queue_free()

## 设置目标精灵
func set_target(sprite: Sprite2D) -> void:
	target_sprite = sprite

## 播放死亡特效
func _play_death_effect() -> void:
	# 闪烁效果
	for i in range(flash_count):
		target_sprite.modulate = death_color
		await get_tree().create_timer(flash_duration).timeout
		target_sprite.modulate = Color.WHITE
		await get_tree().create_timer(flash_duration).timeout

	# 粒子爆发
	_spawn_death_particles()

	# 淡出和缩小
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(target_sprite, "modulate:a", 0.0, fade_duration)
	tween.tween_property(target_sprite, "scale", Vector2(shrink_scale, shrink_scale), fade_duration)

## 播放简单特效（无目标精灵时）
func _play_simple_effect() -> void:
	# 创建简单的圆形爆发
	_spawn_death_particles()

## 生成死亡粒子
func _spawn_death_particles() -> void:
	for i in range(particle_burst_count):
		var particle = _create_death_particle()
		add_child(particle)
		_animate_death_particle(particle, i)

## 创建死亡粒子
func _create_death_particle() -> Node2D:
	var particle = Node2D.new()

	# 创建圆形粒子
	var circle = ReferenceRect.new()
	circle.editor_only = false
	circle.rect_size = Vector2(6, 6)
	circle.border_color = death_color
	particle.add_child(circle)

	return particle

## 动画化死亡粒子
func _animate_death_particle(particle: Node2D, index: int) -> void:
	var angle = (float(index) / float(particle_burst_count)) * TAU
	var direction = Vector2(cos(angle), sin(angle))

	var tween = create_tween()
	tween.set_parallel(true)

	# 爆发移动
	var target_pos = direction * 50.0
	tween.tween_property(particle, "position", target_pos, fade_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 淡出
	tween.tween_property(particle, "modulate:a", 0.0, fade_duration)\
		.set_delay(fade_duration * 0.3)

## 创建死亡特效实例
static func create(position: Vector2, sprite: Sprite2D = null) -> DeathEffect:
	var effect = DeathEffect.new()
	effect.global_position = position
	if sprite:
		effect.set_target(sprite)
	return effect

## 在指定位置显示死亡特效
static func show_death(position: Vector2, sprite: Sprite2D = null) -> DeathEffect:
	var effect = create(position, sprite)
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		tree.current_scene.add_child(effect)
	return effect