extends Control
class_name SeedShopUI

signal shop_closed
signal item_bought(item_id: String, quantity: int, total_price: int)

const SHOP_ITEMS: Array[Dictionary] = [
	{"id": "turnip_seed", "name": "防风草种子", "description": "春天播种，4 天成熟。适合初次耕种。", "price": 20, "season": "spring"},
	{"id": "potato_seed", "name": "土豆种子", "description": "春天播种，6 天成熟。适合做各种料理。", "price": 50, "season": "spring"},
	{"id": "green_bean_seed", "name": "青豆种子", "description": "春天播种，成熟后还可以再收几次。", "price": 60, "season": "spring"},
	{"id": "tomato_seed", "name": "番茄种子", "description": "夏天播种，11 天成熟。多汁酸甜。", "price": 50, "season": "summer"},
	{"id": "corn_seed", "name": "玉米种子", "description": "夏天播种，14 天成熟。金灿灿的谷物。", "price": 80, "season": "summer"},
	{"id": "pumpkin_seed", "name": "南瓜种子", "description": "秋天播种，13 天成熟。丰收季的明星。", "price": 100, "season": "fall"},
]

var shop_items: Array[Dictionary] = []
var selected_item: Dictionary = {}
var selected_quantity := 1
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _description: Label
var _season: Label
var _owned: Label
var _quantity: SpinBox
var _total: Label
var _balance: Label
var _buy: Button
var _status: Label
var item_list: ItemList


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	shop_items = SHOP_ITEMS.duplicate(true)
	_build_ui()
	item_list = ItemList.new()
	item_list.name = "CompatibilityItemList"
	item_list.visible = false
	add_child(item_list)
	_refresh_items()
	_update_money_display()
	if MoneySystem:
		MoneySystem.money_changed.connect(_on_money_changed)


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func open_shop() -> void:
	show()
	GameManager.current_state = GameManager.GameState.DIALOGUE
	selected_quantity = 1
	_refresh_items()
	_update_money_display()
	await get_tree().process_frame
	UIFactory.focus_first(self)


func close() -> void:
	hide()
	if GameManager.is_game_active:
		GameManager.current_state = GameManager.GameState.PLAYING
	shop_closed.emit()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	add_child(shade)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 48)
	safe.add_theme_constant_override("margin_top", 38)
	safe.add_theme_constant_override("margin_right", 48)
	safe.add_theme_constant_override("margin_bottom", 38)
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1080, 610))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UIFactory.title("莉莉的种子铺")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 20)
	header.add_child(_balance)
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	outer.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	outer.add_child(body)

	var list_panel := UIFactory.paper_panel(Vector2(360, 0))
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	list_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var details := UIFactory.paper_panel()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 12)
	details.add_child(detail_content)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(140, 140)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_content.add_child(_icon)
	_name = UIFactory.title("选择商品", HORIZONTAL_ALIGNMENT_CENTER)
	detail_content.add_child(_name)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_content.add_child(_description)
	_season = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	detail_content.add_child(_season)
	_owned = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	detail_content.add_child(_owned)

	var checkout := UIFactory.paper_panel(Vector2(250, 0))
	body.add_child(checkout)
	var checkout_content := VBoxContainer.new()
	checkout_content.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	checkout.add_child(checkout_content)
	checkout_content.add_child(UIFactory.title("结算", HORIZONTAL_ALIGNMENT_CENTER))
	var quantity_label := Label.new()
	quantity_label.text = "购买数量"
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
	_total.add_theme_font_size_override("font_size", 25)
	checkout_content.add_child(_total)
	_buy = UIFactory.button("购买", &"PrimaryButton", Vector2(0, 52))
	_buy.pressed.connect(_on_buy_button_pressed)
	checkout_content.add_child(_buy)
	_status = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_content.add_child(_status)

	var footer := UIFactory.subtitle("选择商品后调整数量；购买后的余额会即时更新。")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(footer)


