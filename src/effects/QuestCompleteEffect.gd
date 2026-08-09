extends CanvasLayer
class_name QuestCompleteEffect

## QuestCompleteEffect - 任务完成动画效果
## 显示任务完成的视觉反馈，包括粒子效果、文字动画等

## 动画持续时间
const ANIM_DURATION: float = 2.5

## 粒子数量
const PARTICLE_COUNT: int = 20

## 主容器
var _container: Control

## 背景遮罩
var _background: ColorRect

## 标题标签
var _title_label: Label

## 任务名称标签
var _quest_name_label: Label

## 奖励容器
var _rewards_container: VBoxContainer

## 粒子容器
var _particles_container: Node2D

## 动画计时器
var _timer: float = 0.0

## 是否正在动画
var _is_animating: bool = false

## 任务数据
var _quest_data: QuestSystem.QuestData

## 奖励数据
var _rewards: Dictionary


func _ready() -> void:
	layer = 100  # 确保在最上层
	_create_ui()


func _create_ui() -> void:
	# 创建主容器
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	# 创建背景遮罩
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0, 0, 0, 0)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_background)

	# 创建中心容器
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(center_container)

	# 创建内容面板
	var content_panel: PanelContainer = PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(400, 200)
	center_container.add_child(content_panel)

	# 面板样式
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(1.0, 0.85, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	content_panel.add_theme_stylebox_override("panel", style)

	# 内容VBox
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	content_panel.add_child(content_vbox)

	# 标题
	_title_label = Label.new()
	_title_label.text = "任务完成!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_title_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0))
	_title_label.add_theme_constant_override("outline_size", 3)
	content_vbox.add_child(_title_label)

	# 分隔线
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", _create_separator_style())
	content_vbox.add_child(separator)

	# 任务名称
	_quest_name_label = Label.new()
	_quest_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_name_label.add_theme_font_size_override("font_size", 20)
	_quest_name_label.add_theme_color_override("font_color", Color.WHITE)
	_quest_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quest_name_label.add_theme_constant_override("outline_size", 2)
	content_vbox.add_child(_quest_name_label)

	# 奖励容器
	_rewards_container = VBoxContainer.new()
	_rewards_container.add_theme_constant_override("separation", 6)
	content_vbox.add_child(_rewards_container)

	# 粒子容器（2D）
	_particles_container = Node2D.new()
	_particles_container.z_index = 10
	_container.add_child(_particles_container)


func _create_separator_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.85, 0.2, 0.5)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


## 设置任务数据
func setup(quest: QuestSystem.QuestData, rewards: Dictionary) -> void:
	_quest_data = quest
	_rewards = rewards

	# 设置任务名称
	if _quest_name_label:
		_quest_name_label.text = quest.title

	# 创建奖励显示
	_create_reward_display(rewards)


## 创建奖励显示
func _create_reward_display(rewards: Dictionary) -> void:
	if not _rewards_container:
		return

	# 清空现有奖励
	for child in _rewards_container.get_children():
		child.queue_free()

	# 金钱奖励
	var money: int = rewards.get("money", 0)
	if money > 0:
		_add_reward_item("金币", str(money), Color(1.0, 0.9, 0.3))

	# 经验奖励
	var experience: int = rewards.get("experience", 0)
	if experience > 0:
		_add_reward_item("经验", str(experience), Color(0.7, 0.9, 1.0))

	# 物品奖励
	var items: Array = rewards.get("items", [])
	for item in items:
		var item_id: String = item.get("id", "")
		var quantity: int = item.get("quantity", 1)
		var item_name: String = _get_item_name(item_id)
		_add_reward_item(item_name, str(quantity), Color(0.8, 1.0, 0.8))


func _add_reward_item(name: String, value: String, color: Color) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)

	var name_label: Label = Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.text = "x" + value
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", color)
	hbox.add_child(value_label)

	_rewards_container.add_child(hbox)


func _get_item_name(item_id: String) -> String:
	if ItemDatabase:
		var item = ItemDatabase.get_item(item_id)
		if item:
			return item.name
	return item_id


