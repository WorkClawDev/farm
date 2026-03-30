extends Node2D
class_name PlayerHouse

## PlayerHouse - 玩家房屋场景
## 可升级的房屋内部，包含家具系统和升级功能

const TimeDisplayScene = preload("res://src/ui/hud/TimeDisplay.tscn")

@onready var tile_map: TileMap = $TileMap
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var furniture_container: Node2D = $FurnitureContainer
@onready var room_extensions: Node2D = $RoomExtensions
@onready var exit_area: Area2D = $ExitArea
@onready var interaction_zones: Node2D = $InteractionZones

var time_display: Control
var ui_canvas: CanvasLayer
var house_data: Dictionary = {}

func _ready() -> void:
	print("[PlayerHouse] Scene loaded")
	_setup_ui()
	_setup_house_data()
	_connect_signals()
	_apply_house_upgrades()
	_setup_furniture()

func _setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10
	add_child(ui_canvas)

	time_display = TimeDisplayScene.instantiate()
	ui_canvas.add_child(time_display)
	print("[PlayerHouse] TimeDisplay added to UI canvas")

func _setup_house_data() -> void:
	# 初始化默认房屋数据
	house_data = {
		"level": 1,
		"rooms": ["main"],  # main, bedroom, kitchen, storage
		"furniture": {},
		"decorations": []
	}

func _connect_signals() -> void:
	if exit_area:
		exit_area.body_entered.connect(_on_exit_area_entered)

	# 连接床的交互
	var bed_zone = interaction_zones.get_node_or_null("BedZone")
	if bed_zone:
		bed_zone.body_entered.connect(_on_bed_zone_entered)

	# 连接升级站交互
	var upgrade_station = interaction_zones.get_node_or_null("UpgradeStation")
	if upgrade_station:
		upgrade_station.body_entered.connect(_on_upgrade_station_entered)

	# 连接EventBus信号
	if EventBus:
		get_node("/root/EventBus").spawn_point_changed.connect(_on_spawn_point_changed)

	print("[PlayerHouse] Signals connected")

func _on_exit_area_entered(body: Node2D) -> void:
	if body is Player:
		# 切换到农场场景
		SceneTransition.transition_to("res://src/world/maps/Farm.tscn", "house_exit")
		print("[PlayerHouse] Player exiting to farm")

func _on_bed_zone_entered(body: Node2D) -> void:
	if body is Player:
		_show_sleep_dialog()

func _on_upgrade_station_entered(body: Node2D) -> void:
	if body is Player:
		# 显示房屋升级UI
		_show_upgrade_ui()

func _show_sleep_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "要睡觉到第二天吗？体力会完全恢复。"
	dialog.window_title = "休息"
	dialog.confirmed.connect(_on_sleep_confirmed)
	dialog.canceled.connect(_on_sleep_canceled)
	add_child(dialog)
	dialog.popup_centered()

func _on_sleep_confirmed() -> void:
	if TimeManager:
		TimeManager.advance_to_next_day()
		# 恢复体力
		if GameManager:
			GameManager.current_stamina = GameManager.max_stamina
		print("[PlayerHouse] Advanced to next day, stamina restored")

func _on_sleep_canceled() -> void:
	print("[PlayerHouse] Sleep canceled")

func _show_upgrade_ui() -> void:
	if HouseUpgradeSystem:
		HouseUpgradeSystem.open_upgrade_ui()

func _apply_house_upgrades() -> void:
	# 根据房屋等级和已解锁房间更新场景
	if HouseUpgradeSystem:
		var current_level = HouseUpgradeSystem.get_house_level()
		var unlocked_rooms = HouseUpgradeSystem.get_unlocked_rooms()

		# 更新TileMap或显示/隐藏房间节点
		_update_house_layout(current_level, unlocked_rooms)

		print("[PlayerHouse] Applied house level: ", current_level)

func _update_house_layout(level: int, rooms: Array) -> void:
	# 根据等级和房间调整房屋布局
	# Level 1: 基础房间
	# Level 2: 添加厨房
	# Level 3: 添加卧室
	# Level 4: 添加储藏室

	match level:
		1:
			# 基础布局
			pass
		2:
			# 显示厨房
			_enable_room("kitchen")
		3:
			# 显示卧室
			_enable_room("bedroom")
		4:
			# 显示储藏室
			_enable_room("storage")

func _enable_room(room_name: String) -> void:
	# 启用指定房间
	if room_extensions:
		var room = room_extensions.get_node_or_null(room_name)
		if room:
			room.visible = true
			room.process_mode = Node.PROCESS_MODE_INHERIT

func _setup_furniture() -> void:
	# 设置已放置的家具
	var furniture_system = get_node_or_null("/root/FurnitureSystem")
	if furniture_system and furniture_system.has_method("setup_house_furniture"):
		furniture_system.setup_house_furniture(self)

func get_spawn_position() -> Vector2:
	return player_spawn.global_position

func get_furniture_container() -> Node2D:
	return furniture_container

func _on_spawn_point_changed(spawn_point: String) -> void:
	if spawn_point == "house_entrance":
		# 玩家从农场进入房屋
		if player_spawn:
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				player.global_position = player_spawn.global_position

## 保存房屋状态
func save_state() -> Dictionary:
	return {
		"level": house_data.get("level", 1),
		"rooms": house_data.get("rooms", ["main"]),
		"furniture": house_data.get("furniture", {}),
		"decorations": house_data.get("decorations", [])
	}

## 加载房屋状态
func load_state(data: Dictionary) -> void:
	house_data = data
	_apply_house_upgrades()
	_setup_furniture()
