extends Control
class_name ShippingBinUI

signal shipping_closed

var _inventory_list: VBoxContainer
var _bin_list: VBoxContainer
var _summary_label: Label
var _capacity_label: Label
var _refresh_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	theme = UIStyles.active_theme()
	_build_ui()
	Inventory.inventory_changed.connect(_queue_refresh)
	ShippingSystem.bin_contents_changed.connect(_on_bin_contents_changed)
	_refresh()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 44)
	safe.add_theme_constant_override("margin_top", 34)
	safe.add_theme_constant_override("margin_right", 44)
	safe.add_theme_constant_override("margin_bottom", 34)
	add_child(safe)

	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1080, 620))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	outer.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(UIFactory.title(_text("ui.shipping.title", "农场出货箱")))
	title_box.add_child(UIFactory.subtitle(_text(
		"ui.shipping.subtitle",
		"放入的物品会在次日清晨结算；睡觉前可以随时取回。"
	)))
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.tooltip_text = _text("ui.common.close", "关闭")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	outer.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	outer.add_child(columns)

	var inventory_panel := UIFactory.paper_panel()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(inventory_panel)
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation", UIStyles.SPACE_SM)
	inventory_panel.add_child(inventory_box)
	inventory_box.add_child(UIFactory.title(_text("ui.shipping.inventory", "背包中的可售物品")))
	var inventory_hint := UIFactory.subtitle(_text(
		"ui.shipping.inventory_hint",
		"任务物品和无售价物品不会显示。"
	))
	inventory_box.add_child(inventory_hint)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_box.add_child(inventory_scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 8)
	inventory_scroll.add_child(_inventory_list)

	var bin_panel := UIFactory.paper_panel()
	bin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(bin_panel)
	var bin_box := VBoxContainer.new()
	bin_box.add_theme_constant_override("separation", UIStyles.SPACE_SM)
	bin_panel.add_child(bin_box)
	var bin_header := HBoxContainer.new()
	bin_header.add_theme_constant_override("separation", UIStyles.SPACE_SM)
	bin_box.add_child(bin_header)
	var bin_title := UIFactory.title(_text("ui.shipping.contents", "今晚的出货"))
	bin_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bin_header.add_child(bin_title)
	_capacity_label = UIFactory.subtitle("")
	_capacity_label.custom_minimum_size = Vector2(108, 0)
	_capacity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_capacity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bin_header.add_child(_capacity_label)
	var bin_scroll := ScrollContainer.new()
	bin_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bin_box.add_child(bin_scroll)
	_bin_list = VBoxContainer.new()
	_bin_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bin_list.add_theme_constant_override("separation", 8)
	bin_scroll.add_child(_bin_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	outer.add_child(footer)
	_summary_label = UIFactory.title("")
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.add_theme_font_size_override("font_size", 24)
	footer.add_child(_summary_label)
	var done_button := UIFactory.button(
		_text("ui.shipping.done", "完成"),
		&"PrimaryButton",
		Vector2(180, 50)
	)
	done_button.pressed.connect(close)
	footer.add_child(done_button)


func close() -> void:
	shipping_closed.emit()


func _refresh() -> void:
	if _inventory_list == null or _bin_list == null:
		return
	_refresh_pending = false
	UIFactory.clear_children(_inventory_list)
	UIFactory.clear_children(_bin_list)
	_build_inventory_rows()
	_build_bin_rows()
	var value_info: Dictionary = ShippingSystem.calculate_total_value()
	_summary_label.text = _text("ui.shipping.summary", "预计收入 {money} 金 · 共 {count} 件") \
		.replace("{money}", str(int(value_info.get("total_value", 0)))) \
		.replace("{count}", str(int(value_info.get("total_items", 0))))
	_capacity_label.text = _text("ui.shipping.capacity", "{used}/{max} 格") \
		.replace("{used}", str(ShippingSystem.get_slot_count())) \
		.replace("{max}", str(ShippingSystem.MAX_BIN_SLOTS))
	await get_tree().process_frame
	if is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		UIFactory.focus_first(self)


func _build_inventory_rows() -> void:
	var sellable_ids: Array[String] = []
	for item_id in Inventory.get_all_item_ids():
		var item = ItemDatabase.get_item(item_id)
		if item != null and int(item.sell_price) > 0:
			sellable_ids.append(item_id)
	sellable_ids.sort_custom(func(a: String, b: String) -> bool:
		return str(ItemDatabase.get_item(a).name) < str(ItemDatabase.get_item(b).name)
	)
	if sellable_ids.is_empty():
		_inventory_list.add_child(_empty_state(
			_text("ui.shipping.no_sellable", "背包里暂时没有可以出货的物品。")
		))
		return
	for item_id in sellable_ids:
		var item = ItemDatabase.get_item(item_id)
		var count := Inventory.get_item_count(item_id)
		var row := _item_row(item_id, str(item.name), count, int(item.sell_price))
		var one := UIFactory.button("+1", &"", Vector2(62, 42))
		one.tooltip_text = _text("ui.shipping.deposit_one", "放入 1 个")
		one.disabled = not ShippingSystem.can_accept(item_id, 1, 0)
		one.pressed.connect(_deposit.bind(item_id, 1))
		row.add_child(one)
		var five := UIFactory.button("+5", &"", Vector2(62, 42))
		five.tooltip_text = _text("ui.shipping.deposit_five", "放入最多 5 个")
		five.disabled = not ShippingSystem.can_accept(item_id, mini(5, count), 0)
		five.pressed.connect(_deposit.bind(item_id, mini(5, count)))
		row.add_child(five)
		var all_button := UIFactory.button(
			_text("ui.shipping.all", "全部"),
			&"",
			Vector2(76, 42)
		)
		all_button.disabled = not ShippingSystem.can_accept(item_id, count, 0)
		all_button.pressed.connect(_deposit.bind(item_id, count))
		row.add_child(all_button)
		_inventory_list.add_child(row)


func _build_bin_rows() -> void:
	var contents := ShippingSystem.get_bin_contents()
	if contents.is_empty():
		_bin_list.add_child(_empty_state(
			_text("ui.shipping.empty", "出货箱还是空的。把今天的收获放进来吧。")
		))
		return
	for slot in contents:
		var item_id := str(slot.get("item_id", ""))
		var quantity := int(slot.get("quantity", 0))
		var quality := int(slot.get("quality", 0))
		var item = ItemDatabase.get_item(item_id)
		if item == null:
			continue
		var unit_price := int(float(item.sell_price) * (1.0 + quality * 0.25))
		var row := _item_row(item_id, str(item.name), quantity, unit_price)
		var one := UIFactory.button(
			_text("ui.shipping.take_one", "取回 1"),
			&"",
			Vector2(88, 42)
		)
		one.pressed.connect(_withdraw.bind(item_id, 1, quality))
		row.add_child(one)
		var all_button := UIFactory.button(
			_text("ui.shipping.take_all", "全部取回"),
			&"",
			Vector2(104, 42)
		)
		all_button.pressed.connect(_withdraw.bind(item_id, quantity, quality))
		row.add_child(all_button)
		_bin_list.add_child(row)


func _item_row(item_id: String, item_name: String, quantity: int, unit_price: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 60
	row.add_theme_constant_override("separation", UIStyles.SPACE_SM)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.texture = ItemDatabase.load_icon_texture(item_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var name_label := Label.new()
	name_label.text = "%s  ×%d" % [item_name, quantity]
	name_label.add_theme_font_size_override("font_size", 18)
	labels.add_child(name_label)
	labels.add_child(UIFactory.subtitle(
		_text("ui.shipping.unit_price", "单价 {price} 金").replace("{price}", str(unit_price))
	))
	return row


func _empty_state(message: String) -> Control:
	var panel := UIFactory.hud_panel()
	panel.custom_minimum_size.y = 84
	var label := UIFactory.subtitle(message, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _deposit(item_id: String, quantity: int) -> void:
	var available := Inventory.get_item_count(item_id)
	var actual := mini(quantity, available)
	if actual <= 0:
		return
	if not ShippingSystem.deposit_from_inventory(item_id, actual, 0):
		UIManager.show_toast("ui.shipping.full", {}, "warning")
		return
	var unit_price := 0
	var item = ItemDatabase.get_item(item_id)
	if item != null:
		unit_price = int(item.sell_price)
	# Quality 0 on this path. Same unit price the bin row shows.
	var payout := unit_price * actual
	UIManager.show_toast("已出货 ×%d（预计 +%d 金）" % [actual, payout], {}, "success")


func _withdraw(item_id: String, quantity: int, quality: int) -> void:
	if not ShippingSystem.withdraw_to_inventory(item_id, quantity, quality):
		UIManager.show_toast("ui.toast.inventory_full", {}, "warning")


func _queue_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_refresh")


func _on_bin_contents_changed(_items: Array[Dictionary]) -> void:
	_queue_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _text(key: String, fallback: String) -> String:
	return UIStyles.tr_key(key, fallback)
