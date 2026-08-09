extends Node

## SeasonSystem - 季节系统
## 管理季节变化、作物季节适配、天气影响

# 季节枚举
enum Season { SPRING = 0, SUMMER = 1, FALL = 2, WINTER = 3 }

# 季节名称映射
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
const SEASON_NAMES_CN: Array[String] = ["春", "夏", "秋", "冬"]

# 季节颜色主题
const SEASON_COLORS: Dictionary = {
	Season.SPRING: Color(0.6, 0.8, 0.5),    # 嫩绿色
	Season.SUMMER: Color(0.9, 0.85, 0.4),   # 明亮黄色
	Season.FALL: Color(0.85, 0.5, 0.2),     # 橙色
	Season.WINTER: Color(0.7, 0.85, 0.95)   # 淡蓝色
}

# 季节图标路径
const SEASON_ICONS: Dictionary = {
	Season.SPRING: "res://assets/sprites/ui/icons/season_spring.png",
	Season.SUMMER: "res://assets/sprites/ui/icons/season_summer.png",
	Season.FALL: "res://assets/sprites/ui/icons/season_fall.png",
	Season.WINTER: "res://assets/sprites/ui/icons/season_winter.png"
}

# 信号
signal season_changed(new_season: int, season_name: String)
signal season_day_started(season: int, day: int)
signal weather_changed_for_season(weather_type: String, season: int)

# 作物季节适配信号
signal crop_out_of_season(crop_id: String, position: Vector2)
signal crop_season_bonus(crop_id: String, bonus_multiplier: float)

# 当前状态
var current_season: int = Season.SPRING
var previous_season: int = -1

# 天气影响配置
const WEATHER_GROWTH_BONUS: Dictionary = {
	"sunny": 1.0,
	"cloudy": 0.9,
	"rainy": 1.1,      # 雨天有额外生长加成
	"stormy": 0.8,
	"snowy": 0.5       # 雪天生长减缓
}

# 季节特定天气概率
const SEASON_WEATHER_WEIGHTS: Dictionary = {
	Season.SPRING: {"sunny": 50, "cloudy": 25, "rainy": 25, "stormy": 0, "snowy": 0},
	Season.SUMMER: {"sunny": 60, "cloudy": 15, "rainy": 20, "stormy": 5, "snowy": 0},
	Season.FALL: {"sunny": 40, "cloudy": 30, "rainy": 25, "stormy": 5, "snowy": 0},
	Season.WINTER: {"sunny": 30, "cloudy": 25, "rainy": 5, "stormy": 0, "snowy": 40}
}

# 作物季节配置缓存
var _crop_season_data: Dictionary = {}

# 当前活跃的季节特效
var _active_season_effect: Node2D = null


func _ready() -> void:
	print("[SeasonSystem] Initialized")
	_connect_signals()


func _connect_signals() -> void:
	if TimeManager:
		TimeManager.season_changed.connect(_on_time_season_changed)
		get_node("/root/TimeManager").day_changed.connect(_on_day_changed)


## 获取当前季节
func get_current_season() -> int:
	return current_season


## 获取当前季节名称
func get_season_name() -> String:
	return SEASON_NAMES[current_season]


## 获取当前季节中文名
func get_season_name_cn() -> String:
	return SEASON_NAMES_CN[current_season]


## 获取季节颜色
func get_season_color() -> Color:
	return SEASON_COLORS[current_season]


## 获取季节图标路径
func get_season_icon_path() -> String:
	return SEASON_ICONS[current_season]


## 检查作物是否适合当前季节
func is_crop_in_season(crop_seasons: Array) -> bool:
	if crop_seasons.is_empty():
		return true

	var current_season_name := get_season_name().to_lower()
	for season in crop_seasons:
		if season.to_lower() == current_season_name:
			return true
	return false


## 获取作物的季节生长加成
func get_crop_growth_multiplier(crop_seasons: Array, current_weather: String = "sunny") -> float:
	var multiplier := 1.0

	# 季节适配加成
	if is_crop_in_season(crop_seasons):
		multiplier *= 1.0  # 正常生长
	else:
		multiplier *= 0.0  # 非季节作物不生长

	# 天气影响
	var weather_bonus: float = WEATHER_GROWTH_BONUS.get(current_weather, 1.0)
	multiplier *= weather_bonus

	return multiplier


