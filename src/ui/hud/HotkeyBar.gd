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
	theme = UIStyles.active_theme()
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
		var slot := UIFactory.button("", &"", Vector2(60, 58))
		slot.name = "Slot_%d" % index
		slot.clip_contents = false
		slot.tooltip_text = "快捷栏 %d" % (index + 1)
		slot.pressed.connect(_select.bind(index))
		slots.add_child(slot)
		_slots.append(slot)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 7
		icon.offset_top = 6
		icon.offset_right = -7
		icon.offset_bottom = -6
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_slot_icons.append(icon)

		var key_label := _slot_label(12)
		key_label.name = "Key"
		key_label.text = str(index + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_child(key_label)
		_key_labels.append(key_label)

		var quantity_label := _slot_label(14)
		quantity_label.name = "Quantity"
		quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot.add_child(quantity_label)
		_quantity_labels.append(quantity_label)

		var selection := Panel.new()
		selection.name = "Selection"
		selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var selection_style := StyleBoxFlat.new()
		selection_style.bg_color = Color.TRANSPARENT
		selection_style.border_color = UIStyles.COLOR_GOLD
		selection_style.set_border_width_all(3)
		selection_style.set_corner_radius_all(10)
		selection.add_theme_stylebox_override("panel", selection_style)
		slot.add_child(selection)
		_selection_frames.append(selection)


func _slot_label(font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 5
	label.offset_top = 3
	label.offset_right = -5
	label.offset_bottom = -3
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UIStyles.COLOR_INK)
	label.add_theme_color_override("font_outline_color", UIStyles.COLOR_CREAM)
	label.add_theme_constant_override("outline_size", 3)
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
	key_label.text = str(index + 1)
	key_label.modulate.a = 0.72
	quantity_label.text = ""
	button.text = ""
	button.modulate = Color.WHITE
	button.scale = Vector2.ONE
	if data and not data.is_empty():
		icon.texture = ItemDatabase.load_icon_texture(data.item_id)
		quantity_label.text = "×%d" % data.quantity if data.quantity > 1 else ""
		button.tooltip_text = "[%d] %s × %d" % [index + 1, Inventory.get_item_name(data.item_id), data.quantity]
	else:
		button.tooltip_text = "快捷栏 %d · 空" % (index + 1)
	_selection_frames[index].visible = index == Inventory.get_selected_hotbar_index()
	if index == Inventory.get_selected_hotbar_index():
		button.scale = Vector2(1.08, 1.08)
		button.pivot_offset = button.size * 0.5


func _select(index: int) -> void:
	Inventory.set_selected_hotbar_index(index)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for index in range(HOTBAR_SIZE):
			if event.keycode == KEY_1 + index:
				_select(index)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("hotbar_next"):
		_select((Inventory.get_selected_hotbar_index() + 1) % HOTBAR_SIZE)
		get_viewport().set_input_as_handled()


func get_selected_item_id() -> String:
	return Inventory.get_selected_item_id()
