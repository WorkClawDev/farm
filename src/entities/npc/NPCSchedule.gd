class_name NPCSchedule
extends RefCounted

## NPCSchedule - NPC 日程管理组件
## 管理按时间表的移动、不同地点活动、睡觉/工作/休闲状态

# 信号
signal schedule_changed(new_activity: Dictionary)
signal destination_reached(location_id: String)
signal activity_changed(activity_type: String)

# 活动类型枚举
enum ActivityType {
	SLEEP,      # 睡觉
	WORK,       # 工作
	LEISURE,    # 休闲
	EAT,        # 吃饭
	SOCIAL,     # 社交
	SHOPPING,   # 购物
	TRAVEL,     # 移动中
	IDLE        # 空闲
}

# 位置类型
enum LocationType {
	HOME,       # 家
	SHOP,       # 商店
	FARM,       # 农场
	PLAZA,      # 广场
	TAVERN,     # 酒馆
	CHURCH,     # 教堂
	BEACH,      # 海滩
	FOREST,     # 森林
	MINE,       # 矿洞
	GENERIC     # 通用位置
}

# 日程项结构
class ScheduleEntry:
	var start_time: float        # 开始时间 (0.0 - 24.0)
	var end_time: float          # 结束时间
	var activity: int            # ActivityType
	var location_id: String      # 地点ID
	var location_position: Vector2  # 目标位置
	var facing_direction: int    # 面向方向
	var dialog_override: String  # 对话覆盖
	var conditions: Dictionary   # 条件 (天气、季节等)

	func _init(data: Dictionary = {}) -> void:
		start_time = data.get("start_time", 6.0)
		end_time = data.get("end_time", 22.0)
		activity = data.get("activity", NPCSchedule.ActivityType.IDLE)
		location_id = data.get("location_id", "")
		var location_data = data.get("location_position", Vector2.ZERO)
		location_position = location_data if location_data is Vector2 else Vector2(location_data.get("x", 0.0), location_data.get("y", 0.0))
		facing_direction = data.get("facing_direction", 0)
		dialog_override = data.get("dialog_override", "")
		conditions = data.get("conditions", {})

# NPC 配置
var npc_id: String
var npc_name: String
var default_location: String

# 日程数据
var schedule_entries: Array[ScheduleEntry] = []
var current_entry: ScheduleEntry = null
var current_activity: int = ActivityType.IDLE

# 移动状态
var is_moving: bool = false
var is_at_destination: bool = true
var current_location_id: String = ""

# 日程缓存 (按星期几分组)
var _weekday_schedules: Dictionary = {}
var _seasonal_schedules: Dictionary = {}
var _special_schedules: Dictionary = {}  # 特殊日期日程

# 基础日程 (默认日程)
var _base_schedule: Array[ScheduleEntry] = []


func _init(npc_data: Dictionary = {}) -> void:
	npc_id = npc_data.get("id", "unknown")
	npc_name = npc_data.get("name", "Unknown NPC")
	default_location = npc_data.get("default_location", "home")
	_load_schedule_from_data(npc_data.get("schedule", []))


## 从数据加载日程
func _load_schedule_from_data(schedule_data: Array) -> void:
	schedule_entries.clear()

	for entry_data in schedule_data:
		var entry := ScheduleEntry.new(entry_data)
		schedule_entries.append(entry)

	# 按开始时间排序
	_sort_schedule()

	if schedule_entries.is_empty():
		_create_default_schedule()


## 创建默认日程
func _create_default_schedule() -> void:
	# 基础日程：早上在家 -> 白天工作 -> 晚上回家睡觉
	schedule_entries = [
		ScheduleEntry.new({
			"start_time": 6.0,
			"end_time": 8.0,
			"activity": ActivityType.IDLE,
			"location_id": default_location + "_home"
		}),
		ScheduleEntry.new({
			"start_time": 8.0,
			"end_time": 12.0,
			"activity": ActivityType.WORK,
			"location_id": default_location + "_work"
		}),
		ScheduleEntry.new({
			"start_time": 12.0,
			"end_time": 13.0,
			"activity": ActivityType.EAT,
			"location_id": "plaza"
		}),
		ScheduleEntry.new({
			"start_time": 13.0,
			"end_time": 18.0,
			"activity": ActivityType.WORK,
			"location_id": default_location + "_work"
		}),
		ScheduleEntry.new({
			"start_time": 18.0,
			"end_time": 21.0,
			"activity": ActivityType.LEISURE,
			"location_id": "plaza"
		}),
		ScheduleEntry.new({
			"start_time": 21.0,
			"end_time": 24.0,
			"activity": ActivityType.IDLE,
			"location_id": default_location + "_home"
		}),
		ScheduleEntry.new({
			"start_time": 0.0,
			"end_time": 6.0,
			"activity": ActivityType.SLEEP,
			"location_id": default_location + "_home"
		})
	]


