extends Control
class_name InventoryUI

## InventoryUI - 背包界面
## 显示背包格子，支持物品拖拽和交互

signal inventory_closed

# 常量
const SLOT_SIZE := 48
const SLOT_PADDING := 4
const COLS := 9
const ROWS := 4

# 节点引用
var grid_container: GridContainer
var slot_panel: PanelContainer
var tooltip_label: Label
var close_button: Button

# 格子场景
var slot_scene: PackedScene

# 数据
var _slots: Array[Control] = []
var _dragging_slot_index: int = -1
var _drag_preview: Control = null
var _is_open: bool = false

func _ready() -> void:
	_setup_ui()
	_connect_inventory_signals()
	_update_all_slots()

func _setup_ui() -> void:
	# 主面板
	var main_panel := Panel.new()
	main_panel.name = "MainPanel"
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -250
	main_panel.offset_right = 250
	main_panel.offset_top = -200
	main_panel.offset_bottom = 200
	add_child(main_panel)

	# 背景遮罩
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.5)
	background.anchor_right = 1.0
	background.bottom_right = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	# 主容器
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_panel.add_child(vbox)

	# 顶部栏（标题和关闭按钮）
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	# 标题
	var title := Label.new()
	title.text = "背包"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# 关闭按钮
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# 分隔
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# 格子容器背景
	slot_panel = PanelContainer.new()
	slot_panel.name = "SlotPanel"
	vbox.add_child(slot_panel)

	# 格子网格
	grid_container = GridContainer.new()
	grid_container.name = "SlotGrid"
	grid_container.columns = COLS
	grid_container.add_theme_constant_override("h_separation", SLOT_PADDING)
	grid_container.add_theme_constant_override("v_separation", SLOT_PADDING)
	slot_panel.add_child(grid_container)

	# 创建格子
	_create_slots()

	# 工具提示
	tooltip_label = Label.new()
	tooltip_label.name = "Tooltip"
	tooltip_label.visible = false
	tooltip_label.add_theme_font_size_override("font_size", 14)
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tooltip_label.add_theme_constant_override("outline_size", 2)
	add_child(tooltip_label)

	# 设置层级
	main_panel.z_index = 10

func _create_slots() -> void:
	for i in Inventory.MAX_SLOTS:
		var slot := _create_slot(i)
		_slots.append(slot)
		grid_container.add_child(slot)

func _create_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# 添加物品图标容器
	var item_icon := TextureRect.new()
	item_icon.name = "ItemIcon"
	item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	item_icon.anchor_left = 0.5
	item_icon.anchor_top = 0.5
	item_icon.offset_left = -(SLOT_SIZE - 8) / 2
	item_icon.offset_top = -(SLOT_SIZE - 8) / 2
	item_icon.offset_right = (SLOT_SIZE - 8) / 2
	item_icon.offset_bottom = (SLOT_SIZE - 8) / 2
	item_icon.modulate = Color(1, 1, 1, 0)
	slot.add_child(item_icon)

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

	# 选中高亮
	var selection := ColorRect.new()
	selection.name = "SelectionHighlight"
	selection.color = Color(1, 1, 1, 0.3)
	selection.visible = false
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(selection)

	# 存储索引
	slot.set_meta("slot_index", index)

	# 连接信号
	slot.gui_input.connect(_on_slot_gui_input.bind(index))

	return slot

func _connect_inventory_signals() -> void:
	if Inventory:
		Inventory.inventory_changed.connect(_update_all_slots)
		Inventory.slot_changed.connect(_update_slot)

func _update_all_slots() -> void:
	for i in Inventory.MAX_SLOTS:
		_update_slot(i)

func _update_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return

	var slot: Control = _slots[index]
	var item_icon: TextureRect = slot.get_node("ItemIcon")
	var quantity_label: Label = slot.get_node("QuantityLabel")

	var slot_data := Inventory.get_slot(index)
	if slot_data == null or slot_data.is_empty():
		item_icon.modulate = Color(1, 1, 1, 0)
		quantity_label.visible = false
		slot.set_meta("item_id", "")
		return

	# 设置物品数据
	slot.set_meta("item_id", slot_data.item_id)
	quantity_label.text = str(slot_data.quantity)
	quantity_label.visible = slot_data.quantity > 1

	# 加载物品图标
	var icon_texture := _load_item_icon(slot_data.item_id)
	if icon_texture:
		item_icon.texture = icon_texture
		item_icon.modulate = Color(1, 1, 1, 1)
	else:
		# 没有图标则用类型颜色作为背景
		item_icon.texture = null
		var item_type := _get_item_type_color(slot_data.item_id)
		item_icon.modulate = item_type

func _get_item_type_color(item_id: String) -> Color:
	# 根据物品类型返回不同颜色（没有图标时的备用方案）
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
	# 从 ItemDatabase 获取物品图标
	var db := Inventory.get_item_database() if Inventory else null
	if db:
		return db.load_icon_texture(item_id)
	return null

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(index, mouse_event.shift_pressed)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_handle_right_click(index)

