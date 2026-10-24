extends CharacterBody2D
class_name Player

# 移动速度
@export var speed: float = 150.0

# 方向枚举
enum Direction { DOWN, UP, LEFT, RIGHT }

# 当前方向
var current_direction: Direction = Direction.DOWN

# 动画状态
var is_walking: bool = false

# NPC交互
var npc_in_range: NPC = null
var nearby_npcs: Array[NPC] = []
var animal_in_range: Animal = null
var nearby_animals: Array[Animal] = []

# 建筑交互
var building_in_range: Node = null

# 对话/商店刚结束时，要先松开交互键才会再次交互（BUG-20）
var _interact_needs_release := false
## After a dialogue closes, a second E/Space within this window is taken as part of
## closing it, not as "talk again" (BUG-26 residual: the line after the last one).
const DIALOGUE_RETALK_COOLDOWN_MS := 600
var _interact_blocked_until_msec := 0
## A direction key still held from walking into the previous map's exit would
## carry the player past the arrival spot (BUG-37); ignore it until released.
var _move_needs_release := false

# 战斗组件
var combat: PlayerCombat

# 工具管理器
var tool_manager: ToolManager = null

# 交互检测区域
var interaction_range: float = 32.0

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var interaction_area: Area2D = $InteractionArea

# 方向对应的静止帧
const IDLE_FRAMES = {
	Direction.DOWN: 0,
	Direction.UP: 6,
	Direction.LEFT: 2,
	Direction.RIGHT: 4
}

func _ready() -> void:
	# 初始化相机
	if camera:
		camera.enabled = true
		camera.make_current()
	# 设置初始帧
	if sprite:
		sprite.frame = IDLE_FRAMES[current_direction]
	# 初始化战斗系统
	_setup_combat()
	# 初始化工具管理器
	_setup_tool_manager()
	# 设置交互区域
	_setup_interaction_area()
	# 添加到玩家组
	add_to_group("player")
	GameManager.register_player(self)
	_move_needs_release = InputManager.get_movement_vector() != Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		# The E/Space press that closes a dialogue or shop is still "just pressed"
		# when control comes back here; without this it re-talks to the NPC and the
		# shop reopens (BUG-20). Wait until the key is released.
		_interact_needs_release = true
		if GameManager.current_state == GameManager.GameState.DIALOGUE:
			_interact_blocked_until_msec = Time.get_ticks_msec() + DIALOGUE_RETALK_COOLDOWN_MS
		velocity = Vector2.ZERO
		# 对话/商店等非游戏状态下停在原地，不要原地踏步。
		is_walking = false
		_update_animation()
		return
	# 挥工具期间站定，挥完立刻恢复（按住的方向键会直接接着走）
	if is_tool_locked():
		velocity = Vector2.ZERO
		is_walking = false
		_update_animation()
		_handle_tool_input()
		return
	# 获取输入方向
	var input_direction := _get_input_direction()
	if _move_needs_release:
		if input_direction == Vector2.ZERO:
			_move_needs_release = false
		else:
			input_direction = Vector2.ZERO

	# 更新速度
	velocity = input_direction * speed

	# 更新方向和动画
	_update_direction(input_direction)
	_update_animation()

	# 移动
	var start_pos := global_position
	move_and_slide()
	_update_npc_squeeze(input_direction, start_pos)

	# 处理NPC交互
	_handle_interaction()

	# 处理战斗输入
	_handle_combat_input()

	# 处理工具切换输入
	_handle_tool_input()

func _get_input_direction() -> Vector2:
	return InputManager.get_movement_vector()

func _update_direction(input_direction: Vector2) -> void:
	if input_direction == Vector2.ZERO:
		is_walking = false
		return

	is_walking = true

	var previous_direction := current_direction
	# 根据主要方向更新当前方向
	if abs(input_direction.x) > abs(input_direction.y):
		current_direction = Direction.LEFT if input_direction.x < 0 else Direction.RIGHT
	else:
		current_direction = Direction.UP if input_direction.y < 0 else Direction.DOWN
	if current_direction != previous_direction and tool_manager:
		tool_manager.update_pose()

func _update_animation() -> void:
	var anim_prefix := _get_animation_prefix()
	var anim_name := anim_prefix + ("_walk" if is_walking else "_idle")

	if animation_player:
		if is_walking and animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
		else:
			animation_player.stop()
			# 设置静止帧（上/下走路循环会镜像跨步帧，停下时还原）
			if sprite and IDLE_FRAMES.has(current_direction):
				sprite.frame = IDLE_FRAMES[current_direction]
				sprite.flip_h = false

