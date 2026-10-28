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
const DayNightTint = preload("res://src/world/maps/DayNightTint.gd")
const VILLAGE_SCENE := "res://src/world/maps/Village.tscn"
## BUG-55 debug: F9 spawns one of each farm animal (debug builds only).
const DEBUG_SPAWN_ANIMALS_KEY := KEY_F9
const DEBUG_ANIMAL_SCENES := [
	"res://src/entities/animals/Chicken.tscn",
	"res://src/entities/animals/Pig.tscn",
	"res://src/entities/animals/Cow.tscn",
	"res://src/entities/animals/Sheep.tscn",
	"res://src/entities/animals/Horse.tscn",
]
## Open grass between the pond, the fenced field and the barn.
const DEBUG_ANIMAL_AREA_CENTER := Vector2(1100, 360)
const DEBUG_ANIMAL_CLEARANCE := 40.0

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
var actor_layer: Node2D
var _player_at_house_door: Player = null
var _entering_house := false
## BUG-59: steps only (door point is the bottom step; shape sits above it).
const HOUSE_ENTRANCE_SIZE := Vector2(40, 24)

# Draw order on the farm. Farm.tscn offsets the FarmMap instance by z -3, so its
# profile layers (ground 0, terrain_overlay 1, decoration 2, objects 10) end up at:
#   Ground -3 < TerrainOverlay (paths/fences) -2 < TilledArea soil -1
#   < Player 0 == crop sprites 0 (Y-sorted together via Farm/TilledArea/FarmPlot y_sort)
#   < Objects 7 (buildings, unchanged relative to the player).
# Plot centres sit on tile centres of the fenced field interior (tiles x 2..11, y 10..17).
const PLOT_ORIGIN := Vector2(640, 400)  # south of farmhouse; house-plot-road triangle
const PLOT_SPACING := 64.0

func _ready() -> void:
	print("[Farm] Scene loaded")
	_setup_map()
	_setup_ui()
	add_child(DayNightTint.new())  # outdoor night tint (round 8)
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
	_setup_actor_layer()
	_setup_field_fence()

## Field fence follows the tilled plot rectangle. Straight runs use Kenney
## fence_h / fence_v (rails meet: horizontal pitch 48, vertical pitch 64).
## Corners and the open north ends use fence_post. The baked overlay was only
## repeating posts, offset from the ridges, with a gap along the south edge.
const TEX_FENCE_H := preload("res://assets/tiles/kenney/decor/fence_h.png")
const TEX_FENCE_V := preload("res://assets/tiles/kenney/decor/fence_v.png")
const TEX_FENCE_POST := preload("res://assets/tiles/kenney/decor/fence_post.png")
const FENCE_H_PITCH := 48.0