func _handle_left_click(index: int, shift_pressed: bool) -> void:
	if _dragging_slot_index == -1:
		# 开始拖拽
		var slot_data := Inventory.get_slot(index)
		if slot_data and not slot_data.is_empty():
			_dragging_slot_index = index
			_create_drag_preview(index)
			_highlight_slot(index, true)
	else:
		# 放置物品
		if index != _dragging_slot_index:
			if shift_pressed:
				# 分割物品
				Inventory.split_slot(_dragging_slot_index, index)
			else:
				# 检查是否可以合并
				var from_slot := Inventory.get_slot(_dragging_slot_index)
				var to_slot := Inventory.get_slot(index)

				if to_slot and not to_slot.is_empty() and to_slot.item_id == from_slot.item_id:
					# 合并
					Inventory.merge_slots(_dragging_slot_index, index)
				else:
					# 交换
					Inventory.swap_slots(_dragging_slot_index, index)

		_end_drag()

func _handle_right_click(index: int) -> void:
	# 右键点击 - 使用物品或取消拖拽
	if _dragging_slot_index != -1:
		_end_drag()
	else:
		var slot_data := Inventory.get_slot(index)
		if slot_data and not slot_data.is_empty():
			_use_item(index)

func _use_item(index: int) -> void:
	var slot_data := Inventory.get_slot(index)
	if slot_data == null or slot_data.is_empty():
		return

	var item_id: String = slot_data.item_id
	var db := Inventory.get_item_database()
	var item := db.get_item(item_id) if db else null
	if item == null:
		print("[InventoryUI] Item not found: ", item_id)
		return

	match item.type:
		ItemDatabase.ItemType.FOOD:
			# 消耗食物，恢复体力
			var effect: Dictionary = item.get("use_effect", {})
			var stamina_restore: float = effect.get("stamina", 0.0)
			var health_restore: float = effect.get("health", 0.0)
			if GameManager and stamina_restore > 0:
				GameManager.current_stamina = minf(GameManager.current_stamina + stamina_restore, GameManager.max_stamina)
			if health_restore > 0:
				print("[InventoryUI] Health restore: ", health_restore)
			Inventory.remove_item(index)
			print("[InventoryUI] Consumed food: %s (+%s stamina, +%s health)" % [item_id, stamina_restore, health_restore])

		ItemDatabase.ItemType.SEED:
			print("[InventoryUI] Seed: right-click on tilled soil to plant")

		ItemDatabase.ItemType.TOOL:
			print("[InventoryUI] Tool: equip from toolbar")

		ItemDatabase.ItemType.CROP:
			print("[InventoryUI] Crop: sell at shipping bin or give as gift")

		ItemDatabase.ItemType.FISH:
			print("[InventoryUI] Fish: give as gift or sell")

		_:
			print("[InventoryUI] Item: %s (type=%s) - sell or gift" % [item_id, item.type])

func _create_drag_preview(index: int) -> void:
	if _drag_preview:
		_drag_preview.queue_free()

	_drag_preview = Control.new()
	_drag_preview.name = "DragPreview"
	_drag_preview.z_index = 100

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_drag_preview.add_child(panel)

	var slot_data := Inventory.get_slot(index)
	var icon_texture := _load_item_icon(slot_data.item_id) if slot_data else null

	if icon_texture:
		var item_icon := TextureRect.new()
		item_icon.texture = icon_texture
		item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		item_icon.anchor_left = 0.5
		item_icon.anchor_top = 0.5
		item_icon.offset_left = -(SLOT_SIZE - 8) / 2
		item_icon.offset_top = -(SLOT_SIZE - 8) / 2
		item_icon.offset_right = (SLOT_SIZE - 8) / 2
		item_icon.offset_bottom = (SLOT_SIZE - 8) / 2
		panel.add_child(item_icon)
	else:
		# 没有图标则用颜色方块
		var item_icon := ColorRect.new()
		item_icon.color = _get_item_type_color(slot_data.item_id) if slot_data else Color(0.5, 0.5, 0.5)
		item_icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		item_icon.anchor_left = 0.5
		item_icon.anchor_top = 0.5
		item_icon.offset_left = -(SLOT_SIZE - 8) / 2
		item_icon.offset_top = -(SLOT_SIZE - 8) / 2
		item_icon.offset_right = (SLOT_SIZE - 8) / 2
		item_icon.offset_bottom = (SLOT_SIZE - 8) / 2
		panel.add_child(item_icon)

	add_child(_drag_preview)

func _end_drag() -> void:
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null

	if _dragging_slot_index != -1:
		_highlight_slot(_dragging_slot_index, false)

	_dragging_slot_index = -1

func _highlight_slot(index: int, highlighted: bool) -> void:
	if index < 0 or index >= _slots.size():
		return

	var slot: Control = _slots[index]
	var highlight: ColorRect = slot.get_node_or_null("SelectionHighlight")
	if highlight:
		highlight.visible = highlighted

func _process(_delta: float) -> void:
	if _drag_preview:
		_drag_preview.position = get_global_mouse_position() - Vector2(SLOT_SIZE / 2, SLOT_SIZE / 2)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if _is_open:
				close()
				get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	close()

func open() -> void:
	visible = true
	_is_open = true
	_update_all_slots()

	if EventBus:
		get_node("/root/EventBus").ui_opened.emit("inventory")

func close() -> void:
	visible = false
	_is_open = false
	_end_drag()

	if EventBus:
		get_node("/root/EventBus").ui_closed.emit("inventory")

	inventory_closed.emit()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func is_open() -> bool:
	return _is_open