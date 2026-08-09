extends Control
class_name HealthBar

## HealthBar - 玩家血条显示
## 显示玩家当前生命值，带有动画效果

# 配置
@export var show_value_label: bool = true
@export var animate_changes: bool = true
@export var animation_duration: float = 0.3
@export var low_health_threshold: float = 0.25
@export var critical_health_threshold: float = 0.1

# 颜色配置
@export var normal_color: Color = Color.GREEN
@export var low_health_color: Color = Color.YELLOW
@export var critical_color: Color = Color.RED

# 节点引用
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var health_label: Label = $HealthLabel
@onready var background: NinePatchRect = $Background

# 状态
var current_health: int = 100
var max_health: int = 100
var displayed_health: float = 100.0

# 动画
var health_tween: Tween

func _ready() -> void:
	_setup_nodes()
	_connect_signals()
	_update_display()

func _setup_nodes() -> void:
	if progress_bar == null:
		progress_bar = $ProgressBar
	if health_label == null:
		health_label = $HealthLabel

	# 设置进度条
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = max_health
		progress_bar.value = current_health
		progress_bar.show_percentage = false

func _connect_signals() -> void:
	get_node("/root/EventBus").player.health_changed.connect(_on_health_changed)

## 更新显示
func _update_display() -> void:
	if progress_bar:
		if animate_changes:
			_animate_health_change()
		else:
			progress_bar.value = current_health
			displayed_health = current_health

	if health_label and show_value_label:
		health_label.text = "%d / %d" % [current_health, max_health]

	_update_color()

## 动画化血量变化
func _animate_health_change() -> void:
	if health_tween and health_tween.is_valid():
		health_tween.kill()

	health_tween = create_tween()
	health_tween.tween_property(self, "displayed_health", float(current_health), animation_duration)
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.set_trans(Tween.TRANS_QUAD)

	# 更新进度条
	health_tween.step_finished.connect(_on_tween_step)

func _on_tween_step(_step: int) -> void:
	if progress_bar:
		progress_bar.value = displayed_health

## 更新颜色
func _update_color() -> void:
	var health_percent = float(current_health) / float(max_health)

	if progress_bar is ProgressBar:
		var style_box = progress_bar.get("theme_override_styles/fill")
		if style_box is StyleBoxFlat:
			if health_percent <= critical_health_threshold:
				style_box.bg_color = critical_color
			elif health_percent <= low_health_threshold:
				style_box.bg_color = low_health_color
			else:
				style_box.bg_color = normal_color

## 设置血量
func set_health(current: int, maximum: int) -> void:
	var old_health = current_health
	current_health = clamp(current, 0, maximum)
	max_health = maximum

	_update_display()

	# 低血量警告
	if current_health <= max_health * critical_health_threshold:
		_show_critical_warning()
	elif current_health <= max_health * low_health_threshold:
		_show_low_health_warning()

## 显示低血量警告
func _show_low_health_warning() -> void:
	if progress_bar:
		var flash_tween = create_tween()
		flash_tween.set_loops(2)
		flash_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.1)
		flash_tween.tween_property(progress_bar, "modulate", low_health_color, 0.1)

## 显示危急血量警告
func _show_critical_warning() -> void:
	if progress_bar:
		var flash_tween = create_tween()
		flash_tween.set_loops(3)
		flash_tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.08)
		flash_tween.tween_property(progress_bar, "modulate", critical_color, 0.08)

## 血量变化回调
func _on_health_changed(current: int, maximum: int) -> void:
	set_health(current, maximum)

## 显示受伤效果
func show_damage_effect(damage: int) -> void:
	# 创建伤害数字
	var damage_label = Label.new()
	damage_label.text = "-%d" % damage
	damage_label.add_theme_font_size_override("font_size", 16)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.position = Vector2(randi_range(-20, 20), -20)

	add_child(damage_label)

	# 动画
	var tween = create_tween()
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 0.5)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(damage_label.queue_free)

## 显示治疗效果
func show_heal_effect(amount: int) -> void:
	# 创建治疗数字
	var heal_label = Label.new()
	heal_label.text = "+%d" % amount
	heal_label.add_theme_font_size_override("font_size", 16)
	heal_label.add_theme_color_override("font_color", Color.GREEN)
	heal_label.position = Vector2(randi_range(-20, 20), -20)

	add_child(heal_label)

	# 动画
	var tween = create_tween()
	tween.tween_property(heal_label, "position:y", heal_label.position.y - 30, 0.5)
	tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(heal_label.queue_free)

## 获取血量百分比
func get_health_percent() -> float:
	return float(current_health) / float(max_health) * 100.0

## 设置显示模式
func set_compact_mode(compact: bool) -> void:
	if health_label:
		health_label.visible = not compact