func _setup_field_fence() -> void:
	if map_root == null:
		return
	_clear_baked_fence_tiles()
	var rows := FarmState.GRID_HEIGHT
	var cols := FarmState.GRID_WIDTH
	var half := 30.0
	var fence := Node2D.new()
	fence.name = "FieldFence"
	# Same draw band as TerrainOverlay (FarmMap z -3 + overlay z 1).
	# Stays under the player; BUG-61 y-sort is left alone.
	fence.z_index = -2
	fence.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(fence)

	var left_x := PLOT_ORIGIN.x - half - 16.0
	var right_x := PLOT_ORIGIN.x + float(cols - 1) * PLOT_SPACING + half + 16.0
	var bottom_y := PLOT_ORIGIN.y + float(rows - 1) * PLOT_SPACING + half + 16.0
	for row in rows:
		var row_y := PLOT_ORIGIN.y + float(row) * PLOT_SPACING
		_add_fence_sprite(fence, TEX_FENCE_V, Vector2(left_x, row_y), PI * 0.5)
		_add_fence_sprite(fence, TEX_FENCE_V, Vector2(right_x, row_y), -PI * 0.5)

	var span := right_x - left_x
	var h_count := int(round(span / FENCE_H_PITCH))
	var h_run := float(h_count) * FENCE_H_PITCH
	var h_start := (left_x + right_x) * 0.5 - h_run * 0.5
	for i in h_count + 1:
		_add_fence_sprite(fence, TEX_FENCE_H, Vector2(h_start + float(i) * FENCE_H_PITCH, bottom_y), 0.0)

	var top_y := PLOT_ORIGIN.y - PLOT_SPACING * 0.5
	var bot_post_y := PLOT_ORIGIN.y + float(rows - 1) * PLOT_SPACING + PLOT_SPACING * 0.5
	for corner in [Vector2(left_x, top_y), Vector2(right_x, top_y), Vector2(left_x, bot_post_y), Vector2(right_x, bot_post_y)]:
		_add_fence_sprite(fence, TEX_FENCE_POST, corner, 0.0)
	# Short returns at the north corners. The middle stays open onto the road.
	for i in 3:
		_add_fence_sprite(fence, TEX_FENCE_H, Vector2(left_x + 16.0 + float(i) * FENCE_H_PITCH, top_y - 16.0), 0.0)
		_add_fence_sprite(fence, TEX_FENCE_H, Vector2(right_x - 16.0 - float(i) * FENCE_H_PITCH, top_y - 16.0), 0.0)

	var thickness := 16.0
	# Start below the road so Joe's tavern stand (600, 350) stays clear.
	var side_top := PLOT_ORIGIN.y - 24.0
	_add_fence_blocker(fence, Rect2(left_x - thickness * 0.5, side_top, thickness, bot_post_y - side_top + 8.0))
	_add_fence_blocker(fence, Rect2(right_x - thickness * 0.5, side_top, thickness, bot_post_y - side_top + 8.0))
	_add_fence_blocker(fence, Rect2(h_start - 16.0, bottom_y - thickness * 0.5, h_run + 32.0, thickness))


func _clear_baked_fence_tiles() -> void:
	var overlay := map_root.get_layer(&"terrain_overlay") as TileMapLayer
	if overlay == null:
		return
	var doomed: Array[Vector2i] = []
	for cell in overlay.get_used_cells():
		var atlas: Vector2i = overlay.get_cell_atlas_coords(cell)
		if atlas.x == FarmTilesetBuilder.FENCE_HORIZONTAL or atlas.x == FarmTilesetBuilder.FENCE_VERTICAL:
			doomed.append(cell)
	for cell in doomed:
		overlay.erase_cell(cell)


