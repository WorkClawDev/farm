extends Node
class_name MoneyManager

## MoneyManager - 金钱管理器
## 负责游戏货币的增减

signal money_changed(amount: int, delta: int)

var money: int = 500

func _ready() -> void:
	print("[MoneyManager] Initialized, starting money: ", money)

func add_money(amount: int) -> void:
	if amount <= 0:
		push_warning("[MoneyManager] add_money called with non-positive amount: %d" % amount)
		return
	money += amount
	money_changed.emit(money, amount)
	print("[MoneyManager] Added %d money, total: %d" % [amount, money])

func spend_money(amount: int) -> bool:
	if amount <= 0:
		push_warning("[MoneyManager] spend_money called with non-positive amount: %d" % amount)
		return false
	if money >= amount:
		money -= amount
		money_changed.emit(money, -amount)
		print("[MoneyManager] Spent %d money, remaining: %d" % [amount, money])
		return true
	else:
		push_warning("[MoneyManager] Not enough money: need %d, have %d" % [amount, money])
		return false

func get_money() -> int:
	return money

func set_money(amount: int) -> void:
	if amount < 0:
		push_warning("[MoneyManager] set_money called with negative amount: %d" % amount)
		amount = 0
	var delta = amount - money
	money = amount
	money_changed.emit(money, delta)
	print("[MoneyManager] Set money to %d (delta: %d)" % [money, delta])

func save_state() -> Dictionary:
	return {"money": money}

func load_state(data: Dictionary) -> void:
	money = data.get("money", 500)
	print("[MoneyManager] Loaded money: %d" % money)
