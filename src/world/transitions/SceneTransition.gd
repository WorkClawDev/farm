extends CanvasLayer

## SceneTransition - 场景切换管理器
## 提供淡入淡出效果的场景切换功能

signal transition_completed
signal transition_started

# 单例引用

# 切换参数
const FADE_DURATION: float = 0.5  # 淡入淡出持续时间
const TRANSITION_COLOR: Color = Color.BLACK

# 状态
var is_transitioning: bool = false
var _fade_rect: ColorRect
var _tween: Tween

func _ready() -> void:
	# 设置单例
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
func transition_to(scene_path: String, spawn_point: String = "") -> void:
	if is_transitioning:
		push_warning("[SceneTransition] Already transitioning")
		return
	
	_perform_transition(scene_path, spawn_point)

## 立即切换场景（无动画）
func change_scene_immediate(scene_path: String) -> void:
	if get_tree():
		get_tree().change_scene_to_file(scene_path)

## 执行场景切换动画
func _perform_transition(scene_path: String, spawn_point: String) -> void:
	is_transitioning = true
	GameManager.current_spawn_point = spawn_point
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
	
	# 等待场景加载后淡入
	await get_tree().scene_changed
	await get_tree().process_frame
	if not spawn_point.is_empty():
		set_spawn_point(spawn_point)
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
func set_spawn_point(spawn_point: String) -> void:
	# 通过EventBus通知新场景设置玩家位置
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.player:
		event_bus.player.spawn_point_changed.emit(spawn_point)
