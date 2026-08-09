extends CanvasLayer
class_name ToolUpgradeUI

const TOOL_UPGRADE_SCRIPT := preload("res://src/core/crafting/ToolUpgrade.gd")

## ToolUpgradeUI - 工具升级界面
## 显示工具升级选项、材料需求和升级效果

# 信号
signal upgrade_completed(tool_type: int, new_tier: int)
signal ui_closed

# UI节点引用
@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var tools_list: VBoxContainer = $CenterContainer/Panel/VBoxContainer/ScrollContainer/ToolsList
@onready var info_panel: Panel = $CenterContainer/Panel/VBoxContainer/HBoxContainer/InfoPanel
@onready var tool_name_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/ToolNameLabel
@onready var tool_tier_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/ToolTierLabel
@onready var tool_stats_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/ToolStatsLabel
@onready var upgrade_effects_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/InfoPanel/VBoxContainer/UpgradeEffectsLabel
@onready var materials_panel: Panel = $CenterContainer/Panel/VBoxContainer/HBoxContainer/MaterialsPanel
@onready var materials_list: VBoxContainer = $CenterContainer/Panel/VBoxContainer/HBoxContainer/MaterialsPanel/VBoxContainer/MaterialsList
@onready var upgrade_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ControlsPanel/VBoxContainer/UpgradeButton
@onready var close_button: Button = $CenterContainer/Panel/VBoxContainer/Header/CloseButton
@onready var message_label: Label = $CenterContainer/Panel/VBoxContainer/Footer/MessageLabel

# 动画节点
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var upgrade_particles: GPUParticles2D = $UpgradeParticles

# 状态
var selected_tool_type: int = -1
var tool_upgrade_system: Node = null

func _ready() -> void:
	if tool_upgrade_system == null:
		tool_upgrade_system = TOOL_UPGRADE_SCRIPT.new()
		tool_upgrade_system.name = "ToolUpgradeSystem"
		add_child(tool_upgrade_system)
	hide()
	_connect_signals()
	set_tool_upgrade_system(tool_upgrade_system)
	_create_animation_player()

func _connect_signals() -> void:
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	close_button.pressed.connect(_on_close_pressed)

func _create_animation_player() -> void:
	# 创建AnimationPlayer如果不存在
	if not has_node("AnimationPlayer"):
		var anim_player := AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		add_child(anim_player)
		animation_player = anim_player

		# 创建升级动画
		var animation := Animation.new()
		animation.length = 0.5

		# 添加缩放轨道
		var track_index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, "CenterContainer/Panel:scale")
		animation.track_insert_key(track_index, 0.0, Vector2(1.0, 1.0))
		animation.track_insert_key(track_index, 0.25, Vector2(1.1, 1.1))
		animation.track_insert_key(track_index, 0.5, Vector2(1.0, 1.0))

		anim_player.add_animation("upgrade_success", animation)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()

## 设置工具升级系统引用
func set_tool_upgrade_system(system: Node) -> void:
	if tool_upgrade_system and tool_upgrade_system != system:
		if tool_upgrade_system.tool_upgraded.is_connected(_on_tool_upgraded):
			tool_upgrade_system.tool_upgraded.disconnect(_on_tool_upgraded)
		if tool_upgrade_system.upgrade_failed.is_connected(_on_upgrade_failed):
			tool_upgrade_system.upgrade_failed.disconnect(_on_upgrade_failed)
	tool_upgrade_system = system
	if tool_upgrade_system:
		if not tool_upgrade_system.tool_upgraded.is_connected(_on_tool_upgraded):
			tool_upgrade_system.tool_upgraded.connect(_on_tool_upgraded)
		if not tool_upgrade_system.upgrade_failed.is_connected(_on_upgrade_failed):
			tool_upgrade_system.upgrade_failed.connect(_on_upgrade_failed)

## 打开界面
func open() -> void:
	_refresh_tools_list()
	_clear_selection()
	show()

	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")

	# 暂停游戏
	if GameManager:
		GameManager.pause_game()

## 关闭界面
func close() -> void:
	hide()

	if GameManager:
		GameManager.resume_game()

	ui_closed.emit()

## 刷新工具列表
func _refresh_tools_list() -> void:
	# 清空列表
	for child in tools_list.get_children():
		child.queue_free()

	if tool_upgrade_system == null:
		return

	# 创建工具按钮
	for tool_type in TOOL_UPGRADE_SCRIPT.ToolType.values():
		_create_tool_button(tool_type)

## 创建工具按钮
func _create_tool_button(tool_type: int) -> void:
	var tool: Variant = tool_upgrade_system.get_tool_data(tool_type)
	if tool == null:
		return

	var button := Button.new()
	button.text = "%s [%s]" % [tool.get_type_name(), tool.get_tier_name()]
	button.custom_minimum_size = Vector2(280, 45)

	# 检查是否可以升级
	var check: Dictionary = tool_upgrade_system.can_upgrade(tool_type)
	if check.can_upgrade:
		button.text += " ↑"
	else:
		button.modulate = Color(0.7, 0.7, 0.7)

	button.tooltip_text = "点击查看详情"
	button.pressed.connect(_on_tool_button_pressed.bind(tool_type))

	tools_list.add_child(button)

## 工具按钮点击
func _on_tool_button_pressed(tool_type: int) -> void:
	selected_tool_type = tool_type
	_update_tool_info()
	_update_materials_list()
	_update_upgrade_button()

