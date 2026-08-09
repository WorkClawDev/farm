extends Node

signal game_started
signal game_paused
signal game_resumed
signal game_saved
signal game_loaded
signal day_advanced(reason: String, shipment: Dictionary)
signal notification_requested(message: String)

enum GameState { MENU, PLAYING, PAUSED, DIALOGUE, CUTSCENE }

const FARM_SCENE := "res://src/world/maps/Farm.tscn"
const MENU_SCENE := "res://src/ui/menus/MainMenu.tscn"
const PLAYABLE_SCENES := [
	FARM_SCENE,
	"res://src/world/maps/PlayerHouse.tscn",
	"res://src/world/maps/Village.tscn",
	"res://src/world/maps/Beach.tscn",
	"res://src/world/maps/Forest.tscn",
	"res://src/world/maps/Mine.tscn",
]

var current_state: GameState = GameState.MENU
var is_game_active := false
var current_spawn_point := "farm_start"
var player: Node2D
var _advancing_day := false


func _ready() -> void:
	TimeManager.day_end_requested.connect(_on_day_end_requested)
	print("[GameManager] Initialized")


func start_new_game(slot: int = 0) -> void:
	get_tree().paused = false
	TimeManager.reset()
	MoneySystem.reset()
	Inventory.reset_with_starter_items()
	StaminaManager.set_max_stamina(100.0)
	StaminaManager.set_stamina(100.0)
	ShippingSystem.reset()
	FarmState.reset()
	for system in [QuestSystem, Friendship, GiftSystem, NPCManager, DialogueManager,
			HouseUpgradeSystem, AchievementSystem, FestivalSystem, GameSession,
			ForagingSystem, CraftingSystem, CookingManager, FishingSystem]:
		if system and system.has_method("reset"):
			system.reset()
	QuestSystem.start_tutorial()
	SaveManager.reset_session(slot)
	current_spawn_point = "farm_start"
	current_state = GameState.PLAYING
	is_game_active = true
	game_started.emit()
	await _change_scene(FARM_SCENE)
	SaveManager.save_game(slot)


func load_game(slot: int = 0) -> void:
	var snapshot := SaveManager.load_snapshot(slot)
	if snapshot.is_empty():
		notification_requested.emit("存档读取失败")
		return
	if not SaveManager.apply_global_snapshot(snapshot):
		notification_requested.emit("存档数据无效")
		return

	var game_data: Dictionary = snapshot.get("game", {})
	var scene_path := str(game_data.get("scene_path", FARM_SCENE))
	if scene_path not in PLAYABLE_SCENES:
		scene_path = FARM_SCENE
	current_spawn_point = str(game_data.get("spawn_point", "farm_start"))
	current_state = GameState.PLAYING
	is_game_active = true
	get_tree().paused = false
	await _change_scene(scene_path)
	_apply_player_snapshot(snapshot.get("player", {}))
	SaveManager.mark_loaded(slot)
	game_loaded.emit()


func change_location(scene_path: String, spawn_point: String) -> void:
	current_spawn_point = spawn_point
	await _change_scene(scene_path)


func advance_day(reason: String = "sleep") -> void:
	if _advancing_day or not is_game_active:
		return
	_advancing_day = true
	TimeManager.pause_time()
	var shipment := ShippingSystem.process_shipment()
	FarmState.advance_day()
	TimeManager.advance_to_next_day()
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate.get("tool_manager") and candidate.tool_manager.has_method("refill_tools"):
			candidate.tool_manager.refill_tools()
	if SaveManager.get_current_slot() >= 0:
		SaveManager.save_game()
	TimeManager.resume_time()
	_advancing_day = false
	day_advanced.emit(reason, shipment)
	notification_requested.emit("新的一天开始了")


func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	current_state = GameState.PAUSED
	get_tree().paused = true
	game_paused.emit()


func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	current_state = GameState.PLAYING
	get_tree().paused = false
	game_resumed.emit()


func save_game(slot: int = -1) -> bool:
	var success := SaveManager.save_game(slot)
	if success:
		game_saved.emit()
	return success


func return_to_menu() -> void:
	get_tree().paused = false
	is_game_active = false
	current_state = GameState.MENU
	player = null
	get_tree().change_scene_to_file(MENU_SCENE)


func quit_game() -> void:
	get_tree().quit()


func register_player(player_node: Node2D) -> void:
	player = player_node


func get_current_state() -> GameState:
	return current_state


func is_paused() -> bool:
	return current_state == GameState.PAUSED


func get_inventory_manager():
	return Inventory


func get_money_manager():
	return MoneySystem


func get_stamina_manager():
	return StaminaManager


func _change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		notification_requested.emit("无法加载场景")
		return
	await get_tree().scene_changed
	await get_tree().process_frame


func _apply_player_snapshot(data: Dictionary) -> void:
	var loaded_player := get_tree().get_first_node_in_group("player") as Node2D
	if loaded_player == null or data.is_empty():
		return
	loaded_player.global_position = Vector2(
		float(data.get("position_x", loaded_player.global_position.x)),
		float(data.get("position_y", loaded_player.global_position.y))
	)
	if "current_direction" in loaded_player:
		loaded_player.current_direction = int(data.get("direction", 0))


func _on_day_end_requested(reason: String) -> void:
	advance_day(reason)
