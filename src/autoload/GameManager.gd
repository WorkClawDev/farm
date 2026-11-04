extends Node

signal game_started
signal game_paused
signal game_resumed
signal game_saved
signal game_loaded
signal day_advanced(reason: String, shipment: Dictionary)
signal notification_requested(message: String)

enum GameState { MENU, PLAYING, PAUSED, DIALOGUE, CUTSCENE }

const DebugLaunchScript = preload("res://src/core/debug/DebugLaunch.gd")
const FARM_SCENE := "res://src/world/maps/Farm.tscn"
const MENU_SCENE := "res://src/ui/menus/MainMenu.tscn"
const PLAYER_HOUSE_SCENE := "res://src/world/maps/PlayerHouse.tscn"
## Collapse wakes the player on the farmhouse birth marker (not the village door).
const PLAYER_HOUSE_SPAWN := "house_entrance"
## Pass-out fee is about 10% of gold in hand, and at least this much.
const COLLAPSE_FEE_PERCENT := 10
const COLLAPSE_FEE_FLOOR := 50
const PLAYABLE_SCENES := [
	FARM_SCENE,
	PLAYER_HOUSE_SCENE,
	"res://src/world/maps/Village.tscn",
	"res://src/world/maps/Beach.tscn",
	"res://src/world/maps/Forest.tscn",
	"res://src/world/maps/Mine.tscn",
]

## Debug sleep. Bare F is not a game binding (interact is Space/E).
## Ctrl+F is Godot's built-in ui_filedialog_find; this ignores modifiers. F9 spawns farm animals.
const DEBUG_SLEEP_KEY := KEY_F
## Debug iron for the smith. Bare F8, no modifiers. Copper watering can needs 5 iron ingots.
const DEBUG_IRON_KEY := KEY_F8
const DEBUG_IRON_ITEM := "iron_ingot"
const DEBUG_IRON_COUNT := 5
## Debug clock jump to 1:55. Bare F7, no modifiers. Stays under 26.0 so 2:00 still arrives on its own.
const DEBUG_TIME_SKIP_KEY := KEY_F7
const DEBUG_TIME_SKIP_HOUR := 25
const DEBUG_TIME_SKIP_MINUTE := 55

var current_state: GameState = GameState.MENU
var is_game_active := false
var current_spawn_point := "farm_start"
var player: Node2D
var _advancing_day := false


func _ready() -> void:
	# Smith UI and UIManager modals pause the tree. Debug F8 still has to arrive.
	# Sleep keeps the old rule and ignores keys while the tree is paused.
	if OS.is_debug_build():
		process_mode = Node.PROCESS_MODE_ALWAYS
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
	# After resets, so day/season/crop are not wiped. Before the tutorial, so
	# quest timers start on the debug calendar. No-op unless --new-game is set.
	DebugLaunchScript.apply_new_game_options(DebugLaunchScript.from_cmdline())
	QuestSystem.start_tutorial()
	SaveManager.reset_session(slot)
	current_spawn_point = "farm_start"
	current_state = GameState.PLAYING
	is_game_active = true
	game_started.emit()
	await _change_scene(FARM_SCENE)
	SaveManager.save_game(slot)


## debug_spawn is a SPAWNS id (see DebugLaunch). Only debug builds honor it,
## and only after the slot has loaded: the saved scene and player position are
## replaced by that entry.
func load_game(slot: int = 0, debug_spawn: String = "") -> bool:
	var snapshot := SaveManager.load_snapshot(slot)
	if snapshot.is_empty():
		notification_requested.emit("存档读取失败")
		return false
	if not SaveManager.apply_global_snapshot(snapshot):
		notification_requested.emit("存档数据无效")
		return false

	var game_data: Dictionary = snapshot.get("game", {})
	var scene_path := str(game_data.get("scene_path", FARM_SCENE))
	if scene_path not in PLAYABLE_SCENES:
		scene_path = FARM_SCENE
	current_spawn_point = str(game_data.get("spawn_point", "farm_start"))
	var spawn_spec := {}
	if OS.is_debug_build() and not debug_spawn.is_empty():
		spawn_spec = DebugLaunchScript.spawn_spec(debug_spawn)
	if not spawn_spec.is_empty():
		var forced := str(spawn_spec.get("scene", ""))
		if forced in PLAYABLE_SCENES:
			scene_path = forced
		current_spawn_point = str(spawn_spec.get("spawn_point", current_spawn_point))
		print("[DebugLaunch] slot %d -> %s (%s)" % [slot, debug_spawn, scene_path])
	current_state = GameState.PLAYING
	is_game_active = true
	get_tree().paused = false
	await _change_scene(scene_path)
	_apply_player_snapshot(snapshot.get("player", {}))
	if not spawn_spec.is_empty():
		_apply_debug_spawn(spawn_spec)
	SaveManager.mark_loaded(slot)
	game_loaded.emit()
	return true


