extends Node2D
class_name Forest

## Forest - 森林场景
## 可采集野果、蘑菇、草药等野生资源

const TimeDisplayScene = preload("res://src/ui/hud/TimeDisplay.tscn")
const ForageItemScene = preload("res://src/entities/items/ForageItem.tscn")
const PlayerScene = preload("res://src/entities/player/Player.tscn")

@onready var tile_map: TileMap = $TileMap
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var forage_points: Node2D = $ForagePoints

var time_display: Control
var ui_canvas: CanvasLayer
var forage_items: Array[ForageItem] = []


func _ready() -> void:
	print("[Forest] Scene loaded")
	_setup_tilemap()
	_setup_ui()
	_setup_forage_points()
	_connect_signals()
	_generate_random_forage()


func _setup_tilemap() -> void:
	if tile_map.tile_set == null:
		var tile_set: TileSet = TileSet.new()
		tile_map.tile_set = tile_set
	print("[Forest] TileMap setup complete")


func _setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10
	add_child(ui_canvas)

	time_display = TimeDisplayScene.instantiate()
	ui_canvas.add_child(time_display)
	print("[Forest] TimeDisplay added to UI canvas")


func _setup_forage_points() -> void:
	if forage_points:
		for child in forage_points.get_children():
			if child is ForageItem:
				forage_items.append(child)
		print("[Forest] Found ", forage_items.size(), " forage items")


func _generate_random_forage() -> void:
	# 根据季节生成额外的随机采集点
	if ForagingSystem == null:
		return

	var season: String = get_node("/root/TimeManager").get_season_name() if TimeManager else "Spring"
	var spawn_positions: Array[Vector2] = [
		Vector2(200, 200), Vector2(400, 150), Vector2(600, 200),
		Vector2(250, 400), Vector2(450, 350), Vector2(650, 400),
		Vector2(150, 300), Vector2(750, 300), Vector2(350, 500)
	]

	# 获取季节可用的采集物品
	var available_forage: Array = ForagingSystem.get_seasonal_forage(season)
	var forest_forage: Array = []
	for forage in available_forage:
		if forage.locations.has("forest"):
			forest_forage.append(forage)

	if forest_forage.is_empty():
		print("[Forest] No forage available for season: ", season)
		return

	# 随机生成3-5个采集点
	var spawn_count: int = randi_range(3, 5)
	var used_positions: Array[int] = []

	for i in range(spawn_count):
		var pos_index: int
		while true:
			pos_index = randi() % spawn_positions.size()
			if not used_positions.has(pos_index):
				used_positions.append(pos_index)
				break

		# 根据稀有度选择物品
		var selected_forage = ForagingSystem._select_random_forage(forest_forage)
		if selected_forage:
			_spawn_forage_item(selected_forage.id, spawn_positions[pos_index])


func _spawn_forage_item(forage_id: String, pos: Vector2) -> void:
	if ForageItemScene == null:
		return

	var item: ForageItem = ForageItemScene.instantiate()
	item.forage_id = forage_id
	item.global_position = pos
	forage_points.add_child(item)
	forage_items.append(item)
	print("[Forest] Spawned forage: ", forage_id, " at ", pos)


func _connect_signals() -> void:
	if TimeManager:
		TimeManager.day_changed.connect(_on_day_changed)
		TimeManager.season_changed.connect(_on_season_changed)
	print("[Forest] Connected to signals")


func _on_day_changed(new_day: int) -> void:
	print("[Forest] Day changed to: ", new_day)
	# 检查刷新
	_check_forage_respawn()


func _on_season_changed(new_season: int, season_name: String) -> void:
	print("[Forest] Season changed to: ", season_name)
	# 重新生成本季节的采集物品
	_regenerate_forage()


func _check_forage_respawn() -> void:
	for item in forage_items:
		if item.is_collected:
			# ForagingSystem 会处理刷新逻辑
			pass


func _regenerate_forage() -> void:
	# 清除现有的采集物品
	for item in forage_items:
		if is_instance_valid(item):
			item.queue_free()
	forage_items.clear()

	# 重新生成
	_generate_random_forage()


func get_player_spawn_position() -> Vector2:
	return player_spawn.global_position