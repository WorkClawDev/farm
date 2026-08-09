extends Node

## FishingSystem - 钓鱼全局管理系统
## 跟踪钓鱼统计、鱼类图鉴、钓鱼成就
## Autoload: /root/FishingSystem

# 信号
signal fish_caught(fish_id: String, fish_data: Dictionary, location: String)
signal fishing_session_started(location: String)
signal fishing_session_ended(location: String, fish_count: int)

# 钓鱼统计
var total_fish_caught: int = 0
var total_fish_caught_by_location: Dictionary = {}
var fish_caught_history: Array[Dictionary] = []
var current_session_fish_count: int = 0
var current_session_location: String = ""

func _ready() -> void:
	print("[FishingSystem] Initialized")


## 开始钓鱼会话
func start_session(location: String) -> void:
	current_session_location = location
	current_session_fish_count = 0
	fishing_session_started.emit(location)
	print("[FishingSystem] Fishing session started at: ", location)


## 结束钓鱼会话
func end_session() -> void:
	if current_session_location.is_empty():
		return
	fishing_session_ended.emit(current_session_location, current_session_fish_count)
	print("[FishingSystem] Fishing session ended at: ", current_session_location, ", fish caught: ", current_session_fish_count)
	current_session_location = ""
	current_session_fish_count = 0


## 记录钓到的鱼
func record_catch(fish_id: String, fish_data: Dictionary, location: String) -> void:
	total_fish_caught += 1
	current_session_fish_count += 1
	
	# 按地点统计
	if not total_fish_caught_by_location.has(location):
		total_fish_caught_by_location[location] = 0
	total_fish_caught_by_location[location] += 1
	
	# 记录历史
	var record := {
		"fish_id": fish_id,
		"fish_name": fish_data.get("name", fish_id),
		"location": location,
		"size": fish_data.get("size", 0),
		"timestamp": Time.get_datetime_string_from_system()
	}
	fish_caught_history.append(record)
	
	fish_caught.emit(fish_id, fish_data, location)
	
	# 检查成就
	_check_fishing_achievements(fish_id)
	
	print("[FishingSystem] Caught: ", fish_data.get("name", fish_id), " at ", location)


## 检查钓鱼相关成就
func _check_fishing_achievements(fish_id: String) -> void:
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	if not achievement_system:
		return
	
	# 第一次钓到鱼
	if total_fish_caught == 1:
		achievement_system.unlock_achievement("first_fish")
	
	# 钓鱼达人：钓到50条鱼
	if total_fish_caught >= 50:
		achievement_system.unlock_achievement("fisherman")


## 获取总钓鱼数
func get_total_fish_caught() -> int:
	return total_fish_caught


## 获取某地点钓鱼数
func get_fish_caught_at_location(location: String) -> int:
	return total_fish_caught_by_location.get(location, 0)


## 获取钓鱼历史
func get_catch_history() -> Array[Dictionary]:
	return fish_caught_history.duplicate()


## 获取特定鱼种已钓数量
func get_catch_count_for_fish(fish_id: String) -> int:
	var count := 0
	for record in fish_caught_history:
		if record.get("fish_id") == fish_id:
			count += 1
	return count


## 检查是否已钓过某鱼
func has_caught_fish(fish_id: String) -> bool:
	for record in fish_caught_history:
		if record.get("fish_id") == fish_id:
			return true
	return false


## 获取存档数据
func save_state() -> Dictionary:
	return {
		"total_fish_caught": total_fish_caught,
		"total_fish_caught_by_location": total_fish_caught_by_location.duplicate(),
		"fish_caught_history": fish_caught_history.duplicate()
	}


## 加载存档数据
func load_state(data: Dictionary) -> void:
	total_fish_caught = maxi(0, int(data.get("total_fish_caught", 0)))

	total_fish_caught_by_location.clear()
	var locations_value: Variant = data.get("total_fish_caught_by_location", {})
	if locations_value is Dictionary:
		for raw_location in locations_value:
			total_fish_caught_by_location[str(raw_location)] = maxi(
				0,
				int(locations_value[raw_location])
			)

	fish_caught_history.clear()
	var history_value: Variant = data.get("fish_caught_history", [])
	if history_value is Array:
		for record in history_value:
			if record is Dictionary:
				fish_caught_history.append(record.duplicate(true))
	print("[FishingSystem] State loaded: total fish caught = ", total_fish_caught)


func reset() -> void:
	total_fish_caught = 0
	total_fish_caught_by_location.clear()
	fish_caught_history.clear()
	current_session_fish_count = 0
	current_session_location = ""
