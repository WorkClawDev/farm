extends Node2D
class_name FishingRod

## FishingRod - 鱼竿工具
## 用于钓鱼，包含钓鱼小游戏逻辑

# 信号
signal fishing_started
signal fishing_ended(success: bool, fish_id: String, size: int)
signal fish_hooked(fish_data: Dictionary)
signal catch_progress_changed(progress: float)
signal energy_consumed(amount: int)

# 工具属性
@export var tool_name: String = "鱼竿"
@export var energy_cost_per_cast: int = 3  # 每次抛竿消耗体力
@export var energy_cost_per_catch: int = 5  # 每次成功钓鱼额外消耗

# 钓鱼状态
enum FishingState { IDLE, CASTING, WAITING, HOOKED, MINIGAME, CATCHING, REELING }
var current_state: FishingState = FishingState.IDLE

# 鱼竿动画状态
var is_using: bool = false

# 钓鱼小游戏引用
var minigame: Node = null

# 当前钓鱼数据
var current_fish_data: Dictionary = {}
var current_location: String = ""
var fishing_timer: float = 0.0

# 配置
const MIN_WAIT_TIME: float = 1.0
const MAX_WAIT_TIME: float = 5.0
const MINIGAME_SCENE_PATH: String = "res://src/ui/minigames/FishingMinigame.tscn"

# 鱼类数据库
var _fish_database: Dictionary = {}
var _difficulty_settings: Dictionary = {}

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var cast_timer: Timer = Timer.new()

func _ready() -> void:
	_load_fish_database()
	_setup_timers()
	print("[FishingRod] Tool initialized: ", tool_name)

func _setup_timers() -> void:
	cast_timer.one_shot = true
	cast_timer.timeout.connect(_on_cast_timer_timeout)
	add_child(cast_timer)

