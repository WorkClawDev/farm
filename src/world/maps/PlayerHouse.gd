extends Node2D
class_name PlayerHouse

## PlayerHouse - 玩家房屋场景
## 可升级的房屋内部，包含家具系统和升级功能

const GameConstants = preload("res://src/core/constants/GameConstants.gd")
const HouseConstants = preload("res://src/core/constants/HouseConstants.gd")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")
const MapMenuInput = preload("res://src/world/maps/MapMenuInput.gd")
const IllustratedMapBackdropScene = preload("res://src/world/maps/IllustratedMapBackdrop.gd")
const WorldCollisionLayoutScene = preload("res://src/world/maps/WorldCollisionLayout.gd")

var tile_map: TileMap = null # Legacy builder compatibility; no longer part of the runtime scene.
@onready var map_root: EditableMap2D = $PlayerHouseMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")
@onready var furniture_container: Node2D = $FurnitureContainer
@onready var room_extensions: Node2D = $RoomExtensions
@onready var exit_area: Area2D = $ExitArea
@onready var interaction_zones: Node2D = $InteractionZones

var time_display: Control
var ui_canvas: CanvasLayer
var house_data: Dictionary = {}

var _exit_to_village := false
var _in_bed_zone := false

func _ready() -> void:
	print("[PlayerHouse] Scene loaded")
	_setup_map()
	_setup_ui()
	_setup_house_data()
	_connect_signals()
	_apply_house_upgrades()
	_setup_furniture()
	# Leave by the door you came in through (BUG-40): the village door or the farm.
	_exit_to_village = GameManager.current_spawn_point == "village_house_entrance"
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = player_spawn.global_position

func _setup_map() -> void:
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[PlayerHouseMap:%s] %s" % [issue.code, issue.message])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		map_root.apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
	print("[PlayerHouse] Authored map loaded: ", map_root.map_id)

func _setup_tilemap() -> void:
	if tile_map == null:
		return

	tile_map.scale = Vector2(GameConstants.TILE_RENDER_SCALE, GameConstants.TILE_RENDER_SCALE)

	if tile_map.tile_set == null or tile_map.tile_set.get_source_count() == 0:
		tile_map.tile_set = IndoorTilesetBuilder.build_tileset()

	tile_map.clear()
	var wood_floor := IndoorTilesetBuilder.TileCoord.WOOD_FLOOR
	var wall := IndoorTilesetBuilder.TileCoord.WALLPAPER_CREAM
	var rug := IndoorTilesetBuilder.TileCoord.CARPET_RED
	var bed := IndoorTilesetBuilder.TileCoord.BED_DOUBLE
	var table := IndoorTilesetBuilder.TileCoord.TABLE
	var chest := IndoorTilesetBuilder.TileCoord.CHEST
	var stove := IndoorTilesetBuilder.TileCoord.STOVE
	var fireplace := IndoorTilesetBuilder.TileCoord.FIREPLACE

	for y in range(HouseConstants.MAP_TILES_Y):
		for x in range(HouseConstants.MAP_TILES_X):
			var tile := wood_floor
			if x < HouseConstants.BORDER_THICKNESS or y < HouseConstants.BORDER_THICKNESS or x >= HouseConstants.MAP_TILES_X - HouseConstants.BORDER_THICKNESS or y >= HouseConstants.MAP_TILES_Y - HouseConstants.BORDER_THICKNESS:
				tile = wall
			tile_map.set_cell(0, Vector2i(x, y), 0, IndoorTilesetBuilder.get_coord(tile))

	for y in range(HouseConstants.RUG_Y_MIN, HouseConstants.RUG_Y_MAX + 1):
		for x in range(HouseConstants.RUG_X_MIN, HouseConstants.RUG_X_MAX + 1):
			tile_map.set_cell(0, Vector2i(x, y), 0, IndoorTilesetBuilder.get_coord(rug))

	tile_map.set_cell(2, HouseConstants.BED_POSITION, 0, IndoorTilesetBuilder.get_coord(bed))
	tile_map.set_cell(2, HouseConstants.TABLE_POSITION, 0, IndoorTilesetBuilder.get_coord(table))
	tile_map.set_cell(2, HouseConstants.CHEST_POSITION, 0, IndoorTilesetBuilder.get_coord(chest))
	tile_map.set_cell(2, HouseConstants.STOVE_POSITION, 0, IndoorTilesetBuilder.get_coord(stove))
	tile_map.set_cell(2, HouseConstants.FIREPLACE_POSITION, 0, IndoorTilesetBuilder.get_coord(fireplace))