## 更新工具信息
func _update_tool_info() -> void:
	if selected_tool_type == -1 or tool_upgrade_system == null:
		_clear_tool_info()
		return

	var tool: Variant = tool_upgrade_system.get_tool_data(selected_tool_type)
	if tool == null:
		return

	tool_name_label.text = tool.get_type_name()
	tool_tier_label.text = "当前等级: %s" % tool.get_tier_name()
	tool_stats_label.text = "效率: %.1fx | 范围: %d格 | 体力消耗: %d" % [
		tool.efficiency, tool.range, tool.energy_cost
	]

	# 显示升级效果
	var next_tier: int = tool_upgrade_system.get_next_tier(tool.current_tier)
	if next_tier != -1:
		upgrade_effects_label.text = tool_upgrade_system.get_upgrade_effect_description(tool.current_tier, next_tier)
	else:
		upgrade_effects_label.text = "已达最高等级!"

## 更新材料列表
func _update_materials_list() -> void:
	# 清空材料列表
	for child in materials_list.get_children():
		child.queue_free()

	if selected_tool_type == -1 or tool_upgrade_system == null:
		return

	var tool: Variant = tool_upgrade_system.get_tool_data(selected_tool_type)
	if tool == null:
		return

	var next_tier: int = tool_upgrade_system.get_next_tier(tool.current_tier)
	if next_tier == -1:
		var label := Label.new()
		label.text = "已达最高等级"
		materials_list.add_child(label)
		return

	var requirements: Array = tool_upgrade_system.get_upgrade_requirements(tool.current_tier)

	for req in requirements:
		var hbox := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = req.material_id
		name_label.custom_minimum_size.x = 150

		var have := _get_material_count(req.material_id)
		var count_label := Label.new()
		count_label.text = "%d / %d" % [have, req.quantity]

		# 标记材料不足
		if have < req.quantity:
			count_label.modulate = Color.RED
		else:
			count_label.modulate = Color.GREEN

		hbox.add_child(name_label)
		hbox.add_child(count_label)
		materials_list.add_child(hbox)

## 获取材料数量
func _get_material_count(material_id: String) -> int:
	# 通过库存系统获取材料数量
	if tool_upgrade_system and tool_upgrade_system._inventory:
		return tool_upgrade_system._inventory.get_item_count(material_id)
	return 0

## 更新升级按钮
func _update_upgrade_button() -> void:
	if selected_tool_type == -1 or tool_upgrade_system == null:
		upgrade_button.disabled = true
		upgrade_button.text = "选择工具"
		return

	var check: Dictionary = tool_upgrade_system.can_upgrade(selected_tool_type)

	if check.can_upgrade:
		upgrade_button.disabled = false
		var tool: Variant = tool_upgrade_system.get_tool_data(selected_tool_type)
		var next_tier_name: String = tool_upgrade_system.get_tier_name(check.next_tier)
		upgrade_button.text = "升级到 %s" % next_tier_name
	else:
		upgrade_button.disabled = true
		match check.reason:
			"max_tier_reached":
				upgrade_button.text = "已达最高等级"
			"insufficient_materials":
				upgrade_button.text = "材料不足"
			_:
				upgrade_button.text = "无法升级"

## 清除工具信息
func _clear_tool_info() -> void:
	tool_name_label.text = "选择工具"
	tool_tier_label.text = ""
	tool_stats_label.text = ""
	upgrade_effects_label.text = ""

## 清除选择
func _clear_selection() -> void:
	selected_tool_type = -1
	_clear_tool_info()
	upgrade_button.disabled = true
	upgrade_button.text = "选择工具"

## 显示消息
func show_message(message: String, is_error: bool = false) -> void:
	message_label.text = message
	if is_error:
		message_label.modulate = Color.RED
	else:
		message_label.modulate = Color.GREEN

	# 3秒后清除
	await get_tree().create_timer(3.0).timeout
	message_label.text = ""

## 播放升级成功动画
func play_upgrade_animation() -> void:
	if animation_player and animation_player.has_animation("upgrade_success"):
		animation_player.play("upgrade_success")

	# 粒子效果
	if upgrade_particles:
		upgrade_particles.emitting = true
		upgrade_particles.global_position = panel.global_position + panel.size / 2

		await get_tree().create_timer(1.0).timeout
		upgrade_particles.emitting = false

# 信号回调

func _on_upgrade_pressed() -> void:
	if selected_tool_type == -1 or tool_upgrade_system == null:
		return

	var tool: Variant = tool_upgrade_system.get_tool_data(selected_tool_type)
	if tool == null:
		return

	var old_tier: int = tool.current_tier

	if tool_upgrade_system.upgrade_tool(selected_tool_type):
		play_upgrade_animation()
		show_message("升级成功!")

		upgrade_completed.emit(selected_tool_type, tool.current_tier)

		# 刷新界面
		_refresh_tools_list()
		_update_tool_info()
		_update_materials_list()
		_update_upgrade_button()
	else:
		show_message("升级失败!", true)

func _on_close_pressed() -> void:
	close()

func _on_tool_upgraded(tool_type: int, new_tier: int) -> void:
	print("[ToolUpgradeUI] Tool %d upgraded to tier %d" % [tool_type, new_tier])

func _on_upgrade_failed(tool_type: int, reason: String) -> void:
	show_message("升级失败: %s" % reason, true)