func _get_animation_prefix() -> String:
	match current_direction:
		Direction.DOWN:
			return "down"
		Direction.LEFT:
			return "left"
		Direction.RIGHT:
			return "right"
		Direction.UP:
			return "up"
		_:
			return "down"

# 设置玩家位置（用于传送等）
func set_spawn_position(pos: Vector2) -> void:
	global_position = pos

# 处理NPC交互
func _handle_interaction() -> void:
	if _interact_needs_release:
		# A quick tap (xdotool, fast fingers) delivers press and release in the same
		# frame: the key is never seen held, but is_action_just_pressed is still true
		# on the first PLAYING physics frame, so the closing press restarted the
		# dialogue (BUG-26). Swallow that press too; Space is also ui_accept.
		if _interact_key_active():
			return
		_interact_needs_release = false
	if Time.get_ticks_msec() < _interact_blocked_until_msec:
		return
	if Input.is_action_just_pressed("interact"):
		_refresh_nearest_npc()
		_refresh_nearest_animal()
		# 优先处理NPC交互
		if npc_in_range and npc_in_range.interactable:
			_interact_with_npc()
		elif building_in_range and building_in_range.has_method("interact"):
			building_in_range.interact()
		else:
			# 使用工具进行交互
			_use_tool_on_target()

func _interact_key_active() -> bool:
	for action in [&"interact", &"ui_accept"]:
		if Input.is_action_pressed(action) or Input.is_action_just_pressed(action):
			return true
	return false

## 使用工具与目标交互
func _use_tool_on_target() -> void:
	if tool_manager == null:
		return

	_play_use_feedback()

	# 农场：按格子选“脚下那格的前一格”（BUG：四个方向只锄出 3 格）
	var farm := _find_farm_scene()
	var facing_coord := Vector2i(-1, -1)
	if farm:
		facing_coord = farm.get_facing_plot_coord(global_position, _get_direction_vector())
		if facing_coord.x >= 0:
			farm.perform_farm_action(facing_coord, tool_manager.get_current_tool_type())
			return
		# BUG-9: 面向田地网格外（草地/土路）时锄头要有提示。不翻地、不扣体力。其它工具仍走下面的探测。
		if tool_manager.get_current_tool_type() == ToolManager.ToolType.HOE:
			UIManager.show_toast("这里不能耕地", {}, "info")
			return

	# 获取面向位置的目标
	var target_pos = global_position + _get_direction_vector() * interaction_range

	# 检测目标位置的土壤
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results = space_state.intersect_point(query)

	for result in results:
		var collider = result.collider
		if collider is FarmPlot:
			if farm:
				continue  # facing out of the field: don't fall back to the plot under our own feet
			var scene := get_tree().current_scene
			if scene and scene.has_method("perform_farm_action"):
				scene.perform_farm_action(collider.grid_coord, tool_manager.get_current_tool_type())
			return
		if collider is Soil:
			tool_manager.use_tool(collider)
			return
		elif collider.get_parent() is Soil:
			tool_manager.use_tool(collider.get_parent())
			return

	# 如果没有找到土壤，尝试使用工具（如钓鱼）
	tool_manager.use_tool(null)

## BUG-21: villagers are solid, but when they crowd the player (three of them share
## the plaza target by the fountain) WASD looked dead. Like Stardew, pushing into a
## villager for a moment lets the player squeeze past; it's solid again once apart.
const NPC_SQUEEZE_SECONDS := 0.25
const NPC_SQUEEZE_CLEAR_DISTANCE := 40.0
var _npc_push_time := {}  # NPC -> seconds spent pushing into it without getting anywhere
var _npc_passing: Array[PhysicsBody2D] = []

func _update_npc_squeeze(input_direction: Vector2, start_pos: Vector2) -> void:
	var delta := get_physics_process_delta_time()
	for i in range(_npc_passing.size() - 1, -1, -1):
		var npc := _npc_passing[i]
		if not is_instance_valid(npc) or npc.global_position.distance_to(global_position) > NPC_SQUEEZE_CLEAR_DISTANCE:
			if is_instance_valid(npc):
				remove_collision_exception_with(npc)
				npc.remove_collision_exception_with(self)
			_npc_passing.remove_at(i)
	if input_direction == Vector2.ZERO:
		_npc_push_time.clear()
		return
	var expected := speed * delta
	var stuck := global_position.distance_to(start_pos) < expected * 0.5
	var pushing := {}
	for i in get_slide_collision_count():
		var npc := get_slide_collision(i).get_collider() as NPC
		if npc and stuck and not _npc_passing.has(npc):
			pushing[npc] = float(_npc_push_time.get(npc, 0.0)) + delta
	_npc_push_time = pushing
	for npc in pushing:
		if pushing[npc] >= NPC_SQUEEZE_SECONDS:
			add_collision_exception_with(npc)
			npc.add_collision_exception_with(self)
			_npc_passing.append(npc)
			_npc_push_time.erase(npc)

