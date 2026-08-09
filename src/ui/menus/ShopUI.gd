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
var _is_closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.tooltip_text = "关闭"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	_buy_tab = UIFactory.button("购买", &"TabButton", Vector2(140, 44))
	_buy_tab.toggle_mode = true
	_buy_tab.pressed.connect(set_mode.bind(UIMode.BUY))
	tabs.add_child(_buy_tab)
	_sell_tab = UIFactory.button("出售", &"TabButton", Vector2(140, 44))
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
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
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
	_confirm.disabled = true
	_confirm.pressed.connect(_on_confirm_pressed)
	checkout_content.add_child(_confirm)
	_status = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_content.add_child(_status)

	var footer := UIFactory.subtitle("方向键 / 摇杆选择  ·  Enter / A 确认  ·  Esc / B 返回")
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
	item_list.clear()
	var entries: Array[Dictionary] = []
	if current_mode == UIMode.BUY:
		var shop: Variant = shop_system.get_current_shop()
		if shop != null:
			for shop_item in shop.items:
				entries.append({
					"item_id": str(shop_item.get("item_id", "")),
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
		var button := UIFactory.button(
			"%s\n%d 金  ·  %s" % [item_data.name, price, stock_text],
			&"",
			Vector2(0, 70)
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = ItemDatabase.load_icon_texture(item_id)
		button.expand_icon = true
		button.tooltip_text = str(item_data.description)
		button.pressed.connect(_select_item.bind(item_id))
		_items.add_child(button)


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
	_confirm.disabled = false
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
	_confirm.disabled = true


func _set_checkout_error(message: String) -> void:
	_confirm.disabled = true
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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
