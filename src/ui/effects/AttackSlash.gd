extends Node2D
class_name AttackSlash

## AttackSlash - 攻击斩击特效
## 显示玩家攻击时的斩击动画

# 配置
@export var slash_duration: float = 0.2
@export var slash_size: float = 40.0
@export var slash_arc: float = PI * 0.5  # 90度弧

# 颜色
@export var slash_color: Color = Color.WHITE

# 节点
var slash_line: Line2D

func _ready() -> void:
	_create_slash()
	_play_slash_animation()
	await get_tree().create_timer(slash_duration + 0.1).timeout
	queue_free()

## 创建斩击线条
func _create_slash() -> void:
	slash_line = Line2D.new()
	slash_line.width = 3.0
	slash_line.default_color = slash_color
	slash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(slash_line)

## 播放斩击动画
func _play_slash_animation() -> void:
	# 创建弧形点的动画
	var tween = create_tween()

	for i in range(10):
		tween.tween_callback(_update_slash_arc.bind(float(i) / 9.0))
		tween.tween_interval(slash_duration / 10.0)

## 更新斩击弧度
func _update_slash_arc(progress: float) -> void:
	if slash_line == null:
		return

	slash_line.clear_points()

	var start_angle = -slash_arc * 0.5
	var current_angle = start_angle + slash_arc * progress

	var points = 5
	for i in range(points):
		var angle = start_angle + (current_angle - start_angle) * (float(i) / float(points - 1))
		var point = Vector2(cos(angle), sin(angle)) * slash_size
		slash_line.add_point(point)

## 设置方向
func set_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()

## 创建斩击特效
static func create(position: Vector2, direction: Vector2 = Vector2.RIGHT) -> AttackSlash:
	var slash = AttackSlash.new()
	slash.global_position = position
	slash.set_direction(direction)
	return slash

## 显示斩击特效
static func show_slash(position: Vector2, direction: Vector2 = Vector2.RIGHT) -> AttackSlash:
	var slash = create(position, direction)
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		tree.current_scene.add_child(slash)
	return slash