func _add_fence_sprite(parent: Node2D, texture: Texture2D, pos: Vector2, rotation_radians: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = pos
	sprite.rotation = rotation_radians
	parent.add_child(sprite)


func _add_fence_blocker(parent: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = PHYSICS_LAYERS.WORLD
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


## Animals share one Y-sorted layer with the player (z 0) so whoever stands lower
## on screen draws in front. FarmMap/Objects sits at z 7 and would always draw
## animals over the player; any Animal that lands there is moved here.
func _setup_actor_layer() -> void:
	actor_layer = Node2D.new()
	actor_layer.name = "Actors"
	actor_layer.y_sort_enabled = true
	add_child(actor_layer)
	for node in layout_root.find_children("*", "Animal", true, false):
		_adopt_actor(node)
	get_tree().node_added.connect(_on_tree_node_added)

func _on_tree_node_added(node: Node) -> void:
	if node is Animal and layout_root and layout_root.is_ancestor_of(node):
		_adopt_actor.call_deferred(node)

func _adopt_actor(node: Node) -> void:
	if not is_instance_valid(node) or actor_layer == null or node.get_parent() == actor_layer:
		return
	if layout_root and layout_root.is_ancestor_of(node):
		node.reparent(actor_layer, true)

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


func _on_crop_harvested(crop_type: String, _quality: int, quantity: int) -> void:
	var display_name := crop_type
	var item = ItemDatabase.get_item(crop_type)
	if item != null and not str(item.name).is_empty():
		display_name = str(item.name)
	_show_notification("收获 %d 个 %s" % [quantity, display_name])


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

## Plot the player works on: the grid cell next to the one they stand in, in the
## facing direction (-1,-1 when that is outside the field). Picking it by a point
## 32px ahead (less than the 64px plot pitch) hit the player's own plot for some
## directions, so 4 directions only tilled 3 plots, and from a plot centre the
## point fell in the 4px gap between plots and hit nothing.
func get_facing_plot_coord(world_position: Vector2, facing: Vector2) -> Vector2i:
	var local := (world_position - global_position - PLOT_ORIGIN) / PLOT_SPACING
	var standing := Vector2i(roundi(local.x), roundi(local.y))
	var target := standing + Vector2i(roundi(facing.x), roundi(facing.y))
	if target.x < 0 or target.y < 0 or target.x >= FarmState.GRID_WIDTH or target.y >= FarmState.GRID_HEIGHT:
		return Vector2i(-1, -1)
	return target

func perform_farm_action(coord: Vector2i, tool_type: ToolManager.ToolType) -> void:
	if StaminaManager.current_stamina < 2.0:
		_show_notification("体力不足")
		return
	var success := false
	var message := ""
	var selected_item := Inventory.get_selected_item_id()
	var selected_data = ItemDatabase.get_item(selected_item) if not selected_item.is_empty() else null
	var cell := FarmState.get_cell(coord)
	var debris := str(cell.get("debris", ""))

	# 规则（BUG-14）：手里拿的东西决定动作。
	# - 拿着工具（Q/R 切换）时只执行该工具的动作，快捷栏里选着种子也不会播种；
	# - 按数字键选快捷栏物品会收起工具（ToolType.NONE），这时选中的是种子才播种。
	# 格子上有杂物时，先用对应工具清除；用错工具只提示，不扣体力。
	if not debris.is_empty():
		if tool_type == ToolManager.ToolType.NONE:
			message = "这里有%s，按 Q/R 拿工具清除" % FarmState.debris_display_name(debris)
		else:
			var cleared := _clear_debris_with_tool(coord, tool_type)
			success = bool(cleared.get("success", false))
			message = str(cleared.get("message", ""))
	elif tool_type == ToolManager.ToolType.NONE:
		if selected_data and selected_data.type == ItemDatabase.ItemType.SEED:
			if int(cell.get("state", FarmState.UNTILLED)) == FarmState.UNTILLED:
				message = "先用锄头翻地再播种"
			elif bool(Dictionary(cell.get("crop", {})).get("dead", false)):
				message = "用锄头或镰刀清除枯死的作物"
			elif not Dictionary(cell.get("crop", {})).is_empty():
				message = "这里已经种了作物"
			else:
				success = FarmState.plant(coord, selected_item)
				message = "已播种" if success else "这里不能种植"
		else:
			message = "选择种子，或按 Q/R 拿工具"
	else:
		match tool_type:
			ToolManager.ToolType.HOE:
				if FarmState.is_crop_dead(coord):
					success = FarmState.clear_dead_crop(coord)
					message = "清除了枯死的作物" if success else "这里清不掉"
				else:
					success = FarmState.till(coord)
					message = "土地已翻好" if success else (
						"这里已经翻过了（按数字键选种子播种）"
						if Dictionary(cell.get("crop", {})).is_empty() and not cell.is_empty()
						else "这里已经翻过了"
					)
			ToolManager.ToolType.WATERING_CAN:
				# 水量只在 FarmState 里记；只有真正浇上水才扣水、扣体力。
				match FarmState.water_with_can(coord):
					FarmState.WaterResult.WATERED_OK:
						success = true
						message = "浇水完成（水壶 %d/%d）" % [
							FarmState.get_watering_can_uses_left(),
							FarmState.get_watering_can_max_uses(),
						]
					FarmState.WaterResult.ALREADY_WATERED:
						message = "这块地今天已经浇过水了"
					FarmState.WaterResult.CAN_EMPTY:
						message = "水壶空了，去池塘边按空格装水"
					_:
						message = "这里不能浇水，先用锄头翻地"
			ToolManager.ToolType.SICKLE:
				if FarmState.is_crop_dead(coord):
					success = FarmState.clear_dead_crop(coord)
					message = "清除了枯死的作物" if success else "这里清不掉"
				else:
					var result := FarmState.harvest(coord)
					success = not result.is_empty()
					if success:
						# 文案只由 _on_crop_harvested 弹一次。这里再写同样的 message 会合成 ×2。
						# emit 保留：任务和成就听这个信号。
						EventBus.farm.crop_harvested.emit(
							str(result.get("crop_id", "")),
							int(result.get("quality", 0)),
							int(result.get("quantity", 0))
						)
						message = ""
					else:
						message = "作物尚未成熟"
			ToolManager.ToolType.AXE:
				message = "这里没有树枝或树桩"
			ToolManager.ToolType.PICKAXE:
				message = "这里没有石头"
			_:
				message = "选择种子或合适的工具"

	if success:
		StaminaManager.use_stamina(2.0)
	_show_notification(message)


func _farm_tool_key(tool_type: ToolManager.ToolType) -> String:
	match tool_type:
		ToolManager.ToolType.SICKLE:
			return FarmState.TOOL_SICKLE
		ToolManager.ToolType.PICKAXE:
			return FarmState.TOOL_PICKAXE
		ToolManager.ToolType.AXE:
			return FarmState.TOOL_AXE
		_:
			return ""


func _clear_debris_with_tool(coord: Vector2i, tool_type: ToolManager.ToolType) -> Dictionary:
	var kind := FarmState.get_debris(coord)
	if kind.is_empty():
		return {"success": false, "message": ""}
	if _farm_tool_key(tool_type) != FarmState.tool_for_debris(kind):
		return {"success": false, "message": FarmState.debris_wrong_tool_message(kind)}
	var drop := FarmState.peek_debris_drop(coord)
	if drop != "" and not Inventory.can_add_item(drop, 1):
		return {"success": false, "message": "背包已满"}
	var result := FarmState.strike_debris(coord)
	if result.is_empty():
		return {"success": false, "message": "这里清不掉"}
	var item_id := str(result.get("item_id", ""))
	var quantity := int(result.get("quantity", 0))
	if item_id != "" and quantity > 0:
		Inventory.add_item(item_id, quantity)
	return {"success": true, "message": _debris_cleared_message(result)}


func _debris_cleared_message(result: Dictionary) -> String:
	var kind := str(result.get("kind", ""))
	if not bool(result.get("cleared", false)):
		return "树桩还没砍倒（%d/%d）" % [int(result.get("hits", 0)), int(result.get("hits_needed", 3))]
	match kind:
		FarmState.DEBRIS_WEED:
			return "清除了杂草，获得纤维"
		FarmState.DEBRIS_STONE:
			return "敲碎了石头，获得石头"
		FarmState.DEBRIS_TWIG:
			return "捡起了树枝，获得木材"
		FarmState.DEBRIS_STUMP:
			return "砍倒了树桩，获得木材"
		_:
			return "杂物已清除"

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
	# BUG-59: only the porch steps (door point = bottom step), not the road in
	# front of the house. Walking past along the road must never enter.
	shape.size = HOUSE_ENTRANCE_SIZE
	collision.shape = shape
	collision.name = "CollisionShape2D"
	collision.position = Vector2(0, -HOUSE_ENTRANCE_SIZE.y * 0.5)
	_house_entrance.add_child(collision)
	_house_entrance.body_entered.connect(_on_house_entrance_entered)
	_house_entrance.body_exited.connect(_on_house_entrance_exited)
	add_child(_house_entrance)

func _on_house_entrance_entered(body: Node2D) -> void:
	if body is Player:
		_player_at_house_door = body as Player
		_try_enter_house()

func _on_house_entrance_exited(body: Node2D) -> void:
	if body == _player_at_house_door:
		_player_at_house_door = null

## Enter only while standing on the steps and walking north (into the door).
func _try_enter_house() -> void:
	var player := _player_at_house_door
	if _entering_house or player == null or not is_instance_valid(player):
		return
	if not player.is_walking or player.current_direction != Player.Direction.UP:
		return
	_entering_house = true
	GameManager.change_location("res://src/world/maps/PlayerHouse.tscn", "house_entrance")

func _physics_process(_delta: float) -> void:
	if _player_at_house_door != null:
		_try_enter_house()

func get_house_door_position() -> Vector2:
	return _house_entrance.global_position if _house_entrance else Vector2(841, 286)


func _setup_village_exit() -> void:
	_village_exit = Area2D.new()
	_village_exit.name = "VillageExit"
	_village_exit.position = from_village_spawn.position + Vector2(100, 0)  # clear of from_village spawn (no instant bounce)
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
	if (
		OS.is_debug_build()
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and (event as InputEventKey).keycode == DEBUG_SPAWN_ANIMALS_KEY
	):
		debug_spawn_animals()
		get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed("inventory") or event.is_action_pressed("journal")) and not GameManager.is_paused():
		var context := {}
		if event.is_action_pressed("inventory"):
			context["tab"] = "inventory"
		UIManager.open_screen("journal", context)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		# Esc belongs to the topmost UIManager screen/confirmation when one is open.
		if UIManager.has_open_modal():
			return
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


## BUG-55: debug-only animal spawner (no save data or shop sells animals yet).
## Returns the spawned animals so tests can inspect them.
func debug_spawn_animals() -> Array[Animal]:
	var spawned: Array[Animal] = []
	if not OS.is_debug_build() or layout_root == null:
		return spawned
	var taken: Array[Vector2] = []
	for existing in get_tree().get_nodes_in_group("debug_spawned_animal"):
		if existing is Node2D:
			taken.append((existing as Node2D).global_position)
	for scene_path in DEBUG_ANIMAL_SCENES:
		var packed := load(scene_path) as PackedScene
		var animal := packed.instantiate() as Animal if packed else null
		if animal == null:
			continue
		var spot := _find_debug_animal_spot(taken)
		if spot == Vector2.INF:
			animal.free()
			continue
		taken.append(spot)
		animal.add_to_group("debug_spawned_animal")
		actor_layer.add_child(animal)
		animal.set_home_position(spot)
		animal.go_outside()
		spawned.append(animal)
	print("[Farm] DEBUG F9 spawned %d animals" % spawned.size())
	_show_notification("调试：生成了 %d 只动物" % spawned.size())
	return spawned


func _find_debug_animal_spot(taken: Array[Vector2]) -> Vector2:
	var space := get_world_2d().direct_space_state
	var probe := CircleShape2D.new()
	probe.radius = DEBUG_ANIMAL_CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = PHYSICS_LAYERS.WORLD | PHYSICS_LAYERS.PLAYER | PHYSICS_LAYERS.NPC
	query.collide_with_areas = false
	for ring in range(0, 6):
		var count := maxi(1, ring * 8)
		for i in range(count):
			var angle := TAU * float(i) / float(count)
			var spot := DEBUG_ANIMAL_AREA_CENTER + Vector2(cos(angle), sin(angle)) * ring * 72.0
			var clear := true
			for other in taken:
				if other.distance_to(spot) < DEBUG_ANIMAL_CLEARANCE * 2.0:
					clear = false
					break
			if not clear:
				continue
			query.transform = Transform2D(0.0, spot)
			if space.intersect_shape(query, 1).is_empty():
				return spot
	return Vector2.INF