## 加载鱼类数据库
func _load_fish_database() -> void:
	var file := FileAccess.open("res://data/fish.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error == OK:
			var data: Dictionary = json.data
			for fish in data.get("fish", []):
				_fish_database[fish.id] = fish
			_difficulty_settings = data.get("difficulty_settings", {})
			print("[FishingRod] Loaded ", _fish_database.size(), " fish types")
		else:
			push_error("[FishingRod] Failed to parse fish.json: " + json.get_error_message())

## 使用鱼竿
func use(target_position: Vector2, location_type: String = "lake") -> bool:
	if is_using or current_state != FishingState.IDLE:
		print("[FishingRod] Already in use")
		return false

	current_location = location_type
	is_using = true

	# 消耗体力
	energy_consumed.emit(energy_cost_per_cast)

	# 开始钓鱼
	_start_casting()
	return true

## 开始抛竿动画
func _start_casting() -> void:
	current_state = FishingState.CASTING
	fishing_started.emit()

	if animation_player and animation_player.has_animation("cast"):
		animation_player.play("cast")
	else:
		# 简单的抛竿动画
		var tween := create_tween()
		tween.tween_property(self, "rotation", -PI / 6, 0.2)
		tween.tween_property(self, "rotation", PI / 8, 0.3)

	# 等待动画完成后开始等待鱼咬钩
	get_tree().create_timer(0.5).timeout.connect(_start_waiting, CONNECT_ONE_SHOT)

## 开始等待鱼咬钩
func _start_waiting() -> void:
	current_state = FishingState.WAITING

	# 随机等待时间
	var wait_time := randf_range(MIN_WAIT_TIME, MAX_WAIT_TIME)
	cast_timer.wait_time = wait_time
	cast_timer.start()

	print("[FishingRod] Waiting for fish... (", wait_time, "s)")

## 抛竿计时器结束
func _on_cast_timer_timeout() -> void:
	if current_state == FishingState.WAITING:
		_fish_hooked()

## 鱼咬钩
func _fish_hooked() -> void:
	current_state = FishingState.HOOKED

	# 根据当前条件选择鱼
	current_fish_data = _select_fish()
	if current_fish_data.is_empty():
		# 没有可钓的鱼，随机垃圾或小东西
		_fishing_failed()
		return

	fish_hooked.emit(current_fish_data)
	print("[FishingRod] Fish hooked: ", current_fish_data.get("name", "Unknown"))

	# 播放咬钩音效和动画
	_play_hooked_effects()

	# 给玩家短时间反应
	get_tree().create_timer(0.5).timeout.connect(_on_hook_reaction_window_finished, CONNECT_ONE_SHOT)

func _on_hook_reaction_window_finished() -> void:
	# 如果玩家没有操作，自动开始小游戏
	if current_state == FishingState.HOOKED:
		_start_minigame()

## 选择要钓的鱼
func _select_fish() -> Dictionary:
	var available_fish: Array = []
	var current_hour := int(get_node("/root/TimeManager").current_time) if TimeManager else 12
	var current_season: String = TimeManager.get_season_name().to_lower() if TimeManager else "spring"
	var current_weather: String = "sunny"  # WeatherSystem 未实现，默认晴天

	# 筛选符合当前条件的鱼
	for fish_id in _fish_database:
		var fish: Dictionary = _fish_database[fish_id]

		# 检查地点
		if not fish.get("locations", []).has(current_location):
			continue

		# 检查季节
		if not fish.get("seasons", []).has(current_season):
			continue

		# 检查时间
		var time_valid := false
		for time_range in fish.get("time_ranges", []):
			if current_hour >= time_range.start and current_hour < time_range.end:
				time_valid = true
				break
		if not time_valid:
			continue

		# 检查天气
		if not fish.get("weather", []).has(current_weather):
			continue

		available_fish.append(fish)

	if available_fish.is_empty():
		return {}

	# 根据稀有度权重随机选择
	var weighted_fish: Array = []
	var rarity_weights: Dictionary = {
		"common": 60,
		"uncommon": 25,
		"rare": 12,
		"legendary": 3
	}

	for fish in available_fish:
		var weight = rarity_weights.get(fish.get("rarity", "common"), 10)
		for i in range(weight):
			weighted_fish.append(fish)

	return weighted_fish.pick_random()

## 播放咬钩特效
func _play_hooked_effects() -> void:
	# 播放音效
	# AudioManager.play_sfx("fish_hooked")

	# 播放动画
	if animation_player and animation_player.has_animation("hooked"):
		animation_player.play("hooked")
	else:
		var tween := create_tween()
		tween.tween_property(self, "rotation", PI / 8, 0.1)
		tween.tween_property(self, "rotation", -PI / 12, 0.1)
		tween.tween_property(self, "rotation", PI / 8, 0.1)

## 开始钓鱼小游戏
func _start_minigame() -> void:
	current_state = FishingState.MINIGAME

	# 实例化小游戏场景
	var minigame_scene := load(MINIGAME_SCENE_PATH)
	if minigame_scene:
		minigame = minigame_scene.instantiate()
		get_tree().current_scene.add_child(minigame)

		# 设置小游戏数据
		minigame.setup(current_fish_data, _difficulty_settings)
		minigame.catch_success.connect(_on_minigame_success)
		minigame.catch_failed.connect(_on_minigame_failed)
		minigame.progress_changed.connect(_on_minigame_progress)
	else:
		push_error("[FishingRod] Failed to load minigame scene")
		_fishing_failed()

## 小游戏进度更新
func _on_minigame_progress(progress: float) -> void:
	catch_progress_changed.emit(progress)

## 小游戏成功
func _on_minigame_success() -> void:
	current_state = FishingState.CATCHING

	# 消耗体力
	energy_consumed.emit(energy_cost_per_catch)

	# 计算鱼的大小
	var min_size: int = current_fish_data.get("min_size", 30)
	var max_size: int = current_fish_data.get("max_size", 60)
	var fish_size := randi_range(min_size, max_size)
	
	# 成功钓鱼
	get_tree().create_timer(0.5).timeout.connect(_fishing_success.bind(fish_size), CONNECT_ONE_SHOT)

## 小游戏失败
func _on_minigame_failed() -> void:
	_fishing_failed()

## 钓鱼成功
func _fishing_success(fish_size: int) -> void:
	current_state = FishingState.REELING

	# 播放收杆动画
	if animation_player and animation_player.has_animation("reel"):
		animation_player.play("reel")
	get_tree().create_timer(0.3).timeout.connect(_complete_fishing_success.bind(fish_size), CONNECT_ONE_SHOT)

func _complete_fishing_success(fish_size: int) -> void:
	var fish_id: String = current_fish_data.get("id", "")
	fishing_ended.emit(true, fish_id, fish_size)
	
	if fish_id != "" and Inventory:
		Inventory.add_item(fish_id, 1)
	
	print("[FishingRod] Caught fish: ", current_fish_data.get("name"), " (", fish_size, "cm)")
	
	_reset_fishing()

## 钓鱼失败
func _fishing_failed() -> void:
	fishing_ended.emit(false, "", 0)
	print("[FishingRod] Fish got away!")
	_reset_fishing()

## 重置钓鱼状态
func _reset_fishing() -> void:
	current_state = FishingState.IDLE
	is_using = false
	current_fish_data = {}

	if minigame:
		minigame.queue_free()
		minigame = null

## 取消钓鱼
func cancel_fishing() -> void:
	if current_state != FishingState.IDLE:
		print("[FishingRod] Fishing cancelled")
		_fishing_failed()

## 获取工具信息
func get_tool_info() -> Dictionary:
	return {
		"name": tool_name,
		"type": "fishing_rod",
		"energy_cost": energy_cost_per_cast,
		"description": "用于在水边钓鱼"
	}

## 获取当前状态名称
func get_state_name() -> String:
	match current_state:
		FishingState.IDLE: return "空闲"
		FishingState.CASTING: return "抛竿"
		FishingState.WAITING: return "等待"
		FishingState.HOOKED: return "咬钩"
		FishingState.MINIGAME: return "钓鱼中"
		FishingState.CATCHING: return "捕获中"
		FishingState.REELING: return "收杆"
		_: return "未知"
