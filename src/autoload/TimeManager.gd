extends Node

## TimeManager - 时间管理器
## 负责游戏内时间流逝、昼夜循环、季节系统

signal time_changed(new_time: float)
signal hour_changed(new_hour: int)
signal day_changed(new_day: int)
signal season_changed(new_season: int, season_name: String)
signal year_changed(new_year: int)
signal day_end_requested(reason: String)

# 时间配置
const REAL_SECONDS_PER_GAME_MINUTE: float = 1.0  # 现实1秒 = 游戏1分钟
const GAME_HOURS_PER_DAY: int = 20  # 游戏一天20小时 (6:00-2:00)
const DAYS_PER_SEASON: int = 28  # 每季28天
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

# 当前时间状态
var current_time: float = 6.0  # 当前时间 (0.0 - 24.0)，从早上6点开始
var current_day: int = 1  # 当前日期 (1-28)
var current_season: int = 0  # 当前季节 (0-3)
var current_year: int = 1  # 当前年份

# 控制状态
var is_paused: bool = false
var time_scale: float = 1.0

# 内部计时器
var _time_accumulator: float = 0.0

func _ready() -> void:
	print("[TimeManager] Initialized")
	print("[TimeManager] Starting time: ", _format_time(current_time))

func _process(delta: float) -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if is_paused or (game_manager and not game_manager.is_game_active):
		return
	
	_update_time(delta)

func _update_time(delta: float) -> void:
	_time_accumulator += delta * time_scale
	
	# 计算游戏时间增量
	var game_minutes_passed: float = _time_accumulator / REAL_SECONDS_PER_GAME_MINUTE
	
	if game_minutes_passed >= 1.0:
		var previous_hour: int = int(current_time)
		
		# 更新当前时间
		current_time += game_minutes_passed / 60.0
		_time_accumulator = 0.0
		
		# 检查小时变化
		var current_hour: int = int(current_time)
		if current_hour != previous_hour:
			hour_changed.emit(current_hour)
		
		# 检查是否到第二天 (2:00 AM)
		if current_time >= 26.0:  # 2:00 AM = 26:00 (6:00 + 20 hours)
			is_paused = true
			day_end_requested.emit("forced_2am")
		
		time_changed.emit(current_time)

func _advance_day() -> void:
	current_time = 6.0  # 重置到早上6点
	current_day += 1
	
	# 检查季节变化
	if current_day > DAYS_PER_SEASON:
		current_day = 1
		_advance_season()
	
	day_changed.emit(current_day)
	print("[TimeManager] Day advanced to: ", current_day, " of ", SEASONS[current_season])

func advance_to_next_day() -> void:
	_advance_day()

func reset() -> void:
	current_time = 6.0
	current_day = 1
	current_season = 0
	current_year = 1
	is_paused = false
	time_scale = 1.0
	_time_accumulator = 0.0
	time_changed.emit(current_time)
	day_changed.emit(current_day)
	season_changed.emit(current_season, SEASONS[current_season])

func _advance_season() -> void:
	current_season += 1
	
	# 检查年份变化
	if current_season >= SEASONS.size():
		current_season = 0
		current_year += 1
		year_changed.emit(current_year)
	
	season_changed.emit(current_season, SEASONS[current_season])
	print("[TimeManager] Season changed to: ", SEASONS[current_season])

func pause_time() -> void:
	is_paused = true
	print("[TimeManager] Time paused")

func resume_time() -> void:
	is_paused = false
	print("[TimeManager] Time resumed")

func set_time_scale(scale: float) -> void:
	time_scale = max(0.0, scale)
	print("[TimeManager] Time scale set to: ", time_scale)

func get_season_name() -> String:
	return SEASONS[current_season]

func get_current_day() -> int:
	return current_day

func get_current_hour() -> int:
	return int(current_time) % 24

func get_formatted_time() -> String:
	return _format_time(current_time)

func get_formatted_date() -> String:
	return "Year " + str(current_year) + ", " + SEASONS[current_season] + " " + str(current_day)

func _format_time(time: float) -> String:
	var hour: int = int(time) % 24
	var minute: int = int((time - int(time)) * 60)
	var am_pm: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour if hour <= 12 else hour - 12
	if display_hour == 0:
		display_hour = 12
	return str(display_hour) + ":" + str(minute).pad_zeros(2) + " " + am_pm

func save_state() -> Dictionary:
	return {
		"current_time": current_time,
		"current_day": current_day,
		"current_season": current_season,
		"current_year": current_year
	}

func load_state(data: Dictionary) -> void:
	current_time = data.get("current_time", 6.0)
	current_day = data.get("current_day", 1)
	current_season = data.get("current_season", 0)
	current_year = data.get("current_year", 1)
	print("[TimeManager] State loaded: ", get_formatted_date(), " ", get_formatted_time())
