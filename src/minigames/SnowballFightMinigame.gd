extends FestivalMinigame
class_name SnowballFightMinigame

const SNOWBALL_SCENE_PATH := "res://src/minigames/Snowball.tscn"
const PLAYER_SPEED: float = 200.0
const SNOWBALL_SPEED: float = 400.0
const MAX_HEALTH: int = 5

var _health: int = MAX_HEALTH
var _opponents: Array[Node2D] = []
var _snowballs: Array[Node2D] = []
var _can_throw: bool = true
var _throw_cooldown: float = 0.3
var _player_position: Vector2 = Vector2(400, 450)

var _score_label: Label
var _timer_label: Label
var _health_label: Label
var _instruction_label: Label

func _setup_game() -> void:
	super._setup_game()
	game_time = 60.0
	min_score_to_win = 150
	time_remaining = game_time
	_create_ui()
	_spawn_opponents()

func _create_ui() -> void:
	_score_label = Label.new()
	_score_label.position = Vector2(20, 20)
	_score_label.text = "Score: 0"
	add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 50)
	_timer_label.text = "Time: 60"
	add_child(_timer_label)

	_health_label = Label.new()
	_health_label.position = Vector2(20, 80)
	_health_label.text = "Health: *****"
	add_child(_health_label)

	_instruction_label = Label.new()
	_instruction_label.position = Vector2(200, 20)
	_instruction_label.text = "Use WASD to move and click to throw."
	add_child(_instruction_label)

func _spawn_opponents() -> void:
	var opponent_count := 3 + difficulty
	for i in range(opponent_count):
		var opponent := _create_opponent(i)
		_opponents.append(opponent)
		add_child(opponent)

func _create_opponent(index: int) -> Node2D:
	var opponent := Node2D.new()
	opponent.position = Vector2(100 + (index * 150), 100 + (randi() % 100))
	opponent.set_meta("health", 3)
	opponent.set_meta("throw_timer", randf() * 2.0)

	var rect := ColorRect.new()
	rect.size = Vector2(32, 32)
	rect.position = Vector2(-16, -16)
	rect.color = Color.DARK_SLATE_BLUE
	opponent.add_child(rect)

	return opponent

func _update_game(delta: float) -> void:
	_handle_player_movement(delta)
	_update_opponents(delta)
	_update_snowballs(delta)
	_check_collisions()
	_update_ui()

func _handle_player_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		direction.x += 1

	if direction != Vector2.ZERO:
		_player_position += direction.normalized() * PLAYER_SPEED * delta
		_player_position.x = clamp(_player_position.x, 50.0, 750.0)
		_player_position.y = clamp(_player_position.y, 50.0, 550.0)

func _update_opponents(delta: float) -> void:
	for opponent in _opponents:
		if not is_instance_valid(opponent):
			continue

		var health: int = opponent.get_meta("health", 0)
		if health <= 0:
			continue

		var throw_timer: float = opponent.get_meta("throw_timer", 0.0)
		throw_timer -= delta
		if throw_timer <= 0.0:
			_throw_snowball_at_player(opponent)
			throw_timer = 1.0 + randf() * 2.0
		opponent.set_meta("throw_timer", throw_timer)

		opponent.position.x += randf_range(-50.0, 50.0) * delta
		opponent.position.x = clamp(opponent.position.x, 50.0, 750.0)

func _throw_snowball_at_player(opponent: Node2D) -> void:
	var snowball := _instantiate_snowball()
	snowball.position = opponent.position
	snowball.set_meta("direction", (_player_position - opponent.position).normalized())
	snowball.set_meta("is_player_snowball", false)
	_snowballs.append(snowball)
	add_child(snowball)

func _update_snowballs(delta: float) -> void:
	var to_remove: Array[Node2D] = []
	for snowball in _snowballs:
		if not is_instance_valid(snowball):
			to_remove.append(snowball)
			continue

		var direction: Vector2 = snowball.get_meta("direction", Vector2.ZERO)
		snowball.position += direction * SNOWBALL_SPEED * delta

		if snowball.position.x < 0.0 or snowball.position.x > 800.0 or snowball.position.y < 0.0 or snowball.position.y > 600.0:
			snowball.queue_free()
			to_remove.append(snowball)

	for snowball in to_remove:
		_snowballs.erase(snowball)

func _check_collisions() -> void:
	var hit_snowballs: Array[Node2D] = []
	for snowball in _snowballs:
		if not is_instance_valid(snowball):
			hit_snowballs.append(snowball)
			continue

		var is_player: bool = snowball.get_meta("is_player_snowball", true)
		if is_player:
			for opponent in _opponents:
				if not is_instance_valid(opponent):
					continue

				var health: int = opponent.get_meta("health", 0)
				if health <= 0:
					continue

				if snowball.position.distance_to(opponent.position) < 30.0:
					health -= 1
					opponent.set_meta("health", health)
					snowball.queue_free()
					hit_snowballs.append(snowball)

					if health <= 0:
						add_score(30)
						opponent.visible = false
					else:
						add_score(10)
					break
		elif snowball.position.distance_to(_player_position) < 30.0:
			_health -= 1
			snowball.queue_free()
			hit_snowballs.append(snowball)
			if _health <= 0:
				end_game()

	for snowball in hit_snowballs:
		_snowballs.erase(snowball)

func _input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
		return

	if event is InputEventMouseButton and event.pressed and _can_throw:
		_throw_snowball(event.position)

func _throw_snowball(target: Vector2) -> void:
	var snowball := _instantiate_snowball()
	snowball.position = _player_position
	snowball.set_meta("direction", (target - _player_position).normalized())
	snowball.set_meta("is_player_snowball", true)
	_snowballs.append(snowball)
	add_child(snowball)

	_can_throw = false
	await get_tree().create_timer(_throw_cooldown).timeout
	_can_throw = true

func _instantiate_snowball() -> Node2D:
	if ResourceLoader.exists(SNOWBALL_SCENE_PATH):
		var scene := load(SNOWBALL_SCENE_PATH) as PackedScene
		if scene:
			return scene.instantiate() as Node2D

	var snowball := Node2D.new()
	var rect := ColorRect.new()
	rect.size = Vector2(10, 10)
	rect.position = Vector2(-5, -5)
	rect.color = Color.WHITE
	snowball.add_child(rect)
	return snowball

func _update_ui() -> void:
	if _score_label:
		_score_label.text = "Score: %d" % score
	if _timer_label:
		_timer_label.text = "Time: %d" % int(time_remaining)
	if _health_label:
		var hearts := ""
		for i in range(MAX_HEALTH):
			hearts += "*" if i < _health else "-"
		_health_label.text = "Health: %s" % hearts

func _on_game_started() -> void:
	super._on_game_started()
	if _instruction_label:
		_instruction_label.text = "Fight back before time runs out."

func _on_game_ended(success: bool) -> void:
	super._on_game_ended(success)
	if not _instruction_label:
		return

	if _health <= 0:
		_instruction_label.text = "You were defeated."
	elif success:
		_instruction_label.text = "Round cleared."
	else:
		_instruction_label.text = "Time is up."

func get_result() -> Dictionary:
	var result := super.get_result()
	result["health_remaining"] = _health
	result["opponents_defeated"] = _count_defeated_opponents()
	return result

func _count_defeated_opponents() -> int:
	var defeated := 0
	for opponent in _opponents:
		if is_instance_valid(opponent) and opponent.get_meta("health", 0) <= 0:
			defeated += 1
	return defeated
