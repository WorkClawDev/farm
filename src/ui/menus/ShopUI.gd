extends Control
class_name ShopUI

const SHOP_SYSTEM_SCRIPT := preload("res://src/core/economy/ShopSystem.gd")

signal shop_closed

enum UIMode {
	BUY,
	SELL,
}

var current_mode := UIMode.BUY
var selected_item_id := ""
var selected_quantity := 1
var shop_system: Node
var item_list: ItemList

var _shop_name: Label
var _balance: Label
var _buy_tab: Button
var _sell_tab: Button
var _items: VBoxContainer
var _item_icon: TextureRect
var _item_name: Label
var _item_description: Label
var _item_meta: Label
var _quantity: SpinBox
var _total: Label
var _confirm: Button
var _status: Label
var _close_button: Button
var _list_scroll: ScrollContainer
var _item_buttons: Array[Button] = []
var _keyboard_target: Control = null
var _is_closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	add_to_group("themed_ui_root")
	theme = UIStyles.active_theme()
	_build_ui()
	item_list = ItemList.new()
	item_list.name = "CompatibilityItemList"
	item_list.visible = false
	add_child(item_list)

	shop_system = SHOP_SYSTEM_SCRIPT.new()
	shop_system.name = "ShopSystem"
	add_child(shop_system)
	_connect_shop_signals()
	if MoneySystem:
		MoneySystem.money_changed.connect(_on_money_changed)
	hide()


func configure(context: Dictionary) -> void:
	open(str(context.get("shop_id", "general_store")))


func open(shop_id: String) -> void:
	_is_closing = false
	selected_item_id = ""
	selected_quantity = 1
	show()
	_update_balance()
	if not shop_system.open_shop(shop_id):
		_shop_name.text = "暂未营业"
		var shop_data = shop_system.get_shop(shop_id)
		if shop_data:
			_status.text = "%s的营业时间是 %d:00–%d:00，现在还没开门。" % [shop_data.shop_name, shop_data.opening_hour, shop_data.closing_hour]
		else:
			_status.text = "商店现在没有营业，请在营业时间再来。"
		_status.modulate = UIStyles.COLOR_DANGER
		_clear_selection()
		await get_tree().process_frame
		UIFactory.focus_first(self)


func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	if shop_system and shop_system.get_current_shop() != null:
		shop_system.close_shop()
	hide()
	shop_closed.emit()


func set_mode(mode: UIMode) -> void:
	current_mode = mode
	_buy_tab.button_pressed = current_mode == UIMode.BUY
	_sell_tab.button_pressed = current_mode == UIMode.SELL
	_confirm.text = "购买" if current_mode == UIMode.BUY else "出售"
	selected_item_id = ""
	selected_quantity = 1
	_quantity.value = 1
	_refresh_items()
	_clear_selection()


