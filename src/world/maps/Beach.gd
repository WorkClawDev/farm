extends Node2D
class_name Beach

## Beach - 海滩场景
## 可以进行钓鱼活动的海边区域

const BeachConstants = preload("res://src/core/constants/BeachConstants.gd")
const HUDScene = preload("res://src/ui/hud/HUD.tscn")
const HotkeyBarScene = preload("res://src/ui/hud/HotkeyBar.tscn")
const ToolDisplayScene = preload("res://src/ui/hud/ToolDisplay.tscn")
const QuestTrackerScene = preload("res://src/ui/hud/QuestTracker.tscn")

# 场景配置
@export var scene_name: String = "Beach"
@export var is_outdoor: bool = true

# 钓鱼点配置
@export var fishing_locations: Array[String] = ["beach"]

# 节点引用
@onready var map_root: EditableMap2D = $BeachMap
@onready var player_spawn: MapMarker2D = map_root.get_marker(&"player_spawn")
@onready var fishing_spots: Node2D = $FishingSpots if has_node("FishingSpots") else null
@onready var background_rect: ColorRect = $Background if has_node("Background") else null
@onready var water_layer: ColorRect = $WaterLayer if has_node("WaterLayer") else null

# 场景切换点
@onready var exit_to_village: Area2D = $ExitToVillage if has_node("ExitToVillage") else null

const VILLAGE_SCENE = "res://src/world/maps/Village.tscn"

func _ready() -> void:
	_setup_map()
	_setup_ui()
	_setup_fishing_spots()
	_setup_exits()
	print("[Beach] Scene initialized")

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player_spawn:
		player.global_position = player_spawn.global_position
	AudioManager.update_location_bgm("beach")

func _setup_map() -> void:
	if background_rect:
		background_rect.visible = false
	if water_layer:
		water_layer.visible = false
	for issue in map_root.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			push_error("[BeachMap:%s] %s" % [issue.code, issue.message])
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		map_root.apply_camera_limits(player.get_node_or_null("Camera2D") as Camera2D)
	print("[Beach] Authored map loaded: ", map_root.map_id)

func _setup_ui() -> void:
	var hud := HUDScene.instantiate()
	add_child(hud)
	hud.add_child(HotkeyBarScene.instantiate())
	hud.add_child(ToolDisplayScene.instantiate())
	var quest_tracker := QuestTrackerScene.instantiate()
	quest_tracker.position = Vector2(16, 70)
	hud.add_child(quest_tracker)
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
		SceneTransition.transition_to(VILLAGE_SCENE, "from_beach")

## 获取钓鱼地点类型
func get_fishing_location_type() -> String:
	return "beach"