func change_location(scene_path: String, spawn_point: String) -> void:
	current_spawn_point = spawn_point
	await _change_scene(scene_path)


func advance_day(reason: String = "sleep") -> void:
	if _advancing_day or not is_game_active:
		return
	_advancing_day = true
	TimeManager.pause_time()
	# Fee is gold in hand at collapse. The bin still pays in full afterwards.
	var collapse_paid := 0
	if reason == "forced_2am":
		collapse_paid = _charge_collapse_fee()
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
	day_advanced.emit(reason, shipment)
	_request_notification(day_start_notice(shipment, collapse_paid))
	if reason == "forced_2am":
		await _return_player_home()
	_advancing_day = false


## 10% of held gold, but at least COLLAPSE_FEE_FLOOR. Never more than gold, and 0 when broke.
static func forced_overnight_fee(gold: int) -> int:
	if gold <= 0:
		return 0
	var percent := gold * COLLAPSE_FEE_PERCENT / 100
	var floor_fee := mini(COLLAPSE_FEE_FLOOR, gold)
	return maxi(percent, floor_fee)


## Empty bin keeps the plain line. A payout stays on that line.
## A collapse fee is the next line, so "N 金" cannot wrap off by itself.
static func day_start_notice(shipment: Dictionary, collapse_fee_paid: int = 0) -> String:
	var paid := maxi(0, int(shipment.get("total_money", 0)))
	var text := "新的一天开始了"
	if paid > 0:
		text += "，出货到账 %d 金" % paid
	if collapse_fee_paid > 0:
		text += "。\n凌晨倒地，扣除 %d 金" % collapse_fee_paid
	return text


func _charge_collapse_fee() -> int:
	var fee := forced_overnight_fee(MoneySystem.get_money())
	if fee <= 0:
		return 0
	if MoneySystem.spend_money(fee, MoneySystem.ExpenseType.OTHER, "凌晨强制过夜"):
		return fee
	return 0


func _request_notification(message: String) -> void:
	# Farm already shows this signal. Elsewhere the autoload toast is the only listener.
	var heard := not notification_requested.get_connections().is_empty()
	if not heard and UIManager != null:
		UIManager.show_toast(message, {}, "info")
	notification_requested.emit(message)


func _return_player_home() -> void:
	current_spawn_point = PLAYER_HOUSE_SPAWN
	var tree := get_tree()
	if tree == null:
		return
	var current := tree.current_scene
	var path := current.scene_file_path if current != null else ""
	if path == PLAYER_HOUSE_SCENE:
		var player_node := tree.get_first_node_in_group("player") as Node2D
		if player_node != null and current.has_method("get_spawn_position"):
			player_node.global_position = current.call("get_spawn_position")
		return
	# Unit and integration runners are not playable maps. Record the spawn and leave them up.
	if path not in PLAYABLE_SCENES:
		return
	await _change_scene(PLAYER_HOUSE_SCENE)


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
	# Let the audio server drop the stopped music before shutdown (no leak at exit).
	AudioManager.release_streams()
	await get_tree().create_timer(0.25, true, false, true).timeout
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
	# change_scene_to_file 会立刻把当前场景移出场景树。门口/出口是 Area2D.body_entered
	# 触发的（物理回调里），这时移除 CollisionObject 会报错（BUG-16），先等到空闲帧再切。
	# MainMenu._ready 里启动时根节点还在 add_child，内部 remove_child 会报
	# "Parent node is busy"。先按引擎提示把当前场景推迟移出，再加载。
	if Engine.is_in_physics_frame():
		await get_tree().process_frame
	var tree := get_tree()
	if tree == null:
		return
	if _caller_is_ready():
		var current := tree.current_scene
		var parent: Node = current.get_parent() if current != null else null
		if parent != null:
			parent.call_deferred("remove_child", current)
		await tree.process_frame
		tree = get_tree()
		if tree == null:
			return
		if current != null and is_instance_valid(current) and tree.current_scene == current:
			tree.current_scene = null
			current.queue_free()
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		notification_requested.emit("无法加载场景")
		return
	await tree.scene_changed
	await tree.process_frame


func _caller_is_ready() -> bool:
	for frame in get_stack():
		if str(frame.get("function", "")) == "_ready":
			return true
	return false


func _apply_debug_spawn(spec: Dictionary) -> void:
	var loaded_player := get_tree().get_first_node_in_group("player") as Node2D
	if loaded_player == null:
		return
	loaded_player.global_position = spec.get("position", loaded_player.global_position)


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


