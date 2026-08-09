extends Node2D
class_name UpgradeAnimation

## UpgradeAnimation - 工具升级动画效果
## 显示升级成功时的视觉反馈

# 动画配置
@export var duration: float = 1.0
@export var particle_count: int = 30
@export var flash_color: Color = Color.GOLD
@export var glow_intensity: float = 2.0

# 节点引用
var _particles: GPUParticles2D = null
var _glow_sprite: Sprite2D = null
var _tween: Tween = null

# 信号
signal animation_finished

func _ready() -> void:
	_setup_particles()
	_setup_glow()

func _setup_particles() -> void:
	_particles = GPUParticles2D.new()
	_particles.emitting = false
	_particles.amount = particle_count
	_particles.one_shot = true
	_particles.explosiveness = 0.8
	_particles.lifetime = 0.8

	# 创建粒子材质
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 20.0
	process_mat.direction = Vector3(0, -1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 100.0
	process_mat.initial_velocity_max = 200.0
	process_mat.gravity = Vector3(0, 50, 0)
	process_mat.scale_min = 2.0
	process_mat.scale_max = 5.0
	process_mat.color = flash_color

	_particles.process_material = process_mat
	add_child(_particles)

func _setup_glow() -> void:
	_glow_sprite = Sprite2D.new()
	_glow_sprite.modulate = Color(1, 1, 1, 0)
	_glow_sprite.scale = Vector2(2, 2)
	add_child(_glow_sprite)

## 播放升级动画
func play(target_position: Vector2 = Vector2.ZERO) -> void:
	global_position = target_position

	# 停止之前的动画
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	# 粒子效果
	_particles.emitting = true

	# 发光效果
	_tween.tween_property(_glow_sprite, "modulate:a", glow_intensity, duration * 0.3)
	_tween.tween_property(_glow_sprite, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)

	# 缩放效果
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), duration * 0.3)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration * 0.7).set_delay(duration * 0.3)

	# 等待动画完成
	await _tween.finished
	animation_finished.emit()

## 播放简单闪烁效果
func play_flash() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_glow_sprite, "modulate", flash_color, 0.1)
	_tween.tween_property(_glow_sprite, "modulate", Color.WHITE, 0.1)
	_tween.tween_property(_glow_sprite, "modulate", flash_color, 0.1)
	_tween.tween_property(_glow_sprite, "modulate", Color.WHITE, 0.1)

	await _tween.finished
	animation_finished.emit()

## 播放星星爆发效果
func play_star_burst() -> void:
	# 创建多个星星
	for i in range(5):
		var star := _create_star()
		add_child(star)

		var angle := (i / 5.0) * TAU
		var distance := 50.0

		var tween := create_tween()
		tween.tween_property(star, "position", Vector2(cos(angle), sin(angle)) * distance, 0.5)
		tween.parallel().tween_property(star, "modulate:a", 0.0, 0.5).set_delay(0.3)

		tween.tween_callback(star.queue_free)

	await get_tree().create_timer(0.6).timeout
	animation_finished.emit()

func _create_star() -> Node2D:
	var star := Sprite2D.new()
	star.modulate = Color.GOLD
	star.scale = Vector2(0.3, 0.3)
	star.position = Vector2.ZERO

	# 创建简单的星星纹理（使用Polygon2D代替）
	var polygon := Polygon2D.new()
	polygon.polygon = _create_star_polygon(10, 5, 2.5)
	polygon.color = Color.GOLD

	return polygon

func _create_star_polygon(outer_radius: float, points: int, inner_radius: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in range(points * 2):
		var angle := (i / float(points * 2)) * TAU - PI / 2
		var radius := outer_radius if i % 2 == 0 else inner_radius
		polygon.append(Vector2(cos(angle), sin(angle)) * radius)
	return polygon

## 设置颜色
func set_color(color: Color) -> void:
	flash_color = color
	if _particles and _particles.process_material:
		_particles.process_material.color = color