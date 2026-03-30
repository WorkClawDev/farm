extends Control
class_name HotkeyBar

## HotkeyBar - 快捷栏UI
## 显示背包前9格物品，支持快捷键选择

# 常量
const SLOT_SIZE := 48
const SLOT_PADDING := 4
const HOTBAR_SIZE := 9

# 节点
var hbox: HBoxContainer
var _slots: Array[Control] = []

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_all_slots()

func _setup_ui() -> void:
	# 定位到底部中央
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -((SLOT_SIZE + SLOT_PADDING) * HOTBAR_SIZE) / 2
	offset_right = ((SLOT_SIZE + SLOT_PADDING) * HOTBAR_SIZE) / 2
	offset_top = -SLOT_SIZE - 20
	offset_bottom = -20

	# 背景面板
	var panel := Panel.new()
	panel.name = "Background"
	panel.anchor_right = 1.0
	panel.bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# 水平容器
	hbox = HBoxContainer.new()
	hbox.name = "SlotsHBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", SLOT_PADDING)
	hbox.offset_top = 4
	hbox.offset_bottom = SLOT_SIZE + 4
	hbox.offset_left = 4
	hbox.offset_right = -4
	add_child(hbox)

	# 创建格子
	for i in HOTBAR_SIZE:
		var slot := _create_slot(i)
		_slots.append(slot)
		hbox.add_child(slot)

func _create_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# 选中边框
	var border := ColorRect.new()
	border.name = "SelectionBorder"
	border.color = Color(1, 1, 0, 0.8)  # 黄色边框
	border.visible = index == 0
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.offset_left = -2
	border.offset_top = -2
	border.offset_right = 2
	border.offset_bottom = 2
	slot.add_child(border)

	# 物品图标
	var item_icon := TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.modulate = Color(1, 1, 1, 0)  # 隐藏默认
	item_icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	item_icon.offset_left = 4
	item_icon.offset_top = 4
	item_icon.offset_right = -4
	item_icon.offset_bottom = -4
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(item_icon)

	# 颜色备用层（当没有图标时显示）
	var color_fallback := ColorRect.new()
	color_fallback.name = "ColorFallback"
	color_fallback.color = Color(0.3, 0.3, 0.3, 0.5)
	color_fallback.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	color_fallback.offset_left = 4
	color_fallback.offset_top = 4
	color_fallback.offset_right = -4
	color_fallback.offset_bottom = -4
	color_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(color_fallback)

	# 数量标签
	var quantity_label := Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.offset_left = 4
	quantity_label.offset_top = SLOT_SIZE - 18
	quantity_label.offset_right = -2
	quantity_label.offset_bottom = SLOT_SIZE - 2
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 12)
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quantity_label.add_theme_constant_override("outline_size", 2)
	quantity_label.visible = false
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(quantity_label)

	# 快捷键提示
	var key_label := Label.new()
	key_label.name = "KeyLabel"
	key_label.text = str(index + 1)
	key_label.offset_left = 2
	key_label.offset_top = 2
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key_label)

	# 存储索引
	slot.set_meta("slot_index", index)

	# 鼠标点击选择
	slot.gui_input.connect(_on_slot_gui_input.bind(index))

	return slot

func _connect_signals() -> void:
	if Inventory:
		Inventory.slot_changed.connect(_update_slot)
		Inventory.inventory_changed.connect(_update_all_slots)

func _update_all_slots() -> void:
	for i in HOTBAR_SIZE:
		_update_slot(i)

func _update_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return

	var slot: Control = _slots[index]
	var item_icon: TextureRect = slot.get_node("ItemIcon")
	var color_fallback: ColorRect = slot.get_node("ColorFallback")
	var quantity_label: Label = slot.get_node("QuantityLabel")
	var border: ColorRect = slot.get_node("SelectionBorder")

	# 更新选中状态
	border.visible = index == Inventory.get_selected_hotbar_index()

	# 获取背包数据
	var slot_data := Inventory.get_slot(index)
	if slot_data == null or slot_data.is_empty():
		item_icon.modulate = Color(1, 1, 1, 0)
		color_fallback.color = Color(0.3, 0.3, 0.3, 0.5)
		quantity_label.visible = false
		return

	# 加载物品图标
	var icon_texture := _load_item_icon(slot_data.item_id)
	if icon_texture:
		item_icon.texture = icon_texture
		item_icon.modulate = Color(1, 1, 1, 1)
		color_fallback.color = Color(1, 1, 1, 0)  # 隐藏备用
	else:
		# 没有图标则用颜色
		item_icon.modulate = Color(1, 1, 1, 0)
		color_fallback.color = _get_item_type_color(slot_data.item_id)

	quantity_label.text = str(slot_data.quantity)
	quantity_label.visible = slot_data.quantity > 1

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

func _select_slot(index: int) -> void:
	Inventory.set_selected_hotbar_index(index)
	_update_all_slots()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 数字键 1-9 选择快捷栏
		for i in HOTBAR_SIZE:
			if event.keycode == KEY_1 + i:
				_select_slot(i)
				get_viewport().set_input_as_handled()
				break

		# 滚轮切换
		if event.keycode == KEY_TAB:
			var current := Inventory.get_selected_hotbar_index()
			var next := (current + 1) % HOTBAR_SIZE
			_select_slot(next)
			get_viewport().set_input_as_handled()

func get_selected_item_id() -> String:
	return Inventory.get_selected_item_id()