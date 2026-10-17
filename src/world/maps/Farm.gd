extends Node2D
class_name Farm

const PHYSICS_LAYERS = preload("res://src/core/constants/PhysicsLayers.gd")

## Farm - 农场场景
## 游戏主场景，玩家农场所在地

const GameConstants = preload("res://src/core/constants/GameConstants.gd")
const FarmConstants = preload("res://src/core/constants/FarmConstants.gd")
const TimeDisplayScene = preload("res://src/ui/hud/TimeDisplay.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const PauseMenuScene = preload("res://src/ui/menus/PauseMenu.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")
const FarmPlotScript = preload("res://src/world/objects/FarmPlot.gd")
const VILLAGE_SCENE := "res://src/world/maps/Village.tscn"

@onready var map_root: EditableMap2D = $FarmMap
@onready var tile_map: MapTileLayer = map_root.get_layer(&"ground") as MapTileLayer
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")
@onready var from_village_spawn: MapMarker2D = map_root.get_marker(&"from_village")
@onready var tilled_area: Node2D = $TilledArea

var time_display: Control
var ui_canvas: CanvasLayer
var soil_plots: Array[Soil] = []
var layout_root: Node2D
var farm_plots: Dictionary = {}
var pause_menu: PauseMenu
var notification_label: Label
var _house_entrance: Area2D
var _village_exit: Area2D

# Draw order on the farm. Farm.tscn offsets the FarmMap instance by z -3, so its
# profile layers (ground 0, terrain_overlay 1, decoration 2, objects 10) end up at:
#   Ground -3 < TerrainOverlay (paths/fences) -2 < TilledArea soil -1
#   < Player 0 == crop sprites 0 (Y-sorted together via Farm/TilledArea/FarmPlot y_sort)
#   < Objects 7 (buildings, unchanged relative to the player).
# Plot centres sit on tile centres of the fenced field interior (tiles x 2..11, y 10..17).
const PLOT_ORIGIN := Vector2(160, 672)
const PLOT_SPACING := 64.0

func _ready() -> void:
	print("[Farm] Scene loaded")
	_setup_map()
	_setup_ui()
	_setup_soil_plots()
	_setup_house_entrance()
	_setup_village_exit()
	_connect_time_signals()
	_connect_event_signals()
	FarmState.cell_changed.connect(_on_farm_cell_changed)
	FarmState.farm_reset.connect(_refresh_all_plots)
	GameManager.notification_requested.connect(_show_notification)
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	if player_node:
		match GameManager.current_spawn_point:
			"house_exit":
				player_node.global_position = get_house_door_position() + Vector2(0, 72)
			"from_village":
				player_node.global_position = from_village_spawn.global_position
			_:
				player_node.global_position = player_spawn.global_position
		var player_camera := player_node.get_node_or_null("Camera2D") as Camera2D
		map_root.apply_camera_limits(player_camera)
	AudioManager.update_location_bgm("farm")

func _setup_map() -> void:
	if map_root == null:
		push_error("[Farm] FarmMap is missing")
		return
	layout_root = map_root.get_layer(&"objects") as Node2D
	if tile_map == null or layout_root == null or player_spawn == null or from_village_spawn == null:
		push_error("[Farm] FarmMap is missing one or more required layers/markers")
		return
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[FarmMap:%s] %s" % [issue.code, issue.message])
		elif issue.severity == MapValidationIssue.Severity.WARNING:
			push_warning("[FarmMap:%s] %s" % [issue.code, issue.message])
	print("[Farm] Authored map loaded: ", map_root.map_id, " (", map_root.size_in_tiles, ")")

func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	var hotbar := HotkeyBarScene.instantiate()
	hud.add_child(hotbar)
	var tool_display := ToolDisplayScene.instantiate()
	hud.add_child(tool_display)
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)

	pause_menu = PauseMenuScene.instantiate()
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.quit_to_menu_requested.connect(GameManager.return_to_menu)
	pause_menu.quit_game_requested.connect(GameManager.quit_game)
	hud.add_child(pause_menu)

	notification_label = null