func _refresh_items() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	item_list.clear()
	var current_season := _get_current_season()
	for item in shop_items:
		if str(item.get("season", "")).to_lower() != current_season:
			continue
		item_list.add_item(str(item.name))
		var in_season := str(item.season) == current_season
		var button := UIFactory.button(
			"%s  %s\n%d 金  ·  持有 %d" % [
				"◆" if in_season else "◇",
				item.name,
				int(item.price),
				Inventory.get_item_count(item.id),
			],
			&"",
			Vector2(0, 68)
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = ItemDatabase.load_icon_texture(item.id)
		button.expand_icon = true
		button.tooltip_text = item.description
		button.pressed.connect(_select_item.bind(item))
		_list.add_child(button)
	if selected_item.is_empty() and not shop_items.is_empty():
		selected_item = shop_items[0]
	_update_item_details()


func _select_item(item: Dictionary) -> void:
	selected_item = item
	selected_quantity = 1
	_quantity.value = 1
	_status.text = ""
	_update_item_details()


func _update_item_details() -> void:
	if selected_item.is_empty():
		_buy.disabled = true
		return
	_icon.texture = ItemDatabase.load_icon_texture(selected_item.id)
	_name.text = str(selected_item.name)
	_description.text = str(selected_item.description)
	var season_name: String = str({"spring": "春季", "summer": "夏季", "fall": "秋季", "winter": "冬季"}.get(str(selected_item.season), "全年"))
	_season.text = "%s作物%s" % [season_name, " · 当季推荐" if str(selected_item.season) == _get_current_season() else ""]
	_owned.text = "背包持有 %d" % Inventory.get_item_count(selected_item.id)
	_update_total_price()


func _update_total_price() -> void:
	if selected_item.is_empty():
		return
	selected_quantity = int(_quantity.value)
	var total: int = int(selected_item.price) * selected_quantity
	var money: int = MoneySystem.get_money() if MoneySystem else 0
	_total.text = "总计 %d 金\n购买后 %d 金" % [total, maxi(0, money - total)]
	_buy.disabled = total > money or not Inventory.can_add_item(str(selected_item.id), selected_quantity)
	if total > money:
		_status.text = "金币不足"
	elif not Inventory.can_add_item(str(selected_item.id), selected_quantity):
		_status.text = "背包空间不足"
	else:
		_status.text = ""


func _update_money_display() -> void:
	if _balance:
		_balance.text = "余额 %d 金  " % (MoneySystem.get_money() if MoneySystem else 0)


func _on_buy_button_pressed() -> void:
	if selected_item.is_empty():
		return
	if str(selected_item.get("season", "")).to_lower() != _get_current_season():
		_status.text = "这种种子不是当季的"
		if UIManager:
			UIManager.show_toast("这种种子不是当季的", {}, "warning")
		return
	var item_id := str(selected_item.id)
	var total := int(selected_item.price) * selected_quantity
	if not Inventory.can_add_item(item_id, selected_quantity):
		UIManager.show_toast("ui.toast.inventory_full", {}, "error")
		return
	if not MoneySystem.can_afford(total):
		UIManager.show_toast("ui.toast.money_low", {}, "error")
		return
	if not MoneySystem.spend_money(total, MoneySystem.ExpenseType.SEED_PURCHASE, item_id):
		return
	if not Inventory.add_item(item_id, selected_quantity):
		MoneySystem.add_money(total, MoneySystem.IncomeSource.OTHER, "purchase rollback")
		UIManager.show_toast("ui.toast.inventory_full", {}, "error")
		return
	item_bought.emit(item_id, selected_quantity, total)
	UIManager.show_toast("ui.toast.item_received", {
		"item": str(selected_item.name),
		"count": selected_quantity,
	}, "success")
	_refresh_items()
	_update_money_display()
	_update_total_price()


func _get_current_season() -> String:
	return TimeManager.get_season_name().to_lower() if TimeManager else "spring"


func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_update_total_price()


func _on_money_changed(_amount: int, _delta: int) -> void:
	_update_money_display()
	_update_total_price()


func _on_close_button_pressed() -> void:
	close()


func _on_increase_quantity() -> void:
	_quantity.value = mini(99, int(_quantity.value) + 1)


func _on_decrease_quantity() -> void:
	_quantity.value = maxi(1, int(_quantity.value) - 1)


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < shop_items.size():
		_select_item(shop_items[index])


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
