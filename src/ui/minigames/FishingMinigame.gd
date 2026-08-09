extends CanvasLayer
class_name FishingMinigame

## FishingMinigame - 钓鱼小游戏
## 玩家需要在进度条内保持光标在鱼的捕获区域内

# 信号
signal catch_success
signal catch_failed
signal progress_changed(progress: float)

# 游戏配置
@export var game_duration: float = 15.0  # 游戏总时长
@export var catch_zone_height: float = 80.0  # 捕获区域高度

# 当前游戏数据
var fish_data: Dictionary = {}
var difficulty_settings: Dictionary = {}

# 游戏状态
var is_active: bool = false
var game_timer: float = 0.0
var catch_progress: float = 0.0  # 0-1, 满了就成功

# 捕获区域位置 (0-1 相对位置)
var catch_zone_position: float = 0.5

# 鱼的位置 (0-1 相对位置)
var fish_position: float = 0.5

# 鱼的移动
var fish_target_position: float = 0.5
var fish_speed: float = 1.0
var fish_is_erratic: bool = false
var struggle_intensity: float = 0.5

# 玩家控制
var player_bar_speed: float = 2.0

# 节点引用
@onready var background: ColorRect = $Background
@onready var game_container: VBoxContainer = $GameContainer
@onready var fish_name_label: Label = $GameContainer/FishNameLabel
@onready var timer_bar: ProgressBar = $GameContainer/TimerBar
@onready var fishing_bar: Control = $GameContainer/FishingBar
@onready var catch_zone: ColorRect = $GameContainer/FishingBar/CatchZone
@onready var fish_indicator: ColorRect = $GameContainer/FishingBar/FishIndicator
@onready var progress_bar: ProgressBar = $GameContainer/ProgressBar
@onready var instruction_label: Label = $GameContainer/InstructionLabel

# 捕获区域移动相关
var catch_zone_velocity: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()
	print("[FishingMinigame] Initialized")

func _setup_ui() -> void:
	# 设置背景
	if background:
		background.color = Color(0, 0, 0, 0.5)
		background.mouse_filter = Control.MOUSE_FILTER_STOP

	# 设置按键提示
	if instruction_label:
		instruction_label.text = "[按住空格键/鼠标左键上移捕获区域]"

## 设置小游戏
func setup(fish: Dictionary, settings: Dictionary) -> void:
	fish_data = fish
	difficulty_settings = settings

	# 获取难度设置
	var difficulty: int = fish.get("difficulty", 1)
	var diff_settings: Dictionary = settings.get(str(difficulty), {})

	# 应用难度设置
	player_bar_speed = diff_settings.get("bar_speed", 1.5) * 100.0
	fish_speed = diff_settings.get("fish_speed", 1.0) * 50.0
	catch_zone_height = diff_settings.get("capture_zone_size", 0.2) * fishing_bar.size.y if fishing_bar else 80
	struggle_intensity = diff_settings.get("struggle_intensity", 0.5)

	# 获取鱼的行为
	var behavior: Dictionary = fish.get("behavior", {})
	fish_is_erratic = behavior.get("erratic", false)
	fish_speed = behavior.get("speed", 2.0) * 30.0

	# 设置UI
	if fish_name_label:
		fish_name_label.text = fish.get("name", "???")

	# 初始化位置
	fish_position = 0.5
	fish_target_position = 0.5
	catch_zone_position = 0.5

	# 开始游戏
	is_active = true
	game_timer = game_duration
	catch_progress = 0.0

	# 随机时间后设置新的鱼目标
	_schedule_new_fish_target()

	print("[FishingMinigame] Setup complete for: ", fish.get("name"), " difficulty: ", difficulty)

## 安排新的鱼目标位置
func _schedule_new_fish_target() -> void:
	await get_tree().create_timer(randf_range(0.5, 2.0)).timeout

	if is_active:
		# 根据鱼的特性决定新目标
		if fish_is_erratic:
			fish_target_position = randf_range(0.1, 0.9)
		else:
			# 比较温和的移动
			fish_target_position = clamp(fish_target_position + randf_range(-0.3, 0.3), 0.1, 0.9)

		_schedule_new_fish_target()

func _process(delta: float) -> void:
	if not is_active:
		return

	# 更新游戏计时器
	game_timer -= delta
	if game_timer <= 0:
		_end_game(false)
		return

	# 更新UI
	_update_timer_ui()

	# 更新鱼的位置
	_update_fish_position(delta)

	# 更新捕获区域位置 (玩家控制)
	_update_catch_zone_position(delta)

	# 检查是否在捕获范围内
	_check_catch_zone(delta)

	# 更新进度条UI
	_update_progress_ui()

## 更新计时器UI
func _update_timer_ui() -> void:
	if timer_bar:
		timer_bar.value = (game_timer / game_duration) * 100

## 更新鱼的位置
func _update_fish_position(delta: float) -> void:
	# 鱼向目标移动
	var direction := signf(fish_target_position - fish_position)
	var move_speed := fish_speed * delta

	# 添加随机挣扎
	if randf() < struggle_intensity * delta * 10:
		direction = randf_range(-1, 1)

	# 更新位置
	fish_position += direction * move_speed * 0.01
	fish_position = clamp(fish_position, 0.0, 1.0)

	# 更新UI
	if fish_indicator:
		var bar_height: float = fishing_bar.size.y
		fish_indicator.position.y = fish_position * (bar_height - fish_indicator.size.y)

## 更新捕获区域位置
func _update_catch_zone_position(delta: float) -> void:
	var input_direction := 0.0

	# 检测输入
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		input_direction = -1.0  # 向上
	if Input.is_action_pressed("ui_cancel"):
		input_direction = 1.0   # 向下 (可选)

	# 更新位置
	catch_zone_position += input_direction * player_bar_speed * delta * 0.01
	catch_zone_position = clamp(catch_zone_position, 0.0, 1.0)

	# 更新UI
	if catch_zone:
		var bar_height: float = fishing_bar.size.y
		catch_zone.position.y = catch_zone_position * (bar_height - catch_zone.size.y)

## 检查是否在捕获范围内
func _check_catch_zone(delta: float) -> void:
	# 计算鱼和捕获区域的距离
	var distance := absf(fish_position - catch_zone_position)

	# 如果鱼在捕获区域内
	var capture_threshold := catch_zone_height / (fishing_bar.size.y * 2) if fishing_bar else 0.1

	if distance < capture_threshold:
		# 在范围内，增加进度
		catch_progress += delta * 0.15
		catch_progress = min(catch_progress, 1.0)

		# 检查是否成功
		if catch_progress >= 1.0:
			_end_game(true)
	else:
		# 不在范围内，缓慢减少进度
		catch_progress -= delta * 0.08
		catch_progress = max(catch_progress, 0.0)

	progress_changed.emit(catch_progress)

## 更新进度UI
func _update_progress_ui() -> void:
	if progress_bar:
		progress_bar.value = catch_progress * 100

## 结束游戏
func _end_game(success: bool) -> void:
	is_active = false

	# 播放结果动画
	await get_tree().create_timer(0.3).timeout

	if success:
		catch_success.emit()
		print("[FishingMinigame] Catch success!")
	else:
		catch_failed.emit()
		print("[FishingMinigame] Catch failed!")

	queue_free()

## 获取当前进度
func get_progress() -> float:
	return catch_progress