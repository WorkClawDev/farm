extends Node

## WeatherSystem - 天气系统
## 管理每日天气生成、天气效果、应用天气影响
## Session-owned service: /root/GameSession/WeatherSystem

# 天气类型枚举
enum WeatherType {
	SUNNY = 0,
	CLOUDY = 1,
	RAINY = 2,
	STORMY = 3,
	SNOWY = 4
}

# 天气名称映射
const WEATHER_NAMES: Dictionary = {
	WeatherType.SUNNY: "sunny",
	WeatherType.CLOUDY: "cloudy",
	WeatherType.RAINY: "rainy",
	WeatherType.STORMY: "stormy",
	WeatherType.SNOWY: "snowy"
}

const WEATHER_NAMES_CN: Dictionary = {
	"sunny": "晴天",
	"cloudy": "多云",
	"rainy": "雨天",
	"stormy": "暴风雨",
	"snowy": "雪天"
}

# 天气对应的作物生长加成（与 SeasonSystem.WEATHER_GROWTH_BONUS 保持一致）
const GROWTH_BONUS: Dictionary = {
	"sunny": 1.0,
	"cloudy": 0.9,
	"rainy": 1.1,
	"stormy": 0.8,
	"snowy": 0.5
}

# 钓鱼难度加成（雨/风暴天鱼更容易上钩）
const FISHING_BONUS: Dictionary = {
	"sunny": 1.0,
	"cloudy": 1.1,
	"rainy": 1.3,
	"stormy": 1.5,
	"snowy": 1.2
}

# 信号
signal weather_changed(weather: String, weather_type: int)
signal weather_day_started(weather: String)

# 当前天气状态
var current_weather: String = "sunny"
var current_weather_type: int = WeatherType.SUNNY
var previous_weather: String = "sunny"
## 非空时跳过随机，测试用来钉住 rainy / stormy。
var forced_weather: String = ""

# 天气效果节点
var _weather_effect: Node2D = null

func _ready() -> void:
	_connect_signals()
	_initialize_weather()
	print("[WeatherSystem] Initialized with weather: ", current_weather)


func _connect_signals() -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		tm.day_changed.connect(_on_day_changed)
		print("[WeatherSystem] Connected to TimeManager.day_changed")


func _initialize_weather() -> void:
	# 初始化当天天气
	var new_weather = _generate_daily_weather()
	_set_weather(new_weather)


## 新的一天触发天气生成
func _on_day_changed(new_day: int) -> void:
	previous_weather = current_weather
	var new_weather = _generate_daily_weather()
	_set_weather(new_weather)
	weather_day_started.emit(current_weather)
	# 过夜把时钟拨到 6:00。TimeManager.reset() 也发 day_changed，但是 9:00，不能顺手浇地。
	var tm = get_node_or_null("/root/TimeManager")
	if tm and is_equal_approx(float(tm.current_time), 6.0):
		apply_day_start_watering()


func _generate_daily_weather() -> String:
	if forced_weather != "":
		return forced_weather
	# 使用 SeasonSystem 的权重来生成天气
	var ss = get_node_or_null("/root/GameSession/SeasonSystem")
	if ss and ss.has_method("generate_weather_for_season"):
		return ss.generate_weather_for_season()
	# Fallback: 使用春季默认权重
	var weights := {
		"sunny": 50, "cloudy": 25, "rainy": 25, "stormy": 0, "snowy": 0
	}
	return _weighted_random_weather(weights)


func _weighted_random_weather(weights: Dictionary) -> String:
	var total := 0
	for v in weights.values():
		total += v
	var roll := randi() % total
	var cumulative := 0
	for weather_type in weights:
		cumulative += weights[weather_type]
		if roll < cumulative:
			return weather_type
	return "sunny"


func _set_weather(weather: String) -> void:
	current_weather = weather
	current_weather_type = _weather_name_to_type(weather)
	weather_changed.emit(weather, current_weather_type)
	_apply_weather_effect()
	print("[WeatherSystem] Weather changed to: ", weather)


func set_current_weather(weather: String) -> void:
	_set_weather(weather)


func is_rain_or_storm() -> bool:
	return current_weather == "rainy" or current_weather == "stormy"


## 当天是雨或暴风雨时浇地。晴天、多云、雪天不动。
func apply_day_start_watering() -> void:
	if not is_rain_or_storm():
		return
	var farm = get_node_or_null("/root/FarmState")
	if farm and farm.has_method("water_from_rain"):
		farm.water_from_rain()


