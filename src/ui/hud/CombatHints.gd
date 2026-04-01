extends Control
class_name CombatHints

## CombatHints - 战斗提示显示
## 显示战斗相关的提示信息，如按键提示、敌人信息等

# 配置
@export var button_hints_enabled: bool = true
@export var show_enemy_info: bool = true
@export var hint_display_time: float = 3.0
@export var fade_duration: float = 0.5

# 节点引用
@onready var hint_container: VBoxContainer = $VBoxContainer
@onready var button_hint: HBoxContainer = $VBoxContainer/ButtonHint
@onready var enemy_info: Panel = $VBoxContainer/EnemyInfo
@onready var enemy_name_label: Label = $VBoxContainer/EnemyInfo/VBoxContainer/EnemyName
@onready var enemy_health_bar: ProgressBar = $VBoxContainer/EnemyInfo/VBoxContainer/EnemyHealthBar

# 当前显示的敌人
var current_enemy: Enemy = null
var hint_queue: Array[String] = []
var is_showing_hint: bool = false

func _ready() -> void:
	_connect_signals()
	_setup_ui()
	hide()  # 默认隐藏

func _connect_signals() -> void:
	get_node("/root/EventBus").combat.combat_started.connect(_on_combat_started)
	get_node("/root/EventBus").combat.combat_ended.connect(_on_combat_ended)
	get_node("/root/EventBus").combat.enemy_damaged.connect(_on_enemy_damaged)
	get_node("/root/EventBus").combat.enemy_died.connect(_on_enemy_died)

func _setup_ui() -> void:
	if enemy_info:
		enemy_info.visible = false

	if button_hint:
		button_hint.visible = false

## 显示提示
func show_hint(message: String, duration: float = -1.0) -> void:
	if duration < 0:
		duration = hint_display_time

	hint_queue.append(message)

	if not is_showing_hint:
		_process_hint_queue()

func _process_hint_queue() -> void:
	if hint_queue.is_empty():
		is_showing_hint = false
		return

	is_showing_hint = true
	var message = hint_queue.pop_front()
	_display_hint(message)

	await get_tree().create_timer(hint_display_time).timeout
	_hide_current_hint()

	await get_tree().create_timer(fade_duration).timeout
	_process_hint_queue()

func _display_hint(message: String) -> void:
	visible = true

	# 创建提示标签
	var hint_label = Label.new()
	hint_label.text = message
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.modulate.a = 0.0

	if hint_container:
		hint_container.add_child(hint_label)

		# 淡入动画
		var tween = create_tween()
		tween.tween_property(hint_label, "modulate:a", 1.0, fade_duration)

func _hide_current_hint() -> void:
	if hint_container and hint_container.get_child_count() > 0:
		var last_hint = hint_container.get_child(hint_container.get_child_count() - 1)
		if last_hint:
			var tween = create_tween()
			tween.tween_property(last_hint, "modulate:a", 0.0, fade_duration)
			tween.tween_callback(last_hint.queue_free)

## 显示按钮提示
func show_button_hints(hints: Dictionary) -> void:
	if not button_hints_enabled or not button_hint:
		return

	button_hint.visible = true

	# 清除旧的提示
	for child in button_hint.get_children():
		child.queue_free()

	# 添加新提示
	for action in hints:
		var key_label = Label.new()
		key_label.text = "[%s]" % action
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color.YELLOW)

		var desc_label = Label.new()
		desc_label.text = hints[action]
		desc_label.add_theme_font_size_override("font_size", 12)

		button_hint.add_child(key_label)
		button_hint.add_child(desc_label)

## 隐藏按钮提示
func hide_button_hints() -> void:
	if button_hint:
		button_hint.visible = false

## 显示敌人信息
func show_enemy_info(enemy: Enemy) -> void:
	if not show_enemy_info or not enemy_info:
		return

	current_enemy = enemy
	enemy_info.visible = true

	_update_enemy_display()

func _update_enemy_display() -> void:
	if current_enemy == null or not is_instance_valid(current_enemy):
		hide_enemy_info()
		return

	if enemy_name_label:
		enemy_name_label.text = current_enemy.enemy_name

	if enemy_health_bar:
		enemy_health_bar.max_value = current_enemy.max_health
		enemy_health_bar.value = current_enemy.current_health

## 隐藏敌人信息
func hide_enemy_info() -> void:
	if enemy_info:
		enemy_info.visible = false
	current_enemy = null

## 战斗开始回调
func _on_combat_started() -> void:
	show()
	show_button_hints({
		"J/Z": tr("Attack"),
		"K/X": tr("Dodge"),
		"Space": tr("Interact")
	})

## 战斗结束回调
func _on_combat_ended() -> void:
	hide_button_hints()
	hide_enemy_info()

	# 延迟隐藏
	await get_tree().create_timer(2.0).timeout
	hide()

## 敌人受伤回调
func _on_enemy_damaged(enemy: Node, _damage: int) -> void:
	if enemy is Enemy and enemy == current_enemy:
		_update_enemy_display()

## 敌人死亡回调
func _on_enemy_died(enemy: Node, _loot: Dictionary) -> void:
	if enemy is Enemy and enemy == current_enemy:
		hide_enemy_info()
		show_hint(tr("Enemy defeated!"))
