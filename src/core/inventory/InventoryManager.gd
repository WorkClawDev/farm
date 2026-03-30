extends Node
class_name InventoryManager

## InventoryManager - 背包管理器
## 负责物品的添加、移除、查询

signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full
signal inventory_changed()

const MAX_INVENTORY_SLOTS: int = 36

var inventory: Array[Dictionary] = []

func _ready() -> void:
	print("[InventoryManager] Initialized")

func add_item(item_id: String, quantity: int = 1) -> bool:
	# 检查是否已有该物品
	for slot in inventory:
		if slot.get("item_id", "") == item_id:
			slot["quantity"] = slot.get("quantity", 0) + quantity
			item_added.emit(item_id, quantity)
			inventory_changed.emit()
			print("[InventoryManager] Added %dx %s to existing stack" % [quantity, item_id])
			return true
	
	# 检查是否有空槽
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		inventory_full.emit()
		print("[InventoryManager] Inventory full, cannot add %s" % item_id)
		return false
	
	inventory.append({"item_id": item_id, "quantity": quantity})
	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	print("[InventoryManager] Added %dx %s as new stack" % [quantity, item_id])
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(inventory.size()):
		var slot = inventory[i]
		if slot.get("item_id", "") == item_id:
			var current_quantity = slot.get("quantity", 0)
			if current_quantity > quantity:
				slot["quantity"] = current_quantity - quantity
				item_removed.emit(item_id, quantity)
				inventory_changed.emit()
				print("[InventoryManager] Removed %dx %s" % [quantity, item_id])
				return true
			elif current_quantity == quantity:
				inventory.remove_at(i)
				item_removed.emit(item_id, quantity)
				inventory_changed.emit()
				print("[InventoryManager] Removed all %s" % item_id)
				return true
			else:
				print("[InventoryManager] Not enough %s to remove" % item_id)
				return false
	
	print("[InventoryManager] Item %s not found in inventory" % item_id)
	return false

func has_item(item_id: String, quantity: int = 1) -> bool:
	for slot in inventory:
		if slot.get("item_id", "") == item_id:
			return slot.get("quantity", 0) >= quantity
	return false

func get_item_quantity(item_id: String) -> int:
	for slot in inventory:
		if slot.get("item_id", "") == item_id:
			return slot.get("quantity", 0)
	return 0

func get_inventory() -> Array[Dictionary]:
	return inventory

func get_all_items() -> Array:
	"""获取所有物品列表（用于UI显示）"""
	return inventory.duplicate()

func clear_inventory() -> void:
	inventory.clear()
	inventory_changed.emit()

func save_state() -> Dictionary:
	return {"inventory": inventory.duplicate(true)}

func load_state(data: Dictionary) -> void:
	inventory = data.get("inventory", []).duplicate(true)
	print("[InventoryManager] Loaded %d inventory slots" % inventory.size())
