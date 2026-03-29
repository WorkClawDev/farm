extends CharacterBody2D
class_name NPC

## NPC - 非玩家角色基类
## 处理移动、动画、碰撞检测、玩家交互和日程AI

# NPC 配置
@export var npc_id: String = "npc_001"
@export var npc_name: String = "NPC"
@export var move_speed: float = 80.0
@export var interactable: bool = true
@export var default_dialogue: String = ""  # 默认对话键

# 方向枚举
enum Direction { DOWN, UP, LEFT, RIGHT }

# 当前状态
var current_direction: Direction = Direction.DOWN
var is_walking: bool = false
var is_interacting: bool = false
var is_facing_player: bool = false

# 日程系统
var schedule: NPCSchedule = null
var current_activity: int = 0  # NPCSchedule.ActivityType.IDLE

# 移动目标
var target_position: Vector2 = Vector2.ZERO
var has_target: bool = false
var current_location_id: String = ""

# 空闲行为
var idle_timer: float = 0.0
var is_doing_idle_action: bool = false

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D if has_node("NavigationAgent2D") else null

# 信号
signal interacted(npc: NPC)
signal direction_changed(new_direction: Direction)
signal activity_changed(activity_type: String)
signal location_reached(location_id: String)
signal dialogue_started
signal dialogue_ended

# 方向对应的静止帧 (用于精灵图)
const IDLE_FRAMES = {
	Direction.DOWN: 0,
	Direction.UP: 6,
	Direction.LEFT: 2,
	Direction.RIGHT: 4
}

func _ready() -> void:
	_setup_interaction_area()
	_load_npc_data()
	_setup_animation()
	_connect_time_signals()
	_connect_dialogue_signals()
	print("[NPC] %s initialized" % npc_name)

func _physics_process(delta: float) -> void:
	if is_interacting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 更新日程状态
	_update_schedule()

	if has_target:
		_move_towards_target(delta)
	else:
		velocity = Vector2.ZERO
		_process_idle_behavior(delta)

	_update_animation()
	move_and_slide()

## 连接时间信号
func _connect_time_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if not time_manager.time_changed.is_connected(_on_time_changed):
			time_manager.time_changed.connect(_on_time_changed)
		if not time_manager.hour_changed.is_connected(_on_hour_changed):
			time_manager.hour_changed.connect(_on_hour_changed)

## 更新日程状态
func _update_schedule() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if schedule and time_manager:
		schedule.update(
			time_manager.current_time,
			time_manager.current_day,
			time_manager.current_season
		)

		# 检查是否需要移动到新地点
		if schedule.should_move_to_destination():
			var dest := schedule.get_destination()
			if dest != Vector2.ZERO:
				move_to(dest)

		current_activity = schedule.current_activity

## 设置交互区域
func _setup_interaction_area() -> void:
	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.connect(_on_interaction_area_body_exited)

## 从JSON加载NPC数据
func _load_npc_data() -> void:
	var data_path = "res://data/npcs.json"
	if not ResourceLoader.exists(data_path):
		return

	var file = FileAccess.open(data_path, FileAccess.READ)
	if not file:
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("[NPC] Failed to parse npcs.json")
		return

	var data = json.get_data()
	if not data.has("npcs"):
		return

	for npc_data in data["npcs"]:
		if npc_data["id"] == npc_id:
			_apply_npc_data(npc_data)
			break

## 应用NPC配置数据
func _apply_npc_data(data: Dictionary) -> void:
	npc_name = data.get("name", npc_name)
	# 初始化日程系统
	if data.has("schedule"):
		schedule = NPCSchedule.new(data)
		_connect_schedule_signals()

## 连接日程信号
func _connect_schedule_signals() -> void:
	if schedule:
		if not schedule.schedule_changed.is_connected(_on_schedule_changed):
			schedule.schedule_changed.connect(_on_schedule_changed)
		if not schedule.destination_reached.is_connected(_on_destination_reached):
			schedule.destination_reached.connect(_on_destination_reached)
		if not schedule.activity_changed.is_connected(_on_activity_changed):
			schedule.activity_changed.connect(_on_activity_changed)

## 设置动画
func _setup_animation() -> void:
	if sprite and IDLE_FRAMES.has(current_direction):
		sprite.frame = IDLE_FRAMES[current_direction]

## 移动到目标位置
func move_to(target: Vector2) -> void:
	target_position = target
	has_target = true

