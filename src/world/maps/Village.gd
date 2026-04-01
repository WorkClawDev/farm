extends Node2D
class_name Village

## Village - 村庄场景
## 玩家与NPC交互、购物的主要场所

const GameConstants = preload("res://src/core/constants/GameConstants.gd")
@onready var tile_map: TileMap = $TileMap
@onready var player_spawn: Marker2D = $PlayerSpawn

# 场景切换目标
const FARM_SCENE = "res://src/world/maps/Farm.tscn"

# NPC管理器
var npc_manager: NPCManager = null
var _map_built: bool = false  # 防止重复构建

func _ready() -> void:
	print("[Village] Scene loaded")
	_setup_tilemap()
	_setup_npc_manager()
	_setup_ui()
	_connect_transition_areas()
	_build_placeholder_map()  # 构建白模地图结构

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

func _setup_npc_manager() -> void:
	npc_manager = get_node_or_null("/root/NPCManager")
	if npc_manager:
		npc_manager.set_current_scene(self)
		print("[Village] NPC Manager initialized")

func _setup_ui() -> void:
	# 创建UI画布层
	var ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10
	add_child(ui_canvas)
	
	# 添加时间显示
	var time_display = preload("res://src/ui/hud/TimeDisplay.tscn").instantiate()
	ui_canvas.add_child(time_display)
	print("[Village] UI setup complete")

func _connect_transition_areas() -> void:
	var to_farm_area = $TransitionAreas/ToFarmArea
	if to_farm_area:
		to_farm_area.body_entered.connect(_on_to_farm_area_body_entered)

func _on_to_farm_area_body_entered(body: Node2D) -> void:
	if body is Player:
		SceneTransition.transition_to(FARM_SCENE)

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
