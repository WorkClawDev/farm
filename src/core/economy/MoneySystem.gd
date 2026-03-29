extends Node

## MoneySystem - 货币系统
## 管理玩家的金钱、收入、支出和交易记录

signal money_changed(new_amount: int, delta: int)
signal transaction_recorded(transaction: Dictionary)

# 当前金钱
var _money: int = 500  # 初始金钱

# 交易记录
var _transactions: Array[Dictionary] = []

# 统计数据
var _total_earned: int = 0
var _total_spent: int = 0

# 交易记录最大保存数量
const MAX_TRANSACTIONS: int = 100

# 收入来源类型
enum IncomeSource {
	CROP_SALE,       # 出售作物
	QUEST_REWARD,    # 任务奖励
	FORAGING,        # 采集
	FISHING,         # 钓鱼
	MINING,          # 挖矿
	OTHER            # 其他
}

# 支出类型
enum ExpenseType {
	SEED_PURCHASE,   # 购买种子
	TOOL_PURCHASE,   # 购买工具
	UPGRADE,         # 升级
	BUILDING,        # 建筑
	ANIMAL,          # 购买动物
	OTHER            # 其他
}

func _ready() -> void:
	print("[MoneySystem] Initialized with starting money: ", _money)

## 获取当前金钱
func get_money() -> int:
	return _money

## 设置金钱（仅用于加载存档）
func set_money(amount: int) -> void:
	var delta: int = amount - _money
	_money = amount
	money_changed.emit(_money, delta)

## 添加金钱（收入）
func add_money(amount: int, source: IncomeSource, description: String = "") -> bool:
	if amount <= 0:
		push_warning("[MoneySystem] Cannot add non-positive amount: ", amount)
		return false

	_money += amount
	_total_earned += amount

	var transaction: Dictionary = {
		"type": "income",
		"amount": amount,
		"source": IncomeSource.keys()[source],
		"description": description,
		"timestamp": Time.get_unix_time_from_system(),
		"balance": _money
	}

	_record_transaction(transaction)
	money_changed.emit(_money, amount)
	print("[MoneySystem] +$", amount, " (", IncomeSource.keys()[source], ") - ", description)

	return true

## 扣除金钱（支出）
func spend_money(amount: int, expense_type: ExpenseType, description: String = "") -> bool:
	if amount <= 0:
		push_warning("[MoneySystem] Cannot spend non-positive amount: ", amount)
		return false

	if _money < amount:
		push_warning("[MoneySystem] Insufficient funds: need $", amount, ", have $", _money)
		return false

	_money -= amount
	_total_spent += amount

	var transaction: Dictionary = {
		"type": "expense",
		"amount": amount,
		"expense_type": ExpenseType.keys()[expense_type],
		"description": description,
		"timestamp": Time.get_unix_time_from_system(),
		"balance": _money
	}

	_record_transaction(transaction)
	money_changed.emit(_money, -amount)
	print("[MoneySystem] -$", amount, " (", ExpenseType.keys()[expense_type], ") - ", description)

	return true

## 检查是否有足够的金钱
func can_afford(amount: int) -> bool:
	return _money >= amount

## 出售作物获得金钱
func sell_crop(crop_id: String, crop_name: String, quality: int, base_price: int, quantity: int = 1) -> int:
	# 品质加成: 0=普通(100%), 1=良好(125%), 2=优质(150%), 3=完美(200%)
	var quality_multiplier: float = 1.0 + (quality * 0.25)
	var total_price: int = int(base_price * quality_multiplier) * quantity

	var quality_name: String = _get_quality_name(quality)
	var description: String = "%dx %s (%s)" % [quantity, crop_name, quality_name]

	if add_money(total_price, IncomeSource.CROP_SALE, description):
		# 发射事件信号
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("item_sold"):
			event_bus.item_sold.emit(crop_id, total_price)
		return total_price

	return 0

## 领取任务奖励
func claim_quest_reward(quest_id: String, quest_name: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var description: String = "Quest: " + quest_name
	return add_money(amount, IncomeSource.QUEST_REWARD, description)

## 购买种子
func buy_seeds(seed_id: String, seed_name: String, price: int, quantity: int = 1) -> bool:
	var total_cost: int = price * quantity
	var description: String = "%dx %s" % [quantity, seed_name]

	return spend_money(total_cost, ExpenseType.SEED_PURCHASE, description)

## 购买工具
func buy_tool(tool_id: String, tool_name: String, price: int) -> bool:
	return spend_money(price, ExpenseType.TOOL_PURCHASE, tool_name)

## 获取交易记录
func get_transactions(count: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = max(0, _transactions.size() - count)

	for i in range(start_index, _transactions.size()):
		result.append(_transactions[i])

	return result

## 获取所有交易记录
func get_all_transactions() -> Array[Dictionary]:
	return _transactions.duplicate()

## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"current_money": _money,
		"total_earned": _total_earned,
		"total_spent": _total_spent,
		"transaction_count": _transactions.size()
	}

## 记录交易
func _record_transaction(transaction: Dictionary) -> void:
	_transactions.append(transaction)

	# 保持记录数量限制
	while _transactions.size() > MAX_TRANSACTIONS:
		_transactions.remove_at(0)

	transaction_recorded.emit(transaction)

## 获取品质名称
func _get_quality_name(quality: int) -> String:
	match quality:
		0: return "Normal"
		1: return "Good"
		2: return "Quality"
		3: return "Perfect"
		_: return "Unknown"

## 序列化保存
func save_state() -> Dictionary:
	return {
		"money": _money,
		"total_earned": _total_earned,
		"total_spent": _total_spent,
		"transactions": _transactions.slice(-20)  # 只保存最近20条记录
	}

## 反序列化加载
func load_state(data: Dictionary) -> void:
	_money = data.get("money", 500)
	_total_earned = data.get("total_earned", 0)
	_total_spent = data.get("total_spent", 0)

	var saved_transactions: Array = data.get("transactions", [])
	_transactions.clear()
	for t in saved_transactions:
		_transactions.append(t)

	print("[MoneySystem] Loaded state: $", _money, " (Earned: $", _total_earned, ", Spent: $", _total_spent, ")")

## 重置到初始状态
func reset() -> void:
	_money = 500
	_total_earned = 0
	_total_spent = 0
	_transactions.clear()
	money_changed.emit(_money, 0)
	print("[MoneySystem] Reset to initial state")