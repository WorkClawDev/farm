extends Node

## ShippingSystem - 运输系统
## 管理出货箱、次日结算、批量出售功能

signal item_added_to_bin(item_id: String, quantity: int)
signal item_removed_from_bin(item_id: String, quantity: int)
signal bin_contents_changed(items: Array[Dictionary])
signal shipment_completed(total_money: int, items_count: int)
signal shipment_summary(summary: Dictionary)

# 出货箱内容
# 格式: [{ "item_id": String, "quantity": int, "quality": int }]
var _bin_contents: Array[Dictionary] = []

# 结算历史记录
var _shipment_history: Array[Dictionary] = []

# 历史记录最大保存数量
const MAX_HISTORY: int = 30

# 出货箱容量限制
const MAX_BIN_SLOTS: int = 36
const MAX_STACK: int = 999

func _ready() -> void:
	print("[ShippingSystem] Initialized")
	_connect_signals()

func _connect_signals() -> void:
	# 监听天数变化，触发结算
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("day_changed"):
		time_manager.day_changed.connect(_on_day_changed)
		print("[ShippingSystem] Connected to TimeManager.day_changed")

## 添加物品到出货箱
func add_item(item_id: String, quantity: int = 1, quality: int = 0) -> bool:
	if quantity <= 0:
		push_warning("[ShippingSystem] Invalid quantity: ", quantity)
		return false

	# 检查物品是否存在
	var item_database = get_node_or_null("/root/ItemDatabase")
	if item_database and not item_database.has_item(item_id):
		push_warning("[ShippingSystem] Item not found: ", item_id)
		return false

	# 尝试堆叠到现有格子
	var added := false
	for slot in _bin_contents:
		if slot.item_id == item_id and slot.quality == quality:
			var new_quantity: int = min(slot.quantity + quantity, MAX_STACK)
			var actual_added: int = new_quantity - slot.quantity
			if actual_added > 0:
				slot.quantity = new_quantity
				added = true
				item_added_to_bin.emit(item_id, actual_added)
				break

	# 如果没有找到可堆叠的格子，创建新格子
	if not added:
		if _bin_contents.size() >= MAX_BIN_SLOTS:
			push_warning("[ShippingSystem] Bin is full")
			return false

		_bin_contents.append({
			"item_id": item_id,
			"quantity": min(quantity, MAX_STACK),
			"quality": quality
		})
		item_added_to_bin.emit(item_id, min(quantity, MAX_STACK))

	bin_contents_changed.emit(_bin_contents.duplicate())
	print("[ShippingSystem] Added ", quantity, "x ", item_id, " (quality: ", quality, ") to bin")
	return true

## 从出货箱移除物品
func remove_item(item_id: String, quantity: int = 1, quality: int = -1) -> bool:
	if quantity <= 0:
		push_warning("[ShippingSystem] Invalid quantity: ", quantity)
		return false

	var index_to_remove := -1
	var removed_quantity: int = 0

	for i in range(_bin_contents.size()):
		var slot = _bin_contents[i]
		if slot.item_id == item_id:
			if quality == -1 or slot.quality == quality:
				var actual_remove: int = min(quantity, slot.quantity)
				slot.quantity -= actual_remove
				removed_quantity = actual_remove

				if slot.quantity <= 0:
					index_to_remove = i
				break

	if removed_quantity == 0:
		return false

	if index_to_remove >= 0:
		_bin_contents.remove_at(index_to_remove)

	item_removed_from_bin.emit(item_id, removed_quantity)
	bin_contents_changed.emit(_bin_contents.duplicate())
	print("[ShippingSystem] Removed ", removed_quantity, "x ", item_id, " from bin")
	return true

## 清空出货箱
func clear_bin() -> void:
	_bin_contents.clear()
	bin_contents_changed.emit(_bin_contents.duplicate())
	print("[ShippingSystem] Bin cleared")

## 获取出货箱内容
func get_bin_contents() -> Array[Dictionary]:
	return _bin_contents.duplicate()

## 获取出货箱物品总数
func get_total_items() -> int:
	var total := 0
	for slot in _bin_contents:
		total += slot.quantity
	return total

## 获取出货箱格子数
func get_slot_count() -> int:
	return _bin_contents.size()