func _unhandled_input(event: InputEvent) -> void:
	if wants_debug_iron(event, OS.is_debug_build()):
		if _debug_iron_allowed():
			get_viewport().set_input_as_handled()
			_grant_debug_iron()
		return
	# Same arrival rule as F8 (this node stays process-always in debug builds) but
	# the skip itself only runs while PLAYING, unpaused, and with no modal.
	# A visible tool upgrade or other quest-bar blocker also refuses F7.
	# F8 still grants iron on that screen; F7 must not.
	if wants_debug_time_skip(event, OS.is_debug_build()):
		if _debug_time_skip_allowed():
			get_viewport().set_input_as_handled()
			_skip_debug_time()
		return
	# This autoload used to be pausable, so sleep never saw keys while the tree was paused.
	if get_tree().paused:
		return
	if not wants_debug_sleep(event, OS.is_debug_build()):
		return
	if not is_game_active or current_state != GameState.PLAYING:
		return
	if UIManager != null and UIManager.has_open_modal():
		return
	get_viewport().set_input_as_handled()
	advance_day("sleep")


## True when this key should sleep in a debug build. Release builds pass false.
func wants_debug_sleep(event: InputEvent, debug_build: bool) -> bool:
	if not debug_build or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return false
	return key.keycode == DEBUG_SLEEP_KEY or key.physical_keycode == DEBUG_SLEEP_KEY


## True when this key should grant debug iron. Release builds pass false.
func wants_debug_iron(event: InputEvent, debug_build: bool) -> bool:
	if not debug_build or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return false
	return key.keycode == DEBUG_IRON_KEY or key.physical_keycode == DEBUG_IRON_KEY


## True when this key should jump the clock to 1:55. Release builds pass false.
func wants_debug_time_skip(event: InputEvent, debug_build: bool) -> bool:
	if not debug_build or not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return false
	return key.keycode == DEBUG_TIME_SKIP_KEY or key.physical_keycode == DEBUG_TIME_SKIP_KEY


## 1:55 on the 6:00–26:00 clock (25 + 55/60). Kept under 26.0 so forced_2am is not immediate.
static func debug_time_skip_target() -> float:
	return float(DEBUG_TIME_SKIP_HOUR) + float(DEBUG_TIME_SKIP_MINUTE) / 60.0


func _debug_time_skip_allowed() -> bool:
	if not is_game_active or current_state != GameState.PLAYING:
		return false
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	if UIManager != null and UIManager.has_open_modal():
		return false
	# Tool upgrade is not a UIManager screen. open() pauses, but if that pause
	# does not stick the visible panel must still block the skip.
	if _debug_time_skip_center_blocked(tree):
		return false
	return true


## Visible ToolUpgradeUI, or any visible quest_bar_blockers member.
func _debug_time_skip_center_blocked(tree: SceneTree) -> bool:
	if _tool_upgrade_ui_open():
		return true
	for node in tree.get_nodes_in_group(QuestTracker.BLOCKER_GROUP):
		if not is_instance_valid(node):
			continue
		if "visible" in node and bool(node.visible):
			return true
	return false


func _skip_debug_time() -> void:
	var target := debug_time_skip_target()
	if target >= 26.0:
		return
	var previous_hour := int(TimeManager.current_time)
	TimeManager.current_time = target
	TimeManager._time_accumulator = 0.0
	var current_hour := int(TimeManager.current_time)
	if current_hour != previous_hour:
		TimeManager.hour_changed.emit(current_hour)
	TimeManager.time_changed.emit(TimeManager.current_time)
	print("[GameManager] debug F7: time -> 1:55 (%.4f)" % target)
	if UIManager != null and UIManager.has_method("show_toast"):
		UIManager.show_toast("调试：时间 → 1:55", {}, "info")


func _debug_iron_allowed() -> bool:
	if not is_game_active:
		return false
	if current_state == GameState.PLAYING and not get_tree().paused:
		return true
	if UIManager != null and UIManager.has_open_modal():
		return true
	return _tool_upgrade_ui_open()


func _tool_upgrade_ui_open() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var ui := tree.root.find_child("ToolUpgradeUI", true, false)
	return ui != null and is_instance_valid(ui) and ui.visible


func _grant_debug_iron() -> void:
	var added := Inventory.add_item(DEBUG_IRON_ITEM, DEBUG_IRON_COUNT)
	var now := Inventory.get_item_count(DEBUG_IRON_ITEM)
	print("[GameManager] debug F8: +%d %s (ok=%s, now=%d)" % [DEBUG_IRON_COUNT, DEBUG_IRON_ITEM, added, now])
	if UIManager != null and UIManager.has_method("show_toast"):
		var text := "调试：铁锭 +%d" % DEBUG_IRON_COUNT
		if not added:
			text = "调试：铁锭没放进背包"
		UIManager.show_toast(text, {}, "info" if added else "warning")
	_refresh_open_tool_upgrade()


func _refresh_open_tool_upgrade() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var ui := tree.root.find_child("ToolUpgradeUI", true, false)
	if ui == null or not is_instance_valid(ui) or not ui.visible:
		return
	if ui.has_method("_update_materials_list"):
		ui.call("_update_materials_list")
	if ui.has_method("_update_upgrade_button"):
		ui.call("_update_upgrade_button")


func _on_day_end_requested(reason: String) -> void:
	advance_day(reason)