func get_visible_item_count() -> int:
	return item_list.item_count if item_list else 0


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 42)
	safe.add_theme_constant_override("margin_top", 34)
	safe.add_theme_constant_override("margin_right", 42)
	safe.add_theme_constant_override("margin_bottom", 34)
	add_child(safe)

	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1120, 650))
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	outer.add_child(header)
	_shop_name = UIFactory.title("商店")
	_shop_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_shop_name)
	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 20)
	header.add_child(_balance)
	_close_button = UIFactory.button("×", &"", Vector2(48, 44))
	_close_button.name = "ShopClose"
	_close_button.tooltip_text = "关闭"
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	_buy_tab = UIFactory.button("购买", &"TabButton", Vector2(140, 44))
	_buy_tab.name = "ShopBuyTab"
	_buy_tab.toggle_mode = true
	_buy_tab.pressed.connect(set_mode.bind(UIMode.BUY))
	tabs.add_child(_buy_tab)
	_sell_tab = UIFactory.button("出售", &"TabButton", Vector2(140, 44))
	_sell_tab.name = "ShopSellTab"
	_sell_tab.toggle_mode = true
	_sell_tab.pressed.connect(set_mode.bind(UIMode.SELL))
	tabs.add_child(_sell_tab)
	var tab_hint := UIFactory.subtitle("购买商店商品，或出售背包中的普通物品")
	tab_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(tab_hint)
	outer.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	outer.add_child(body)

	var list_panel := UIFactory.paper_panel(Vector2(390, 0))
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ShopItemScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	list_panel.add_child(scroll)
	_list_scroll = scroll
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override("separation", 8)
	scroll.add_child(_items)

	var details := UIFactory.paper_panel()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 12)
	details.add_child(detail_content)
	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(144, 144)
	_item_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_content.add_child(_item_icon)
	_item_name = UIFactory.title("选择商品", HORIZONTAL_ALIGNMENT_CENTER)
	detail_content.add_child(_item_name)
	_item_description = Label.new()
	_item_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_content.add_child(_item_description)
	_item_meta = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	_item_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_content.add_child(_item_meta)

	var checkout := UIFactory.paper_panel(Vector2(260, 0))
	body.add_child(checkout)
	var checkout_content := VBoxContainer.new()
	checkout_content.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	checkout.add_child(checkout_content)
	checkout_content.add_child(UIFactory.title("结算", HORIZONTAL_ALIGNMENT_CENTER))
	var quantity_label := Label.new()
	quantity_label.text = "数量"
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkout_content.add_child(quantity_label)
	_quantity = SpinBox.new()
	_quantity.name = "ShopQuantity"
	_quantity.min_value = 1
	_quantity.max_value = 99
	_quantity.value = 1
	_quantity.custom_minimum_size = Vector2(0, 48)
	_quantity.value_changed.connect(_on_quantity_changed)
	checkout_content.add_child(_quantity)
	_total = UIFactory.title("总计 0 金", HORIZONTAL_ALIGNMENT_CENTER)
	_total.add_theme_font_size_override("font_size", 24)
	checkout_content.add_child(_total)
	_confirm = UIFactory.button("购买", &"PrimaryButton", Vector2(0, 52))
	_confirm.name = "ShopConfirm"
	_confirm.disabled = true
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.pressed.connect(_on_confirm_pressed)
	checkout_content.add_child(_confirm)
	_status = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_content.add_child(_status)

	var footer := UIFactory.subtitle("方向键选商品  ·  右键到数量  ·  Tab 到购买  ·  Enter 确认  ·  Esc 关闭")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(footer)


func _connect_shop_signals() -> void:
	shop_system.shop_opened.connect(_on_shop_opened)
	shop_system.shop_closed.connect(_on_system_shop_closed)
	shop_system.item_purchased.connect(_on_item_purchased)
	shop_system.item_sold.connect(_on_item_sold)
	shop_system.purchase_failed.connect(_on_purchase_failed)
	shop_system.sale_failed.connect(_on_sale_failed)


func _on_shop_opened(shop_id: String) -> void:
	var shop: Variant = shop_system.get_shop(shop_id)
	if shop == null:
		return
	_shop_name.text = str(shop.shop_name)
	_status.text = ""
	_status.modulate = Color.WHITE
	set_mode(UIMode.BUY)
	_update_balance()
	show()
	await get_tree().process_frame
	UIFactory.focus_first(self)


