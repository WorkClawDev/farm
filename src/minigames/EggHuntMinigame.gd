extends FestivalMinigame
class_name EggHuntMinigame

## EggHuntMinigame - 彩蛋寻宝小游戏
## 春节活动：在限定时间内找到隐藏的彩蛋

const EGG_SCENE_PATH := "res://src/minigames/Egg.tscn"
const MAX_EGGS: int = 20
const EGG_POINTS := {
	"normal": 10,
	"silver": 25,
	"golden": 50,
}

@export var play_area: Rect2 = Rect2(100, 100, 600, 400)

var _eggs: Array[Node2D] = []
var _found_eggs: int = 0
var _total_eggs: int = 0

var _score_label: Label
var _timer_label: Label
var _hint_label: Label

func _setup_game() -> void:
	super._setup_game()
	game_time = 90.0
	min_score_to_win = 150
	time_remaining = game_time
	_create_ui()
	_spawn_eggs()

func _create_ui() -> void:
	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.text = "Score: 0"
	add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 50)
	_timer_label.text = "Time: 90"
	add_child(_timer_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(200, 20)
	_hint_label.text = "Click eggs to collect them."
	add_child(_hint_label)

func _spawn_eggs() -> void:
	var egg_count := MAX_EGGS + (difficulty * 5)
	for i in range(egg_count):
		var egg := _create_egg(i)
		_eggs.append(egg)
		add_child(egg)

	_total_eggs = egg_count

func _create_egg(_index: int) -> Node2D:
	var egg := _instantiate_egg()
	var x := randf_range(play_area.position.x, play_area.position.x + play_area.size.x)
	var y := randf_range(play_area.position.y, play_area.position.y + play_area.size.y)
	egg.position = Vector2(x, y)

	var roll := randf()
	var egg_type := "normal"
	var color := Color.DEEP_PINK
	if roll > 0.95:
		egg_type = "golden"
		color = Color.GOLD
	elif roll > 0.85:
		egg_type = "silver"
		color = Color.SILVER

	egg.set_meta("egg_type", egg_type)
	egg.set_meta("points", EGG_POINTS[egg_type])

	if egg.get_child_count() == 0:
		var rect := ColorRect.new()
		var size := 15 if egg_type == "normal" else 20
		rect.size = Vector2(size, size)
		rect.position = Vector2(-size / 2.0, -size / 2.0)
		rect.color = color
		egg.add_child(rect)

	var area := Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15 if egg_type == "normal" else 20
	collision.shape = shape
	area.add_child(collision)
	egg.add_child(area)
	area.input_pickable = true
	area.input_event.connect(_on_egg_input_event.bind(egg))

	return egg

func _instantiate_egg() -> Node2D:
	if ResourceLoader.exists(EGG_SCENE_PATH):
		var scene := load(EGG_SCENE_PATH) as PackedScene
		if scene:
			return scene.instantiate() as Node2D
	return Node2D.new()

func _on_egg_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, egg: Node2D) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_egg_clicked(egg)

func _on_egg_clicked(egg: Node2D) -> void:
	if current_state != GameState.PLAYING:
		return
	if egg.get_meta("collected", false):
		return

	egg.set_meta("collected", true)
	var area := egg.get_node_or_null("Area2D") as Area2D
	if area:
		area.input_pickable = false

	var points: int = egg.get_meta("points", 10)
	add_score(points)
	_found_eggs += 1
	_play_collect_effect(egg)
	_eggs.erase(egg)
	_update_ui()

func _play_collect_effect(egg: Node2D) -> void:
	var tween := create_tween()
	tween.tween_property(egg, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(egg, "modulate:a", 0.0, 0.2)
	await tween.finished
	if is_instance_valid(egg):
		egg.queue_free()

func _update_game(_delta: float) -> void:
	_update_ui()

func _update_ui() -> void:
	if _score_label:
		_score_label.text = "Score: %d" % score
	if _timer_label:
		_timer_label.text = "Time: %d" % int(time_remaining)

	if _found_eggs >= _total_eggs and current_state == GameState.PLAYING:
		add_score(50)
		end_game()

func _on_score_changed(new_score: int) -> void:
	super._on_score_changed(new_score)
	if _score_label:
		_score_label.text = "Score: %d" % new_score

func _on_game_started() -> void:
	super._on_game_started()
	if _hint_label:
		_hint_label.text = "Find every egg before time runs out."

func _on_game_ended(success: bool) -> void:
	super._on_game_ended(success)
	if _hint_label:
		if success:
			_hint_label.text = "You found %d eggs." % _found_eggs
		else:
			_hint_label.text = "Time is up."

func get_result() -> Dictionary:
	var result := super.get_result()
	result["eggs_found"] = _found_eggs
	result["total_eggs"] = _total_eggs
	return result