## 向目标移动
func _move_towards_target(_delta: float) -> void:
	var direction_vector = target_position - global_position
	var distance = direction_vector.length()

	if distance < 5.0:
		_reached_destination()
		return

	is_walking = true
	direction_vector = direction_vector.normalized()
	velocity = direction_vector * move_speed

	_update_direction_from_velocity(direction_vector)

## 处理空闲行为
func _process_idle_behavior(delta: float) -> void:
	if is_interacting or is_walking:
		idle_timer = 0.0
		is_doing_idle_action = false
		return

	idle_timer += delta

	# 每5秒执行一次空闲动作
	if not is_doing_idle_action and idle_timer >= 5.0:
		_do_idle_action()
		idle_timer = 0.0

## 执行空闲动作
func _do_idle_action() -> void:
	if schedule and schedule.is_sleeping():
		return

	is_doing_idle_action = true

	# 随机选择空闲动作
	var action: int = randi() % 4
	match action:
		0:  # 转向
			current_direction = randi() % 4 as Direction
		1:  # 小幅移动
			var offset := Vector2(randf_range(-10, 10), randf_range(-10, 10))
			global_position += offset
		2, 3:  # 等待
			pass

	await get_tree().create_timer(1.5).timeout
	is_doing_idle_action = false

## 到达目的地
func _reached_destination() -> void:
	has_target = false
	is_walking = false
	velocity = Vector2.ZERO

	if schedule:
		schedule.arrived_at_destination()
		current_location_id = schedule.get_destination_id()
		location_reached.emit(current_location_id)