func _setup_soil_plots() -> void:
	for child in tilled_area.get_children():
		child.queue_free()
	farm_plots.clear()
	for y in range(FarmState.GRID_HEIGHT):
		for x in range(FarmState.GRID_WIDTH):
			var coord := Vector2i(x, y)
			var plot: FarmPlot = FarmPlotScript.new()
			plot.position = PLOT_ORIGIN + Vector2(x, y) * PLOT_SPACING
			tilled_area.add_child(plot)
			plot.setup(coord)
			farm_plots[coord] = plot
	print("[Farm] Generated %d farm plots" % farm_plots.size())

func _connect_time_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.hour_changed.connect(_on_hour_changed)
		time_manager.day_changed.connect(_on_day_changed)
		time_manager.season_changed.connect(_on_season_changed)
		print("[Farm] Connected to TimeManager signals")

func _connect_event_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.player and event_bus.farm:
		# 连接交互信号
		event_bus.player.player_interacted.connect(_on_player_interacted)
		# 连接收获信号
		event_bus.farm.crop_harvested.connect(_on_crop_harvested)
		print("[Farm] Connected to EventBus signals")

func _on_hour_changed(new_hour: int) -> void:
	print("[Farm] Hour changed to: ", new_hour)

func _on_day_changed(new_day: int) -> void:
	print("[Farm] Day changed to: ", new_day)
	# 新的一天开始，干燥所有土壤
	_dry_all_soil()

func _on_season_changed(new_season: int, season_name: String) -> void:
	print("[Farm] Season changed to: ", season_name)

func _on_player_interacted(target: Node) -> void:
	# 处理玩家与土壤的交互
	if target is Soil:
		var soil := target as Soil
		
		return
	
	# 其他交互由各自的系统处理


func _on_crop_harvested(crop_type: String, quality: int, quantity: int) -> void:
	_show_notification("收获 %d 个 %s" % [quantity, crop_type])


func _get_crop_base_price(crop_id: String) -> int:
	# 临时价格表（实际应该从配置文件加载）
	var crop_prices: Dictionary = {
		"parsnip": 35,
		"potato": 80,
		"cauliflower": 175,
		"bean": 40,
		"tomato": 60,
		"corn": 50,
		"melon": 250,
		"wheat": 25,
		"strawberry": 120,
		"pumpkin": 320,
		"eggplant": 60,
		"carrot": 35,
		"radish": 35,
		"blueberry": 50
	}

	return crop_prices.get(crop_id.to_lower(), 25)  # 默认价格25

func _dry_all_soil() -> void:
	for soil in soil_plots:
		soil.dry()
	print("[Farm] All soil plots dried for new day")

func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position

func perform_farm_action(coord: Vector2i, tool_type: ToolManager.ToolType) -> void:
	if StaminaManager.current_stamina < 2.0:
		_show_notification("体力不足")
		return
	var success := false
	var message := ""
	var selected_item := Inventory.get_selected_item_id()
	var selected_data = ItemDatabase.get_item(selected_item) if not selected_item.is_empty() else null
	var cell := FarmState.get_cell(coord)

	if selected_data and selected_data.type == ItemDatabase.ItemType.SEED \
			and int(cell.get("state", FarmState.UNTILLED)) != FarmState.UNTILLED \
			and Dictionary(cell.get("crop", {})).is_empty():
		success = FarmState.plant(coord, selected_item)
		message = "已播种" if success else "这里不能种植"
	else:
		match tool_type:
			ToolManager.ToolType.HOE:
				success = FarmState.till(coord)
				message = "土地已翻好" if success else "这里已经翻过了"
			ToolManager.ToolType.WATERING_CAN:
				var player_node = get_tree().get_first_node_in_group("player")
				if player_node and player_node.tool_manager.has_watering_charge():
					success = FarmState.water(coord)
					if success:
						player_node.tool_manager.consume_watering_charge()
				message = "浇水完成" if success else "无法浇水或水壶已空"
			ToolManager.ToolType.SICKLE:
				var result := FarmState.harvest(coord)
				success = not result.is_empty()
				if success:
					EventBus.farm.crop_harvested.emit(
						str(result.get("crop_id", "")),
						int(result.get("quality", 0)),
						int(result.get("quantity", 0))
					)
				message = "收获 %d 个 %s" % [result.get("quantity", 0), result.get("crop_id", "")] if success else "作物尚未成熟"
			_:
				message = "选择种子或合适的工具"

	if success:
		StaminaManager.use_stamina(2.0)
	_show_notification(message)

