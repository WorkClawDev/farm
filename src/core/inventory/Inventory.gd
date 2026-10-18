extends Node

## Inventory - 背包系统
## 管理玩家物品存储、堆叠、移动等操作

signal inventory_changed()
signal slot_changed(index: int)
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full()

# 背包配置
const MAX_SLOTS: int = 36        # 最大格子数
const MAX_STACK: int = 999       # 最大堆叠数
const HOTBAR_SIZE: int = 9       # 快捷栏大小

# 背包槽位数据
class InventorySlot extends RefCounted:
	var item_id: String = ""
	var quantity: int = 0

	func is_empty() -> bool:
		return item_id == "" or quantity <= 0

	func clear() -> void:
		item_id = ""
		quantity = 0

	func _to_string() -> String:
		if is_empty():
			return "[Empty]"
		return "[%s x%d]" % [item_id, quantity]

# 背包数据
var _slots: Array[InventorySlot] = []
var _selected_hotbar_index: int = 0

# 手上拿的是什么（BUG-15）：Player/ToolManager 每个场景都会重建，所以放在这个常驻 autoload 里。
# 值是 ToolManager.ToolType 的整数；0 (NONE) 表示收起工具、手持快捷栏选中的物品。
const DEFAULT_EQUIPPED_TOOL := 1  # ToolManager.ToolType.HOE
var _equipped_tool: int = DEFAULT_EQUIPPED_TOOL
var _last_tool: int = DEFAULT_EQUIPPED_TOOL

# 数据库引用
var _item_database: ItemDatabase = null

func _ready() -> void:
	_initialize_slots()
	_connect_database()

func _initialize_slots() -> void:
	_slots.clear()
	for i in MAX_SLOTS:
		_slots.append(InventorySlot.new())

func _connect_database() -> void:
	# 等待 ItemDatabase 加载完成
	_item_database = get_node_or_null("/root/ItemDatabase")
	if _item_database == null:
		# 创建 ItemDatabase 实例
		_item_database = get_node_or_null("/root/ItemDatabase")
		

## 获取物品数据库
func get_item_database() -> ItemDatabase:
	return _item_database

## 添加物品到背包
func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false

	if _item_database and not _item_database.has_item(item_id):
		push_warning("[Inventory] Unknown item: " + item_id)
		return false

	var remaining := quantity

	# 首先尝试堆叠到现有槽位
	for slot in _slots:
		if slot.item_id == item_id and slot.quantity < MAX_STACK:
			var space := MAX_STACK - slot.quantity
			var to_add := mini(space, remaining)
			slot.quantity += to_add
			remaining -= to_add

			if remaining <= 0:
				_emit_slot_changes()
				_emit_item_added(item_id, quantity)
				return true

	# 寻找空槽位
	if remaining > 0:
		for i in _slots.size():
			var slot := _slots[i]
			if slot.is_empty():
				slot.item_id = item_id
				slot.quantity = mini(MAX_STACK, remaining)
				remaining -= slot.quantity

				if remaining <= 0:
					_emit_slot_changes()
					_emit_item_added(item_id, quantity)
					return true

	# 没有足够空间
	if remaining > 0:
		_emit_slot_changes()
		inventory_full.emit()
		var added := quantity - remaining
		if added > 0:
			_emit_item_added(item_id, added)
		push_warning("[Inventory] Not enough space for %d %s, added %d" % [quantity, item_id, added])
		return false

	return true

## 检查物品能否完整放入背包，不产生部分写入。
func can_add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if _item_database and not _item_database.has_item(item_id):
		return false
	var capacity := 0
	for slot in _slots:
		if slot.is_empty():
			capacity += MAX_STACK
		elif slot.item_id == item_id:
			capacity += MAX_STACK - slot.quantity
		if capacity >= quantity:
			return true
	return false

## 移除物品
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false

	var remaining := quantity

	# 从后往前移除（保护快捷栏物品）
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if slot.item_id == item_id:
			var to_remove := mini(slot.quantity, remaining)
			slot.quantity -= to_remove
			remaining -= to_remove

			if slot.quantity <= 0:
				slot.clear()

			if remaining <= 0:
				_emit_slot_changes()
				item_removed.emit(item_id, quantity)
				return true

	# 没有足够的物品
	if remaining > 0:
		_emit_slot_changes()
		var removed := quantity - remaining
		if removed > 0:
			item_removed.emit(item_id, removed)
		push_warning("[Inventory] Not enough %s to remove, removed %d" % [item_id, removed])
		return false

	return true

## 检查是否有足够物品
func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

## 获取物品数量
func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total

func get_all_item_ids() -> Array[String]:
	var result: Array[String] = []
	for slot in _slots:
		if not slot.is_empty() and slot.item_id not in result:
			result.append(slot.item_id)
	return result

## 获取槽位信息
func get_slot(index: int) -> InventorySlot:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]

## 设置槽位内容（用于拖拽操作）
func set_slot(index: int, item_id: String, quantity: int) -> bool:
	if index < 0 or index >= _slots.size():
		return false

	_slots[index].item_id = item_id
	_slots[index].quantity = quantity
	slot_changed.emit(index)
	inventory_changed.emit()
	return true

