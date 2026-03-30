extends CanvasLayer
class_name ShopUI

## ShopUI - 商店界面
## 显示商品列表、购买/出售功能

# UI模式
enum UIMode {
	BUY,
	SELL
}

# 信号
signal shop_closed

# UI节点引用
@onready var panel: Panel = $CenterContainer/Panel
@onready var shop_name_label: Label = $CenterContainer/Panel/VBoxContainer/Header/ShopNameLabel
@onready var mode_tabs: HBoxContainer = $CenterContainer/Panel/VBoxContainer/Header/ModeTabs
@onready var buy_button: Button = $CenterContainer/Panel/VBoxContainer/Header/ModeTabs/BuyButton
@onready var sell_button: Button = $CenterContainer/Panel/VBoxContainer/Header/ModeTabs/SellButton
@onready var items_list: VBoxContainer = $CenterContainer/Panel/VBoxContainer/ScrollContainer/ItemsList
@onready var item_info_panel: Panel = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ItemInfoPanel
@onready var item_name_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemNameLabel
@onready var item_desc_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemDescLabel
@onready var item_price_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemPriceLabel
@onready var item_stock_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ItemInfoPanel/VBoxContainer/ItemStockLabel
@onready var quantity_spinbox: SpinBox = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ControlsPanel/VBoxContainer/QuantitySpinBox
@onready var total_price_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ControlsPanel/VBoxContainer/TotalPriceLabel
@onready var confirm_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/ControlsPanel/VBoxContainer/ConfirmButton
@onready var close_button: Button = $CenterContainer/Panel/VBoxContainer/Header/CloseButton
@onready var money_label: Label = $CenterContainer/Panel/VBoxContainer/Footer/MoneyLabel
@onready var message_label: Label = $CenterContainer/Panel/VBoxContainer/Footer/MessageLabel

# 状态
var current_mode: UIMode = UIMode.BUY
var selected_item_id: String = ""
var selected_quantity: int = 1

func _ready() -> void:
	hide()
	_connect_signals()
	_connect_shop_signals()

