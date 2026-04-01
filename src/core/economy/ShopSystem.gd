extends Node

## ShopSystem - 商店系统
## 管理商店、商品列表、库存和交易

# 商店数据结构
class ShopData extends RefCounted:
	var shop_id: String = ""
	var shop_name: String = ""
	var shop_type: String = "general"  # general, seed, tool, fish, etc.
	var npc_id: String = ""
	var opening_hour: int = 9
	var closing_hour: int = 18
	var items: Array[Dictionary] = []
	var buy_multiplier: float = 1.0
	var sell_multiplier: float = 1.0

	func _to_string() -> String:
		return "[Shop:%s] %s - %d items" % [shop_id, shop_name, items.size()]

# 商品条目结构
class ShopItem extends RefCounted:
	var item_id: String = ""
	var stock: int = -1  # -1 = 无限库存
	var max_stock: int = -1
	var restock_days: int = 1
	var buy_price_override: int = -1  # -1 = 使用默认价格
	var sell_price_override: int = -1
	var unlock_condition: String = ""  # 解锁条件

	func get_buy_price() -> int:
		if buy_price_override >= 0:
			return buy_price_override
		var item_data = ItemDatabase.get_item(item_id)
		if item_data:
			return item_data.buy_price
		return 0

	func get_sell_price() -> int:
		if sell_price_override >= 0:
			return sell_price_override
		var item_data = ItemDatabase.get_item(item_id)
		if item_data:
			return item_data.sell_price
		return 0

# 信号
signal shop_opened(shop_id: String)
signal shop_closed
signal item_purchased(item_id: String, quantity: int, total_price: int)
signal item_sold(item_id: String, quantity: int, total_price: int)
signal purchase_failed(reason: String)
signal sale_failed(reason: String)

# 商店数据库
var _shops: Dictionary = {}
var _current_shop: ShopData = null
var _shop_stock: Dictionary = {}  # shop_id -> {item_id: current_stock}
var _is_loaded: bool = false

# 玩家引用（通过GameManager获取）
var _player_inventory = null

func _ready() -> void:
	load_shops()
	_connect_signals()

func _get_money_system():
	return get_node_or_null("/root/MoneySystem")

func _get_inventory():
	return get_node_or_null("/root/Inventory")

func _connect_signals() -> void:
	if EventBus:
		get_node("/root/EventBus").shop.shop_opened.connect(_on_event_bus_shop_opened)
		get_node("/root/EventBus").shop.shop_closed.connect(_on_event_bus_shop_closed)

func _on_event_bus_shop_opened(shop_id: String) -> void:
	open_shop(shop_id)

func _on_event_bus_shop_closed() -> void:
	close_shop()