func get_save_state() -> Dictionary:
	return FarmState.get_save_state()

func load_save_state(data: Dictionary) -> void:
	FarmState.load_save_state(data)
	_refresh_all_plots()

func _setup_house_entrance() -> void:
	_house_entrance = Area2D.new()
	_house_entrance.name = "HouseEntrance"
	var house := (
		layout_root.get_node_or_null("PlayerHouseExterior") as HouseExterior
		if layout_root else null
	)
	var door_position := (
		house.get_door_global_position()
		if house else Vector2(841, 286)
	)
	_house_entrance.position = door_position
	player_spawn.position = door_position + Vector2(0, 72)
	_house_entrance.collision_layer = 0
	_house_entrance.collision_mask = PHYSICS_LAYERS.PLAYER
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 40)
	collision.shape = shape
	_house_entrance.add_child(collision)
	_house_entrance.body_entered.connect(_on_house_entrance_entered)
	add_child(_house_entrance)

func _on_house_entrance_entered(body: Node2D) -> void:
	if body is Player:
		GameManager.change_location("res://src/world/maps/PlayerHouse.tscn", "house_entrance")

func get_house_door_position() -> Vector2:
	return _house_entrance.global_position if _house_entrance else Vector2(841, 286)


func _setup_village_exit() -> void:
	_village_exit = Area2D.new()
	_village_exit.name = "VillageExit"
	_village_exit.position = from_village_spawn.position + Vector2(60, 0)
	_village_exit.collision_layer = 0
	_village_exit.collision_mask = PHYSICS_LAYERS.PLAYER
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 160)
	collision.shape = shape
	_village_exit.add_child(collision)
	var label := Label.new()
	label.position = Vector2(-70, -110)
	label.size = Vector2(140, 30)
	label.text = "→ 前往村庄"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	_village_exit.add_child(label)
	_village_exit.body_entered.connect(_on_village_exit_entered)
	add_child(_village_exit)


func _on_village_exit_entered(body: Node2D) -> void:
	if body is Player:
		GameManager.change_location(VILLAGE_SCENE, "from_farm")

func _on_farm_cell_changed(coord: Vector2i) -> void:
	var plot: FarmPlot = farm_plots.get(coord)
	if plot:
		plot.refresh()

func _refresh_all_plots() -> void:
	for plot: FarmPlot in farm_plots.values():
		plot.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("inventory") or event.is_action_pressed("journal")) and not GameManager.is_paused():
		var context := {}
		if event.is_action_pressed("inventory"):
			context["tab"] = "inventory"
		UIManager.open_screen("journal", context)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if GameManager.is_paused():
			_close_pause_menu()
		else:
			GameManager.pause_game()
			pause_menu.visible = true
		get_viewport().set_input_as_handled()

func _close_pause_menu() -> void:
	pause_menu.visible = false
	GameManager.resume_game()

func _show_notification(message: String) -> void:
	if message.is_empty():
		return
	UIManager.show_toast(message, {}, "info")

## 获取指定位置的土壤地块
func get_soil_at_position(pos: Vector2) -> Soil:
	for soil in soil_plots:
		if soil.global_position.distance_to(pos) < 16.0:
			return soil
	return null

## 获取所有可种植的土壤
func get_plantable_soils() -> Array[Soil]:
	var result: Array[Soil] = []
	for soil in soil_plots:
		if soil.can_plant():
			result.append(soil)
	return result
