extends Control
class_name HotkeyBar

const HOTBAR_SIZE := 9

var _slots: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _key_labels: Array[Label] = []
var _quantity_labels: Array[Label] = []
var _selection_frames: Array[Panel] = []


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -310
	offset_top = -92
	offset_right = 310
	offset_bottom = -20
	UIStyles.follow_theme(self)
	_build_ui()
	if Inventory:
		Inventory.slot_changed.connect(_update_slot)
		Inventory.inventory_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var panel := UIFactory.hud_panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 6)
	panel.add_child(slots)
	for index in range(HOTBAR_SIZE):
		var slot := UIFactory.button("", &"SlotButton", Vector2(60, 58))
		slot.name = "Slot_%d" % index
		slot.clip_contents = false
		slot.tooltip_text = UIFactory.slot_tooltip("", 0)
		slot.pressed.connect(_select.bind(index))
		slots.add_child(slot)
		_slots.append(slot)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Bottom strip stays free for "×15" (it used to sit on the icon).
		icon.offset_left = 10
		icon.offset_top = 5
		icon.offset_right = -10
		icon.offset_bottom = -18
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Stage D pixel icons
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_slot_icons.append(icon)

		var key_label := _slot_label(&"SlotKeyLabel")
		key_label.name = "Key"
		# 1–6 是工具直选，格子上不再画数字，避免当成物品快捷键。
		key_label.text = ""
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_child(key_label)
		_key_labels.append(key_label)

		var quantity_label := _slot_label(&"SlotQuantityLabel")
		quantity_label.name = "Quantity"
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot.add_child(quantity_label)
		_quantity_labels.append(quantity_label)

		var selection := Panel.new()
		selection.name = "Selection"
		selection.theme_type_variation = &"SlotSelectFrame"
		selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(selection)
		_selection_frames.append(selection)

	var hint := Label.new()
	hint.name = "SelectHint"
	hint.theme_type_variation = &"HUDSmall"
	hint.text = "点击或 Tab 选物品"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = -18
	hint.offset_bottom = -2
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


## Slot styles (SlotButton / SlotKeyLabel / SlotQuantityLabel / SlotSelectFrame) live in GameTheme.tres.
func _slot_label(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 5
	label.offset_top = 1
	label.offset_right = -4
	label.offset_bottom = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh() -> void:
	for index in range(HOTBAR_SIZE):
		_update_slot(index)


func _update_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var button := _slots[index]
	var data = Inventory.get_slot(index)
	var icon := _slot_icons[index]
	var key_label := _key_labels[index]
	var quantity_label := _quantity_labels[index]
	icon.texture = null
	key_label.text = ""
	key_label.modulate.a = 0.72
	quantity_label.text = ""
	button.text = ""
	button.modulate = Color.WHITE
	button.scale = Vector2.ONE
	if data and not data.is_empty():
		icon.texture = ItemDatabase.load_icon_texture(data.item_id)
		quantity_label.text = "×%d" % data.quantity if data.quantity > 1 else ""
		button.tooltip_text = _slot_select_tooltip(UIFactory.slot_tooltip(Inventory.get_item_name(data.item_id), data.quantity))
	else:
		button.tooltip_text = _slot_select_tooltip(UIFactory.slot_tooltip("", 0))
	_selection_frames[index].visible = index == Inventory.get_selected_hotbar_index()
	# 拿着工具时快捷栏选中框变淡：表示按空格用的是工具，不是这个物品。
	_selection_frames[index].modulate.a = 0.35 if _is_tool_equipped() else 1.0
	if index == Inventory.get_selected_hotbar_index():
		button.scale = Vector2(1.08, 1.08)
		button.pivot_offset = button.size * 0.5


func _select(index: int) -> void:
	Inventory.set_selected_hotbar_index(index)
	# 选快捷栏物品 = 收起工具改拿这个物品（BUG-14：锄头不会顺手把种子种下去）。
	# 鼠标点击和 Tab 走这里。数字键 1–6 留给工具直选。
	var tool_manager := _get_tool_manager()
	if tool_manager:
		tool_manager.put_away_tool()
	_refresh()


func _get_tool_manager() -> ToolManager:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player == null:
		return null
	var tool_manager = player.get("tool_manager")
	if tool_manager is ToolManager:
		if not tool_manager.tool_changed.is_connected(_on_tool_changed):
			tool_manager.tool_changed.connect(_on_tool_changed)
		return tool_manager
	return null


func _is_tool_equipped() -> bool:
	var tool_manager := _get_tool_manager()
	return tool_manager != null and not tool_manager.is_using_hotbar_item()


func _on_tool_changed(_tool_type: int, _tool_name: String) -> void:
	_refresh()


func _slot_select_tooltip(item_tip: String) -> String:
	return "%s\n点击选择 · Tab 下一格" % item_tip


func _input(event: InputEvent) -> void:
	# 数字键 1–6 由 Player 直选工具，这里不占用。7–9 也不再选物品。
	if event.is_action_pressed("hotbar_next"):
		_select((Inventory.get_selected_hotbar_index() + 1) % HOTBAR_SIZE)
		get_viewport().set_input_as_handled()


func get_selected_item_id() -> String:
	return Inventory.get_selected_item_id()
