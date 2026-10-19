extends Node2D
class_name Village

## Village - 村庄场景
## 玩家与NPC交互、购物的主要场所

const GameConstants = preload("res://src/core/constants/GameConstants.gd")
const IllustratedMapBackdropScene = preload("res://src/world/maps/IllustratedMapBackdrop.gd")
const WorldCollisionLayoutScene = preload("res://src/world/maps/WorldCollisionLayout.gd")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")
const PauseMenuScene = preload("res://src/ui/menus/PauseMenu.tscn")
const DayNightTint = preload("res://src/world/maps/DayNightTint.gd")
var tile_map: TileMap = null # Legacy builder compatibility; no longer part of the runtime scene.
@onready var map_root: EditableMap2D = $VillageMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")

# 场景切换目标
const FARM_SCENE = "res://src/world/maps/Farm.tscn"
const TRANSITION_TARGETS := {
	"ToFarmArea": ["res://src/world/maps/Farm.tscn", "from_village"],
	"ToPlayerHouseArea": ["res://src/world/maps/PlayerHouse.tscn", "village_house_entrance"],
	"ToBeachArea": ["res://src/world/maps/Beach.tscn", "from_village"],
	"ToForestArea": ["res://src/world/maps/Forest.tscn", "from_village"],
	"ToMineArea": ["res://src/world/maps/Mine.tscn", "from_village"],
}
const EXIT_SIGNS := {
	"ToFarmArea": "← 农场",
	"ToBeachArea": "海滩 →",
	"ToForestArea": "↑ 森林",
	"ToMineArea": "↓ 矿洞",
	"ToPlayerHouseArea": "⌂ 小屋",
}
## The mine exit is a band along the bottom edge; its sign sits just above it.
const EXIT_SIGN_OFFSETS := {
	"ToMineArea": Vector2(0, -44),
}

# NPC管理器
var npc_manager: NPCManager = null
var _map_built: bool = false  # 防止重复构建
var pause_menu: PauseMenu

func _ready() -> void:
	print("[Village] Scene loaded")
	_setup_map()
	_setup_ui()
	add_child(DayNightTint.new())  # night tint (round 7)
	_connect_transition_areas()
	# Also on GameManager.change_location (farm/house -> village), which does not go
	# through SceneTransition: the scene's villagers get registered and placed by
	# schedule, once (BUG-44).
	_setup_npc_manager()

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		match GameManager.current_spawn_point:
			"from_farm":
				player.global_position = Vector2(150, 300)
			# Arrive next to the exit you came through (BUG-32); the old mine spawn
			# was inside the north-east building.
			"from_beach":
				player.global_position = Vector2(1110, 690)
			"from_forest":
				player.global_position = Vector2(410, -20)
			# East of SW building + Tree10 corridor (BUG-53); still above ToMineArea.
			"from_mine":
				player.global_position = Vector2(520, 880)
			# The house door on the lower road (BUG-40).
			"from_house":
				player.global_position = Vector2(470, 575)
			_:
				player.global_position = player_spawn.global_position
	AudioManager.update_location_bgm("village")

func _setup_map() -> void:
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[VillageMap:%s] %s" % [issue.code, issue.message])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		map_root.apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
	print("[Village] Authored map loaded: ", map_root.map_id)

func _setup_tilemap() -> void:
	tile_map.scale = Vector2(GameConstants.TILE_RENDER_SCALE, GameConstants.TILE_RENDER_SCALE)
	# 确保 TileMap 格式正确
	
	# 确保有 4 层
	# Layer 0: 地面
	# Layer 1: 建筑/墙体
	# Layer 2: 装饰/物品
	# Layer 3: 碰撞层
	
	if tile_map.tile_set == null:
		var tile_set: TileSet = TileSet.new()
		tile_set.resource_name = "VillageTileSet"
		tile_map.tile_set = tile_set
	
	# 清理旧 atlas sources（如果有的话）
	if tile_map.tile_set.get_source_count() > 0:
		for i in range(tile_map.tile_set.get_source_count() - 1, -1, -1):
			tile_map.tile_set.remove_source(i)
	
	print("[Village] TileMap setup complete, format: ", tile_map.format)

func _setup_illustrated_backdrop() -> void:
	tile_map.visible = false
	var backdrop := IllustratedMapBackdropScene.new()
	backdrop.setup("village")
	add_child(backdrop)
	move_child(backdrop, 0)

func _setup_world_collision() -> void:
	var collision_layout := WorldCollisionLayoutScene.new()
	collision_layout.setup("village")
	add_child(collision_layout)

func _setup_npc_manager() -> void:
	npc_manager = get_node_or_null("/root/NPCManager")
	if npc_manager:
		npc_manager.set_current_scene(self)
		print("[Village] NPC Manager initialized")

func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	hud.add_child(HotkeyBarScene.instantiate())
	hud.add_child(ToolDisplayScene.instantiate())
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)
	# Esc / J used to do nothing in the village: only Farm.gd had these handlers (BUG-20 report).
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.resume_requested.connect(_close_pause_menu)
	pause_menu.quit_to_menu_requested.connect(GameManager.return_to_menu)
	pause_menu.quit_game_requested.connect(GameManager.quit_game)
	hud.add_child(pause_menu)
	print("[Village] UI setup complete")

## Same Esc / J handling as Farm.gd.
func _unhandled_input(event: InputEvent) -> void:
	# Not while a dialogue/shop owns the game state (pause_game() would be a no-op there).
	var playing := GameManager.current_state == GameManager.GameState.PLAYING
	if (event.is_action_pressed("inventory") or event.is_action_pressed("journal")) and playing:
		var context := {}
		if event.is_action_pressed("inventory"):
			context["tab"] = "inventory"
		UIManager.open_screen("journal", context)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if UIManager.has_open_modal():
			return
		if GameManager.is_paused():
			_close_pause_menu()
		elif playing:
			GameManager.pause_game()
			pause_menu.visible = true
		get_viewport().set_input_as_handled()

func _close_pause_menu() -> void:
	pause_menu.visible = false
	GameManager.resume_game()

func _connect_transition_areas() -> void:
	for area_name in TRANSITION_TARGETS:
		var area := get_node_or_null("TransitionAreas/%s" % area_name) as Area2D
		if area:
			area.body_entered.connect(_on_transition_body_entered.bind(area_name))
			_add_exit_sign(area, EXIT_SIGNS.get(area_name, ""), EXIT_SIGN_OFFSETS.get(area_name, Vector2.ZERO))

## Small floating sign so map exits can be found (BUG-32).
func _add_exit_sign(area: Area2D, text: String, offset := Vector2.ZERO) -> void:
	if text.is_empty() or area.get_node_or_null("ExitSign"):
		return
	var label := Label.new()
	label.name = "ExitSign"
	label.text = text
	label.size = Vector2(120, 26)
	label.position = Vector2(-60, -13) + offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(label)

func _on_transition_body_entered(body: Node2D, area_name: String) -> void:
	if not body is Player:
		return
	var target: Array = TRANSITION_TARGETS[area_name]
	SceneTransition.transition_to(target[0], target[1])

func _on_to_farm_area_body_entered(body: Node2D) -> void:
	if body is Player:
		SceneTransition.transition_to(FARM_SCENE, "from_village")

func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position

# ===== 地图构建 =====
func _build_placeholder_map() -> void:
	"""构建 Village 地图（只执行一次）"""
	if _map_built:
		print("[Village] 地图已构建，跳过")
		return
	
	_map_built = true
	
	var builder = VillageBuilder.new()
	builder.name = "VillageBuilder"
	add_child(builder)
	print("[Village] 地图构建器已添加")
