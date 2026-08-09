extends Control
class_name GiftUI

## GiftUI - 送礼界面
## 显示物品选择列表，让玩家选择礼物送给NPC

signal gift_selected(item_id: String)
signal gift_cancelled

# 常量
const SLOT_SIZE := 48
const SLOT_PADDING := 4
const COLS := 6

# 当前NPC
var _current_npc_id: String = ""
var _current_npc_name: String = ""

# 节点引用
var _background: ColorRect
var _main_panel: Panel
var _title_label: Label
var _npc_name_label: Label
var _grid_container: GridContainer
var _close_button: Button
var _info_label: Label

# 物品格子
var _slots: Array[Control] = []
var _selected_slot_index: int = -1

# 状态
var _is_open: bool = false

func _ready() -> void:
	_setup_ui()
	visible = false

func _setup_ui() -> void:
	# 背景遮罩
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0, 0, 0, 0.6)
	_background.anchor_right = 1.0
	_background.anchor_bottom = 1.0
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	# 主面板
	_main_panel = Panel.new()
	_main_panel.name = "MainPanel"
	_main_panel.anchor_left = 0.5
	_main_panel.anchor_right = 0.5
	_main_panel.anchor_top = 0.5
	_main_panel.anchor_bottom = 0.5
	_main_panel.offset_left = -220
	_main_panel.offset_right = 220
	_main_panel.offset_top = -280
	_main_panel.offset_bottom = 280
	add_child(_main_panel)

	# 主容器
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_child(vbox)

	# 顶部栏
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	# 标题
	_title_label = Label.new()
	_title_label.text = "选择礼物"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	# 关闭按钮
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	# NPC名称
	_npc_name_label = Label.new()
	_npc_name_label.text = "送给: ???"
	_npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_name_label.add_theme_font_size_override("font_size", 18)
	_npc_name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(_npc_name_label)

	# 分隔
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer1)

	# 物品面板
	var slot_panel := PanelContainer.new()
	slot_panel.name = "SlotPanel"
	vbox.add_child(slot_panel)

	# 格子网格
	_grid_container = GridContainer.new()
	_grid_container.name = "SlotGrid"
	_grid_container.columns = COLS
	_grid_container.add_theme_constant_override("h_separation", SLOT_PADDING)
	_grid_container.add_theme_constant_override("v_separation", SLOT_PADDING)
	slot_panel.add_child(_grid_container)

	# 创建物品格子
	_create_slots()

	# 分隔
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer2)

	# 信息标签
	_info_label = Label.new()
	_info_label.text = "选择一个物品作为礼物"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_info_label.custom_minimum_size = Vector2(0, 60)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_info_label)

	# 操作提示
	var hint_label := Label.new()
	hint_label.text = "点击物品赠送 | ESC 取消"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint_label)

func _create_slots() -> void:
	# 只创建可赠送物品的格子
	for i in Inventory.MAX_SLOTS:
		var slot := _create_slot(i)
		_slots.append(slot)
		_grid_container.add_child(slot)

func _create_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# 添加物品图标容器
	var item_icon := TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.modulate = Color(1, 1, 1, 0)
	item_icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	item_icon.anchor_left = 0.5
	item_icon.anchor_top = 0.5
	item_icon.offset_left = -(SLOT_SIZE - 8) / 2
	item_icon.offset_top = -(SLOT_SIZE - 8) / 2
	item_icon.offset_right = (SLOT_SIZE - 8) / 2
	item_icon.offset_bottom = (SLOT_SIZE - 8) / 2
	slot.add_child(item_icon)

	# 颜色备用层
	var color_fallback := ColorRect.new()
	color_fallback.name = "ColorFallback"
	color_fallback.color = Color(0.3, 0.3, 0.3)
	color_fallback.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	color_fallback.anchor_left = 0.5
	color_fallback.anchor_top = 0.5
	color_fallback.offset_left = -(SLOT_SIZE - 8) / 2
	color_fallback.offset_top = -(SLOT_SIZE - 8) / 2
	color_fallback.offset_right = (SLOT_SIZE - 8) / 2
	color_fallback.offset_bottom = (SLOT_SIZE - 8) / 2
	slot.add_child(color_fallback)

	# 数量标签
	var quantity_label := Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.anchor_right = 1.0
	quantity_label.anchor_bottom = 1.0
	quantity_label.offset_top = SLOT_SIZE - 18
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 12)
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quantity_label.add_theme_constant_override("outline_size", 2)
	quantity_label.visible = false
	slot.add_child(quantity_label)

	# 偏好标签（显示NPC对该物品的态度）
	var preference_label := Label.new()
	preference_label.name = "PreferenceLabel"
	preference_label.anchor_left = 0.0
	preference_label.anchor_top = 0.0
	preference_label.offset_top = 2
	preference_label.offset_left = 2
	preference_label.add_theme_font_size_override("font_size", 10)
	preference_label.add_theme_color_override("font_color", Color.WHITE)
	preference_label.add_theme_color_override("font_outline_color", Color.BLACK)
	preference_label.add_theme_constant_override("outline_size", 1)
	preference_label.visible = false
	slot.add_child(preference_label)

	# 选中高亮
	var selection := ColorRect.new()
	selection.name = "SelectionHighlight"
	selection.color = Color(1, 1, 0, 0.4)
	selection.visible = false
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(selection)

	# 存储索引
	slot.set_meta("slot_index", index)

	# 连接信号
	slot.gui_input.connect(_on_slot_gui_input.bind(index))
	slot.mouse_entered.connect(_on_slot_mouse_entered.bind(index))
	slot.mouse_exited.connect(_on_slot_mouse_exited.bind(index))

	return slot