## 播放动画
func play_animation() -> void:
	_is_animating = true
	_timer = 0.0

	# 初始状态
	_container.modulate.a = 0.0
	_container.scale = Vector2(0.8, 0.8)

	# 创建入场动画
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	tween.tween_property(_container, "modulate:a", 1.0, 0.4)
	tween.tween_property(_container, "scale", Vector2.ONE, 0.4)

	# 背景淡入
	tween.tween_property(_background, "color:a", 0.5, 0.4)

	# 创建粒子
	tween.tween_callback(_create_particles).set_delay(0.2)

	# 标题闪烁效果
	tween.tween_callback(_flash_title).set_delay(0.5)

	# 播放音效
	_play_sound()

	# 设置自动关闭
	get_tree().create_timer(ANIM_DURATION).timeout.connect(_start_exit_animation)


func _flash_title() -> void:
	if not _title_label:
		return

	var tween: Tween = create_tween()
	for i in range(3):
		tween.tween_property(_title_label, "modulate", Color(1.5, 1.3, 0.5), 0.1)
		tween.tween_property(_title_label, "modulate", Color.WHITE, 0.1)


func _create_particles() -> void:
	if not _particles_container:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = viewport_size / 2

	for i in range(PARTICLE_COUNT):
		var particle: Sprite2D = Sprite2D.new()

		# 创建粒子纹理
		particle.texture = _create_star_texture()
		particle.scale = Vector2(0.3, 0.3)

		# 随机起始位置（从中心）
		var angle: float = randf() * TAU
		var distance: float = 50.0 + randf() * 100.0
		particle.position = center + Vector2(cos(angle), sin(angle)) * distance

		# 随机颜色
		var colors: Array[Color] = [
			Color(1.0, 0.85, 0.2),  # 金色
			Color(1.0, 1.0, 0.5),   # 亮黄
			Color(1.0, 0.7, 0.3),   # 橙色
			Color.WHITE
		]
		particle.modulate = colors[randi() % colors.size()]

		_particles_container.add_child(particle)

		# 粒子动画
		_animate_particle(particle, center, i)


func _create_star_texture() -> ImageTexture:
	var size: int = 16
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# 绘制星形
	var center: Vector2 = Vector2(size / 2, size / 2)
	for x in range(size):
		for y in range(size):
			var pos: Vector2 = Vector2(x, y)
			var dist: float = pos.distance_to(center)

			# 简单的星形
			var angle: float = pos.angle_to_point(center)
			var star_dist: float = 6.0 * (0.5 + 0.5 * abs(cos(angle * 2)))

			if dist <= star_dist:
				image.set_pixel(x, y, Color.WHITE)

	return ImageTexture.create_from_image(image)


func _animate_particle(particle: Sprite2D, center: Vector2, index: int) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# 随机方向扩散
	var angle: float = randf() * TAU
	var distance: float = 150.0 + randf() * 100.0
	var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance

	# 延迟启动
	var delay: float = index * 0.02

	tween.tween_property(particle, "position", end_pos, 1.0).set_delay(delay).set_ease(Tween.EASE_OUT)
	tween.tween_property(particle, "modulate:a", 0.0, 0.8).set_delay(delay + 0.5)
	tween.tween_property(particle, "scale", Vector2.ZERO, 0.5).set_delay(delay + 0.7)
	tween.tween_property(particle, "rotation", randf() * PI * 2, 1.0).set_delay(delay)


func _play_sound() -> void:
	if AudioManager:
		# 播放任务完成音效
		AudioManager.play_sfx("quest_complete")


func _start_exit_animation() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	tween.tween_property(_container, "modulate:a", 0.0, 0.4)
	tween.tween_property(_container, "scale", Vector2(1.1, 1.1), 0.4)
	tween.tween_property(_background, "color:a", 0.0, 0.4)

	tween.tween_callback(queue_free).set_delay(0.5)


## 静态方法：创建并播放任务完成效果
static func show_completion(quest: QuestSystem.QuestData, rewards: Dictionary) -> QuestCompleteEffect:
	var effect: QuestCompleteEffect = QuestCompleteEffect.new()
	effect.setup(quest, rewards)

	# 添加到场景树
	var tree: SceneTree = Engine.get_main_loop()
	if tree and tree.root:
		tree.root.add_child(effect)
		effect.play_animation()

	return effect