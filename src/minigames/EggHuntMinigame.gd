extends FestivalMinigame
class_name EggHuntMinigame

## EggHuntMinigame - 彩蛋寻宝小游戏
## 春节活动：在限定时间内找到隐藏的彩蛋

# 彩蛋配置
var EGG_SCENE: PackedScene = preload("res://src/minigames/Egg.tscn") if FileAccess.file_exists("res://src/minigames/Egg.tscn") else null
const MAX_EGGS: int = 20
const EGG_POINTS: Dictionary = {
	"normal": 10,
	"silver": 25,
	"golden": 50
}

# 游戏区域
@export var play_area: Rect2 = Rect2(100, 100, 600, 400)

# 彩蛋列表
var _eggs: Array[Node] = []
var _found_eggs: int = 0
var _total_eggs: int = 0

# UI引用
var _score_label: Label
var _timer_label: Label
var _hint_label: Label


func _setup_game() -> void:
	game_time = 90.0
	min_score_to_win = 150
	_create_ui()
	_spawn_eggs()


func _create_ui() -> void:
	# 创建分数显示
	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.text = "分数: 0"
	add_child(_score_label)

	# 创建计时器显示
	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 50)
	_timer_label.text = "时间: 90"
	add_child(_timer_label)

	# 创建提示标签
	_hint_label = Label.new()
	_hint_label.position = Vector2(200, 20)
	_hint_label.text = "点击彩蛋收集它们！"
	add_child(_hint_label)


func _spawn_eggs() -> void:
	var egg_count := MAX_EGGS + (difficulty * 5)

	for i in range(egg_count):
		var egg := _create_egg(i)
		_eggs.append(egg)
		add_child(egg)

	_total_eggs = egg_count


func _create_egg(_index: int) -> Node2D:
	var egg: Node2D
	if EGG_SCENE:
		egg = EGG_SCENE.instantiate()
	else:
		egg = Node2D.new()

	# 随机位置
	var x := randf_range(play_area.position.x, play_area.position.x + play_area.size.x)
	var y := randf_range(play_area.position.y, play_area.position.y + play_area.size.y)
	egg.position = Vector2(x, y)

	# 随机类型
	var roll := randf()
	var egg_type := "normal"
	var color := Color.DEEP_PINK
	if roll > 0.95:
		egg_type = "golden"
		color = Color.GOLD
	elif roll > 0.85:
		egg_type = "silver"
		color = Color.SILVER

	# 设置元数据
	egg.set_meta("egg_type", egg_type)
	egg.set_meta("points", EGG_POINTS[egg_type])

	# Add visual representation if needed
	if egg.get_child_count() == 0:
		var rect := ColorRect.new()
		var size := 15 if egg_type == "normal" else 20
		rect.size = Vector2(size, size)
		rect.position = Vector2(-size/2.0, -size/2.0)
		rect.color = color
		egg.add_child(rect)

	# 添加点击检测
	var area := Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15 if egg_type == "normal" else 20
	collision.shape = shape
	area.add_child(collision)
	egg.add_child(area)
	area.input_pickable = true

	area.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed:
			_on_egg_clicked(egg)
	)

	return egg


func _on_egg_clicked(egg: Node2D) -> void:
	if current_state != GameState.PLAYING:
		return

	var points: int = egg.get_meta("points", 10)
	add_score(points)

	_found_eggs += 1

	# 播放收集效果
	_play_collect_effect(egg)

	# 移除彩蛋
	egg.queue_free()
	_eggs.erase(egg)

	# 更新UI
	_update_ui()


func _play_collect_effect(egg: Node2D) -> void:
	# 简单的缩放动画
	var tween := create_tween()
	tween.tween_property(egg, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(egg, "modulate:a", 0.0, 0.2)


func _update_game(_delta: float) -> void:
	_update_ui()


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "分数: %d" % score
	if _timer_label:
		_timer_label.text = "时间: %d" % int(time_remaining)

	# 检查是否找到所有彩蛋
	if _found_eggs >= _total_eggs:
		# 额外奖励
		add_score(50)
		end_game()


func _on_score_changed(new_score: int) -> void:
	if _score_label:
		_score_label.text = "分数: %d" % new_score


func _on_game_started() -> void:
	_hint_label.text = "开始找彩蛋！"


func _on_game_ended(success: bool) -> void:
	var message := "恭喜！找到 %d 个彩蛋！" % _found_eggs if success else "时间到！"
	_hint_label.text = message


func get_result() -> Dictionary:
	var result := super.get_result()
	result["eggs_found"] = _found_eggs
	result["total_eggs"] = _total_eggs
	return result