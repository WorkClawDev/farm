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
var tile_map: TileMap = null # Legacy builder compatibility; no longer part of the runtime scene.
@onready var map_root: EditableMap2D = $VillageMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")

# 场景切换目标
const FARM_SCENE = "res://src/world/maps/Farm.tscn"
const TRANSITION_TARGETS := {
	"ToFarmArea": ["res://src/world/maps/Farm.tscn", "from_village"],
	"ToPlayerHouseArea": ["res://src/world/maps/PlayerHouse.tscn", "house_entrance"],
	"ToBeachArea": ["res://src/world/maps/Beach.tscn", "from_village"],
	"ToForestArea": ["res://src/world/maps/Forest.tscn", "from_village"],
	"ToMineArea": ["res://src/world/maps/Mine.tscn", "from_village"],
}

# NPC管理器
var npc_manager: NPCManager = null
var _map_built: bool = false  # 防止重复构建

func _ready() -> void:
	print("[Village] Scene loaded")
	_setup_map()
	_setup_ui()
	_connect_transition_areas()

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		match GameManager.current_spawn_point:
			"from_farm":
				player.global_position = Vector2(150, 300)
			"from_beach":
				player.global_position = Vector2(320, 620)
			"from_forest":
				player.global_position = Vector2(850, 360)
			"from_mine":
				player.global_position = Vector2(720, 120)
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
	print("[Village] UI setup complete")

func _connect_transition_areas() -> void:
	for area_name in TRANSITION_TARGETS:
		var area := get_node_or_null("TransitionAreas/%s" % area_name) as Area2D
		if area:
			area.body_entered.connect(_on_transition_body_entered.bind(area_name))

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
