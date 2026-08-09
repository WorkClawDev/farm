extends Node2D
class_name Mine

## Mine - 矿洞场景
## 多层矿洞系统，包含梯子和矿石资源

const MineConstants = preload("res://src/core/constants/MineConstants.gd")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")
const PickaxeScene = preload("res://src/entities/tools/Pickaxe.tscn")
const OreScene = preload("res://src/world/objects/Ore.tscn")

# 矿洞层级配置
@export var total_floors: int = 10
@export var current_floor: int = 1

# 节点引用
@onready var map_root: EditableMap2D = $MineMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")
@onready var ladder_down: Area2D = $Ladders/LadderDown
@onready var ladder_up: Area2D = $Ladders/LadderUp
@onready var ores_container: Node2D = $Ores

# UI组件
var time_display: Control
var ui_canvas: CanvasLayer

# 工具
var pickaxe_tool: Pickaxe

# 矿石刷新配置
var ore_respawn_days: int = 3
var last_respawn_day: int = 0

# 当前层矿石列表
var floor_ores: Array[Ore] = []

# 信号
signal floor_changed(new_floor: int)
signal ore_mined(ore_type: String, quantity: int, quality: int)


func _ready() -> void:
	print("[Mine] Scene loaded, Floor: ", current_floor)
	_setup_map()
	_setup_ui()
	_setup_tools()
	_setup_ladders()
	_setup_ores()
	_connect_signals()


func _setup_map() -> void:
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[MineMap:%s] %s" % [issue.code, issue.message])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		map_root.apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
	print("[Mine] Authored map loaded: ", map_root.map_id)


func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	hud.add_child(HotkeyBarScene.instantiate())
	hud.add_child(ToolDisplayScene.instantiate())
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)
	print("[Mine] Unified HUD added")


func _setup_tools() -> void:
	pickaxe_tool = PickaxeScene.instantiate()
	add_child(pickaxe_tool)
	print("[Mine] Pickaxe tool initialized")


func _setup_ladders() -> void:
	if ladder_down:
		ladder_down.body_entered.connect(_on_ladder_down_entered)
	if ladder_up:
		ladder_up.body_entered.connect(_on_ladder_up_entered)
	print("[Mine] Ladders configured")


func _setup_ores() -> void:
	# 清理现有矿石
	for ore in floor_ores:
		ore.queue_free()
	floor_ores.clear()

	# 根据当前层生成矿石
	_generate_floor_ores()
	print("[Mine] Generated ores for floor ", current_floor)


func _generate_floor_ores() -> void:
	# 根据层级决定矿石类型和数量
	var ore_count: int = _get_ore_count_for_floor()
	var available_ores: Array[String] = _get_available_ores_for_floor()

	for i in range(ore_count):
		var ore_type: String = available_ores.pick_random()
		var position: Vector2 = _get_random_ore_position()

		var ore: Ore = OreScene.instantiate()
		ore.setup(ore_type, current_floor)
		ore.global_position = position
		ore.ore_mined.connect(_on_ore_mined)

		ores_container.add_child(ore)
		floor_ores.append(ore)


func _get_ore_count_for_floor() -> int:
	# 越深矿石越多
	return 5 + current_floor * 2


func _get_available_ores_for_floor() -> Array[String]:
	var ores: Array[String] = []

	# 铜矿 - 所有层都有
	ores.append("copper")

	# 铁矿 - 2层起
	if current_floor >= 2:
		ores.append("iron")

	# 银矿 - 4层起
	if current_floor >= 4:
		ores.append("silver")

	# 金矿 - 6层起
	if current_floor >= 6:
		ores.append("gold")

	# 宝石 - 8层起
	if current_floor >= 8:
		ores.append("gem")

	# 水晶 - 10层起
	if current_floor >= 10:
		ores.append("crystal")

	return ores


