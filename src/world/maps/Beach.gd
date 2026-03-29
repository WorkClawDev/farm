extends Node2D
class_name Beach

## Beach - 海滩场景
## 可以进行钓鱼活动的海边区域

# 场景配置
@export var scene_name: String = "Beach"
@export var is_outdoor: bool = true

# 钓鱼点配置
@export var fishing_locations: Array[String] = ["beach"]

# 节点引用
@onready var tilemap: TileMap = $TileMap if has_node("TileMap") else null
@onready var player_spawn: Marker2D = $PlayerSpawn if has_node("PlayerSpawn") else null
@onready var fishing_spots: Node2D = $FishingSpots if has_node("FishingSpots") else null

# 场景切换点
@onready var exit_to_village: Area2D = $ExitToVillage if has_node("ExitToVillage") else null

const VILLAGE_SCENE = "res://src/world/maps/Village.tscn"

func _ready() -> void:
	_setup_ui()
	_setup_fishing_spots()
	_setup_exits()
	print("[Beach] Scene initialized")

func _setup_ui() -> void:
	# 创建UI画布层
	var ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 10
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
	get_node("/root/EventBus").ui_opened.emit("fishing")

## 钓鱼结束
func _on_fishing_ended(spot: FishingSpot, success: bool, fish_id: String) -> void:
	print("[Beach] Fishing ended: ", "success" if success else "failed")
	get_node("/root/EventBus").ui_closed.emit("fishing")

	if success and not fish_id.is_empty():
		get_node("/root/EventBus").notification_shown.emit("钓到了鱼!", 0)

## 离开海滩去村庄
func _on_exit_village(body: Node2D) -> void:
	if body is Player:
		print("[Beach] Player exiting to village")
		SceneTransition.transition_to(VILLAGE_SCENE)

## 获取钓鱼地点类型
func get_fishing_location_type() -> String:
	return "beach"