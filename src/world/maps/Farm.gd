extends Node2D
class_name Farm

## Farm - 农场场景
## 游戏主场景，玩家农场所在地

const TimeDisplayScene = preload("res://src/ui/hud/TimeDisplay.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const HoeScene = preload("res://src/entities/tools/Hoe.tscn")
const MapLoaderScript = preload("res://src/core/map/MapLoader.gd")
const FARM_LAYOUT_PATH := "res://data/farm_layout.json"
const EDITOR_MAP_PATH := "res://data/maps/farm_layout.json"
const LAYOUT_SCENES := {
	"shipping_bin": preload("res://src/world/objects/ShippingBin.tscn"),
	"workbench": preload("res://src/world/objects/Workbench.tscn"),
	"fishing_spot": preload("res://src/world/objects/FishingSpot.tscn"),
	"coop": preload("res://src/world/objects/Coop.tscn"),
	"barn": preload("res://src/world/objects/Barn.tscn"),
	"ore": preload("res://src/world/objects/Ore.tscn")
}

@onready var tile_map: TileMap = $TileMap
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var tilled_area: Node2D = $TilledArea

var time_display: Control
var ui_canvas: CanvasLayer
var hoe_tool: Hoe
var soil_plots: Array[Soil] = []
var planting_manager: PlantingManager = null
var layout_root: Node2D

func _ready() -> void:
	print("[Farm] Scene loaded")
	_setup_tilemap()
	print("[Farm] Tileset: ", tile_map.tile_set)
	_setup_layout_root()
	_apply_layout_from_file()
	_setup_ui()
	_setup_tools()
	_setup_soil_plots()
	_setup_planting_manager()
	_connect_time_signals()
	_connect_event_signals()

func _setup_tilemap() -> void:
	print("[Farm] Tileset: ", tile_map.tile_set)
	# 使用 FarmTilesetBuilder 构建瓦片集
	if tile_map.tile_set == null:
		var tile_set: TileSet = FarmTilesetBuilder.build_tileset()
		tile_map.tile_set = tile_set
		print("[Farm] TileSet built from FarmTilesetBuilder")

	# 尝试从 MapLoader 加载编辑器地图
	if MapLoaderScript.map_exists(EDITOR_MAP_PATH):
		var editor_tiles: Array = MapLoaderScript.load_layout(EDITOR_MAP_PATH)
		if _has_meaningful_editor_layout(editor_tiles):
			_paint_editor_layout(editor_tiles)
			print("[Farm] Loaded map from MapLoader: ", EDITOR_MAP_PATH)
		else:
			_paint_default_farm()
			print("[Farm] Editor map is empty placeholder data, using default farm")
	else:
		_paint_default_farm()
		print("[Farm] No editor map found, using default farm")
	print("[Farm] TileMap setup complete")

func _has_meaningful_editor_layout(editor_tiles: Array) -> bool:
	for row in editor_tiles:
		if row is Array:
			for tile_id in row:
				if tile_id is int and tile_id != 0:
					return true
				if tile_id is float and int(tile_id) != 0:
					return true
	return false

func _paint_default_farm() -> void:
	print("[Farm] Painting default farm layout...")
	# 地图：50x35 瓦片 @ 64px = 3200x2240 像素
	var GRASS := FarmTilesetBuilder.TileCoord.GRASS_PLAIN
	var PATH := FarmTilesetBuilder.TileCoord.PATH_DIRT
	var FENCE_H := FarmTilesetBuilder.TileCoord.FENCE_H
	var FENCE_V := FarmTilesetBuilder.TileCoord.FENCE_V
	var FENCE_POST := FarmTilesetBuilder.TileCoord.FENCE_POST
	var WATER := FarmTilesetBuilder.TileCoord.WATER_POND
	var WATER_EDGE_TL := FarmTilesetBuilder.TileCoord.WATER_EDGE_TL
	var WATER_EDGE_TR := FarmTilesetBuilder.TileCoord.WATER_EDGE_TR
	var WATER_EDGE_BL := FarmTilesetBuilder.TileCoord.WATER_EDGE_BL
	var WATER_EDGE_BR := FarmTilesetBuilder.TileCoord.WATER_EDGE_BR
	var WOOD := FarmTilesetBuilder.TileCoord.WOOD_PLANKS

	# 填满草地
	for x in range(50):
		for y in range(35):
			tile_map.set_cell(0, Vector2i(x, y), 0, FarmTilesetBuilder.get_coord(GRASS))

	# 主路（中间垂直）
	for y in range(35):
		tile_map.set_cell(0, Vector2i(25, y), 0, FarmTilesetBuilder.get_coord(PATH))

	# 横向小路
	for x in range(15, 36):
		tile_map.set_cell(0, Vector2i(x, 15), 0, FarmTilesetBuilder.get_coord(PATH))

	# 入口路径
	for x in range(20, 31):
		tile_map.set_cell(0, Vector2i(x, 25), 0, FarmTilesetBuilder.get_coord(PATH))

	# 池塘（右上角）
	for x in range(38, 45):
		for y in range(3, 10):
			var coord: Vector2i
			if x == 38 and y == 3: coord = FarmTilesetBuilder.get_coord(WATER_EDGE_TL)
			elif x == 44 and y == 3: coord = FarmTilesetBuilder.get_coord(WATER_EDGE_TR)
			elif x == 38 and y == 9: coord = FarmTilesetBuilder.get_coord(WATER_EDGE_BL)
			elif x == 44 and y == 9: coord = FarmTilesetBuilder.get_coord(WATER_EDGE_BR)
			else: coord = FarmTilesetBuilder.get_coord(WATER)
			tile_map.set_cell(0, Vector2i(x, y), 0, coord)

	# 木地板（房子底板）
	for x in range(28, 40):
		for y in range(6, 12):
			tile_map.set_cell(0, Vector2i(x, y), 0, FarmTilesetBuilder.get_coord(WOOD))

	# 篱笆围栏
	for x in range(10, 40):
		tile_map.set_cell(0, Vector2i(x, 4), 0, FarmTilesetBuilder.get_coord(FENCE_H))
		tile_map.set_cell(0, Vector2i(x, 28), 0, FarmTilesetBuilder.get_coord(FENCE_H))
	for y in range(4, 29):
		tile_map.set_cell(0, Vector2i(10, y), 0, FarmTilesetBuilder.get_coord(FENCE_V))
		tile_map.set_cell(0, Vector2i(40, y), 0, FarmTilesetBuilder.get_coord(FENCE_V))
	for corner in [Vector2i(10, 4), Vector2i(40, 4), Vector2i(10, 28), Vector2i(40, 28)]:
		tile_map.set_cell(0, corner, 0, FarmTilesetBuilder.get_coord(FENCE_POST))

	print("[Farm] Default farm layout painted.")


## Map editor tile ID → FarmTilesetBuilder TileCoord mapping.
## Editor tile IDs 0-15 correspond to the first 8 columns × 2 rows of the farm_tiles.png atlas.
## This maps each editor tile to the most appropriate FarmTilesetBuilder tile.
const _EDITOR_TILE_MAP := {
	0:  FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # grass
	1:  FarmTilesetBuilder.TileCoord.GRASS_2,        # dark_grass
	2:  FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # medium_grass (→ grass)
	3:  FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # light_grass (→ grass)
	4:  FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # dry_grass (→ grass)
	5:  FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # flower_grass (→ grass)
	6:  FarmTilesetBuilder.TileCoord.PATH_DIRT,       # path
	7:  FarmTilesetBuilder.TileCoord.PATH_DIRT,       # dirt (→ dirt path)
	8:  FarmTilesetBuilder.TileCoord.WATER_POND,      # water
	9:  FarmTilesetBuilder.TileCoord.WATER_POND,      # shallow_water (→ water)
	10: FarmTilesetBuilder.TileCoord.GRASS_PLAIN,    # sand (→ grass placeholder)
	11: FarmTilesetBuilder.TileCoord.FENCE_H,         # fence
	12: FarmTilesetBuilder.TileCoord.GATE_OPEN,       # gate
	13: FarmTilesetBuilder.TileCoord.WOOD_PLANKS,     # wood_floor
	14: FarmTilesetBuilder.TileCoord.STONE_WALL,      # stone_floor (→ stone wall)
	15: FarmTilesetBuilder.TileCoord.FERTILE_SOIL,    # farmland
}

## Paint the map from the map editor's JSON layout (30×20 grid).
## Each cell in editor_tiles is an editor tile ID (0-15), which is translated
## to a FarmTilesetBuilder TileCoord and painted on the TileMap.
func _paint_editor_layout(editor_tiles: Array) -> void:
	print("[Farm] Painting editor layout (", editor_tiles.size(), " rows)...")
	for row in range(editor_tiles.size()):
		var row_data: Array = editor_tiles[row]
		for col in range(row_data.size()):
			var editor_id: int = row_data[col]
			var tile_coord: int = _EDITOR_TILE_MAP.get(editor_id, FarmTilesetBuilder.TileCoord.GRASS_PLAIN)
			var atlas_coord: Vector2i = FarmTilesetBuilder.get_coord(tile_coord)
			tile_map.set_cell(0, Vector2i(col, row), 0, atlas_coord)
	print("[Farm] Editor layout painted.")


func _setup_layout_root() -> void:
	layout_root = get_node_or_null("LayoutRoot")
	if layout_root == null:
		layout_root = Node2D.new()
		layout_root.name = "LayoutRoot"
		add_child(layout_root)

func _apply_layout_from_file() -> void:
	if layout_root == null:
		return
	for child in layout_root.get_children():
		child.queue_free()

	var file: FileAccess = FileAccess.open(FARM_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		print("[Farm] No farm layout file found, using empty layout")
		return

	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[Farm] Failed to parse farm_layout.json")
		return

	var data: Dictionary = json.data
	for object_data in data.get("objects", []):
		var node: Node2D = _build_layout_node(object_data)
		if node:
			layout_root.add_child(node)
	print("[Farm] Loaded layout objects: ", layout_root.get_child_count())

func _build_layout_node(object_data: Dictionary) -> Node2D:
	var kind: String = str(object_data.get("kind", ""))
	if kind == "rect":
		return _build_rect_node(object_data)
	if kind == "scene":
		return _build_scene_node(object_data)
	return null

func _build_rect_node(object_data: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	node.name = object_data.get("name", "RectObject")
	var size_dict: Dictionary = object_data.get("size", {})
	var color_dict: Dictionary = object_data.get("color", {})
	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(size_dict.get("x", 32.0), size_dict.get("y", 32.0))
	rect.position = -rect.size / 2.0
	rect.color = Color(
		color_dict.get("r", 1.0),
		color_dict.get("g", 1.0),
		color_dict.get("b", 1.0),
		color_dict.get("a", 1.0)
	)
	node.add_child(rect)
	var pos_dict: Dictionary = object_data.get("position", {})
	node.position = Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
	return node

func _build_scene_node(object_data: Dictionary) -> Node2D:
	var scene_key: String = object_data.get("scene_key", "")
	var packed: PackedScene = LAYOUT_SCENES.get(scene_key)
	if packed == null:
		push_warning("[Farm] Unknown scene key: " + scene_key)
		return null
	var node = packed.instantiate() as Node2D
	if node == null:
		push_warning("[Farm] Scene key did not instantiate a Node2D: " + scene_key)
		return null
	node.name = object_data.get("name", scene_key)
	var pos_dict: Dictionary = object_data.get("position", {})
	node.position = Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
	var properties: Dictionary = object_data.get("properties", {})
	for key in properties.keys():
		node.set(key, properties[key])
	return node

func _setup_ui() -> void:
	# 创建UI画布层
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10  # UI层
	add_child(ui_canvas)

	# 添加时间显示
	time_display = TimeDisplayScene.instantiate()
	ui_canvas.add_child(time_display)
	print("[Farm] TimeDisplay added to UI canvas")
	
	# 添加工具显示
	var tool_display = ToolDisplayScene.instantiate()
	ui_canvas.add_child(tool_display)
	print("[Farm] ToolDisplay added to UI canvas")

func _setup_tools() -> void:
	# 创建锄头工具实例
	hoe_tool = HoeScene.instantiate()
	add_child(hoe_tool)
	print("[Farm] Hoe tool initialized")

func _setup_soil_plots() -> void:
	# 收集所有土壤地块
	if tilled_area:
		for child in tilled_area.get_children():
			if child is Soil:
				soil_plots.append(child)
		print("[Farm] Found ", soil_plots.size(), " soil plots")

func _setup_planting_manager() -> void:
	var PlantingManagerScript = load("res://src/core/farming/PlantingManager.gd")
	planting_manager = PlantingManagerScript.new()
	planting_manager.name = "PlantingManager"
	add_child(planting_manager)
	print("[Farm] Planting manager initialized")

func _connect_time_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.hour_changed.connect(_on_hour_changed)
		time_manager.day_changed.connect(_on_day_changed)
		time_manager.season_changed.connect(_on_season_changed)
		print("[Farm] Connected to TimeManager signals")

func _connect_event_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		# 连接交互信号
		event_bus.player_interacted.connect(_on_player_interacted)
		# 连接收获信号
		event_bus.crop_harvested.connect(_on_crop_harvested)
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
		
		# 如果土壤未耕地，使用锄头
		if soil.can_till():
			if hoe_tool:
				hoe_tool.use(soil)
		return
	
	# 其他交互由各自的系统处理


func _on_crop_harvested(crop_type: String, quality: int, quantity: int) -> void:
	# 收获作物后自动出售获得金钱
	# 获取作物的基础价格（从配置中获取或使用默认值）
	var base_price: int = _get_crop_base_price(crop_type)

	var money_system = get_node_or_null("/root/MoneySystem")
	if base_price > 0 and money_system:
		var total_earned: int = money_system.sell_crop(
			crop_type,
			crop_type.capitalize(),
			quality,
			base_price,
			quantity
		)
		print("[Farm] Earned $", total_earned, " from selling ", quantity, " ", crop_type)


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
