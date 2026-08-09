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

func _physics_process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		velocity = Vector2.ZERO
		_update_animation()
		return
	# 获取输入方向
	var input_direction := _get_input_direction()

	# 更新速度
	velocity = input_direction * speed

	# 更新方向和动画
	_update_direction(input_direction)
	_update_animation()

	# 移动
	move_and_slide()

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

	# 根据主要方向更新当前方向
	if abs(input_direction.x) > abs(input_direction.y):
		current_direction = Direction.LEFT if input_direction.x < 0 else Direction.RIGHT
	else:
		current_direction = Direction.UP if input_direction.y < 0 else Direction.DOWN

func _update_animation() -> void:
	var anim_prefix := _get_animation_prefix()
	var anim_name := anim_prefix + ("_walk" if is_walking else "_idle")

	if animation_player:
		if is_walking and animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
		else:
			animation_player.stop()
			# 设置静止帧
			if sprite and IDLE_FRAMES.has(current_direction):
				sprite.frame = IDLE_FRAMES[current_direction]

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

## 使用工具与目标交互
func _use_tool_on_target() -> void:
	if tool_manager == null:
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
