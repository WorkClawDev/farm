extends Node

## HouseUpgradeSystem - 房屋升级系统
## 管理玩家房屋的升级和家具放置

# 房屋等级
enum HouseLevel {
	LEVEL_1,  # 初始小屋
	LEVEL_2,  # 中等房屋
	LEVEL_3   # 大房子
}

# 升级配置
const UPGRADE_CONFIG = {
	HouseLevel.LEVEL_1: {
		"name": "初始小屋",
		"description": "简陋的小木屋，空间有限",
		"upgrade_cost": 10000,
		"room_count": 2,
		"furniture_slots": 6,
		"storage_slots": 12,
		"kitchen_available": false,
		"bedroom_count": 1
	},
	HouseLevel.LEVEL_2: {
		"name": "舒适房屋",
		"description": "宽敞的房屋，有厨房和客厅",
		"upgrade_cost": 50000,
		"room_count": 4,
		"furniture_slots": 15,
		"storage_slots": 24,
		"kitchen_available": true,
		"bedroom_count": 2
	},
	HouseLevel.LEVEL_3: {
		"name": "豪华庄园",
		"description": "豪华的大房子，设施齐全",
		"upgrade_cost": 100000,
		"room_count": 6,
		"furniture_slots": 30,
		"storage_slots": 48,
		"kitchen_available": true,
		"bedroom_count": 3
	}
}

# 信号
signal house_upgraded(new_level: int, level_name: String)
signal furniture_placed(furniture_id: String, position: Vector2i)
signal furniture_removed(furniture_id: String)
signal storage_expanded(new_slots: int)

# 当前房屋状态
var current_level: HouseLevel = HouseLevel.LEVEL_1
var furniture: Array[Dictionary] = []  # 家具列表
var placed_furniture: Dictionary = {}  # 已放置的家具 {slot_id: furniture_data}

func _ready() -> void:
	print("[HouseUpgradeSystem] Initialized")

## 获取当前房屋等级
func get_current_level() -> HouseLevel:
	return current_level

## 鍏煎 API锛氳幏鍙栨埧灞嬬瓑绾?
func get_house_level() -> HouseLevel:
	return current_level

## 鍏煎 API锛氳幏鍙栧凡瑙ｉ攣鎴块棿
func get_unlocked_rooms() -> Array[String]:
	var rooms: Array[String] = ["main"]
	if current_level >= HouseLevel.LEVEL_2:
		rooms.append("kitchen")
	if current_level >= HouseLevel.LEVEL_3:
		rooms.append("bedroom")
	rooms.append("storage")
	return rooms

## 获取当前等级配置
func get_current_config() -> Dictionary:
	return UPGRADE_CONFIG.get(current_level, {})

## 获取下一级等级
func get_next_level() -> HouseLevel:
	match current_level:
		HouseLevel.LEVEL_1:
			return HouseLevel.LEVEL_2
		HouseLevel.LEVEL_2:
			return HouseLevel.LEVEL_3
		_:
			return HouseLevel.LEVEL_3  # 已是最高级

## 检查是否可以升级
func can_upgrade() -> bool:
	# 检查是否已是最高级
	if current_level == HouseLevel.LEVEL_3:
		return false
	
	# 检查金钱是否足够
	var next_level = get_next_level()
	var cost = UPGRADE_CONFIG[next_level].upgrade_cost
	
	var money_system = get_node_or_null("/root/MoneySystem")
	if money_system:
		return money_system.get_money() >= cost
	
	return false

## 获取升级费用
func get_upgrade_cost() -> int:
	var next_level = get_next_level()
	return UPGRADE_CONFIG.get(next_level, {}).get("upgrade_cost", 0)

## 升级房屋
func upgrade_house() -> bool:
	if not can_upgrade():
		print("[HouseUpgradeSystem] Cannot upgrade house")
		return false
	
	var next_level = get_next_level()
	var cost = get_upgrade_cost()
	
	# 扣除金钱
	var money_system = get_node_or_null("/root/MoneySystem")
	if money_system:
		if not money_system.spend_money(cost):
			return false
	
	# 更新等级
	var old_level = current_level
	current_level = next_level
	
	# 发射信号
	var config = get_current_config()
	house_upgraded.emit(current_level, config.name)
	
	# 扩展储物空间
	storage_expanded.emit(config.storage_slots)
	
	print("[HouseUpgradeSystem] House upgraded to: ", config.name)
	return true

## 获取家具槽位数量
func get_furniture_slot_count() -> int:
	return UPGRADE_CONFIG[current_level].furniture_slots

## 获取储物槽位数量
func get_storage_slot_count() -> int:
	return UPGRADE_CONFIG[current_level].storage_slots

## 检查是否有厨房
func has_kitchen() -> bool:
	return UPGRADE_CONFIG[current_level].kitchen_available

## 放置家具
func place_furniture(furniture_id: String, slot_id: String, position: Vector2i) -> bool:
	# 检查槽位是否存在
	var max_slots = get_furniture_slot_count()
	if placed_furniture.size() >= max_slots:
		print("[HouseUpgradeSystem] No available furniture slots")
		return false
	
	# 检查槽位是否已被占用
	if placed_furniture.has(slot_id):
		print("[HouseUpgradeSystem] Slot already occupied: ", slot_id)
		return false
	
	# 放置家具
	placed_furniture[slot_id] = {
		"furniture_id": furniture_id,
		"position": position,
		"slot_id": slot_id
	}
	
	furniture_placed.emit(furniture_id, position)
	print("[HouseUpgradeSystem] Placed furniture: ", furniture_id, " at slot: ", slot_id)
	return true

## 移除家具
func remove_furniture(slot_id: String) -> bool:
	if not placed_furniture.has(slot_id):
		return false
	
	var furniture_data = placed_furniture[slot_id]
	placed_furniture.erase(slot_id)
	
	furniture_removed.emit(furniture_data.furniture_id)
	print("[HouseUpgradeSystem] Removed furniture from slot: ", slot_id)
	return true

## 获取已放置的家具
func get_placed_furniture() -> Dictionary:
	return placed_furniture.duplicate()

## 获取房屋等级名称
func get_level_name() -> String:
	return UPGRADE_CONFIG[current_level].name

## 获取房屋描述
func get_level_description() -> String:
	return UPGRADE_CONFIG[current_level].description

## 获取房间数量
func get_room_count() -> int:
	return UPGRADE_CONFIG[current_level].room_count

## 保存状态
func save_state() -> Dictionary:
	return {
		"current_level": current_level,
		"placed_furniture": placed_furniture.duplicate()
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	if data.has("current_level"):
		current_level = data.current_level
	
	if data.has("placed_furniture"):
		placed_furniture = data.placed_furniture.duplicate()
	
	print("[HouseUpgradeSystem] Loaded state, level: ", current_level)