func _update_slots() -> void:
	for i in _slots.size():
		_update_slot(i)

func _update_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return

	var slot: Control = _slots[index]
	var item_icon: TextureRect = slot.get_node("ItemIcon")
	var color_fallback: ColorRect = slot.get_node("ColorFallback")
	var quantity_label: Label = slot.get_node("QuantityLabel")
	var preference_label: Label = slot.get_node("PreferenceLabel")
	var highlight: ColorRect = slot.get_node("SelectionHighlight")

	var slot_data := Inventory.get_slot(index)
	if slot_data == null or slot_data.is_empty():
		item_icon.modulate = Color(1, 1, 1, 0)
		color_fallback.color = Color(0.2, 0.2, 0.2)
		quantity_label.visible = false
		preference_label.visible = false
		slot.set_meta("item_id", "")
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# 设置物品数据
	slot.set_meta("item_id", slot_data.item_id)
	quantity_label.text = str(slot_data.quantity)
	quantity_label.visible = slot_data.quantity > 1
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	# 加载物品图标
	var icon_texture := _load_item_icon(slot_data.item_id)
	if icon_texture:
		item_icon.texture = icon_texture
		item_icon.modulate = Color(1, 1, 1, 1)
		color_fallback.color = Color(1, 1, 1, 0)
	else:
		item_icon.modulate = Color(1, 1, 1, 0)
		color_fallback.color = _get_item_type_color(slot_data.item_id)

	# 显示NPC偏好（如果已知）
	if GiftSystem and _current_npc_id != "":
		var preference := GiftSystem.get_preference_preview(_current_npc_id, slot_data.item_id)
		if preference != "一般":
			preference_label.text = preference
			preference_label.visible = true

			# 设置偏好颜色
			match preference:
				"最爱": preference_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
				"喜欢": preference_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
				"不喜欢": preference_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
				"讨厌": preference_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			preference_label.visible = false

	# 更新选中状态
	highlight.visible = (index == _selected_slot_index)

func _get_item_type_color(item_id: String) -> Color:
	if Inventory:
		var db := Inventory.get_item_database()
		if db:
			var item := db.get_item(item_id)
			if item:
				match item.type:
					ItemDatabase.ItemType.SEED: return Color(0.6, 0.4, 0.2)
					ItemDatabase.ItemType.CROP: return Color(0.4, 0.8, 0.3)
					ItemDatabase.ItemType.TOOL: return Color(0.5, 0.5, 0.6)
					ItemDatabase.ItemType.FOOD: return Color(0.9, 0.6, 0.3)
					ItemDatabase.ItemType.RESOURCE: return Color(0.6, 0.5, 0.4)
					ItemDatabase.ItemType.FISH: return Color(0.3, 0.6, 0.9)
					ItemDatabase.ItemType.DECORATION: return Color(0.9, 0.5, 0.8)
					ItemDatabase.ItemType.QUEST: return Color(1.0, 0.8, 0.2)
	return Color(0.5, 0.5, 0.5)

func _load_item_icon(item_id: String) -> Texture2D:
	var db := Inventory.get_item_database() if Inventory else null
	if db:
		return db.load_icon_texture(item_id)
	return null

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_select_slot(index)

func _on_slot_mouse_entered(index: int) -> void:
	var slot_data := Inventory.get_slot(index)
	if slot_data and not slot_data.is_empty():
		var item_name := Inventory.get_item_name(slot_data.item_id)
		var item_desc := Inventory.get_item_description(slot_data.item_id)

		var info_text := "%s\n%s" % [item_name, item_desc]

		# 显示偏好预览
		if GiftSystem and _current_npc_id != "":
			var preference := GiftSystem.get_preference_preview(_current_npc_id, slot_data.item_id)
			info_text += "\n偏好: %s" % preference

		_info_label.text = info_text

func _on_slot_mouse_exited(_index: int) -> void:
	_info_label.text = "选择一个物品作为礼物"