func _setup_illustrated_backdrop() -> void:
	tile_map.visible = false
	var backdrop := IllustratedMapBackdropScene.new()
	backdrop.setup("house")
	add_child(backdrop)
	move_child(backdrop, 0)

func _setup_world_collision() -> void:
	var collision_layout := WorldCollisionLayoutScene.new()
	collision_layout.setup("house")
	add_child(collision_layout)

func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	hud.add_child(HotkeyBarScene.instantiate())
	hud.add_child(ToolDisplayScene.instantiate())
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)
	hud.add_child(MapMenuInput.new())  # Esc / J, same as Village
	print("[PlayerHouse] Unified HUD added")

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
		bed_zone.body_exited.connect(_on_bed_zone_exited)

	# 连接升级站交互
	var upgrade_station = interaction_zones.get_node_or_null("UpgradeStation")
	if upgrade_station:
		upgrade_station.body_entered.connect(_on_upgrade_station_entered)

	# 连接EventBus信号
	if EventBus:
		get_node("/root/EventBus").player.spawn_point_changed.connect(_on_spawn_point_changed)

	print("[PlayerHouse] Signals connected")

func _on_exit_area_entered(body: Node2D) -> void:
	if body is Player:
		if _exit_to_village:
			GameManager.change_location("res://src/world/maps/Village.tscn", "from_house")
			print("[PlayerHouse] Player exiting to village")
		else:
			GameManager.change_location("res://src/world/maps/Farm.tscn", "house_exit")
			print("[PlayerHouse] Player exiting to farm")

func _on_bed_zone_entered(body: Node2D) -> void:
	if body is Player:
		_in_bed_zone = true

func _on_bed_zone_exited(body: Node2D) -> void:
	if body is Player:
		_in_bed_zone = false
		if UIManager and UIManager.has_open_confirmation():
			UIManager.close_top_screen()

func _on_upgrade_station_entered(body: Node2D) -> void:
	if body is Player:
		# 显示房屋升级UI
		_show_upgrade_ui()

func _input(event: InputEvent) -> void:
	# BUG-8: popup only on a fresh interact press while inside the zone.
	if not _in_bed_zone or event.is_echo() or not event.is_action_pressed("interact"):
		return
	if UIManager == null or UIManager.has_open_confirmation():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	get_viewport().set_input_as_handled()
	_show_sleep_dialog()

func _show_sleep_dialog() -> void:
	UIManager.show_confirmation({
		"title": "休息",
		"message": "要睡觉到第二天吗？体力会完全恢复，出货箱中的物品也会结算。",
		"confirm_key": "ui.common.confirm",
		"cancel_key": "ui.common.cancel",
		"on_confirm": Callable(self, "_on_sleep_confirmed"),
		"on_cancel": Callable(self, "_on_sleep_canceled"),
		"focus_confirm": true,
	})

func _on_sleep_confirmed() -> void:
	GameManager.advance_day("sleep")

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

func get_save_state() -> Dictionary:
	return {"farm": FarmState.get_save_state()}

func load_save_state(data: Dictionary) -> void:
	if data.has("farm"):
		FarmState.load_save_state(data.farm)

func get_furniture_container() -> Node2D:
	return furniture_container

func _on_spawn_point_changed(spawn_point: String) -> void:
	if spawn_point in ["house_entrance", "village_house_entrance"]:
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
