extends Control
class_name HeartDisplay

## HeartDisplay - 好感度心数显示
## 显示NPC的好感度心数，支持动态更新和动画效果

# 心数显示配置
const MAX_VISIBLE_HEARTS: int = 10
const HEART_SIZE: Vector2 = Vector2(16, 16)
const HEART_SPACING: int = 4

# 心的颜色
const COLOR_FULL_HEART = Color(1.0, 0.3, 0.4)  # 红色（满心）
const COLOR_EMPTY_HEART = Color(0.3, 0.3, 0.3, 0.5)  # 灰色（空心）
const COLOR_PARTIAL_HEART = Color(1.0, 0.6, 0.7)  # 浅红色（部分）

# 节点引用
@onready var hearts_container: HBoxContainer = $HBoxContainer
@onready var hearts_label: Label = $HeartsLabel

# 当前显示的NPC
var current_npc_id: String = ""
var current_hearts: int = 0
var current_points: int = 0

# 心图标数组
var heart_icons: Array[TextureRect] = []

# 动画状态
var is_animating: bool = false


func _ready() -> void:
	_setup_hearts_display()
	_connect_signals()


## 设置心数显示
func _setup_hearts_display() -> void:
	# 创建心数容器
	if not hearts_container:
		hearts_container = HBoxContainer.new()
		hearts_container.name = "HBoxContainer"
		add_child(hearts_container)

	hearts_container.spacing = HEART_SPACING

	# 创建心图标
	for i in range(MAX_VISIBLE_HEARTS):
		var heart = TextureRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.name = "Heart%d" % i
		hearts_container.add_child(heart)
		heart_icons.append(heart)

	# 创建心数标签
	if not hearts_label:
		hearts_label = Label.new()
		hearts_label.name = "HeartsLabel"
		add_child(hearts_label)

	hearts_label.add_theme_font_size_override("font_size", 12)


## 连接信号
func _connect_signals() -> void:
	if Friendship:
		Friendship.friendship_hearts_changed.connect(_on_friendship_hearts_changed)
		Friendship.friendship_points_changed.connect(_on_friendship_points_changed)


## 显示NPC好感度
func show_friendship(npc_id: String) -> void:
	current_npc_id = npc_id

	if not Friendship:
		_update_display(0, 0, 0)
		return

	var info = Friendship.get_friendship_info(npc_id)
	_update_display(info.hearts, info.points, info.points_in_current_heart)


## 更新显示
func _update_display(hearts: int, points: int, points_in_heart: int) -> void:
	current_hearts = hearts
	current_points = points

	# 更新心图标
	for i in range(MAX_VISIBLE_HEARTS):
		if i < heart_icons.size():
			var heart = heart_icons[i]
			if i < hearts:
				_set_heart_full(heart)
			else:
				_set_heart_empty(heart)

	# 更新标签
	if hearts_label:
		hearts_label.text = "%d/%d" % [hearts, MAX_VISIBLE_HEARTS]


## 设置满心状态
func _set_heart_full(heart: TextureRect) -> void:
	heart.modulate = COLOR_FULL_HEART
	# 这里可以设置实际的爱心图标
	# heart.texture = preload("res://assets/sprites/ui/heart_full.png")


## 设置空心状态
func _set_heart_empty(heart: TextureRect) -> void:
	heart.modulate = COLOR_EMPTY_HEART
	# heart.texture = preload("res://assets/sprites/ui/heart_empty.png")


## 设置部分心状态
func _set_heart_partial(heart: TextureRect, progress: float) -> void:
	# 使用进度来显示部分填充的心
	var color = COLOR_EMPTY_HEART.lerp(COLOR_FULL_HEART, progress)
	heart.modulate = color


## 播放心数增加动画
func play_heart_gain_animation() -> void:
	if is_animating:
		return

	is_animating = true

	# 找到最后一颗满心的图标进行动画
	var last_full_heart_index = current_hearts - 1
	if last_full_heart_index >= 0 and last_full_heart_index < heart_icons.size():
		var heart = heart_icons[last_full_heart_index]
		_animate_heart_appear(heart)

	await get_tree().create_timer(0.5).timeout
	is_animating = false


## 心出现动画
func _animate_heart_appear(heart: TextureRect) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)

	heart.scale = Vector2(0, 0)
	tween.tween_property(heart, "scale", Vector2(1, 1), 0.4)


## 心跳动画
func play_heartbeat_animation() -> void:
	for heart in heart_icons:
		if heart.modulate == COLOR_FULL_HEART:
			var tween = create_tween()
			tween.tween_property(heart, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(heart, "scale", Vector2(1.0, 1.0), 0.1)


## 好感度心数变化回调
func _on_friendship_hearts_changed(npc_id: String, hearts: int) -> void:
	if npc_id == current_npc_id:
		var info = Friendship.get_friendship_info(npc_id) if Friendship else {}
		_update_display(hearts, info.get("points", 0), info.get("points_in_current_heart", 0))
		play_heart_gain_animation()


## 好感度点数变化回调
func _on_friendship_points_changed(npc_id: String, _points: int, _delta: int) -> void:
	if npc_id == current_npc_id:
		show_friendship(npc_id)


## 隐藏显示
func hide_display() -> void:
	visible = false
	current_npc_id = ""


## 获取当前NPC ID
func get_current_npc_id() -> String:
	return current_npc_id


## 是否显示中
func is_showing() -> bool:
	return visible and not current_npc_id.is_empty()