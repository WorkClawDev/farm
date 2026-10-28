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
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/Header/TitleLabel
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
var animation_player: AnimationPlayer = null
@onready var upgrade_particles: GPUParticles2D = $UpgradeParticles

# 状态
var selected_tool_type: int = -1
var tool_upgrade_system: Node = null
var _tool_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

		var library := AnimationLibrary.new()
		library.add_animation("upgrade_success", animation)
		anim_player.add_animation_library("", library)

func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		return
	if event.is_action_pressed("ui_accept"):
		_activate_focused_button()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_next"):
		_move_chain(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_focus_prev"):
		_move_chain(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down", true):
		_move_vertical(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up", true):
		_move_vertical(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_focus_action_button()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_focus_selected_tool()
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
	bind_player_inventory()
	_refresh_tools_list()
	_clear_selection()
	show()

	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")

	# 暂停游戏
	if GameManager:
		GameManager.pause_game()
	_focus_first_tool()
	# UIThemeBridge restyles next frame and clears focus_mode on a disabled upgrade button.
	call_deferred("_wire_tool_focus")
	call_deferred("_focus_first_tool")

## 关闭界面
func close() -> void:
	hide()

	if GameManager:
		GameManager.resume_game()

	ui_closed.emit()

## 刷新工具列表
func _refresh_tools_list() -> void:
	_tool_buttons.clear()
	# 清空列表。先移出树，避免排队释放的旧按钮还留在焦点链上。
	var old_children := tools_list.get_children()
	for child in old_children:
		tools_list.remove_child(child)
		child.queue_free()

	if tool_upgrade_system == null:
		_wire_tool_focus()
		return

	for tool_type in TOOL_UPGRADE_SCRIPT.ToolType.values():
		_create_tool_button(tool_type)
	_wire_tool_focus()

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

	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.set_meta("tool_type", tool_type)
	button.tooltip_text = "点击查看详情"
	button.pressed.connect(_on_tool_button_pressed.bind(tool_type))

	tools_list.add_child(button)
	_tool_buttons.append(button)

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
		upgrade_effects_label.text = tool_upgrade_system.get_upgrade_effect_description(tool.current_tier, next_tier, selected_tool_type)
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
		name_label.text = _material_display_name(req.material_id)
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

## 材料显示名：物品表里的非空名称，否则回退 id
func _material_display_name(material_id: String) -> String:
	var display_name := material_id
	var item = ItemDatabase.get_item(material_id)
	if item != null and not str(item.name).is_empty():
		display_name = str(item.name)
	return display_name

## 获取材料数量
func _get_material_count(material_id: String) -> int:
	# 通过库存系统获取材料数量
	if tool_upgrade_system and tool_upgrade_system.has_method("get_material_count"):
		return int(tool_upgrade_system.get_material_count(material_id))
	return 0

## 更新升级按钮
func _update_upgrade_button() -> void:
	if selected_tool_type == -1 or tool_upgrade_system == null:
		upgrade_button.disabled = true
		upgrade_button.text = "选择工具"
		_wire_tool_focus()
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
	_wire_tool_focus()

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
	_wire_tool_focus()

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
		_focus_tool_type(selected_tool_type)
	else:
		show_message("升级失败!", true)

func _on_close_pressed() -> void:
	close()

func _on_tool_upgraded(tool_type: int, new_tier: int) -> void:
	print("[ToolUpgradeUI] Tool %d upgraded to tier %d" % [tool_type, new_tier])

func _on_upgrade_failed(tool_type: int, reason: String) -> void:
	show_message("升级失败: %s" % reason, true)


func _focus_owner() -> Control:
	if not is_inside_tree():
		return null
	return get_viewport().gui_get_focus_owner()


func _is_tool_button(node: Node) -> bool:
	return node is Button and _tool_buttons.has(node as Button)


func _selected_tool_button() -> Button:
	for button in _tool_buttons:
		if is_instance_valid(button) and int(button.get_meta("tool_type", -1)) == selected_tool_type:
			return button
	for button in _tool_buttons:
		if is_instance_valid(button):
			return button
	return null


func _action_focus_target() -> Control:
	if upgrade_button and not upgrade_button.disabled:
		return upgrade_button
	if close_button:
		return close_button
	return null


func _focus_chain() -> Array[Control]:
	var chain: Array[Control] = []
	for button in _tool_buttons:
		if is_instance_valid(button):
			chain.append(button)
	if upgrade_button and not upgrade_button.disabled and upgrade_button.focus_mode != Control.FOCUS_NONE:
		chain.append(upgrade_button)
	if close_button and close_button.focus_mode != Control.FOCUS_NONE:
		chain.append(close_button)
	return chain


func _wire_tool_focus() -> void:
	if not is_inside_tree() or upgrade_button == null or close_button == null:
		return
	upgrade_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_button.focus_mode = Control.FOCUS_NONE if upgrade_button.disabled else Control.FOCUS_ALL
	close_button.focus_mode = Control.FOCUS_ALL
	var tools: Array[Button] = []
	for button in _tool_buttons:
		if not is_instance_valid(button):
			continue
		button.focus_mode = Control.FOCUS_ALL
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		tools.append(button)
	var chain := _focus_chain()
	for node in chain:
		node.focus_neighbor_left = NodePath()
		node.focus_neighbor_right = NodePath()
		node.focus_neighbor_top = NodePath()
		node.focus_neighbor_bottom = NodePath()
		node.focus_next = NodePath()
		node.focus_previous = NodePath()
	for i in chain.size():
		var node := chain[i]
		var nxt := chain[(i + 1) % chain.size()]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		node.focus_next = node.get_path_to(nxt)
		node.focus_previous = node.get_path_to(prev)
	var side := _action_focus_target()
	for i in tools.size():
		var button := tools[i]
		var above: Control = tools[i - 1] if i > 0 else button
		var below: Control = tools[i + 1] if i + 1 < tools.size() else button
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		if side != null and side != button:
			button.focus_neighbor_right = button.get_path_to(side)
	var back := _selected_tool_button()
	if upgrade_button.focus_mode != Control.FOCUS_NONE:
		if back != null:
			upgrade_button.focus_neighbor_left = upgrade_button.get_path_to(back)
			upgrade_button.focus_neighbor_top = upgrade_button.get_path_to(back)
		upgrade_button.focus_neighbor_right = upgrade_button.get_path_to(close_button)
		upgrade_button.focus_neighbor_bottom = upgrade_button.get_path_to(close_button)
		close_button.focus_neighbor_top = close_button.get_path_to(upgrade_button)
		close_button.focus_neighbor_left = close_button.get_path_to(upgrade_button)
	elif back != null:
		close_button.focus_neighbor_top = close_button.get_path_to(back)
		close_button.focus_neighbor_left = close_button.get_path_to(back)
		if not tools.is_empty():
			close_button.focus_neighbor_bottom = close_button.get_path_to(tools[0])


func _grab(target: Control) -> void:
	if target == null or not is_instance_valid(target) or not visible:
		return
	if target is BaseButton and (target as BaseButton).disabled:
		return
	if target.focus_mode == Control.FOCUS_NONE:
		target.focus_mode = Control.FOCUS_ALL
	target.grab_focus()
	if tools_list and _is_tool_button(target):
		var scroll := tools_list.get_parent() as ScrollContainer
		if scroll:
			scroll.ensure_control_visible(target)


func _focus_first_tool() -> void:
	if not is_inside_tree() or not visible:
		return
	for button in _tool_buttons:
		if is_instance_valid(button):
			_grab(button)
			return
	_grab(close_button)


func _focus_tool_type(tool_type: int) -> void:
	if not is_inside_tree() or not visible:
		return
	for button in _tool_buttons:
		if is_instance_valid(button) and int(button.get_meta("tool_type", -1)) == tool_type:
			_grab(button)
			return
	_focus_first_tool()


func _focus_selected_tool() -> void:
	if _is_tool_button(_focus_owner()):
		return
	var button := _selected_tool_button()
	if button:
		_grab(button)
	else:
		_focus_first_tool()


func _focus_action_button() -> void:
	var current := _focus_owner()
	if current == upgrade_button:
		_grab(close_button)
		return
	if current == close_button:
		return
	if not _is_tool_button(current):
		_focus_first_tool()
		return
	var target := _action_focus_target()
	if target:
		_grab(target)
	else:
		_focus_first_tool()


func _move_chain(delta: int) -> void:
	var chain := _focus_chain()
	if chain.is_empty():
		return
	var current := _focus_owner()
	var index := chain.find(current) if current != null else -1
	if index < 0:
		index = 0 if delta > 0 else chain.size() - 1
	else:
		index = posmod(index + delta, chain.size())
	_grab(chain[index])


func _move_vertical(delta: int) -> void:
	var tools: Array[Control] = []
	for button in _tool_buttons:
		if is_instance_valid(button):
			tools.append(button)
	var current := _focus_owner()
	var index := -1
	if current != null:
		index = tools.find(current)
	if index >= 0:
		var nxt := index + delta
		if nxt >= 0 and nxt < tools.size():
			_grab(tools[nxt])
			return
		if delta > 0:
			_focus_action_button()
		return
	if current == upgrade_button:
		if delta < 0 and not tools.is_empty():
			_grab(tools[tools.size() - 1])
		elif delta > 0:
			_grab(close_button)
		return
	if current == close_button:
		if delta < 0:
			if upgrade_button and not upgrade_button.disabled:
				_grab(upgrade_button)
			elif not tools.is_empty():
				_grab(tools[tools.size() - 1])
		elif not tools.is_empty():
			_grab(tools[0])
		return
	if not tools.is_empty():
		_grab(tools[0] if delta > 0 else tools[tools.size() - 1])


func _activate_focused_button() -> void:
	var current := _focus_owner()
	if not (_is_tool_button(current) or current == upgrade_button or current == close_button):
		_focus_first_tool()
		return
	var button := current as BaseButton
	if button == null or button.disabled:
		return
	button.pressed.emit()


func bind_player_inventory() -> void:
	if tool_upgrade_system and tool_upgrade_system.has_method("set_inventory"):
		tool_upgrade_system.set_inventory(Inventory)
	if tool_upgrade_system and tool_upgrade_system.has_method("sync_watering_can_from_farm"):
		tool_upgrade_system.sync_watering_can_from_farm()


static func present() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var existing := tree.root.find_child("ToolUpgradeUI", true, false)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		if existing.has_method("open"):
			existing.open()
		return existing
	var packed := load("res://src/ui/menus/ToolUpgradeUI.tscn") as PackedScene
	if packed == null:
		return null
	var ui := packed.instantiate()
	# Root rejects add_child while it is still entering the test scene.
	# After boot, root is ready and the panel stays above map changes.
	var host: Node = tree.root
	if not tree.root.is_node_ready() and tree.current_scene != null:
		host = tree.current_scene
	host.add_child(ui)
	if ui.is_inside_tree() and ui.has_method("open"):
		ui.open()
	return ui