## 交换两个槽位（拖拽操作）
func swap_slots(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= _slots.size():
		return false
	if to_index < 0 or to_index >= _slots.size():
		return false

	var temp_item := _slots[from_index].item_id
	var temp_quantity := _slots[from_index].quantity

	_slots[from_index].item_id = _slots[to_index].item_id
	_slots[from_index].quantity = _slots[to_index].quantity

	_slots[to_index].item_id = temp_item
	_slots[to_index].quantity = temp_quantity

	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()
	return true

## 合并槽位（拖拽堆叠）
func merge_slots(from_index: int, to_index: int) -> int:
	if from_index < 0 or from_index >= _slots.size():
		return 0
	if to_index < 0 or to_index >= _slots.size():
		return 0

	var from_slot := _slots[from_index]
	var to_slot := _slots[to_index]

	# 必须是相同物品
	if from_slot.item_id != to_slot.item_id:
		return 0

	if from_slot.is_empty():
		return 0

	var space := MAX_STACK - to_slot.quantity
	if space <= 0:
		return 0

	var to_move := mini(space, from_slot.quantity)
	to_slot.quantity += to_move
	from_slot.quantity -= to_move

	if from_slot.quantity <= 0:
		from_slot.clear()

	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()
	return to_move

## 分割槽位（Shift+拖拽分一半）
func split_slot(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= _slots.size():
		return false
	if to_index < 0 or to_index >= _slots.size():
		return false

	var from_slot := _slots[from_index]
	var to_slot := _slots[to_index]

	if from_slot.is_empty():
		return false

	# 目标槽位必须为空
	if not to_slot.is_empty():
		return false

	var half := from_slot.quantity / 2
	if half <= 0:
		return false

	to_slot.item_id = from_slot.item_id
	to_slot.quantity = half
	from_slot.quantity -= half

	slot_changed.emit(from_index)
	slot_changed.emit(to_index)
	inventory_changed.emit()
	return true

## 清空背包
func clear_inventory() -> void:
	for slot in _slots:
		slot.clear()
	_emit_slot_changes()
	inventory_changed.emit()

func reset_with_starter_items() -> void:
	clear_inventory()
	_selected_hotbar_index = 0
	_equipped_tool = DEFAULT_EQUIPPED_TOOL
	_last_tool = DEFAULT_EQUIPPED_TOOL
	add_item("turnip_seed", 15)

## 获取空槽位数量
func get_empty_slot_count() -> int:
	var count := 0
	for slot in _slots:
		if slot.is_empty():
			count += 1
	return count

## 获取快捷栏选中索引
func get_selected_hotbar_index() -> int:
	return _selected_hotbar_index

## 设置快捷栏选中
func set_selected_hotbar_index(index: int) -> void:
	if index >= 0 and index < HOTBAR_SIZE:
		_selected_hotbar_index = index
		slot_changed.emit(index)

## 当前装备的工具（ToolManager.ToolType 整数，0 = 手持快捷栏物品）
func get_equipped_tool() -> int:
	return _equipped_tool

## 最近一次拿的工具（从手持物品按 Q/R 时回到它）
func get_last_tool() -> int:
	return _last_tool

## ToolManager 装备/收起工具时调用，跨场景保留。
func set_equipped_tool(tool_type: int, last_tool: int) -> void:
	_equipped_tool = maxi(tool_type, 0)
	if last_tool > 0:
		_last_tool = last_tool

## 获取选中的物品ID
func get_selected_item_id() -> String:
	if _selected_hotbar_index < _slots.size():
		return _slots[_selected_hotbar_index].item_id
	return ""

## 获取背包数据（用于存档）
func get_save_data() -> Array:
	var data := []
	for slot in _slots:
		data.append({
			"item_id": slot.item_id,
			"quantity": slot.quantity
		})
	return data

func save_state() -> Dictionary:
	return {
		"slots": get_save_data(),
		"selected_hotbar_index": _selected_hotbar_index,
		"equipped_tool": _equipped_tool,
		"last_tool": _last_tool,
	}

## 加载背包数据（用于读档）
func load_save_data(data: Array) -> void:
	_initialize_slots()
	for i in mini(data.size(), _slots.size()):
		var slot_data: Dictionary = data[i]
		_slots[i].item_id = slot_data.get("item_id", "")
		_slots[i].quantity = slot_data.get("quantity", 0)
	_emit_slot_changes()
	inventory_changed.emit()

func load_state(data: Dictionary) -> void:
	load_save_data(data.get("slots", []))
	set_selected_hotbar_index(int(data.get("selected_hotbar_index", 0)))
	set_equipped_tool(int(data.get("equipped_tool", DEFAULT_EQUIPPED_TOOL)),
		int(data.get("last_tool", DEFAULT_EQUIPPED_TOOL)))

## 发射槽位变化信号
func _emit_slot_changes() -> void:
	for i in _slots.size():
		slot_changed.emit(i)
	inventory_changed.emit()


func _emit_item_added(item_id: String, quantity: int) -> void:
	item_added.emit(item_id, quantity)
	if EventBus and EventBus.inventory:
		EventBus.inventory.item_added.emit(item_id, quantity)

## 获取物品名称
func get_item_name(item_id: String) -> String:
	if _item_database:
		var item := _item_database.get_item(item_id)
		if item:
			return item.name
	return item_id

## 获取物品描述
func get_item_description(item_id: String) -> String:
	if _item_database:
		var item := _item_database.get_item(item_id)
		if item:
			return item.description
	return ""
