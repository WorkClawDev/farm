extends Node2D
class_name Beach

## Beach - 海滩场景
## 可以进行钓鱼活动的海边区域

const GameConstants = preload("res://src/core/constants/GameConstants.gd")
const BeachConstants = preload("res://src/core/constants/BeachConstants.gd")

# 场景配置
@export var scene_name: String = "Beach"
@export var is_outdoor: bool = true

# 钓鱼点配置
@export var fishing_locations: Array[String] = ["beach"]

# 节点引用
@onready var tilemap: TileMap = $TileMap if has_node("TileMap") else null
@onready var player_spawn: Marker2D = $PlayerSpawn if has_node("PlayerSpawn") else null
@onready var fishing_spots: Node2D = $FishingSpots if has_node("FishingSpots") else null
@onready var background_rect: ColorRect = $Background if has_node("Background") else null
@onready var water_layer: ColorRect = $WaterLayer if has_node("WaterLayer") else null

# 场景切换点
@onready var exit_to_village: Area2D = $ExitToVillage if has_node("ExitToVillage") else null

const VILLAGE_SCENE = "res://src/world/maps/Village.tscn"

func _ready() -> void:
	_setup_tilemap()
	_setup_ui()
	_setup_fishing_spots()
	_setup_exits()
	print("[Beach] Scene initialized")

func _setup_tilemap() -> void:
	if tilemap == null:
		return

	tilemap.scale = Vector2(GameConstants.TILE_RENDER_SCALE, GameConstants.TILE_RENDER_SCALE)

	if tilemap.tile_set == null or tilemap.tile_set.get_source_count() == 0:
		tilemap.tile_set = BeachTilesetBuilder.build_tileset()

	tilemap.clear()
	var sand := BeachTilesetBuilder.TileCoord.SAND_PLAIN
	var wet_sand := BeachTilesetBuilder.TileCoord.SAND_WET
	var path := BeachTilesetBuilder.TileCoord.BEACH_PATH
	var shallow := BeachTilesetBuilder.TileCoord.SHALLOW_WATER
	var deep := BeachTilesetBuilder.TileCoord.DEEP_WATER
	var edge_top := BeachTilesetBuilder.TileCoord.WATER_EDGE_SAND_T
	var shell := BeachTilesetBuilder.TileCoord.SEASHELL
	var grass := BeachTilesetBuilder.TileCoord.BEACH_GRASS

	for y in range(BeachConstants.TILE_Y_MIN, BeachConstants.TILE_Y_MAX + 1):
		for x in range(BeachConstants.TILE_X_MIN, BeachConstants.TILE_X_MAX + 1):
			var tile := sand
			if y >= BeachConstants.WET_SAND_START_Y:
				tile = wet_sand
			if y >= BeachConstants.SHALLOW_WATER_START_Y:
				tile = shallow
			if y >= BeachConstants.DEEP_WATER_START_Y:
				tile = deep
			if y == BeachConstants.WATER_EDGE_Y:
				tile = edge_top
			tilemap.set_cell(0, Vector2i(x, y), 0, BeachTilesetBuilder.get_coord(tile))

	for x in range(BeachConstants.PATH_X_MIN, BeachConstants.PATH_X_MAX + 1):
		for y in range(BeachConstants.PATH_Y_MIN, BeachConstants.PATH_Y_MAX + 1):
			tilemap.set_cell(0, Vector2i(x, y), 0, BeachTilesetBuilder.get_coord(path))

	for x in range(BeachConstants.GRASS_PATCH_X_MIN, BeachConstants.GRASS_PATCH_X_MAX + 1):
		for y in range(BeachConstants.GRASS_PATCH_Y_MIN, BeachConstants.GRASS_PATCH_Y_MAX + 1):
			tilemap.set_cell(2, Vector2i(x, y), 0, BeachTilesetBuilder.get_coord(grass))
	for x in BeachConstants.SHELL_POSITIONS:
		tilemap.set_cell(2, Vector2i(x, 1), 0, BeachTilesetBuilder.get_coord(shell))

	if background_rect:
		background_rect.visible = false
	if water_layer:
		water_layer.visible = false

func _setup_ui() -> void:
	# 创建UI画布层
	var ui_canvas = CanvasLayer.new()
	ui_canvas.layer = GameConstants.UI_CANVAS_LAYER
	add_child(ui_canvas)
	
	# 添加时间显示
	var time_display = preload("res://src/ui/hud/TimeDisplay.tscn").instantiate()
	ui_canvas.add_child(time_display)
	
	# 添加任务追踪
	var quest_tracker = preload("res://src/ui/hud/QuestTracker.tscn").instantiate()
	ui_canvas.add_child(quest_tracker)
	print("[Beach] UI setup complete")

## 设置钓鱼点
func _setup_fishing_spots() -> void:
	if fishing_spots:
		for spot in fishing_spots.get_children():
			if spot is FishingSpot:
				spot.fishing_started.connect(_on_fishing_started)
				spot.fishing_ended.connect(_on_fishing_ended)

## 设置出口
func _setup_exits() -> void:
	if exit_to_village:
		exit_to_village.body_entered.connect(_on_exit_village)

## 钓鱼开始
func _on_fishing_started(spot: FishingSpot) -> void:
	print("[Beach] Fishing started at spot: ", spot.name)
	get_node("/root/EventBus").ui.ui_opened.emit("fishing")

## 钓鱼结束
func _on_fishing_ended(spot: FishingSpot, success: bool, fish_id: String) -> void:
	print("[Beach] Fishing ended: ", "success" if success else "failed")
	get_node("/root/EventBus").ui.ui_closed.emit("fishing")

	if success and not fish_id.is_empty():
		get_node("/root/EventBus").ui.notification_shown.emit("钓到了鱼!", 0)

## 离开海滩去村庄
func _on_exit_village(body: Node2D) -> void:
	if body is Player:
		print("[Beach] Player exiting to village")
		SceneTransition.transition_to(VILLAGE_SCENE)

## 获取钓鱼地点类型
func get_fishing_location_type() -> String:
	return "beach"