## 检查作物是否应该枯萎
func should_crop_wither(crop_seasons: Array, is_watered: bool) -> bool:
	# 非季节作物必定枯萎
	if not is_crop_in_season(crop_seasons):
		return true

	# 冬季所有非耐寒作物枯萎
	if current_season == Season.WINTER:
		if not _is_winter_hardy(crop_seasons):
			return true

	return false


## 检查作物是否耐寒
func _is_winter_hardy(crop_seasons: Array) -> bool:
	# 只有明确标注冬季的作物才耐寒
	for season in crop_seasons:
		if season.to_lower() == "winter":
			return true
	return false


## 获取季节天气概率
func get_season_weather_weights() -> Dictionary:
	return SEASON_WEATHER_WEIGHTS.get(current_season, SEASON_WEATHER_WEIGHTS[Season.SPRING])


## 根据季节生成天气
func generate_weather_for_season() -> String:
	var weights := get_season_weather_weights()
	var total_weight := 0

	for weight in weights.values():
		total_weight += weight

	var roll := randi() % total_weight
	var cumulative := 0

	for weather_type in weights:
		cumulative += weights[weather_type]
		if roll < cumulative:
			return weather_type

	return "sunny"


## 处理季节变化
func process_season_change(new_season: int) -> void:
	previous_season = current_season
	current_season = new_season

	# 发射季节变化信号
	season_changed.emit(current_season, SEASON_NAMES[current_season])

	# 更新季节特效
	_update_season_effect()

	# 处理所有作物的季节适配
	_process_crops_for_season_change()

	print("[SeasonSystem] Season changed to: ", SEASON_NAMES[current_season])


## 处理作物季节变化
func _process_crops_for_season_change() -> void:
	# 通知所有农场地图处理季节作物
	if EventBus:
		get_node("/root/EventBus").time.season_changed.emit(current_season, SEASON_NAMES[current_season])


## 更新季节特效
func _update_season_effect() -> void:
	# 移除旧特效
	if _active_season_effect:
		_active_season_effect.queue_free()
		_active_season_effect = null

	# 创建新特效（延迟加载）
	_spawn_season_effect.call_deferred()


## 生成季节特效
func _spawn_season_effect() -> void:
	if _should_skip_visual_effects():
		return

	var effect_scene_path := _get_season_effect_path()
	if effect_scene_path.is_empty():
		return

		if ResourceLoader.exists(effect_scene_path):
			var effect_scene := load(effect_scene_path) as PackedScene
			if effect_scene:
				_active_season_effect = effect_scene.instantiate() as Node2D
				if _active_season_effect:
					# 添加到场景树的根部
					get_tree().current_scene.add_child(_active_season_effect)
					print("[SeasonSystem] Spawned season effect: ", SEASON_NAMES[current_season])


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


## 获取季节特效场景路径
func _get_season_effect_path() -> String:
	match current_season:
		Season.SPRING:
			return "res://src/effects/SeasonEffectSpring.tscn"
		Season.SUMMER:
			return "res://src/effects/SeasonEffectSummer.tscn"
		Season.FALL:
			return "res://src/effects/SeasonEffectFall.tscn"
		Season.WINTER:
			return "res://src/effects/SeasonEffectWinter.tscn"
		_:
			return ""


## 信号回调：时间管理器季节变化
func _on_time_season_changed(new_season: int, season_name: String) -> void:
	process_season_change(new_season)


## 信号回调：新的一天
func _on_day_changed(new_day: int) -> void:
	season_day_started.emit(current_season, new_day)


## 获取季节存档数据
func save_state() -> Dictionary:
	return {
		"current_season": current_season,
		"previous_season": previous_season
	}


## 加载季节存档数据
func load_state(data: Dictionary) -> void:
	current_season = data.get("current_season", Season.SPRING)
	previous_season = data.get("previous_season", -1)

	# 更新季节特效
	_update_season_effect()

	print("[SeasonSystem] State loaded: ", SEASON_NAMES[current_season])


func reset() -> void:
	current_season = Season.SPRING
	previous_season = -1
	_update_season_effect()
