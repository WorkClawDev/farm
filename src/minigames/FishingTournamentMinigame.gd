extends FestivalMinigame
class_name FishingTournamentMinigame

## FishingTournamentMinigame - 钓鱼大赛小游戏
## 夏季海滩节活动

# 鱼类配置
const FISH_TYPES: Array[Dictionary] = [
	{"id": "common", "name": "鲤鱼", "points": 10, "difficulty": 1, "time": 3.0},
	{"id": "uncommon", "name": "鲈鱼", "points": 25, "difficulty": 2, "time": 4.0},
	{"id": "rare", "name": "金枪鱼", "points": 50, "difficulty": 3, "time": 5.0},
	{"id": "legendary", "name": "金龙鱼", "points": 100, "difficulty": 4, "time": 6.0}
]

# 游戏状态
var _current_fish: Dictionary = {}
var _fish_caught: int = 0
var _is_fishing: bool = false
var _fishing_progress: float = 0.0
var _target_zone: float = 0.5
var _fish_position: float = 0.5

# UI
var _score_label: Label
var _timer_label: Label
var _fish_label: Label
var _progress_bar: ProgressBar
var _instruction_label: Label


func _setup_game() -> void:
	game_time = 120.0
	min_score_to_win = 200
	_create_ui()


func _create_ui() -> void:
	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.text = "分数: 0"
	add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 50)
	_timer_label.text = "时间: 120"
	add_child(_timer_label)

	_fish_label = Label.new()
	_fish_label.position = Vector2(20, 80)
	_fish_label.text = "钓到: 0 条"
	add_child(_fish_label)

	_instruction_label = Label.new()
	_instruction_label.position = Vector2(200, 20)
	_instruction_label.text = "按空格键开始钓鱼"
	add_child(_instruction_label)

	# 进度条
	_progress_bar = ProgressBar.new()
	_progress_bar.position = Vector2(200, 300)
	_progress_bar.custom_minimum_size = Vector2(200, 30)
	_progress_bar.value = 0
	add_child(_progress_bar)


func _update_game(delta: float) -> void:
	_update_ui()

	if _is_fishing:
		_update_fishing(delta)


func _update_fishing(delta: float) -> void:
	# 鱼会移动
	var fish_difficulty: float = _current_fish.get("difficulty", 1)
	var move_speed := 0.3 + (fish_difficulty * 0.1)

	# 鱼随机移动
	_fish_position += randf_range(-move_speed, move_speed) * delta
	_fish_position = clamp(_fish_position, 0.0, 1.0)

	# 更新进度条显示
	_progress_bar.value = _fishing_progress * 100

	# 检查是否在目标区域
	if abs(_fish_position - _target_zone) < 0.15:
		_fishing_progress += delta * 0.5
	else:
		_fishing_progress -= delta * 0.3

	_fishing_progress = clamp(_fishing_progress, 0.0, 1.0)

	# 检查是否钓到鱼
	if _fishing_progress >= 1.0:
		_catch_fish()
	elif _fishing_progress <= 0.0:
		_fail_fishing()


func _input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
		return

	if event.is_action_pressed("ui_accept"):  # 空格键
		if not _is_fishing:
			start_fishing()
		else:
			# 调整目标区域
			_target_zone = randf()


func start_fishing() -> void:
	_is_fishing = true
	_fishing_progress = 0.5
	_fish_position = randf()
	_target_zone = randf()

	# 随机选择鱼
	var roll := randf()
	if roll > 0.95:
		_current_fish = FISH_TYPES[3]  # legendary
	elif roll > 0.85:
		_current_fish = FISH_TYPES[2]  # rare
	elif roll > 0.60:
		_current_fish = FISH_TYPES[1]  # uncommon
	else:
		_current_fish = FISH_TYPES[0]  # common

	_instruction_label.text = "按空格键调整位置！钓: " + _current_fish.get("name", "鱼")
	_progress_bar.visible = true


func _catch_fish() -> void:
	var points: int = _current_fish.get("points", 10)
	add_score(points)
	_fish_caught += 1

	_instruction_label.text = "钓到了 " + _current_fish.get("name", "鱼") + "！+" + str(points)
	_is_fishing = false
	_progress_bar.visible = false

	# 短暂延迟后可以继续钓鱼
	await get_tree().create_timer(1.0).timeout
	_instruction_label.text = "按空格键继续钓鱼"


func _fail_fishing() -> void:
	_instruction_label.text = "鱼跑掉了..."
	_is_fishing = false
	_progress_bar.visible = false

	await get_tree().create_timer(1.0).timeout
	_instruction_label.text = "按空格键继续钓鱼"


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "分数: %d" % score
	if _timer_label:
		_timer_label.text = "时间: %d" % int(time_remaining)
	if _fish_label:
		_fish_label.text = "钓到: %d 条" % _fish_caught


func _on_game_started() -> void:
	_instruction_label.text = "按空格键开始钓鱼！"


func _on_game_ended(_success: bool) -> void:
	_is_fishing = false
	_progress_bar.visible = false


func get_result() -> Dictionary:
	var result := super.get_result()
	result["fish_caught"] = _fish_caught
	return result