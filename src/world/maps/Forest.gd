extends Node2D
class_name Forest

## Forest - 森林场景
## 可采集野果、蘑菇、草药等野生资源

const ForestConstants = preload("res://src/core/constants/ForestConstants.gd")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")
const MapMenuInput = preload("res://src/world/maps/MapMenuInput.gd")
const ForageItemScene = preload("res://src/entities/items/ForageItem.tscn")
const PlayerScene = preload("res://src/entities/player/Player.tscn")
const VILLAGE_SCENE := "res://src/world/maps/Village.tscn"
const ExitSign = preload("res://src/world/maps/ExitSign.gd")
const FROM_VILLAGE_SPAWN := Vector2(440, 790)
const EXIT_SIGNS := {
	"ToFarmArea": ["← 村庄", Vector2(40, -48)],
	# Raised and beside the road so the hotbar does not cover it at the bottom edge.
	"ToVillageSouthArea": ["↓ 村庄", Vector2(80, -105)],
}
@onready var map_root: EditableMap2D = $ForestMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")
@onready var forage_points: Node2D = $ForagePoints

var time_display: Control
var ui_canvas: CanvasLayer
var forage_items: Array[ForageItem] = []


func _ready() -> void:
	print("[Forest] Scene loaded")
	_setup_map()
	_setup_ui()
	_setup_forage_points()
	_connect_signals()
	_generate_random_forage()


	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		# Coming up the village's north road you arrive at the forest's south road.
		if GameManager.current_spawn_point == "from_village":
			player.global_position = FROM_VILLAGE_SPAWN
		else:
			player.global_position = player_spawn.global_position
	AudioManager.update_location_bgm("forest")

func _setup_map() -> void:
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[ForestMap:%s] %s" % [issue.code, issue.message])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		map_root.apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
	print("[Forest] Authored map loaded: ", map_root.map_id)


func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	hud.add_child(HotkeyBarScene.instantiate())
	hud.add_child(ToolDisplayScene.instantiate())
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)
	hud.add_child(MapMenuInput.new())  # Esc / J, same as Village
	print("[Forest] Unified HUD added")


func _setup_forage_points() -> void:
	if forage_points:
		for child in forage_points.get_children():
			if child is ForageItem:
				forage_items.append(child)
		print("[Forest] Found ", forage_items.size(), " forage items")


func _generate_random_forage() -> void:
	# 根据季节生成额外的随机采集点
	if ForagingSystem == null:
		return

	var season: String = get_node("/root/TimeManager").get_season_name() if TimeManager else "Spring"
	var spawn_positions: Array[Vector2] = ForestConstants.FORAGE_SPAWN_POSITIONS

	# 获取季节可用的采集物品
	var available_forage: Array = ForagingSystem.get_seasonal_forage(season)
	var forest_forage: Array = []
	for forage in available_forage:
		if forage.locations.has("forest"):
			forest_forage.append(forage)

	if forest_forage.is_empty():
		print("[Forest] No forage available for season: ", season)
		return

	# 随机生成3-5个采集点
	var spawn_count: int = randi_range(3, 5)
	var used_positions: Array[int] = []

	for i in range(spawn_count):
		var pos_index: int
		while true:
			pos_index = randi() % spawn_positions.size()
			if not used_positions.has(pos_index):
				used_positions.append(pos_index)
				break

		# 根据稀有度选择物品
		var selected_forage = ForagingSystem._select_random_forage(forest_forage)
		if selected_forage:
			_spawn_forage_item(selected_forage.id, spawn_positions[pos_index])


func _spawn_forage_item(forage_id: String, pos: Vector2) -> void:
	if ForageItemScene == null:
		return

	var item: ForageItem = ForageItemScene.instantiate()
	item.forage_id = forage_id
	item.global_position = pos
	forage_points.add_child(item)
	forage_items.append(item)
	print("[Forest] Spawned forage: ", forage_id, " at ", pos)


func _connect_signals() -> void:
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
		TimeManager.season_changed.connect(_on_season_changed)
	# Both the west road and the south road lead back to the village (BUG-35).
	for exit_name in EXIT_SIGNS:
		var exit_area := get_node_or_null("TransitionAreas/%s" % exit_name) as Area2D
		if exit_area:
			exit_area.body_entered.connect(_on_exit_to_village)
			ExitSign.attach(exit_area, EXIT_SIGNS[exit_name][0], EXIT_SIGNS[exit_name][1])
	print("[Forest] Connected to signals")


func _on_exit_to_village(body: Node2D) -> void:
	if body is Player:
		SceneTransition.transition_to(VILLAGE_SCENE, "from_forest")


func _on_day_changed(new_day: int) -> void:
	print("[Forest] Day changed to: ", new_day)
	# 检查刷新
	_check_forage_respawn()


func _on_season_changed(new_season: int, season_name: String) -> void:
	print("[Forest] Season changed to: ", season_name)
	# 重新生成本季节的采集物品
	_regenerate_forage()


func _check_forage_respawn() -> void:
	for item in forage_items:
		if item.is_collected:
			# ForagingSystem 会处理刷新逻辑
			pass


func _regenerate_forage() -> void:
	# 清除现有的采集物品
	for item in forage_items:
		if is_instance_valid(item):
			item.queue_free()
	forage_items.clear()

	# 重新生成
	_generate_random_forage()


func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position
