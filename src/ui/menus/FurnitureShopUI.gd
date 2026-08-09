extends Control
class_name FurnitureShopUI

## FurnitureShopUI - 家具商店界面
## 玩家可以购买家具

@onready var furniture_list: ItemList = $Panel/FurnitureList
@onready var item_name_label: Label = $Panel/ItemDetails/NameLabel
@onready var item_desc_label: Label = $Panel/ItemDetails/DescLabel
@onready var item_price_label: Label = $Panel/ItemDetails/PriceLabel
@onready var money_label: Label = $Panel/MoneyLabel
@onready var buy_button: Button = $Panel/BuyButton
@onready var close_button: Button = $Panel/CloseButton

var selected_furniture: Dictionary = {}

func _ready() -> void:
	_setup_signals()
	_populate_furniture_list()
	_update_money_display()

func _setup_signals() -> void:
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if furniture_list:
		furniture_list.item_selected.connect(_on_furniture_selected)

func _populate_furniture_list() -> void:
	if not furniture_list:
		return
	
	furniture_list.clear()
	
	var furniture_db = get_node_or_null("/root/FurnitureDatabase")
	if not furniture_db:
		return
	
	for furniture_id in furniture_db.get_all_furniture_ids():
		var data = furniture_db.get_furniture(furniture_id)
		var display_text = "%s - %dG" % [data.get("name", furniture_id), data.get("buy_price", 0)]
		furniture_list.add_item(display_text)

func _on_furniture_selected(index: int) -> void:
	var furniture_db = get_node_or_null("/root/FurnitureDatabase")
	if not furniture_db:
		return
	
	var furniture_ids = furniture_db.get_all_furniture_ids()
	if index >= 0 and index < furniture_ids.size():
		selected_furniture = furniture_db.get_furniture(furniture_ids[index])
		_update_item_details()

func _update_item_details() -> void:
	if selected_furniture.is_empty():
		return
	
	if item_name_label:
		item_name_label.text = selected_furniture.get("name", "")
	
	if item_desc_label:
		item_desc_label.text = selected_furniture.get("description", "")
	
	if item_price_label:
		item_price_label.text = "价格: %dG" % selected_furniture.get("buy_price", 0)
	
	# 更新购买按钮状态
	var money_system = get_node_or_null("/root/MoneySystem")
	if buy_button and money_system:
		var price = selected_furniture.get("buy_price", 0)
		buy_button.disabled = money_system.get_money() < price

func _update_money_display() -> void:
	var money_system = get_node_or_null("/root/MoneySystem")
	if money_label and money_system:
		money_label.text = "持有: %dG" % money_system.get_money()

func _on_buy_pressed() -> void:
	if selected_furniture.is_empty():
		return
	
	var furniture_id = selected_furniture.get("id", "")
	var price = selected_furniture.get("buy_price", 0)
	
	var money_system = get_node_or_null("/root/MoneySystem")
	var inventory = get_node_or_null("/root/Inventory")
	
	if not money_system or not inventory:
		return
	
	# 检查金钱
	if money_system.get_money() < price:
		print("[FurnitureShopUI] 金钱不足")
		return
	
	# 扣除金钱
	money_system.spend_money(price)
	
	# 添加到背包（作为家具物品）
	inventory.add_item(furniture_id, 1)
	
	# 更新显示
	_update_money_display()
	_update_item_details()
	
	print("[FurnitureShopUI] 购买家具: ", selected_furniture.get("name", furniture_id))

func _on_close_pressed() -> void:
	hide()

func open() -> void:
	show()
	_populate_furniture_list()
	_update_money_display()