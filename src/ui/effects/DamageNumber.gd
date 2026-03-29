extends Node2D
class_name DamageNumber

## DamageNumber - 浮动伤害数字
## 显示伤害或治疗数值，带有动画效果

# 配置
@export var float_distance: float = 50.0
@export var float_duration: float = 0.8
@export var damage_color: Color = Color.RED
@export var heal_color: Color = Color.GREEN
@export var critical_color: Color = Color.YELLOW
@export var font_size_normal: int = 16
@export var font_size_critical: int = 24

# 场景
static var damage_number_scene: PackedScene

func _ready() -> void:
	# 创建标签
	_setup_label()

func _setup_label() -> void:
	pass

## 创建伤害数字实例
static func create(value: int, position: Vector2, is_heal: bool = false, is_critical: bool = false) -> DamageNumber:
	var instance = DamageNumber.new()
	instance.global_position = position

	# 延迟设置显示
	instance.call_deferred("_setup_display", value, is_heal, is_critical)

	return instance

func _setup_display(value: int, is_heal: bool, is_critical: bool) -> void:
	# 创建标签
	var label = Label.new()
	label.name = "ValueLabel"

	# 设置文本
	if is_heal:
		label.text = "+%d" % value
		label.add_theme_color_override("font_color", heal_color)
		label.add_theme_font_size_override("font_size", font_size_normal)
	else:
		label.text = "%d" % value
		if is_critical:
			label.add_theme_color_override("font_color", critical_color)
			label.add_theme_font_size_override("font_size", font_size_critical)
			label.text = "%d!" % value
		else:
			label.add_theme_color_override("font_color", damage_color)
			label.add_theme_font_size_override("font_size", font_size_normal)

	# 居中
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_child(label)

	# 设置初始透明度
	modulate.a = 0.0

	# 启动动画
	_play_animation(label)

## 播放动画
func _play_animation(label: Label) -> void:
	# 淡入
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.1)

	await fade_in.finished

	# 浮动动画
	var tween = create_tween()
	tween.set_parallel(true)

	# 向上浮动
	var target_y = global_position.y - float_distance
	tween.tween_property(self, "global_position:y", target_y, float_duration).set_ease(Tween.EASE_OUT)

	# 淡出
	tween.tween_property(self, "modulate:a", 0.0, float_duration).set_delay(float_duration * 0.5)

	# 缩放效果（暴击时）
	var label_node = get_node_or_null("ValueLabel")
	if label_node:
		if label_node.text.ends_with("!"):
			# 暴击放大效果
			label_node.scale = Vector2(1.5, 1.5)
			var scale_tween = create_tween()
			scale_tween.tween_property(label_node, "scale", Vector2(1.0, 1.0), 0.2)

	await tween.finished
	queue_free()

## 在指定位置显示伤害数字
static func show_damage(damage: int, position: Vector2, is_critical: bool = false) -> DamageNumber:
	return create(-damage, position, false, is_critical)

## 在指定位置显示治疗数字
static func show_heal(heal: int, position: Vector2) -> DamageNumber:
	return create(heal, position, true, false)

## 显示自定义数字（如经验值等）
static func show_value(value: int, position: Vector2, color: Color = Color.WHITE) -> DamageNumber:
	var instance = create(value, position, false, false)
	var label = instance.get_node_or_null("ValueLabel")
	if label:
		label.add_theme_color_override("font_color", color)
	return instance