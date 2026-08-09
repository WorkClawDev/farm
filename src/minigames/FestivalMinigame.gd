extends Node
class_name FestivalMinigame

signal completed(score: int, success: bool)
signal cancelled

enum GameState {
	READY,
	PLAYING,
	PAUSED,
	ENDED,
}

var current_state: GameState = GameState.READY
var score: int = 0
var time_remaining: float = 60.0
var difficulty: int = 1

@export var game_time: float = 60.0
@export var min_score_to_win: int = 100

var _state_label: Label
var _score_change_label: Label

func _ready() -> void:
	time_remaining = game_time
	_setup_game()

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		_update_game(delta)
		_update_timer(delta)
	elif current_state == GameState.PAUSED:
		_update_paused_ui()

func _setup_game() -> void:
	_create_base_ui()

func _update_game(_delta: float) -> void:
	pass

func _update_timer(delta: float) -> void:
	time_remaining -= delta
	if time_remaining <= 0.0:
		time_remaining = 0.0
		end_game()

func start_game() -> void:
	if current_state != GameState.READY:
		return

	current_state = GameState.PLAYING
	score = 0
	time_remaining = game_time
	_on_game_started()

func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return

	current_state = GameState.PAUSED
	get_tree().paused = true
	_on_game_paused()

func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return

	current_state = GameState.PLAYING
	_clear_pause_state()
	_on_game_resumed()

func end_game() -> void:
	if current_state == GameState.ENDED:
		return

	_clear_pause_state()
	current_state = GameState.ENDED
	var success := score >= min_score_to_win
	_on_game_ended(success)
	completed.emit(score, success)

func cancel_game() -> void:
	if current_state == GameState.ENDED:
		return

	_clear_pause_state()
	current_state = GameState.ENDED
	_on_game_cancelled()
	cancelled.emit()

func add_score(points: int) -> void:
	score += points
	_on_score_changed(score)

func set_difficulty(level: int) -> void:
	difficulty = clamp(level, 1, 3)
	_on_difficulty_changed(difficulty)

func get_result() -> Dictionary:
	return {
		"score": score,
		"success": score >= min_score_to_win,
		"time_remaining": time_remaining,
		"difficulty": difficulty,
	}

func _create_base_ui() -> void:
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.position = Vector2(20, 80)
	_state_label.text = "Waiting to start..."
	add_child(_state_label)

	_score_change_label = Label.new()
	_score_change_label.name = "ScoreChangeLabel"
	_score_change_label.position = Vector2(20, 110)
	_score_change_label.modulate = Color(1.0, 1.0, 0.0, 1.0)
	_score_change_label.text = ""
	add_child(_score_change_label)

func _update_paused_ui() -> void:
	if _state_label:
		_state_label.text = "Game paused"

func _on_game_started() -> void:
	if _state_label:
		_state_label.text = "Game running. Target score: %d" % min_score_to_win

func _on_game_paused() -> void:
	if _state_label:
		_state_label.text = "Game paused"
		_create_pause_effect()

func _on_game_resumed() -> void:
	if _state_label:
		_state_label.text = "Game resumed"
		_fade_out_label(_state_label, 1.5)

func _on_game_ended(success: bool) -> void:
	if not _state_label:
		return

	if success:
		_state_label.text = "You win! Final score: %d" % score
		_state_label.modulate = Color(0.2, 1.0, 0.2, 1.0)
	else:
		_state_label.text = "Game over. Score: %d / %d" % [score, min_score_to_win]
		_state_label.modulate = Color(1.0, 0.4, 0.4, 1.0)

func _on_game_cancelled() -> void:
	if _state_label:
		_state_label.text = "Game cancelled"
		_state_label.modulate = Color(0.7, 0.7, 0.7, 1.0)

func _on_score_changed(new_score: int) -> void:
	if _score_change_label:
		_score_change_label.text = "+%d" % new_score
		_score_change_label.modulate = Color(1.0, 1.0, 0.0, 1.0)
		_fade_out_label(_score_change_label, 1.0)

	if new_score >= 100 and new_score < 500:
		_show_milestone("Nice!")
	elif new_score >= 500 and new_score < 1000:
		_show_milestone("Great!")
	elif new_score >= 1000:
		_show_milestone("Perfect!")

func _on_difficulty_changed(new_difficulty: int) -> void:
	if _state_label:
		var stars := ""
		for _i in range(new_difficulty):
			stars += "*"
		_state_label.text = "Difficulty: %s" % stars
		_fade_out_label(_state_label, 2.0)

func _show_milestone(text: String) -> void:
	var milestone := Label.new()
	milestone.name = "MilestoneLabel"
	milestone.position = Vector2(300, 200)
	milestone.text = text
	milestone.modulate = Color(1.0, 0.8, 0.0, 1.0)
	add_child(milestone)

	var tween := create_tween()
	tween.tween_property(milestone, "modulate:a", 0.0, 1.5)
	await tween.finished

	if is_instance_valid(milestone):
		milestone.queue_free()

func _fade_out_label(label: Label, duration: float) -> void:
	if not is_instance_valid(label):
		return

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.5, duration)

func _create_pause_effect() -> void:
	if has_node("PauseOverlay"):
		return

	var overlay := ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.3)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

func _clear_pause_state() -> void:
	get_tree().paused = false
	var overlay = get_node_or_null("PauseOverlay")
	if overlay:
		overlay.queue_free()
