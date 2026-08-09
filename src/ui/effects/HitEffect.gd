extends Node2D
class_name HitEffect

## HitEffect - 攻击命中特效
## 显示攻击命中时的视觉效果

# 配置
@export var particle_count: int = 8
@export var particle_speed: float = 100.0
@export var particle_lifetime: float = 0.3
@export var particle_size: float = 4.0

# 颜色
@export var hit_color: Color = Color.WHITE
@export var critical_color: Color = Color.YELLOW

# 粒子场景
var particle_scene: PackedScene

func _ready() -> void:
	_spawn_particles()
	await get_tree().create_timer(particle_lifetime + 0.1).timeout
	queue_free()

## 生成粒子
func _spawn_particles() -> void:
	for i in range(particle_count):
		var particle = _create_particle()
		add_child(particle)
		_animate_particle(particle, i)

## 创建单个粒子
func _create_particle() -> Node2D:
	var particle = Node2D.new()

	# 创建简单的方块作为粒子
	var rect = ReferenceRect.new()
	rect.editor_only = false
	rect.rect_size = Vector2(particle_size, particle_size)
	rect.border_color = hit_color
	particle.add_child(rect)

	return particle

## 动画化粒子
func _animate_particle(particle: Node2D, index: int) -> void:
	# 随机方向
	var angle = randf() * TAU
	var direction = Vector2(cos(angle), sin(angle))

	# 随机速度变化
	var speed = particle_speed * randf_range(0.5, 1.5)

	# 创建动画
	var tween = create_tween()
	tween.set_parallel(true)

	# 移动
	var target_pos = direction * speed * particle_lifetime
	tween.tween_property(particle, "position", target_pos, particle_lifetime)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# 淡出
	tween.tween_property(particle, "modulate:a", 0.0, particle_lifetime)\
		.set_delay(particle_lifetime * 0.5)

	# 缩小
	tween.tween_property(particle, "scale", Vector2(0.1, 0.1), particle_lifetime)

## 创建命中特效实例
static func create(position: Vector2, is_critical: bool = false) -> HitEffect:
	var effect = HitEffect.new()
	effect.global_position = position

	if is_critical:
		effect.particle_count = 12
		effect.particle_size = 6.0
		effect.hit_color = effect.critical_color

	return effect

## 在指定位置显示命中特效
static func show_hit(position: Vector2, is_critical: bool = false) -> HitEffect:
	var effect = create(position, is_critical)
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		tree.current_scene.add_child(effect)
	return effect