func _weather_name_to_type(name: String) -> int:
	match name:
		"sunny": return WeatherType.SUNNY
		"cloudy": return WeatherType.CLOUDY
		"rainy": return WeatherType.RAINY
		"stormy": return WeatherType.STORMY
		"snowy": return WeatherType.SNOWY
		_: return WeatherType.SUNNY


## 应用天气视觉效果
func _apply_weather_effect() -> void:
	# 移除旧效果
	if _weather_effect:
		_weather_effect.queue_free()
		_weather_effect = null
	
	# 延迟创建新效果
	_create_weather_effect.call_deferred()


func _create_weather_effect() -> void:
	if _should_skip_visual_effects():
		return

	var effect_node = _create_effect_node()
	if effect_node:
		var root = get_tree().current_scene
		if root:
			root.add_child(effect_node)
			_weather_effect = effect_node


func _should_skip_visual_effects() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true

	var scene_path: String = scene.scene_file_path
	if scene_path.begins_with("res://addons/gut/"):
		return true

	var scene_script := scene.get_script() as Script
	if scene_script and scene_script.resource_path.begins_with("res://addons/gut/"):
		return true

	return scene.name.begins_with("Gut")


func _create_effect_node() -> Node2D:
	# 根据天气类型创建不同的视觉效果
	match current_weather:
		"rainy":
			return _create_rain_effect()
		"stormy":
			return _create_storm_effect()
		"snowy":
			return _create_snow_effect()
		"cloudy":
			return _create_cloud_overlay()
	return null


func _create_rain_effect() -> Node2D:
	# 雨滴粒子效果
	var node := Node2D.new()
	node.name = "RainEffect"
	
	# 使用 ParticleEmitter2D 或简单 Timer 驱动的效果
	var timer := Timer.new()
	timer.name = "RainTimer"
	timer.wait_time = 0.05
	timer.autostart = true
	node.add_child(timer)
	
	return node


func _create_storm_effect() -> Node2D:
	var node := Node2D.new()
	node.name = "StormEffect"
	
	# 风暴效果：雨 + 闪电
	var timer := Timer.new()
	timer.name = "StormTimer"
	timer.wait_time = 0.05
	timer.autostart = true
	node.add_child(timer)
	
	# 闪电定时器
	var lightning := Timer.new()
	lightning.name = "LightningTimer"
	lightning.wait_time = 3.0 + randf() * 5.0
	lightning.autostart = true
	node.add_child(lightning)
	
	return node


func _create_snow_effect() -> Node2D:
	var node := Node2D.new()
	node.name = "SnowEffect"
	
	var timer := Timer.new()
	timer.name = "SnowTimer"
	timer.wait_time = 0.1
	timer.autostart = true
	node.add_child(timer)
	
	return node


func _create_cloud_overlay() -> Node2D:
	# 多云只是色调变化，不需要粒子
	return null


## 获取当前天气
func get_current_weather() -> String:
	return current_weather


## 获取当前天气类型（枚举）
func get_current_weather_type() -> int:
	return current_weather_type


## 获取天气中文名
func get_weather_name_cn() -> String:
	return WEATHER_NAMES_CN.get(current_weather, "晴天")


## 获取作物生长加成
func get_growth_bonus() -> float:
	return GROWTH_BONUS.get(current_weather, 1.0)


## 获取钓鱼难度加成
func get_fishing_bonus() -> float:
	return FISHING_BONUS.get(current_weather, 1.0)


## 检查是否是坏天气（影响户外活动）
func is_bad_weather() -> bool:
	return current_weather in ["rainy", "stormy", "snowy"]


## 检查是否是户外活动适宜天气
func is_good_weather_for_outdoor() -> bool:
	return current_weather in ["sunny", "cloudy"]


## 获取存档数据
func save_state() -> Dictionary:
	return {
		"current_weather": current_weather,
		"current_weather_type": current_weather_type,
		"previous_weather": previous_weather
	}


## 加载存档数据
func load_state(data: Dictionary) -> void:
	var saved_weather = data.get("current_weather", "sunny")
	_set_weather(saved_weather)
	previous_weather = data.get("previous_weather", "sunny")
	print("[WeatherSystem] State loaded: ", current_weather)


func reset() -> void:
	forced_weather = ""
	previous_weather = "sunny"
	_set_weather("sunny")
