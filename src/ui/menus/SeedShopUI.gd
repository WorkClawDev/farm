extends Control
class_name SeedShopUI

## SeedShopUI - 种子商店界面
## 玩家可以在这里购买种子

signal shop_closed
signal item_bought(item_id: String, quantity: int, total_price: int)

# 商品列表
var shop_items: Array[Dictionary] = []

# 当前选中的商品
var selected_item: Dictionary = {}
var selected_quantity: int = 1

# 节点引用
@onready var item_list: ItemList = $Panel/ItemList
@onready var item_name_label: Label = $Panel/ItemDetails/NameLabel
@onready var item_desc_label: Label = $Panel/ItemDetails/DescLabel
@onready var item_price_label: Label = $Panel/ItemDetails/PriceLabel
@onready var quantity_label: Label = $Panel/QuantityControl/QuantityLabel
@onready var total_price_label: Label = $Panel/TotalPriceLabel
@onready var money_label: Label = $Panel/MoneyLabel
@onready var buy_button: Button = $Panel/BuyButton
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	_setup_shop_items()
	_setup_ui()
	_update_money_display()

## 设置商店商品
func _setup_shop_items() -> void:
	# 春季种子
	shop_items.append({
		"id": "turnip_seed",
		"name": "芜菁种子",
		"description": "春天播种，4天成熟。朴实无华的蔬菜。",
		"price": 20,
		"season": "spring",
		"icon": null
	})
	
	shop_items.append({
		"id": "potato_seed",
		"name": "土豆种子",
		"description": "春天播种，6天成熟。适合做各种料理。",
		"price": 50,
		"season": "spring",
		"icon": null
	})
	
	# 夏季种子
	shop_items.append({
		"id": "tomato_seed",
		"name": "番茄种子",
		"description": "夏天播种，11天成熟。多汁酸甜。",
		"price": 50,
		"season": "summer",
		"icon": null
	})
	
	shop_items.append({
		"id": "corn_seed",
		"name": "玉米种子",
		"description": "夏天播种，14天成熟。金灿灿的谷物。",
		"price": 80,
		"season": "summer",
		"icon": null
	})
	
	# 秋季种子
	shop_items.append({
		"id": "pumpkin_seed",
		"name": "南瓜种子",
		"description": "秋天播种，13天成熟。万圣节必备。",
		"price": 100,
		"season": "fall",
		"icon": null
	})

## 设置UI
func _setup_ui() -> void:
	# 连接按钮信号
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# 填充商品列表
	if item_list:
		item_list.clear()
		var current_season = _get_current_season()
		
		for item in shop_items:
			# 检查是否适合当前季节
			var is_in_season = item["season"] == current_season
			var season_indicator = "✓" if is_in_season else "✗"
			var display_text = "%s %s - %dG" % [season_indicator, item["name"], item["price"]]
			
			item_list.add_item(display_text)
		
		item_list.item_selected.connect(_on_item_selected)
		
		# 默认选中第一个
		if item_list.item_count > 0:
			item_list.select(0)
			_on_item_selected(0)
	
	_update_quantity_display()

## 获取当前季节
func _get_current_season() -> String:
	if TimeManager:
		return TimeManager.get_season_name().to_lower()
	return "spring"

## 商品选择回调
func _on_item_selected(index: int) -> void:
	if index >= 0 and index < shop_items.size():
		selected_item = shop_items[index]
		selected_quantity = 1
		_update_item_details()
		_update_quantity_display()

## 更新商品详情显示
func _update_item_details() -> void:
	if selected_item.is_empty():
		return
	
	if item_name_label:
		item_name_label.text = selected_item.get("name", "")
	
	if item_desc_label:
		item_desc_label.text = selected_item.get("description", "")
	
	if item_price_label:
		item_price_label.text = "单价: %dG" % selected_item.get("price", 0)
	
	_update_total_price()

## 更新数量显示
func _update_quantity_display() -> void:
	if quantity_label:
		quantity_label.text = "x%d" % selected_quantity
	
	_update_total_price()

## 更新总价显示
func _update_total_price() -> void:
	if selected_item.is_empty():
		return
	
	var price = selected_item.get("price", 0)
	var total = price * selected_quantity
	
	if total_price_label:
		total_price_label.text = "总计: %dG" % total
	
	# 检查是否买得起
	if buy_button:
		var current_money = MoneySystem.get_money() if MoneySystem else 0
		buy_button.disabled = total > current_money

## 更新金钱显示
func _update_money_display() -> void:
	if money_label:
		var current_money = MoneySystem.get_money() if MoneySystem else 0
		money_label.text = "持有: %dG" % current_money

## 增加数量
func _on_increase_quantity() -> void:
	selected_quantity = min(selected_quantity + 1, 99)
	_update_quantity_display()

## 减少数量
func _on_decrease_quantity() -> void:
	selected_quantity = max(selected_quantity - 1, 1)
	_update_quantity_display()

## 购买按钮回调
func _on_buy_button_pressed() -> void:
	if selected_item.is_empty():
		return
	
	var item_id = selected_item.get("id", "")
	var price = selected_item.get("price", 0)
	var total_price = price * selected_quantity
	
	# 检查金钱
	if MoneySystem and MoneySystem.get_money() >= total_price:
		# 扣除金钱
		MoneySystem.spend_money(total_price, MoneySystem.ExpenseType.SEED_PURCHASE, item_id)
		
		# 添加到背包
		if Inventory:
			Inventory.add_item(item_id, selected_quantity)
		
		# 发射信号
		item_bought.emit(item_id, selected_quantity, total_price)
		
		# 更新显示
		_update_money_display()
		_update_total_price()
		
		print("[SeedShopUI] Bought ", selected_quantity, "x ", item_id, " for ", total_price, "G")
	else:
		print("[SeedShopUI] Not enough money!")

## 关闭按钮回调
func _on_close_button_pressed() -> void:
	hide()
	shop_closed.emit()

## 打开商店
func open_shop() -> void:
	show()
	_update_money_display()
	selected_quantity = 1
	_update_quantity_display()

## 处理输入
func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
	elif event.is_action_pressed("ui_up"):
		_on_increase_quantity()
	elif event.is_action_pressed("ui_down"):
		_on_decrease_quantity()
