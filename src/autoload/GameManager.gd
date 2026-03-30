extends Node

## GameManager - 游戏主管理器
## 负责游戏整体状态管理，协调各个系统
##
## 已拆分出的职责：
## - InventoryManager : 背包管理 (src/core/inventory/InventoryManager.gd)
## - MoneyManager      : 金钱管理 (src/core/economy/MoneyManager.gd)
## - StaminaManager    : 体力管理 (src/core/systems/StaminaManager.gd)

signal game_started
signal game_paused
signal game_resumed
signal game_saved
signal game_loaded

# 游戏状态
enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	DIALOGUE,
	CUTSCENE
}

var current_state: GameState = GameState.MENU
var is_game_active: bool = false

# 玩家引用
var player: Node2D = null

func _ready() -> void:
	print("[GameManager] Initialized")
	_connect_signals()

func _connect_signals() -> void:
	# 连接其他系统的信号
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("day_changed"):
		time_manager.day_changed.connect(_on_day_changed)

func start_game() -> void:
	current_state = GameState.PLAYING
	is_game_active = true
	game_started.emit()
	print("[GameManager] Game started, loading Farm scene...")
	get_tree().change_scene_to_file("res://src/world/maps/Farm.tscn")

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit()
		print("[GameManager] Game paused")

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_resumed.emit()
		print("[GameManager] Game resumed")

func save_game(slot: int = 0) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.save_game(slot)
		game_saved.emit()
		print("[GameManager] Game saved to slot ", slot)

func load_game(slot: int = 0) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.load_game(slot)
		game_loaded.emit()
		print("[GameManager] Game loaded from slot ", slot)

func quit_game() -> void:
	print("[GameManager] Quitting game")
	get_tree().quit()

func _on_day_changed(new_day: int) -> void:
	print("[GameManager] Day changed to: ", new_day)

func get_current_state() -> GameState:
	return current_state

func is_paused() -> bool:
	return current_state == GameState.PAUSED

## 注册玩家引用
func register_player(player_node: Node2D) -> void:
	player = player_node
	print("[GameManager] Player registered")

## 获取管理器引用（便捷方法）
func get_inventory_manager():
	var inv = get_node_or_null("/root/InventoryManager")
	if inv: return inv
	return get_node_or_null("/root/Inventory")

func get_money_manager():
	var money = get_node_or_null("/root/MoneyManager")
	if money: return money
	return get_node_or_null("/root/MoneySystem")

func get_stamina_manager():
	return get_node_or_null("/root/StaminaManager")