## 根据速度方向更新朝向
func _update_direction_from_velocity(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	var new_direction: Direction
	if abs(dir.x) > abs(dir.y):
		new_direction = Direction.LEFT if dir.x < 0 else Direction.RIGHT
	else:
		new_direction = Direction.UP if dir.y < 0 else Direction.DOWN

	if new_direction != current_direction:
		current_direction = new_direction
		direction_changed.emit(current_direction)

## 更新动画状态
func _update_animation() -> void:
	if not animation_player:
		return

	var anim_prefix := _get_animation_prefix()
	var anim_name := anim_prefix + ("_walk" if is_walking else "_idle")

	if animation_player.has_animation(anim_name):
		if is_walking:
			animation_player.play(anim_name)
		else:
			animation_player.stop()
			if sprite and IDLE_FRAMES.has(current_direction):
				sprite.frame = IDLE_FRAMES[current_direction]
	else:
		animation_player.stop()
		if sprite and IDLE_FRAMES.has(current_direction):
			sprite.frame = IDLE_FRAMES[current_direction]

## 获取动画前缀
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

## 设置NPC朝向
func set_direction(direction: Direction) -> void:
	current_direction = direction
	if sprite and IDLE_FRAMES.has(direction):
		sprite.frame = IDLE_FRAMES[direction]

## 面向玩家
func face_position(target_pos: Vector2) -> void:
	var dir_vector = target_pos - global_position
	var new_direction: Direction

	if abs(dir_vector.x) > abs(dir_vector.y):
		new_direction = Direction.LEFT if dir_vector.x < 0 else Direction.RIGHT
	else:
		new_direction = Direction.UP if dir_vector.y < 0 else Direction.DOWN

	set_direction(new_direction)

## 开始交互
func start_interaction() -> void:
	is_interacting = true
	is_walking = false
	velocity = Vector2.ZERO

## 结束交互
func end_interaction() -> void:
	is_interacting = false

## 玩家进入交互区域
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player and interactable:
		body.npc_in_range = self
		print("[NPC] Player in range of %s" % npc_name)

## 玩家离开交互区域
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		if body.npc_in_range == self:
			body.npc_in_range = null
		print("[NPC] Player left range of %s" % npc_name)

## 获取NPC信息
func get_npc_info() -> Dictionary:
	return {
		"id": npc_id,
		"name": npc_name,
		"direction": current_direction,
		"position": global_position
	}

## 保存NPC状态
func save_state() -> Dictionary:
	return {
		"npc_id": npc_id,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"direction": current_direction,
		"is_interacting": is_interacting
	}

## 加载NPC状态
func load_state(state: Dictionary) -> void:
	if state.has("position"):
		global_position = Vector2(state["position"]["x"], state["position"]["y"])
	if state.has("direction"):
		set_direction(state["direction"])

## 连接对话信号
func _connect_dialogue_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if not event_bus.dialogue_ended.is_connected(_on_dialogue_ended):
			event_bus.dialogue_ended.connect(_on_dialogue_ended)

## 时间变化回调
func _on_time_changed(new_time: float) -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if schedule and time_manager:
		schedule.update(new_time, time_manager.current_day, time_manager.current_season)

## 小时变化回调
func _on_hour_changed(_new_hour: int) -> void:
	pass

## 日程变化回调
func _on_schedule_changed(new_activity: Dictionary) -> void:
	var location_id: String = new_activity.get("location_id", "")
	var position_data = new_activity.get("position", Vector2.ZERO)
	var position: Vector2 = position_data if position_data is Vector2 else Vector2(position_data.get("x", 0.0), position_data.get("y", 0.0))

	if position != Vector2.ZERO:
		move_to(position)

	activity_changed.emit(new_activity.get("activity", "idle"))

	# 通过 EventBus 发送通知
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.npc_activity_changed.emit(npc_id, new_activity)

## 到达目的地回调
func _on_destination_reached(location_id: String) -> void:
	print("[NPC] %s arrived at %s" % [npc_name, location_id])
	current_location_id = location_id

## 活动变化回调
func _on_activity_changed(activity_type: String) -> void:
	activity_changed.emit(activity_type)

## 对话结束回调
func _on_dialogue_ended(npc_id_param: String) -> void:
	if npc_id_param == npc_id:
		end_interaction()

## 检查是否可交互
func can_interact() -> bool:
	if not schedule:
		return interactable
	return interactable and schedule.is_interactable()

## 获取当前活动
func get_current_activity() -> String:
	if schedule:
		return schedule.get_activity_name()
	return "idle"

## 检查是否在睡觉
func is_sleeping() -> bool:
	if schedule:
		return schedule.is_sleeping()
	return false

## 检查是否在工作
func is_working() -> bool:
	if schedule:
		return schedule.is_working()
	return false

## 打开送礼菜单
func open_gift_menu() -> void:
	if not interactable:
		return

	print("[NPC] Gift menu requested for %s" % npc_name)

## 获取问候对话
func get_greeting_dialogue() -> Array:
	var npc_data := _get_npc_data_from_json()
	if npc_data.is_empty():
		return ["你好！"]

	var dialogues: Dictionary = npc_data.get("dialogues", {})
	var greetings = dialogues.get("greeting", ["你好！"])

	if typeof(greetings) == TYPE_ARRAY:
		if greetings.is_empty():
			return ["你好！"]
		return [greetings[randi() % greetings.size()]]

	return ["你好！"]

## 获取送礼反应对话
func get_gift_dialogue(reaction: int) -> String:
	var npc_data := _get_npc_data_from_json()
	if npc_data.is_empty():
		return "..."

	var dialogues: Dictionary = npc_data.get("dialogues", {})

	var key := "gift_neutral"
	var gift_system = get_node_or_null("/root/GiftSystem")
	if gift_system:
		match reaction:
			gift_system.ReactionType.LOVE: key = "gift_loved"
			gift_system.ReactionType.LIKE: key = "gift_liked"
			gift_system.ReactionType.DISLIKE: key = "gift_disliked"
			gift_system.ReactionType.HATE: key = "gift_hated"

	var dialogue = dialogues.get(key, "...")
	if typeof(dialogue) == TYPE_STRING:
		return dialogue
	elif typeof(dialogue) == TYPE_ARRAY and not dialogue.is_empty():
		return dialogue[randi() % dialogue.size()]

	return "..."

## 从JSON获取NPC数据
func _get_npc_data_from_json() -> Dictionary:
	var data_path := "res://data/npcs.json"
	if not ResourceLoader.exists(data_path):
		return {}

	var file := FileAccess.open(data_path, FileAccess.READ)
	if not file:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}

	var data: Dictionary = json.get_data()
	if not data.has("npcs"):
		return {}

	for npc_data in data["npcs"]:
		if npc_data.get("id", "") == npc_id:
			return npc_data

	return {}

## 获取好友度心数
func get_friendship_hearts() -> int:
	var gift_system = get_node_or_null("/root/GiftSystem")
	if gift_system:
		return gift_system.get_friendship_hearts(npc_id)
	return 0

## 检查是否是生日
func is_birthday() -> bool:
	var gift_system = get_node_or_null("/root/GiftSystem")
	if gift_system:
		return gift_system.is_npc_birthday(npc_id)
	return false

## 获取NPC偏好预览
func get_preference_for_item(item_id: String) -> String:
	var gift_system = get_node_or_null("/root/GiftSystem")
	if gift_system:
		return gift_system.get_preference_preview(npc_id, item_id)
	return "一般"

## 交互处理
func interact() -> void:
	if not can_interact():
		return

	start_interaction()
	interacted.emit(self)

	# 发射对话开始事件
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.dialogue_started.emit(npc_id)