## 计算当前出货箱总价值
func calculate_total_value() -> Dictionary:
	var total_value := 0
	var total_items := 0
	var breakdown: Array[Dictionary] = []

	var item_database = get_node_or_null("/root/ItemDatabase")
	for slot in _bin_contents:
		var item_data = item_database.get_item(slot.item_id) if item_database else null
		if item_data:
			# 品质加成: 0=普通(100%), 1=良好(125%), 2=优质(150%), 3=完美(200%)
			var quality_multiplier: float = 1.0 + (slot.quality * 0.25)
			var item_value: int = int(item_data.sell_price * quality_multiplier) * slot.quantity

			total_value += item_value
			total_items += slot.quantity

			breakdown.append({
				"item_id": slot.item_id,
				"item_name": item_data.name,
				"quantity": slot.quantity,
				"quality": slot.quality,
				"unit_price": int(item_data.sell_price * quality_multiplier),
				"total_price": item_value
			})

	return {
		"total_value": total_value,
		"total_items": total_items,
		"breakdown": breakdown
	}

## 执行结算（次日自动调用或手动触发）
func process_shipment() -> Dictionary:
	if _bin_contents.is_empty():
		print("[ShippingSystem] Bin is empty, no shipment to process")
		return {"success": false, "reason": "empty"}

	var value_info = calculate_total_value()
	var total_money: int = value_info.total_value
	var total_items: int = value_info.total_items
	var breakdown: Array = value_info.breakdown

	if total_money <= 0:
		print("[ShippingSystem] No valuable items in bin")
		return {"success": false, "reason": "no_value"}

	# 记录结算信息
	var shipment_record := {
		"date": _get_current_date_string(),
		"timestamp": Time.get_unix_time_from_system(),
		"total_money": total_money,
		"total_items": total_items,
		"items": breakdown.duplicate()
	}

	# 发放金钱
	var money_system = get_node_or_null("/root/MoneySystem")
	if money_system:
		money_system.add_money(
			total_money,
			0,  # IncomeSource.CROP_SALE
			"Shipment: %d items" % total_items
		)

	# 记录到历史
	_shipment_history.append(shipment_record)
	while _shipment_history.size() > MAX_HISTORY:
		_shipment_history.pop_front()

	# 清空出货箱
	var processed_contents := _bin_contents.duplicate()
	_bin_contents.clear()

	# 发射信号
	shipment_completed.emit(total_money, total_items)

	var summary := {
		"success": true,
		"total_money": total_money,
		"total_items": total_items,
		"items": breakdown
	}
	shipment_summary.emit(summary)

	print("[ShippingSystem] Shipment processed: $", total_money, " for ", total_items, " items")

	return summary

## 天数变化时触发结算
func _on_day_changed(_new_day: int) -> void:
	# 在新的一天开始时处理出货箱结算
	print("[ShippingSystem] New day - processing shipment...")
	process_shipment()

## 获取结算历史
func get_shipment_history(count: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = max(0, _shipment_history.size() - count)

	for i in range(start_index, _shipment_history.size()):
		result.append(_shipment_history[i])

	return result

## 获取所有结算历史
func get_all_shipment_history() -> Array[Dictionary]:
	return _shipment_history.duplicate()

## 获取当前日期字符串
func _get_current_date_string() -> String:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		return time_manager.get_formatted_date()
	return "Unknown Date"

## 批量添加物品
func add_items_batch(items: Array[Dictionary]) -> Dictionary:
	var added_count := 0
	var failed_count := 0

	for item in items:
		var item_id: String = item.get("item_id", "")
		var quantity: int = item.get("quantity", 1)
		var quality: int = item.get("quality", 0)

		if add_item(item_id, quantity, quality):
			added_count += 1
		else:
			failed_count += 1

	return {
		"added": added_count,
		"failed": failed_count
	}

## 序列化保存
func save_state() -> Dictionary:
	return {
		"bin_contents": _bin_contents.duplicate(),
		"shipment_history": _shipment_history.slice(-10)  # 只保存最近10条记录
	}

## 反序列化加载
func load_state(data: Dictionary) -> void:
	_bin_contents.clear()
	var saved_contents: Array = data.get("bin_contents", [])
	for item in saved_contents:
		_bin_contents.append(item)

	_shipment_history.clear()
	var saved_history: Array = data.get("shipment_history", [])
	for record in saved_history:
		_shipment_history.append(record)

	print("[ShippingSystem] Loaded state: ", _bin_contents.size(), " items in bin, ",
		_shipment_history.size(), " history records")

## 重置到初始状态
func reset() -> void:
	_bin_contents.clear()
	_shipment_history.clear()
	print("[ShippingSystem] Reset to initial state")