## 排序日程
func _sort_schedule() -> void:
	schedule_entries.sort_custom(func(a: ScheduleEntry, b: ScheduleEntry) -> bool:
		return a.start_time < b.start_time
	)


## 更新日程状态 (每帧调用)
func update(current_time: float, current_day: int, current_season: int) -> void:
	var new_entry := get_entry_for_time(current_time, current_day, current_season)

	if new_entry != current_entry:
		current_entry = new_entry
		current_activity = current_entry.activity
		is_at_destination = false

		schedule_changed.emit({
			"activity": current_activity,
			"location_id": current_entry.location_id,
			"position": current_entry.location_position
		})


## 获取指定时间的日程项
func get_entry_for_time(time: float, day: int = 1, season: int = 0) -> ScheduleEntry:
	# 检查特殊日程
	var special_entry := _get_special_entry(time, day, season)
	if special_entry:
		return special_entry

	# 检查星期日程 (day 1-7 循环)
	var weekday: int = ((day - 1) % 7) + 1
	if _weekday_schedules.has(weekday):
		var entry := _find_entry_in_list(time, _weekday_schedules[weekday])
		if entry:
			return entry

	# 检查季节日程
	if _seasonal_schedules.has(season):
		var entry := _find_entry_in_list(time, _seasonal_schedules[season])
		if entry:
			return entry

	# 使用基础日程
	return _find_entry_in_list(time, schedule_entries)


## 获取特殊日程项
func _get_special_entry(time: float, day: int, season: int) -> ScheduleEntry:
	# 检查节日、雨天等特殊条件
	for entry in schedule_entries:
		if not entry.conditions.is_empty():
			if _check_special_conditions(entry.conditions, day, season, time):
				return entry
	return null


## 检查特殊条件
func _check_special_conditions(conditions: Dictionary, day: int, season: int, time: float) -> bool:
	# 检查天气条件
	if conditions.has("weather"):
		var weather_system := _get_weather_system()
		if weather_system == null:
			return false  # WeatherSystem 未就绪，跳过

		var required_weather = conditions.get("weather", "")
		var current_weather: String = weather_system.get_current_weather()
		var weather_match := false

		# 支持数组：满足其中一个天气即可
		if required_weather is Array:
			weather_match = current_weather in required_weather
		elif str(required_weather).begins_with("not_"):
			# 支持 "not_rain" 等反向条件
			var excluded := str(required_weather).substr(4)
			weather_match = current_weather != excluded
		else:
			weather_match = required_weather == current_weather

		if not weather_match:
			return false

	# 检查雨季/雪季特殊条件
	if conditions.has("bad_weather"):
		var weather_system := _get_weather_system()
		if weather_system != null:
			var bad_weather: bool = weather_system.is_bad_weather()
			if not bad_weather:
				return false

	# 检查季节条件
	if conditions.has("season"):
		var required_seasons: Array = conditions.get("season", [])
		if not TimeManager.SEASONS[season] in required_seasons:
			return false

	# 检查特定日期
	if conditions.has("specific_day"):
		if day != conditions.get("specific_day"):
			return false

	# 检查星期几
	if conditions.has("weekday"):
		var weekday: int = ((day - 1) % 7) + 1
		if weekday != conditions.get("weekday"):
			return false

	return true


## 获取 WeatherSystem 引用（安全获取）
func _get_weather_system() -> Node:
	# NPCSchedule is RefCounted, not Node, so use get_tree() if available
	# Otherwise require explicit injection via set_weather_system()
	if _weather_system != null:
		return _weather_system
	# Try engine singleton approach
	var tree := Engine.get_main_loop()
	if tree and tree.has_meta("weather_system"):
		return tree.get_meta("weather_system")
	return null


## 设置 WeatherSystem 引用（用于 RefCounted 环境）
var _weather_system: Node = null

func set_weather_system(system: Node) -> void:
	_weather_system = system