func _refresh_items() -> void:
	for child in _items.get_children():
		child.queue_free()
	_item_buttons.clear()
	item_list.clear()
	var entries: Array[Dictionary] = []
	if current_mode == UIMode.BUY:
		var shop: Variant = shop_system.get_current_shop()
		if shop != null:
			for shop_item in shop.items:
				var listed_id := str(shop_item.get("item_id", ""))
				if not shop_system.is_buyable_this_season(listed_id):
					continue
				entries.append({
					"item_id": listed_id,
					"quantity": -1,
				})
	else:
		var shown := {}
		for slot_index in Inventory.MAX_SLOTS:
			var slot: Variant = Inventory.get_slot(slot_index)
			if slot == null or slot.is_empty() or shown.has(slot.item_id):
				continue
			var item_data: Variant = ItemDatabase.get_item(slot.item_id)
			if not _is_sellable(item_data):
				continue
			shown[slot.item_id] = true
			entries.append({
				"item_id": str(slot.item_id),
				"quantity": Inventory.get_item_count(slot.item_id),
			})

	if entries.is_empty():
		var empty := UIFactory.subtitle(
			"当前没有可购买的商品" if current_mode == UIMode.BUY else "背包中没有可出售的普通物品",
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty.custom_minimum_size.y = 90
		_items.add_child(empty)
		_wire_shop_focus()
		return

	for entry in entries:
		var item_id := str(entry.item_id)
		var item_data: Variant = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue
		item_list.add_item(str(item_data.name))
		var price: int = (
			shop_system.calculate_buy_price(item_id, 1)
			if current_mode == UIMode.BUY
			else shop_system.calculate_sell_price(item_id, 1)
		)
		var stock_text := ""
		if current_mode == UIMode.BUY:
			var shop: Variant = shop_system.get_current_shop()
			var stock: int = shop_system.get_item_stock(str(shop.shop_id), item_id)
			stock_text = "无限库存" if stock < 0 else "库存 %d" % stock
		else:
			stock_text = "持有 %d" % int(entry.quantity)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(0, 70)
		var button := Button.new()
		button.name = "ShopItem_%s" % item_id
		button.set_meta("shop_item_id", item_id)
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = str(item_data.description)
		button.pressed.connect(_select_item.bind(item_id))
		button.focus_entered.connect(_reveal_item.bind(button))
		holder.add_child(button)
		_item_buttons.append(button)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -12
		row.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = ItemDatabase.load_icon_texture(item_id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_l := Label.new()
		name_l.text = str(item_data.name)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var meta_l := Label.new()
		meta_l.text = "%d 金  ·  %s" % [price, stock_text]
		meta_l.theme_type_variation = &"SubtitleLabel"
		meta_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(name_l)
		texts.add_child(meta_l)
		row.add_child(texts)
		holder.add_child(row)
		_items.add_child(holder)
	_wire_shop_focus()


func _select_item(item_id: String) -> void:
	selected_item_id = item_id
	selected_quantity = 1
	_quantity.value = 1
	_status.text = ""
	_status.modulate = Color.WHITE
	_update_item_details()


func _update_item_details() -> void:
	var item_data: Variant = ItemDatabase.get_item(selected_item_id)
	if item_data == null:
		_clear_selection()
		return
	_item_icon.texture = ItemDatabase.load_icon_texture(selected_item_id)
	_item_name.text = str(item_data.name)
	_item_description.text = str(item_data.description)
	var unit_price: int = (
		shop_system.calculate_buy_price(selected_item_id, 1)
		if current_mode == UIMode.BUY
		else shop_system.calculate_sell_price(selected_item_id, 1)
	)
	if current_mode == UIMode.BUY:
		var shop: Variant = shop_system.get_current_shop()
		var stock: int = shop_system.get_item_stock(str(shop.shop_id), selected_item_id)
		var owned := Inventory.get_item_count(selected_item_id)
		_item_meta.text = "单价 %d 金  ·  %s  ·  已持有 %d" % [
			unit_price,
			"无限库存" if stock < 0 else "库存 %d" % stock,
			owned,
		]
		_quantity.max_value = 99 if stock < 0 else maxi(1, mini(99, stock))
	else:
		var owned := Inventory.get_item_count(selected_item_id)
		_item_meta.text = "出售单价 %d 金  ·  持有 %d" % [unit_price, owned]
		_quantity.max_value = maxi(1, owned)
	_update_checkout()


func _update_checkout() -> void:
	if selected_item_id.is_empty():
		_clear_selection()
		return
	selected_quantity = int(_quantity.value)
	var total: int = (
		shop_system.calculate_buy_price(selected_item_id, selected_quantity)
		if current_mode == UIMode.BUY
		else shop_system.calculate_sell_price(selected_item_id, selected_quantity)
	)
	_total.text = "总计 %d 金" % total
	_set_confirm_disabled(false)
	if current_mode == UIMode.BUY:
		var balance := MoneySystem.get_money() if MoneySystem else 0
		_total.text += "\n购买后 %d 金" % maxi(0, balance - total)
		if balance < total:
			_set_checkout_error("金币不足")
		elif not Inventory.can_add_item(selected_item_id, selected_quantity):
			_set_checkout_error("背包空间不足")
	else:
		var item_data: Variant = ItemDatabase.get_item(selected_item_id)
		if not _is_sellable(item_data):
			_set_checkout_error("该物品不可出售")
		elif Inventory.get_item_count(selected_item_id) < selected_quantity:
			_set_checkout_error("持有数量不足")


func _clear_selection() -> void:
	selected_item_id = ""
	_item_icon.texture = null
	_item_name.text = "选择商品" if current_mode == UIMode.BUY else "选择要出售的物品"
	_item_description.text = ""
	_item_meta.text = ""
	_total.text = "总计 0 金"
	_set_confirm_disabled(true)


func _set_confirm_disabled(disabled: bool) -> void:
	if _confirm == null:
		return
	_confirm.disabled = disabled
	# UIThemeBridge sets FOCUS_NONE while 购买 is disabled at open, and does not
	# restore it when the button is enabled again. Keyboard Tab would stop here.
	_confirm.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL


func _set_checkout_error(message: String) -> void:
	_set_confirm_disabled(true)
	_status.text = message
	_status.modulate = UIStyles.COLOR_DANGER


func _is_sellable(item_data: Variant) -> bool:
	return (
		item_data != null
		and int(item_data.type) != ItemDatabase.ItemType.QUEST
		and int(item_data.type) != ItemDatabase.ItemType.TOOL
		and int(item_data.sell_price) > 0
	)


func _on_confirm_pressed() -> void:
	if selected_item_id.is_empty() or _confirm.disabled:
		return
	var success: bool = (
		shop_system.buy_item(selected_item_id, selected_quantity)
		if current_mode == UIMode.BUY
		else shop_system.sell_item(selected_item_id, selected_quantity)
	)
	if success:
		_refresh_items()
		_update_balance()
		_quantity.value = 1
		if ItemDatabase.has_item(selected_item_id):
			_update_item_details()


func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_status.text = ""
	_status.modulate = Color.WHITE
	_update_checkout()


func _update_balance() -> void:
	if _balance:
		_balance.text = "余额 %d 金  " % (MoneySystem.get_money() if MoneySystem else 0)


func show_message(message: String, is_error: bool = false) -> void:
	_status.text = message
	_status.modulate = UIStyles.COLOR_DANGER if is_error else UIStyles.COLOR_GREEN


func _on_item_purchased(item_id: String, quantity: int, total_price: int) -> void:
	var item_data: Variant = ItemDatabase.get_item(item_id)
	show_message("购买成功：%s ×%d（%d 金）" % [
		str(item_data.name) if item_data else item_id,
		quantity,
		total_price,
	])


func _on_item_sold(item_id: String, quantity: int, total_price: int) -> void:
	var item_data: Variant = ItemDatabase.get_item(item_id)
	show_message("出售成功：%s ×%d（%d 金）" % [
		str(item_data.name) if item_data else item_id,
		quantity,
		total_price,
	])


func _on_purchase_failed(reason: String) -> void:
	show_message({
		"out_of_stock": "库存不足",
		"not_enough_money": "金币不足",
		"inventory_full": "背包空间不足",
		"item_not_available": "该商品当前不可购买",
		"wrong_season": "这种种子不是当季的",
	}.get(reason, "购买失败：" + reason), true)


func _on_sale_failed(reason: String) -> void:
	show_message({
		"not_enough_items": "持有数量不足",
		"not_sellable": "任务物品、工具和关键物品不可出售",
	}.get(reason, "出售失败：" + reason), true)


func _on_system_shop_closed() -> void:
	hide()


func _on_money_changed(_amount: int, _delta: int) -> void:
	_update_balance()
	if not selected_item_id.is_empty():
		_update_checkout()


func _on_close_button_pressed() -> void:
	close()


## The inner line edit swallows Tab, so keyboard focus stays on the SpinBox.
func _lock_quantity_text_focus() -> void:
	if _quantity == null:
		return
	_quantity.focus_mode = Control.FOCUS_ALL
	var edit := _quantity.get_line_edit()
	if edit != null:
		edit.focus_mode = Control.FOCUS_NONE


func _quantity_edit() -> Control:
	if _quantity == null:
		return null
	var edit := _quantity.get_line_edit()
	return edit if edit != null else _quantity


func _is_item_button(node: Node) -> bool:
	return node is Button and _item_buttons.has(node as Button)


func _is_quantity_focus(node: Node) -> bool:
	if node == null or _quantity == null:
		return false
	return node == _quantity or _quantity.is_ancestor_of(node)


## Item rows, quantity, the buy/sell button, close, then the tabs.
## Tab follows this loop. Arrows on a row stay in the list; Right leaves it.
func _wire_shop_focus() -> void:
	var chain: Array[Control] = []
	for button in _item_buttons:
		chain.append(button)
	_lock_quantity_text_focus()
	if _quantity != null:
		chain.append(_quantity)
	if _confirm != null:
		chain.append(_confirm)
	if _close_button != null:
		chain.append(_close_button)
	if _buy_tab != null:
		chain.append(_buy_tab)
	if _sell_tab != null:
		chain.append(_sell_tab)
	if chain.is_empty():
		return
	for i in chain.size():
		var node := chain[i]
		var nxt := chain[(i + 1) % chain.size()]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		node.focus_next = node.get_path_to(nxt)
		node.focus_previous = node.get_path_to(prev)
	for i in _item_buttons.size():
		var button := _item_buttons[i]
		var above: Control = _item_buttons[i - 1] if i > 0 else button
		var below: Control = _item_buttons[i + 1] if i + 1 < _item_buttons.size() else button
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_neighbor_left = button.get_path_to(button)
		if _quantity != null:
			button.focus_neighbor_right = button.get_path_to(_quantity)
	if _close_button != null and not _item_buttons.is_empty():
		_close_button.focus_neighbor_bottom = _close_button.get_path_to(_item_buttons[0])


func _reveal_item(button: Button) -> void:
	if _list_scroll == null or button == null or not is_instance_valid(button):
		return
	var row := button.get_parent() as Control
	_list_scroll.ensure_control_visible(row if row != null else button)


func _move_item_focus(delta: int) -> void:
	if _item_buttons.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := _item_buttons.find(current as Button)
	if index < 0:
		index = 0 if delta > 0 else _item_buttons.size() - 1
	else:
		index = clampi(index + delta, 0, _item_buttons.size() - 1)
	var button := _item_buttons[index]
	if button != current:
		button.grab_focus()
	_reveal_item(button)


func _process(_delta: float) -> void:
	if _keyboard_target == null or not is_instance_valid(_keyboard_target):
		_keyboard_target = null
		return
	var target := _keyboard_target
	_keyboard_target = null
	if target.is_visible_in_tree() and not (target is BaseButton and (target as BaseButton).disabled):
		target.grab_focus()


func _queue_focus(target: Control) -> void:
	_keyboard_target = target
	if target == null or not is_instance_valid(target):
		return
	if target is BaseButton and (target as BaseButton).disabled:
		return
	if target.focus_mode == Control.FOCUS_NONE:
		target.focus_mode = Control.FOCUS_ALL
	target.grab_focus()


func _selected_item_button() -> Button:
	for button in _item_buttons:
		if str(button.get_meta("shop_item_id", "")) == selected_item_id:
			return button
	return _item_buttons[0] if not _item_buttons.is_empty() else null


func _focus_quantity() -> void:
	_lock_quantity_text_focus()
	if _quantity != null:
		_quantity.grab_focus()


func _focus_confirm() -> void:
	if _confirm != null and not _confirm.disabled and _confirm.is_visible_in_tree():
		_confirm.grab_focus()
	else:
		_focus_close()


func _focus_close() -> void:
	if _close_button != null:
		_close_button.grab_focus()


func _focus_selected_item() -> void:
	for button in _item_buttons:
		if str(button.get_meta("shop_item_id", "")) == selected_item_id:
			button.grab_focus()
			_reveal_item(button)
			return
	if not _item_buttons.is_empty():
		_item_buttons[0].grab_focus()
		_reveal_item(_item_buttons[0])


func _nudge_quantity(delta: int) -> void:
	if _quantity == null:
		return
	_quantity.value = clampi(int(_quantity.value) + delta, int(_quantity.min_value), int(_quantity.max_value))


## SpinBox eats Up/Down, and its line edit eats Left/Right, so those keys never
## reached 购买. Handle the shop path before the focused control sees the event.
func _input(event: InputEvent) -> void:
	if not visible or _is_closing or event is InputEventJoypadMotion:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		return
	if _is_item_button(focus):
		if event.is_action_pressed("ui_down", true):
			_move_item_focus(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_up", true):
			_move_item_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_focus_quantity()
			get_viewport().set_input_as_handled()
		return
	if _is_quantity_focus(focus):
		# Leave the field before Up/Down. The line edit keeps Tab for itself,
		# and giving it the key puts focus straight back on the text.
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			_queue_focus(_confirm if _confirm != null and not _confirm.disabled else _close_button)
		elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			_queue_focus(_selected_item_button())
		elif event.is_action_pressed("ui_up", true):
			_nudge_quantity(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down", true):
			_nudge_quantity(-1)
			get_viewport().set_input_as_handled()
		return
	if focus == _confirm:
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_focus_close()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_focus_quantity()
			get_viewport().set_input_as_handled()
		return
	if focus == _close_button:
		if event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_left"):
			_focus_confirm()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