## Farm scene that owns the plot grid: an ancestor (or the current scene) with get_facing_plot_coord.
func _find_farm_scene() -> Node:
	var node: Node = get_parent()
	while node:
		if node.has_method("get_facing_plot_coord"):
			return node
		node = node.get_parent()
	var scene := get_tree().current_scene
	return scene if scene and scene.has_method("get_facing_plot_coord") else null

## 使用工具/物品时的动作反馈：手里的工具朝面向方向挥一下，身体往前一探。
## 只动 ToolManager 的旋转和 Sprite 的位置/缩放，结束后复原，不影响移动和判定。
var _use_tween: Tween = null
const USE_LUNGE := 4.0
## Swing = 0.07 + 0.09 + 0.12 s (see _play_use_feedback). The player can't walk meanwhile.
const TOOL_SWING_SECONDS := 0.28
var _tool_lock_until_msec := 0

func is_tool_locked() -> bool:
	return Time.get_ticks_msec() < _tool_lock_until_msec

func _play_use_feedback() -> void:
	_tool_lock_until_msec = Time.get_ticks_msec() + int(TOOL_SWING_SECONDS * 1000.0)
	if sprite == null:
		return
	if _use_tween and _use_tween.is_valid():
		_use_tween.kill()
	var base_scale := SPRITE_BASE_SCALE
	sprite.position = Vector2.ZERO
	sprite.scale = base_scale
	var forward := _get_direction_vector()
	var swing := -1.0 if current_direction == Direction.LEFT else 1.0
	_use_tween = create_tween()
	# 抬手（0.07s）→ 挥下（0.09s）→ 收回（0.12s）
	_use_tween.set_parallel(true)
	_use_tween.tween_property(sprite, "position", -forward * 1.0, 0.07)
	if tool_manager:
		tool_manager.rotation = 0.0
		_use_tween.tween_property(tool_manager, "rotation", -0.5 * swing, 0.07)
	_use_tween.chain().tween_property(sprite, "position", forward * USE_LUNGE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_use_tween.tween_property(sprite, "scale", base_scale * Vector2(1.06, 0.94), 0.09)
	if tool_manager:
		_use_tween.tween_property(tool_manager, "rotation", 1.0 * swing, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_use_tween.chain().tween_property(sprite, "position", Vector2.ZERO, 0.12)
	_use_tween.tween_property(sprite, "scale", base_scale, 0.12)
	if tool_manager:
		_use_tween.tween_property(tool_manager, "rotation", 0.0, 0.12)

## Idle breathing: a slow, subtle stretch of the sprite while standing still.
## Visual only (Sprite2D scale/position); the body, collision, y-sort origin and the
## tool holder are untouched. The feet stay put because the stretch is anchored at
## the frame bottom. Off while walking, swinging a tool, outside PLAYING (dialogue,
## shop, menus) and with reduce_motion.
const BREATH_PERIOD := 2.2
const BREATH_AMOUNT := 0.025
const SPRITE_BASE_SCALE := Vector2(1, 1)  # Villager3 sheet is already 64px (16×4)
const SPRITE_FEET_Y := 32.0  # frame bottom, in texture pixels below the sprite centre
var _breath_time := 0.0
var _breathing := false

func _process(delta: float) -> void:
	_update_idle_breathing(delta)

func is_breathing() -> bool:
	return _breathing

func _update_idle_breathing(delta: float) -> void:
	if sprite == null:
		return
	var swinging := _use_tween != null and _use_tween.is_running()
	var reduce_motion := UserSettings != null and bool(UserSettings.get_value("accessibility", "reduce_motion", false))
	var idle := (GameManager.current_state == GameManager.GameState.PLAYING
		and not is_walking and not is_tool_locked() and not swinging and not reduce_motion)
	if not idle:
		if _breathing:
			_breathing = false
			_breath_time = 0.0
			if not swinging:  # the swing tween owns the sprite while it runs
				sprite.scale = SPRITE_BASE_SCALE
				sprite.position = Vector2.ZERO
		return
	_breathing = true
	_breath_time = fmod(_breath_time + delta, BREATH_PERIOD)
	# 0 at the start of each cycle, so starting/stopping never pops.
	var k := BREATH_AMOUNT * 0.5 * (1.0 - cos(TAU * _breath_time / BREATH_PERIOD))
	sprite.scale = Vector2(SPRITE_BASE_SCALE.x, SPRITE_BASE_SCALE.y * (1.0 + k))
	sprite.position = Vector2(0.0, -SPRITE_FEET_Y * SPRITE_BASE_SCALE.y * k)

# 与NPC交互
func _interact_with_npc() -> void:
	if not npc_in_range:
		return

	# NPC面向玩家
	npc_in_range.face_position(global_position)
	npc_in_range.interact()

	print("[Player] Interacting with %s" % npc_in_range.npc_name)

	# 发送交互信号
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.social:
		event_bus.social.npc_interacted.emit(npc_in_range)

## 初始化战斗系统
func _setup_combat() -> void:
	combat = PlayerCombat.new()
	add_child(combat)
	combat.initialize(self)
	print("[Player] Combat system initialized")

## 初始化工具管理器
func _setup_tool_manager() -> void:
	tool_manager = ToolManager.new()
	tool_manager.name = "ToolManager"
	add_child(tool_manager)
	tool_manager.initialize(self)
	print("[Player] Tool manager initialized")

## 设置交互区域
func _setup_interaction_area() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)

## 交互区域进入
func _on_interaction_body_entered(body: Node) -> void:
	if body is NPC:
		register_nearby_npc(body)

## 交互区域离开
func _on_interaction_body_exited(body: Node) -> void:
	if body is NPC:
		unregister_nearby_npc(body)

func register_nearby_npc(npc: NPC) -> void:
	if npc == null or nearby_npcs.has(npc):
		return
	nearby_npcs.append(npc)
	_refresh_nearest_npc()

func unregister_nearby_npc(npc: NPC) -> void:
	nearby_npcs.erase(npc)
	_refresh_nearest_npc()

func _refresh_nearest_npc() -> void:
	var nearest: NPC = null
	var nearest_distance := INF
	for npc in nearby_npcs.duplicate():
		if not is_instance_valid(npc):
			nearby_npcs.erase(npc)
			continue
		var distance := global_position.distance_squared_to(npc.global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	npc_in_range = nearest

func register_nearby_animal(animal: Animal) -> void:
	if animal == null or nearby_animals.has(animal):
		return
	nearby_animals.append(animal)
	_refresh_nearest_animal()

func unregister_nearby_animal(animal: Animal) -> void:
	nearby_animals.erase(animal)
	_refresh_nearest_animal()

func _refresh_nearest_animal() -> void:
	var nearest: Animal = null
	var nearest_distance := INF
	for animal in nearby_animals.duplicate():
		if not is_instance_valid(animal):
			nearby_animals.erase(animal)
			continue
		var distance := global_position.distance_squared_to(animal.global_position)
		if distance < nearest_distance:
			nearest = animal
			nearest_distance = distance
	animal_in_range = nearest

## 交互区域（Area2D）进入
func _on_interaction_area_entered(area: Area2D) -> void:
	# 可以在这里处理与Area2D的交互
	pass

## 交互区域（Area2D）离开
func _on_interaction_area_exited(area: Area2D) -> void:
	pass

## 获取面向方向的向量
func get_direction() -> Vector2:
	return _get_direction_vector()

## 处理战斗输入
func _handle_combat_input() -> void:
	# 战斗未纳入当前可玩切片。
	return

## 处理工具切换输入
func _handle_tool_input() -> void:
	if Input.is_action_just_pressed("tool_previous"):
		tool_manager.previous_tool()
	elif Input.is_action_just_pressed("tool_next"):
		tool_manager.next_tool()

## 获取方向向量
func _get_direction_vector() -> Vector2:
	match current_direction:
		Direction.DOWN:
			return Vector2.DOWN
		Direction.UP:
			return Vector2.UP
		Direction.LEFT:
			return Vector2.LEFT
		Direction.RIGHT:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

## 受到伤害
func take_damage(damage: int, source: Node = null) -> void:
	if combat:
		combat.take_damage(damage, source)

## 治疗
func heal(amount: int) -> void:
	if combat:
		combat.heal(amount)

## 获取当前生命值
func get_current_health() -> int:
	if combat:
		return combat.current_health
	return 0

## 获取最大生命值
func get_max_health() -> int:
	if combat:
		return combat.max_health
	return 0
