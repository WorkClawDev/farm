extends FestivalMinigame
class_name PumpkinCarvingMinigame

## PumpkinCarvingMinigame - 南瓜雕刻小游戏
## 秋季收获节活动

# 雕刻模式
enum CarveMode { DRAW, ERASE, FILL }

# 配置
const GRID_SIZE: int = 16
const CELL_SIZE: int = 20

# 游戏状态
var _grid: Array = []
var _current_mode: CarveMode = CarveMode.DRAW
var _carve_count: int = 0
var _pattern_score: int = 0

# 预设图案
const PATTERNS: Array[Dictionary] = [
	{"name": "classic", "points": 50, "cells": []},  # 经典南瓜脸
	{"name": "scary", "points": 80, "cells": []},     # 恐怖脸
	{"name": "happy", "points": 60, "cells": []}      # 开心脸
]

# UI
var _grid_container: GridContainer
var _score_label: Label
var _timer_label: Label
var _mode_label: Label
var _instruction_label: Label


func _setup_game() -> void:
	game_time = 90.0
	min_score_to_win = 100
	_init_grid()
	_create_ui()


func _init_grid() -> void:
	_grid.clear()
	for i in range(GRID_SIZE * GRID_SIZE):
		_grid.append(false)  # false = pumpkin (orange), true = carved (black)


func _create_ui() -> void:
	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.text = "分数: 0"
	add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 50)
	_timer_label.text = "时间: 90"
	add_child(_timer_label)

	_mode_label = Label.new()
	_mode_label.position = Vector2(20, 80)
	_mode_label.text = "模式: 雕刻"
	add_child(_mode_label)

	_instruction_label = Label.new()
	_instruction_label.position = Vector2(200, 20)
	_instruction_label.text = "点击雕刻南瓜，按E切换橡皮擦"
	add_child(_instruction_label)

	# 创建网格
	_grid_container = GridContainer.new()
	_grid_container.position = Vector2(200, 100)
	_grid_container.columns = GRID_SIZE
	add_child(_grid_container)

	_create_grid_cells()


func _create_grid_cells() -> void:
	for child in _grid_container.get_children():
		child.queue_free()

	for i in range(GRID_SIZE * GRID_SIZE):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.toggle_mode = true

		var is_carved: bool = _grid[i]
		if is_carved:
			cell.modulate = Color(0.1, 0.1, 0.1)  # 黑色（雕刻部分）
		else:
			cell.modulate = Color(1.0, 0.6, 0.2)  # 橙色（南瓜部分）

		var idx := i
		cell.pressed.connect(func(): _on_cell_clicked(idx))
		_grid_container.add_child(cell)


func _on_cell_clicked(index: int) -> void:
	if current_state != GameState.PLAYING:
		return

	match _current_mode:
		CarveMode.DRAW:
			if not _grid[index]:
				_grid[index] = true
				_carve_count += 1
				add_score(2)
		CarveMode.ERASE:
			if _grid[index]:
				_grid[index] = false
				_carve_count -= 1

	_update_grid_display()
	_check_pattern_bonus()


func _update_grid_display() -> void:
	var cells := _grid_container.get_children()
	for i in range(cells.size()):
		var cell: Button = cells[i]
		if _grid[i]:
			cell.modulate = Color(0.1, 0.1, 0.1)
		else:
			cell.modulate = Color(1.0, 0.6, 0.2)


func _check_pattern_bonus() -> void:
	# 简单的模式检测
	# 检查是否雕刻了足够的格子形成"脸"
	var center_row_start := GRID_SIZE * (GRID_SIZE / 2 - 2)
	var center_row_end := GRID_SIZE * (GRID_SIZE / 2 + 2)

	# 眼睛位置
	var left_eye_idx := (GRID_SIZE / 3) * GRID_SIZE + GRID_SIZE / 3
	var right_eye_idx := (GRID_SIZE / 3) * GRID_SIZE + 2 * GRID_SIZE / 3

	# 嘴巴位置
	var mouth_idx := (2 * GRID_SIZE / 3) * GRID_SIZE + GRID_SIZE / 2

	var has_eyes: bool = _grid[left_eye_idx] != null and _grid[right_eye_idx] != null
	var has_mouth := false
	for i in range(mouth_idx - 2, mouth_idx + 3):
		if i >= 0 and i < _grid.size() and _grid[i]:
			has_mouth = true
			break

	if has_eyes and has_mouth and _pattern_score < 50:
		_pattern_score = 50
		add_score(50)
		_instruction_label.text = "南瓜脸完成！+50分"


func _input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
		return

	if event.is_action_pressed("ui_accept"):  # 空格键切换模式
		_toggle_mode()
	elif event.is_action_pressed("ui_text_backspace"):  # E键
		_toggle_mode()


func _toggle_mode() -> void:
	_current_mode = CarveMode.ERASE if _current_mode == CarveMode.DRAW else CarveMode.DRAW

	match _current_mode:
		CarveMode.DRAW:
			_mode_label.text = "模式: 雕刻"
		CarveMode.ERASE:
			_mode_label.text = "模式: 橡皮擦"


func _update_game(_delta: float) -> void:
	_update_ui()


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "分数: %d" % score
	if _timer_label:
		_timer_label.text = "时间: %d" % int(time_remaining)


func _on_game_started() -> void:
	_instruction_label.text = "开始雕刻你的南瓜灯！"


func _on_game_ended(_success: bool) -> void:
	_instruction_label.text = "雕刻完成！"


func get_result() -> Dictionary:
	var result := super.get_result()
	result["carve_count"] = _carve_count
	result["pattern_bonus"] = _pattern_score
	return result


func save_carving() -> Dictionary:
	return {
		"grid": _grid.duplicate(),
		"grid_size": GRID_SIZE
	}