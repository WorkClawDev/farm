extends CanvasLayer

## SceneTransition - 场景切换管理器
## 提供淡入淡出效果的场景切换功能

signal transition_completed
signal transition_started

# 单例引用
static var instance: SceneTransition = null

# 切换参数
const FADE_DURATION: float = 0.5  # 淡入淡出持续时间
const TRANSITION_COLOR: Color = Color.BLACK

# 状态
var is_transitioning: bool = false
var _fade_rect: ColorRect
var _tween: Tween

func _ready() -> void:
	# 设置单例
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	
	# 创建淡入淡出用的ColorRect
	_fade_rect = ColorRect.new()
	_fade_rect.color = TRANSITION_COLOR
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	add_child(_fade_rect)
	
	# 确保在最上层
	layer = 100
	
	print("[SceneTransition] Initialized")

## 切换到指定场景（带淡入淡出效果）
static func transition_to(scene_path: String, spawn_point: String = "") -> void:
	if instance == null:
		push_error("[SceneTransition] No instance found!")
		return
	
	if instance.is_transitioning:
		push_warning("[SceneTransition] Already transitioning")
		return
	
	instance._perform_transition(scene_path, spawn_point)

## 立即切换场景（无动画）
static func change_scene_immediate(scene_path: String) -> void:
	if instance and instance.get_tree():
		instance.get_tree().change_scene_to_file(scene_path)

## 执行场景切换动画
func _perform_transition(scene_path: String, spawn_point: String) -> void:
	is_transitioning = true
	transition_started.emit()
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.game:
		event_bus.game.scene_transition_started.emit(scene_path)
	
	# 淡出动画
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_callback(_on_fade_out_complete.bind(scene_path, spawn_point))

## 淡出完成回调
func _on_fade_out_complete(scene_path: String, spawn_point: String) -> void:
	# 切换场景
	var result = get_tree().change_scene_to_file(scene_path)
	
	if result != OK:
		push_error("[SceneTransition] Failed to change scene: %s" % scene_path)
		# 淡入恢复
		_tween = create_tween()
		_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
		is_transitioning = false
		return
	
	# 等待场景加载后应用出生点并淡入
	await get_tree().process_frame
	if spawn_point != "":
		_apply_spawn_point(spawn_point)
	_fade_in()

## 淡入动画
func _fade_in() -> void:
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_callback(_on_fade_in_complete)

## 淡入完成回调
func _on_fade_in_complete() -> void:
	is_transitioning = false
	transition_completed.emit()
	get_node("/root/EventBus").game.scene_transition_completed.emit()
	print("[SceneTransition] Transition completed")

## 设置玩家出生点（在新场景中调用）
static func set_spawn_point(spawn_point: String) -> void:
	if instance:
		instance._apply_spawn_point(spawn_point)

func _apply_spawn_point(spawn_point: String) -> void:
	if spawn_point == "":
		return

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.player:
		event_bus.player.spawn_point_changed.emit(spawn_point)

	var scene := get_tree().current_scene
	if scene == null:
		return

	var player: Node = scene.find_child("Player", true, false)
	if player == null:
		return

	# 优先查找与 spawn_point 同名的 Marker2D
	var marker: Node = scene.find_child(spawn_point, true, false)
	if marker is Node2D:
		player.global_position = marker.global_position
		print("[SceneTransition] Player spawned at marker: %s" % spawn_point)
		return

	# 回退：场景提供的默认出生点
	if scene.has_method("get_player_spawn_position"):
		player.global_position = scene.get_player_spawn_position()
		print("[SceneTransition] Player spawned at default position for: %s" % spawn_point)