func _connect_signals() -> void:
	buy_button.pressed.connect(_on_buy_mode_pressed)
	sell_button.pressed.connect(_on_sell_mode_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	close_button.pressed.connect(_on_close_pressed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)

func _connect_shop_signals() -> void:
	if ShopSystem:
		ShopSystem.shop_opened.connect(_on_shop_opened)
		ShopSystem.shop_closed.connect(_on_shop_closed)
		ShopSystem.item_purchased.connect(_on_item_purchased)
		ShopSystem.item_sold.connect(_on_item_sold)
		ShopSystem.purchase_failed.connect(_on_purchase_failed)
		ShopSystem.sale_failed.connect(_on_sale_failed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()

## 打开商店界面
func open(shop_id: String) -> void:
	if ShopSystem:
		ShopSystem.open_shop(shop_id)

## 关闭商店界面
func close() -> void:
	if ShopSystem:
		ShopSystem.close_shop()
	hide()
	if GameManager:
		GameManager.resume_game()
	shop_closed.emit()

## 设置模式
func set_mode(mode: UIMode) -> void:
	current_mode = mode
	_update_mode_buttons()
	_refresh_items_list()
	_clear_selection()

func _update_mode_buttons() -> void:
	buy_button.button_pressed = (current_mode == UIMode.BUY)
	sell_button.button_pressed = (current_mode == UIMode.SELL)
	confirm_button.text = "购买" if current_mode == UIMode.BUY else "出售"

## 刷新商品列表
func _refresh_items_list() -> void:
	# 清空列表
	for child in items_list.get_children():
		child.queue_free()

	if ShopSystem == null:
		return

	var shop = ShopSystem.get_current_shop()
	if shop == null:
		return

	if current_mode == UIMode.BUY:
		# 显示商店商品
		for item_data in shop.items:
			var item_id: String = item_data.get("item_id", "")
			_create_item_button(item_id, true)
	else:
		# 显示玩家可出售的物品
		if GameManager and GameManager.inventory:
			for slot in GameManager.inventory:
				if slot and slot.get("item_id", "") != "":
					var item_id: String = slot["item_id"]
					var quantity: int = slot.get("quantity", 0)
					if quantity > 0:
						_create_item_button(item_id, false, quantity)

## 创建物品按钮
func _create_item_button(item_id: String, is_buy: bool, player_quantity: int = 0) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	var button := Button.new()
	button.text = item_data.name

	if is_buy:
		var price: int = ShopSystem.calculate_buy_price(item_id, 1)
		var stock: int = ShopSystem.get_item_stock(ShopSystem.get_current_shop().shop_id, item_id)
		button.text += " - %dG" % price
		if stock >= 0:
			button.text += " (库存: %d)" % stock
	else:
		var price: int = ShopSystem.calculate_sell_price(item_id, 1)
		button.text += " x%d - %dG" % [player_quantity, price]

	button.tooltip_text = item_data.description
	button.custom_minimum_size = Vector2(300, 40)

	# 绑定点击事件
	button.pressed.connect(_on_item_button_pressed.bind(item_id))

	items_list.add_child(button)

## 物品按钮点击
func _on_item_button_pressed(item_id: String) -> void:
	selected_item_id = item_id
	_update_item_info()
	_update_total_price()

## 更新物品信息
func _update_item_info() -> void:
	if selected_item_id == "":
		_clear_item_info()
		return

	var item_data = ItemDatabase.get_item(selected_item_id)
	if item_data == null:
		return

	item_name_label.text = item_data.name
	item_desc_label.text = item_data.description

	if current_mode == UIMode.BUY:
		var price: int = ShopSystem.calculate_buy_price(selected_item_id, 1)
		item_price_label.text = "购买价格: %dG" % price

		var stock: int = ShopSystem.get_item_stock(ShopSystem.get_current_shop().shop_id, selected_item_id)
		if stock >= 0:
			item_stock_label.text = "库存: %d" % stock
		else:
			item_stock_label.text = "库存: 无限"
	else:
		var price: int = ShopSystem.calculate_sell_price(selected_item_id, 1)
		item_price_label.text = "出售价格: %dG" % price

		# 显示玩家持有数量
		if GameManager and GameManager.inventory:
			var player_qty: int = _get_player_item_quantity(selected_item_id)
			item_stock_label.text = "持有: %d" % player_qty
			quantity_spinbox.max_value = player_qty

## 获取玩家物品数量
func _get_player_item_quantity(item_id: String) -> int:
	if GameManager and GameManager.inventory:
		for slot in GameManager.inventory:
			if slot and slot.get("item_id", "") == item_id:
				return slot.get("quantity", 0)
	return 0

## 清除物品信息
func _clear_item_info() -> void:
	item_name_label.text = "选择物品"
	item_desc_label.text = ""
	item_price_label.text = ""
	item_stock_label.text = ""

## 清除选择
func _clear_selection() -> void:
	selected_item_id = ""
	selected_quantity = 1
	quantity_spinbox.value = 1
	_clear_item_info()
	total_price_label.text = "总计: 0G"

## 更新总价
func _update_total_price() -> void:
	if selected_item_id == "":
		total_price_label.text = "总计: 0G"
		return

	selected_quantity = int(quantity_spinbox.value)
	var total: int

	if current_mode == UIMode.BUY:
		total = ShopSystem.calculate_buy_price(selected_item_id, selected_quantity)
	else:
		total = ShopSystem.calculate_sell_price(selected_item_id, selected_quantity)

	total_price_label.text = "总计: %dG" % total

## 更新金钱显示
func _update_money_display() -> void:
	if GameManager:
		money_label.text = "金币: %dG" % get_node_or_null("/root/GameManager").money if get_node_or_null("/root/GameManager") else 0

## 显示消息
func show_message(message: String, is_error: bool = false) -> void:
	message_label.text = message
	if is_error:
		message_label.modulate = Color.RED
	else:
		message_label.modulate = Color.WHITE

	# 3秒后清除消息
	await get_tree().create_timer(3.0).timeout
	message_label.text = ""

# 信号回调

func _on_shop_opened(shop_id: String) -> void:
	var shop = ShopSystem.get_shop(shop_id)
	if shop:
		shop_name_label.text = shop.shop_name

	_update_money_display()
	set_mode(UIMode.BUY)
	show()

	if GameManager:
		GameManager.pause_game()

func _on_shop_closed() -> void:
	hide()

func _on_buy_mode_pressed() -> void:
	set_mode(UIMode.BUY)

func _on_sell_mode_pressed() -> void:
	set_mode(UIMode.SELL)

func _on_quantity_changed(value: float) -> void:
	selected_quantity = int(value)
	_update_total_price()

func _on_confirm_pressed() -> void:
	if selected_item_id == "":
		show_message("请先选择物品", true)
		return

	var success: bool
	if current_mode == UIMode.BUY:
		success = ShopSystem.buy_item(selected_item_id, selected_quantity)
	else:
		success = ShopSystem.sell_item(selected_item_id, selected_quantity)

	if success:
		# 刷新界面
		_refresh_items_list()
		_update_money_display()
		quantity_spinbox.value = 1

func _on_close_pressed() -> void:
	close()

func _on_item_purchased(_item_id: String, quantity: int, total_price: int) -> void:
	show_message("购买成功! %dx %dG" % [quantity, total_price])

func _on_item_sold(_item_id: String, quantity: int, total_price: int) -> void:
	show_message("出售成功! %dx %dG" % [quantity, total_price])

func _on_purchase_failed(reason: String) -> void:
	var message: String
	match reason:
		"no_shop_open":
			message = "商店未开启"
		"item_not_found":
			message = "物品不存在"
		"out_of_stock":
			message = "库存不足"
		"item_not_available":
			message = "商店不出售此物品"
		"not_enough_money":
			message = "金钱不足"
		_:
			message = "购买失败: " + reason

	show_message(message, true)

func _on_sale_failed(reason: String) -> void:
	var message: String
	match reason:
		"no_shop_open":
			message = "商店未开启"
		"item_not_found":
			message = "物品不存在"
		"not_enough_items":
			message = "物品数量不足"
		_:
			message = "出售失败: " + reason

	show_message(message, true)