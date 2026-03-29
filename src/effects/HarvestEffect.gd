extends Node2D
class_name HarvestEffect

## HarvestEffect - 收获特效
## 显示收获时的视觉效果，包括粒子、图标弹出等

## 品质颜色
const QUALITY_COLORS := {
	CropData.Quality.NORMAL: Color.WHITE,
	CropData.Quality.SILVER: Color(0.75, 0.75, 0.85),
	CropData.Quality.GOLD: Color(1.0, 0.85, 0.4),
	CropData.Quality.IRIDIUM: Color(0.7, 0.5, 1.0)
}

## 品质名称
const QUALITY_NAMES := {
	CropData.Quality.NORMAL: "",
	CropData.Quality.SILVER: "银品质",
	CropData.Quality.GOLD: "金品质",
	CropData.Quality.IRIDIUM: "铱品质"
}

## 收获结果数据
var _harvest_data: Dictionary = {}

## 动画持续时间
var _duration: float = 1.0

## 粒子数量
var _particle_count: int = 8

## 主精灵
var _icon_sprite: Sprite2D

## 标签
var _quantity_label: Label
var _quality_label: Label

## 动画计时器
var _timer: float = 0.0

## 是否正在动画
var _is_animating: bool = false


func _ready() -> void:
	# 创建粒子系统
	_create_particles()

	# 创建图标
	_create_icon()

	# 创建标签
	_create_labels()

	# 开始动画
	_is_animating = true
	_timer = 0.0


func _process(delta: float) -> void:
	if not _is_animating:
		return

	_timer += delta

	# 更新动画
	_update_animation()

	# 检查是否结束
	if _timer >= _duration:
		queue_free()


## 设置收获数据
func setup(harvest_data: Dictionary) -> void:
	_harvest_data = harvest_data

	var quality: int = harvest_data.get("quality", CropData.Quality.NORMAL)
	var quantity: int = harvest_data.get("quantity", 1)
	var crop_id: String = harvest_data.get("crop_id", "")

	# 更新标签
	if _quality_label and quality != CropData.Quality.NORMAL:
		_quality_label.text = QUALITY_NAMES.get(quality, "")
		_quality_label.modulate = QUALITY_COLORS.get(quality, Color.WHITE)

	if _quantity_label:
		_quantity_label.text = "x" + str(quantity)

	# 设置图标颜色
	if _icon_sprite:
		_icon_sprite.modulate = QUALITY_COLORS.get(quality, Color.WHITE)


## 创建粒子系统
func _create_particles() -> void:
	for i in range(_particle_count):
		var particle: Sprite2D = Sprite2D.new()

		# 创建一个小方块作为粒子
		var texture := _create_particle_texture()
		particle.texture = texture
		particle.scale = Vector2(0.15, 0.15)

		# 随机颜色
		var quality: int = _harvest_data.get("quality", CropData.Quality.NORMAL)
		var base_color: Color = QUALITY_COLORS.get(quality, Color.WHITE)
		particle.modulate = base_color

		add_child(particle)

		# 启动粒子动画
		_animate_particle(particle, i)


## 创建粒子纹理
func _create_particle_texture() -> ImageTexture:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture


## 粒子动画
func _animate_particle(particle: Sprite2D, index: int) -> void:
	var angle: float = (float(index) / float(_particle_count)) * TAU
	var distance: float = 30.0 + randf() * 20.0

	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2(cos(angle), sin(angle)) * distance

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(particle, "position", end_pos, 0.6).from(start_pos).set_ease(Tween.EASE_OUT)
	tween.tween_property(particle, "modulate:a", 0.0, 0.6).from(1.0).set_delay(0.3)
	tween.tween_property(particle, "scale", Vector2.ZERO, 0.6).from(Vector2(0.15, 0.15)).set_delay(0.3)


## 创建图标
func _create_icon() -> void:
	_icon_sprite = Sprite2D.new()

	# 创建一个简单的圆形作为收获图标
	var texture: ImageTexture = _create_circle_texture(16, Color.YELLOW)
	_icon_sprite.texture = texture
	_icon_sprite.position = Vector2(0, -20)

	add_child(_icon_sprite)

	# 弹跳动画
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(_icon_sprite, "position:y", -40.0, 0.5).from(-20.0)


## 创建圆形纹理
func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var image: Image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# 绘制填充圆形
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist: float = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


## 创建标签
func _create_labels() -> void:
	# 数量标签
	_quantity_label = Label.new()
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity_label.position = Vector2(-20, -60)
	_quantity_label.add_theme_font_size_override("font_size", 16)
	_quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quantity_label.add_theme_constant_override("outline_size", 2)

	add_child(_quantity_label)

	# 品质标签
	_quality_label = Label.new()
	_quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quality_label.position = Vector2(-20, -80)
	_quality_label.add_theme_font_size_override("font_size", 12)
	_quality_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quality_label.add_theme_constant_override("outline_size", 2)

	add_child(_quality_label)

	# 淡出动画
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_quantity_label, "modulate:a", 0.0, 0.5).from(1.0).set_delay(0.5)
	tween.tween_property(_quality_label, "modulate:a", 0.0, 0.5).from(1.0).set_delay(0.5)


## 更新动画
func _update_animation() -> void:
	# 整体向上移动
	position.y -= 10.0 * get_process_delta_time()

	# 图标浮动效果
	if _icon_sprite:
		_icon_sprite.position.y = -40.0 + sin(_timer * 5.0) * 3.0