func _get_random_ore_position() -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var protected_points: Array[Vector2] = [
		player_spawn.global_position if player_spawn else Vector2(400, 300),
		ladder_up.global_position if ladder_up else Vector2(100, 300),
		ladder_down.global_position if ladder_down else Vector2(700, 300),
	]
	for _attempt in range(32):
		var candidate := Vector2(
			rng.randf_range(MineConstants.ORE_SPAWN_X_MIN, MineConstants.ORE_SPAWN_X_MAX),
			rng.randf_range(MineConstants.ORE_SPAWN_Y_MIN, MineConstants.ORE_SPAWN_Y_MAX)
		)
		var blocked := false
		for protected_point in protected_points:
			if candidate.distance_to(protected_point) < 92.0:
				blocked = true
				break
		if blocked:
			continue
		for existing_ore in floor_ores:
			if is_instance_valid(existing_ore) and candidate.distance_to(existing_ore.global_position) < 68.0:
				blocked = true
				break
		if not blocked:
			return candidate

	return Vector2(250 + floor_ores.size() * 70, 160)


func _connect_signals() -> void:
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
	if EventBus:
		get_node("/root/EventBus").player.player_interacted.connect(_on_player_interacted)


func _on_ladder_down_entered(body: Node2D) -> void:
	if body is Player and current_floor < total_floors:
		_go_to_floor(current_floor + 1)


func _on_ladder_up_entered(body: Node2D) -> void:
	if body is Player:
		if current_floor > 1:
			_go_to_floor(current_floor - 1)
		else:
			# 返回地面（农场或村庄）
			_exit_mine()


func _go_to_floor(floor: int) -> void:
	current_floor = floor
	print("[Mine] Moving to floor ", floor)

	# 更新梯子可见性
	if ladder_up:
		ladder_up.visible = current_floor > 1

	# 重新生成矿石
	_setup_ores()

	# 重置玩家位置
	if player_spawn:
		# 这里应该通知玩家移动到出生点
		get_node("/root/EventBus").player.spawn_point_changed.emit("mine_floor_" + str(floor))

	floor_changed.emit(current_floor)


func _exit_mine() -> void:
	print("[Mine] Exiting mine to surface")
	SceneTransition.transition_to("res://src/world/maps/Village.tscn", "from_mine")


func _on_day_changed(new_day: int) -> void:
	print("[Mine] Day changed to: ", new_day)

	# 检查是否需要刷新矿石
	if new_day - last_respawn_day >= ore_respawn_days:
		_respawn_ores()
		last_respawn_day = new_day


func _respawn_ores() -> void:
	print("[Mine] Respawning ores")

	# 重新生成已挖掘的矿石
	for ore in floor_ores:
		if ore.is_depleted():
			ore.respawn()

	# 如果矿石太少，生成新的
	var active_ores := floor_ores.filter(func(o: Ore): return not o.is_depleted())
	if active_ores.size() < _get_ore_count_for_floor() / 2:
		_generate_floor_ores()


func _on_player_interacted(target: Node) -> void:
	if target is Ore and pickaxe_tool:
		var ore := target as Ore
		if ore.can_mine():
			pickaxe_tool.use(ore)


func _on_ore_mined(ore_type: String, quantity: int, quality: int) -> void:
	print("[Mine] Ore mined: ", ore_type, " x", quantity, " quality:", quality)
	ore_mined.emit(ore_type, quantity, quality)

	# 通知EventBus
	get_node("/root/EventBus").inventory.item_added.emit(ore_type, quantity)


func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position if player_spawn else MineConstants.DEFAULT_PLAYER_FALLBACK_POSITION


## 获取当前层信息
func get_floor_info() -> Dictionary:
	return {
		"current_floor": current_floor,
		"total_floors": total_floors,
		"ore_count": floor_ores.size(),
		"active_ores": floor_ores.filter(func(o: Ore): return not o.is_depleted()).size()
	}


## 保存矿洞状态
func save_state() -> Dictionary:
	var ore_states: Array = []
	for ore in floor_ores:
		ore_states.append(ore.save_state())

	return {
		"current_floor": current_floor,
		"last_respawn_day": last_respawn_day,
		"ores": ore_states
	}


## 加载矿洞状态
func load_state(data: Dictionary) -> void:
	current_floor = data.get("current_floor", 1)
	last_respawn_day = data.get("last_respawn_day", 0)

	var ore_states: Array = data.get("ores", [])
	for i in range(min(ore_states.size(), floor_ores.size())):
		floor_ores[i].load_state(ore_states[i])