## 在列表中查找日程项
func _find_entry_in_list(time: float, entries: Array) -> ScheduleEntry:
	for entry in entries:
		if entry.start_time <= time and time < entry.end_time:
			return entry

	# 处理跨午夜的时间段 (如 22:00 - 2:00)
	for entry in entries:
		if entry.start_time > entry.end_time:  # 跨午夜
			if time >= entry.start_time or time < entry.end_time:
				return entry

	return null


## 获取当前活动类型名称
func get_activity_name() -> String:
	match current_activity:
		ActivityType.SLEEP:
			return "sleep"
		ActivityType.WORK:
			return "work"
		ActivityType.LEISURE:
			return "leisure"
		ActivityType.EAT:
			return "eat"
		ActivityType.SOCIAL:
			return "social"
		ActivityType.SHOPPING:
			return "shopping"
		ActivityType.TRAVEL:
			return "travel"
		_:
			return "idle"


## 获取下一个日程项
func get_next_entry(current_time: float) -> ScheduleEntry:
	for entry in schedule_entries:
		if entry.start_time > current_time:
			return entry

	# 如果没有下一个，返回第一个 (第二天)
	if not schedule_entries.is_empty():
		return schedule_entries[0]

	return null


## 添加日程项
func add_entry(entry_data: Dictionary) -> void:
	var entry := ScheduleEntry.new(entry_data)
	schedule_entries.append(entry)
	_sort_schedule()


## 移除日程项
func remove_entry(start_time: float) -> bool:
	for i in range(schedule_entries.size()):
		if schedule_entries[i].start_time == start_time:
			schedule_entries.remove_at(i)
			return true
	return false


## 设置星期日程
func set_weekday_schedule(weekday: int, entries: Array) -> void:
	_weekday_schedules[weekday] = entries


## 设置季节日程
func set_seasonal_schedule(season: int, entries: Array) -> void:
	_seasonal_schedules[season] = entries


## 设置特殊日期日程
func set_special_schedule(date_key: String, entries: Array) -> void:
	_special_schedules[date_key] = entries


## 检查是否应该移动
func should_move_to_destination() -> bool:
	return current_entry != null and not is_at_destination


## 到达目的地
func arrived_at_destination() -> void:
	is_at_destination = true
	is_moving = false
	if current_entry:
		destination_reached.emit(current_entry.location_id)


## 开始移动
func start_moving() -> void:
	is_moving = true
	activity_changed.emit("travel")


## 获取当前目标位置
func get_destination() -> Vector2:
	if current_entry:
		return current_entry.location_position
	return Vector2.ZERO


## 获取当前目标地点ID
func get_destination_id() -> String:
	if current_entry:
		return current_entry.location_id
	return ""


## 获取当前对话覆盖
func get_dialog_override() -> String:
	if current_entry and not current_entry.dialog_override.is_empty():
		return current_entry.dialog_override
	return ""


## 检查当前是否可交互
func is_interactable() -> bool:
	# 睡觉时不可交互
	if current_activity == ActivityType.SLEEP:
		return false
	# 移动中不能交互
	if is_moving:
		return false
	return true


## 检查是否在睡觉
func is_sleeping() -> bool:
	return current_activity == ActivityType.SLEEP


## 检查是否在工作
func is_working() -> bool:
	return current_activity == ActivityType.WORK


## 序列化日程数据
func serialize() -> Dictionary:
	var entries_data: Array = []
	for entry in schedule_entries:
		entries_data.append({
			"start_time": entry.start_time,
			"end_time": entry.end_time,
			"activity": entry.activity,
			"location_id": entry.location_id,
			"location_position": {"x": entry.location_position.x, "y": entry.location_position.y},
			"facing_direction": entry.facing_direction,
			"dialog_override": entry.dialog_override,
			"conditions": entry.conditions
		})

	return {
		"npc_id": npc_id,
		"current_activity": current_activity,
		"current_location": current_location_id,
		"schedule_entries": entries_data
	}


## 从序列化数据恢复
func deserialize(data: Dictionary) -> void:
	current_activity = data.get("current_activity", ActivityType.IDLE)
	current_location_id = data.get("current_location", "")

	var entries_data: Array = data.get("schedule_entries", [])
	schedule_entries.clear()
	for entry_data in entries_data:
		var pos_data: Dictionary = entry_data.get("location_position", {"x": 0, "y": 0})
		entry_data["location_position"] = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
		schedule_entries.append(ScheduleEntry.new(entry_data))