func _select_slot(index: int) -> void:
	var slot_data := Inventory.get_slot(index)
	if slot_data == null or slot_data.is_empty():
		return

	var item_id: String = slot_data.item_id

	# 检查是否可以赠送
	if GiftSystem:
		var check := GiftSystem.can_give_gift(_current_npc_id, item_id)
		if not check.can_give:
			_info_label.text = check.reason
			return

	# 高亮选中格子
	_selected_slot_index = index
	_update_slot_highlights()

	# 确认赠送
	_confirm_gift(item_id)

func _update_slot_highlights() -> void:
	for i in _slots.size():
		var slot: Control = _slots[i]
		var highlight: ColorRect = slot.get_node("SelectionHighlight")
		highlight.visible = (i == _selected_slot_index)

func _confirm_gift(item_id: String) -> void:
	# 获取物品名称
	var item_name := Inventory.get_item_name(item_id)

	# 简单确认 - 直接赠送
	_do_give_gift(item_id)

func _do_give_gift(item_id: String) -> void:
	if not GiftSystem or not Inventory:
		return

	# 从背包移除物品
	if not Inventory.remove_item(item_id, 1):
		_info_label.text = "无法移除物品"
		return

	# 执行送礼
	var result := GiftSystem.give_gift(_current_npc_id, item_id)

	if result.success:
		# 播放动画效果
		_play_gift_animation(result.reaction)

		# 显示反应对话
		_show_reaction_dialogue(result.dialogue, result.reaction)

		# 发射信号
		gift_selected.emit(item_id)
	else:
		_info_label.text = "送礼失败"

	# 关闭界面
	await get_tree().create_timer(0.5).timeout
	close()

func _play_gift_animation(reaction: int) -> void:
	# 创建动画节点
	var anim_node := Control.new()
	anim_node.name = "GiftAnimation"
	anim_node.anchor_left = 0.5
	anim_node.anchor_top = 0.5
	anim_node.offset_left = -100
	anim_node.offset_right = 100
	anim_node.offset_top = -50
	anim_node.offset_bottom = 50
	anim_node.z_index = 100
	add_child(anim_node)

	# 反应文字
	var reaction_label := Label.new()
	reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reaction_label.add_theme_font_size_override("font_size", 36)
	reaction_label.add_theme_color_override("font_color", Color.WHITE)
	reaction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	reaction_label.add_theme_constant_override("outline_size", 3)

	# 设置反应文字和颜色
	match reaction:
		GiftSystem.ReactionType.LOVE:
			reaction_label.text = "最爱!!"
			reaction_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		GiftSystem.ReactionType.LIKE:
			reaction_label.text = "喜欢!"
			reaction_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		GiftSystem.ReactionType.NEUTRAL:
			reaction_label.text = "一般"
			reaction_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		GiftSystem.ReactionType.DISLIKE:
			reaction_label.text = "不喜欢..."
			reaction_label.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
		GiftSystem.ReactionType.HATE:
			reaction_label.text = "讨厌!"
			reaction_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

	anim_node.add_child(reaction_label)

	# 动画效果
	var tween := create_tween()
	tween.tween_property(anim_node, "modulate:a", 1.0, 0.1).from(0.0)
	tween.tween_property(anim_node, "scale", Vector2(1.2, 1.2), 0.3).from(Vector2(0.5, 0.5))
	tween.parallel().tween_property(anim_node, "position:y", -20, 0.3)
	tween.tween_interval(0.5)
	tween.tween_property(anim_node, "modulate:a", 0.0, 0.3)
	tween.tween_callback(anim_node.queue_free)

func _show_reaction_dialogue(dialogue: String, _reaction: int) -> void:
	# 更新信息标签显示反应
	_info_label.text = dialogue
	_info_label.add_theme_font_size_override("font_size", 16)

func _on_close_pressed() -> void:
	close()
	gift_cancelled.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if _is_open:
				close()
				gift_cancelled.emit()
				get_viewport().set_input_as_handled()

## 打开送礼界面
func open_for_npc(npc_id: String, npc_name: String) -> void:
	_current_npc_id = npc_id
	_current_npc_name = npc_name
	_npc_name_label.text = "送给: %s" % npc_name
	_selected_slot_index = -1
	_info_label.text = "选择一个物品作为礼物"
	_info_label.add_theme_font_size_override("font_size", 14)

	visible = true
	_is_open = true
	_update_slots()

	if EventBus:
		get_node("/root/EventBus").ui.ui_opened.emit("gift")

## 关闭送礼界面
func close() -> void:
	visible = false
	_is_open = false
	_current_npc_id = ""
	_current_npc_name = ""

	if EventBus:
		get_node("/root/EventBus").ui.ui_closed.emit("gift")

## 检查是否打开
func is_open() -> bool:
	return _is_open