## 加载商店数据
func load_shops() -> bool:
	var path := "res://data/shops.json"

	if not FileAccess.file_exists(path):
		push_warning("[ShopSystem] shops.json not found at: " + path)
		_create_default_shops()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("[ShopSystem] Failed to open shops.json: " + str(error))
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("[ShopSystem] JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return false

	var data: Dictionary = json.get_data()
	_parse_shops(data)

	_is_loaded = true
	print("[ShopSystem] Loaded %d shops" % _shops.size())
	return true

## 解析商店数据
func _parse_shops(data: Dictionary) -> void:
	if not data.has("shops"):
		push_warning("[ShopSystem] No 'shops' array in shops.json")
		return

	var shops_array: Array = data["shops"]
	for shop_data in shops_array:
		var shop := _create_shop_from_dict(shop_data)
		if shop.shop_id != "":
			_shops[shop.shop_id] = shop
			_initialize_shop_stock(shop)

## 从字典创建商店
func _create_shop_from_dict(data: Dictionary) -> ShopData:
	var shop := ShopData.new()

	shop.shop_id = data.get("id", "")
	if shop.shop_id == "":
		push_warning("[ShopSystem] Shop missing 'id' field")
		return shop

	shop.shop_name = data.get("name", shop.shop_id)
	shop.shop_type = data.get("type", "general")
	shop.npc_id = data.get("npc_id", "")
	shop.opening_hour = data.get("opening_hour", 9)
	shop.closing_hour = data.get("closing_hour", 18)
	shop.buy_multiplier = data.get("buy_multiplier", 1.0)
	shop.sell_multiplier = data.get("sell_multiplier", 1.0)

	# 解析商品列表
	if data.has("items"):
		for item_data in data["items"]:
			var shop_item := _create_shop_item(item_data)
			shop.items.append({
				"item_id": shop_item.item_id,
				"stock": shop_item.stock,
				"max_stock": shop_item.max_stock,
				"buy_price_override": shop_item.buy_price_override,
				"sell_price_override": shop_item.sell_price_override,
				"unlock_condition": shop_item.unlock_condition
			})

	return shop

## 创建商品条目
func _create_shop_item(data: Dictionary) -> ShopItem:
	var item := ShopItem.new()
	item.item_id = data.get("item_id", "")
	item.stock = data.get("stock", -1)
	item.max_stock = data.get("max_stock", -1)
	item.buy_price_override = data.get("buy_price", -1)
	item.sell_price_override = data.get("sell_price", -1)
	item.unlock_condition = data.get("unlock_condition", "")
	return item

## 初始化商店库存
func _initialize_shop_stock(shop: ShopData) -> void:
	if not _shop_stock.has(shop.shop_id):
		_shop_stock[shop.shop_id] = {}

	for item_data in shop.items:
		var item_id: String = item_data.get("item_id", "")
		var stock: int = item_data.get("stock", -1)
		_shop_stock[shop.shop_id][item_id] = stock

## 创建默认商店
func _create_default_shops() -> void:
	var default_shop := ShopData.new()
	default_shop.shop_id = "general_store"
	default_shop.shop_name = "杂货店"
	default_shop.shop_type = "general"
	default_shop.opening_hour = 9
	default_shop.closing_hour = 18
	default_shop.items = [
		{"item_id": "turnip_seed", "stock": -1},
		{"item_id": "potato_seed", "stock": -1},
		{"item_id": "watering_can", "stock": 1}
	]

	_shops[default_shop.shop_id] = default_shop
	_initialize_shop_stock(default_shop)

	_is_loaded = true
	print("[ShopSystem] Created default shop: general_store")

## 获取商店数据
func get_shop(shop_id: String) -> ShopData:
	return _shops.get(shop_id, null)

## 获取所有商店ID
func get_all_shop_ids() -> Array:
	return _shops.keys()

## 打开商店
func open_shop(shop_id: String) -> bool:
	if not _shops.has(shop_id):
		push_warning("[ShopSystem] Shop not found: " + shop_id)
		return false

	var shop: ShopData = _shops[shop_id]

	# 检查营业时间
	if not is_shop_open(shop_id):
		push_warning("[ShopSystem] Shop %s is closed" % shop_id)
		return false

	_current_shop = shop
	shop_opened.emit(shop_id)
	print("[ShopSystem] Opened shop: %s" % shop.shop_name)
	return true

## 关闭商店
func close_shop() -> void:
	_current_shop = null
	shop_closed.emit()
	print("[ShopSystem] Closed shop")

## 获取当前商店
func get_current_shop() -> ShopData:
	return _current_shop

## 检查商店是否营业
func is_shop_open(shop_id: String) -> bool:
	var shop: ShopData = _shops.get(shop_id)
	if shop == null:
		return false

	if TimeManager:
		var current_hour: int = TimeManager.get_current_hour()
		return current_hour >= shop.opening_hour and current_hour < shop.closing_hour

	return true  # 没有时间管理器时默认营业

## 获取商品列表
func get_shop_items(shop_id: String = "") -> Array:
	var target_shop: ShopData = _shops.get(shop_id) if shop_id != "" else _current_shop
	if target_shop == null:
		return []

	return target_shop.items

## 获取商品库存
func get_item_stock(shop_id: String, item_id: String) -> int:
	if not _shop_stock.has(shop_id):
		return -1
	if not _shop_stock[shop_id].has(item_id):
		return -1
	return _shop_stock[shop_id][item_id]

## 计算购买价格
func calculate_buy_price(item_id: String, quantity: int = 1) -> int:
	if _current_shop == null:
		return 0

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return 0

	# 查找是否有价格覆盖
	var base_price: int = item_data.buy_price
	for shop_item in _current_shop.items:
		if shop_item.item_id == item_id:
			if shop_item.buy_price_override >= 0:
				base_price = shop_item.buy_price_override
			break

	return int(base_price * _current_shop.buy_multiplier * quantity)

## 计算出售价格
func calculate_sell_price(item_id: String, quantity: int = 1) -> int:
	if _current_shop == null:
		return 0

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return 0

	return int(item_data.sell_price * _current_shop.sell_multiplier * quantity)

## 购买物品
func buy_item(item_id: String, quantity: int = 1) -> bool:
	if _current_shop == null:
		purchase_failed.emit("no_shop_open")
		return false

	# 检查物品是否存在
	if not ItemDatabase.has_item(item_id):
		purchase_failed.emit("item_not_found")
		return false

	# 检查库存
	var stock: int = get_item_stock(_current_shop.shop_id, item_id)
	if stock >= 0 and stock < quantity:
		purchase_failed.emit("out_of_stock")
		return false

	# 检查是否在商店商品列表中
	var is_in_shop: bool = false
	for shop_item in _current_shop.items:
		if shop_item.item_id == item_id:
			is_in_shop = true
			break

	if not is_in_shop:
		purchase_failed.emit("item_not_available")
		return false

	# 计算价格
	var total_price: int = calculate_buy_price(item_id, quantity)

	# 检查金钱
	var money_system = _get_money_system()
	var inventory = _get_inventory()
	if money_system == null or inventory == null:
		purchase_failed.emit("system_unavailable")
		return false

	if not money_system.can_afford(total_price):
		purchase_failed.emit("not_enough_money")
		return false

	if not money_system.spend_money(total_price, money_system.ExpenseType.OTHER, item_id):
		purchase_failed.emit("not_enough_money")
		return false

	if not inventory.add_item(item_id, quantity):
		# Roll back the money if inventory add fails.
		money_system.add_money(total_price, money_system.IncomeSource.OTHER, "shop_refund_" + item_id)
		purchase_failed.emit("inventory_full")
		return false

	# 减少库存
	if stock > 0:
		_shop_stock[_current_shop.shop_id][item_id] = stock - quantity

	# 发送事件
	var final_price: int = calculate_buy_price(item_id, quantity)
	item_purchased.emit(item_id, quantity, final_price)
	if EventBus:
		get_node("/root/EventBus").shop.item_bought.emit(item_id, final_price)

	print("[ShopSystem] Bought %dx %s for %dG" % [quantity, item_id, final_price])
	return true

## 出售物品
func sell_item(item_id: String, quantity: int = 1) -> bool:
	if _current_shop == null:
		sale_failed.emit("no_shop_open")
		return false

	# 检查物品是否存在
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		sale_failed.emit("item_not_found")
		return false

	# 检查玩家是否有该物品
	var inventory = _get_inventory()
	var money_system = _get_money_system()
	if inventory == null or money_system == null:
		sale_failed.emit("system_unavailable")
		return false

	if not inventory.has_item(item_id, quantity):
		sale_failed.emit("not_enough_items")
		return false

	# 计算价格
	var total_price: int = calculate_sell_price(item_id, quantity)

	# 移除物品
	if not inventory.remove_item(item_id, quantity):
		sale_failed.emit("not_enough_items")
		return false

	# 增加金钱
	money_system.add_money(total_price, money_system.IncomeSource.OTHER, item_id)

	# 发送事件
	var final_price: int = calculate_sell_price(item_id, quantity)
	item_sold.emit(item_id, quantity, final_price)
	if EventBus:
		get_node("/root/EventBus").shop.item_sold.emit(item_id, final_price)

	print("[ShopSystem] Sold %dx %s for %dG" % [quantity, item_id, final_price])
	return true

## 补充库存
func restock_shop(shop_id: String) -> void:
	if not _shops.has(shop_id):
		return

	var shop: ShopData = _shops[shop_id]
	if not _shop_stock.has(shop_id):
		_shop_stock[shop_id] = {}

	for item_data in shop.items:
		var item_id: String = item_data.get("item_id", "")
		var max_stock: int = item_data.get("max_stock", -1)

		if max_stock > 0:
			_shop_stock[shop_id][item_id] = max_stock

	print("[ShopSystem] Restocked shop: %s" % shop_id)

## 每日补货（由TimeManager调用）
func on_day_changed() -> void:
	for shop_id in _shops.keys():
		restock_shop(shop_id)

## 保存商店状态
func save_state() -> Dictionary:
	return {
		"shop_stock": _shop_stock.duplicate(true)
	}

## 加载商店状态
func load_state(state: Dictionary) -> void:
	if state.has("shop_stock"):
		_shop_stock = state["shop_stock"].duplicate(true)
