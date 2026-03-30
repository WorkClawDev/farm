extends Node
class_name GiftAnimationPlayer

## GiftAnimationPlayer - 送礼动画播放器
## 处理送礼时的各种动画效果

# 动画预设
enum AnimationType {
	POPUP,      # 弹出效果
	HEARTS,     # 爱心飘散
	STARS,      # 星星闪烁
	DROPLETS,   # 汗滴（不喜欢）
	BROKEN      # 破碎效果（讨厌）
}

# 粒子场景
var _heart_particle: PackedScene
var _star_particle: PackedScene
var _droplet_particle: PackedScene

# 动画队列
var _animation_queue: Array = []
var _is_playing: bool = false

func _ready() -> void:
	_create_particle_scenes()
	print("[GiftAnimationPlayer] Initialized")

func _create_particle_scenes() -> void:
	# 创建爱心粒子
	_heart_particle = _create_particle_scene(Color(1, 0.4, 0.5), "heart")

	# 创建星星粒子
	_star_particle = _create_particle_scene(Color(1, 0.9, 0.3), "star")

	# 创建汗滴粒子
	_droplet_particle = _create_particle_scene(Color(0.6, 0.8, 1), "droplet")

func _create_particle_scene(color: Color, type: String) -> PackedScene:
	var particle := Control.new()
	particle.name = type.capitalize() + "Particle"

	# 粒子图形
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(8, 8)

	# 根据类型调整形状
	match type:
		"heart":
			rect.custom_minimum_size = Vector2(16, 16)
		"star":
			rect.custom_minimum_size = Vector2(12, 12)
		"droplet":
			rect.custom_minimum_size = Vector2(6, 10)

	particle.add_child(rect)

	# 创建场景
	var scene := PackedScene.new()
	scene.pack(particle)

	particle.queue_free()
	return scene

## 播放送礼动画
func play_gift_animation(reaction: int, position: Vector2, parent: Node) -> void:
	var anim_type := _get_animation_type_for_reaction(reaction)
	_play_animation(anim_type, reaction, position, parent)

func _get_animation_type_for_reaction(reaction: int) -> AnimationType:
	match reaction:
		GiftSystem.ReactionType.LOVE:
			return AnimationType.HEARTS
		GiftSystem.ReactionType.LIKE:
			return AnimationType.STARS
		GiftSystem.ReactionType.NEUTRAL:
			return AnimationType.POPUP
		GiftSystem.ReactionType.DISLIKE:
			return AnimationType.DROPLETS
		GiftSystem.ReactionType.HATE:
			return AnimationType.BROKEN
		_:
			return AnimationType.POPUP

func _play_animation(anim_type: AnimationType, reaction: int, position: Vector2, parent: Node) -> void:
	match anim_type:
		AnimationType.HEARTS:
			_spawn_hearts(position, parent, 8)
		AnimationType.STARS:
			_spawn_stars(position, parent, 6)
		AnimationType.POPUP:
			_spawn_popup(position, parent, reaction)
		AnimationType.DROPLETS:
			_spawn_droplets(position, parent, 4)
		AnimationType.BROKEN:
			_spawn_broken(position, parent)

func _spawn_hearts(position: Vector2, parent: Node, count: int) -> void:
	for i in count:
		var heart := _create_heart_node()
		heart.global_position = position

		# 随机偏移
		var offset := Vector2(randf_range(-30, 30), randf_range(-20, 0))
		heart.position += offset

		parent.add_child(heart)

		# 动画
		var tween := parent.create_tween()
		tween.set_parallel(true)

		var target_y := heart.position.y - 60
		tween.tween_property(heart, "position:y", target_y, 1.0).set_ease(Tween.EASE_OUT)
		tween.tween_property(heart, "modulate:a", 0.0, 1.0).set_delay(0.5)
		tween.tween_property(heart, "scale", Vector2(0.5, 0.5), 1.0)

		# 随机延迟
		await parent.get_tree().create_timer(randf_range(0, 0.2)).timeout

func _create_heart_node() -> Control:
	var heart := Control.new()
	heart.name = "Heart"

	# 爱心图形（使用两个圆和一个三角形模拟）
	var shape := Control.new()

	var circle1 := ColorRect.new()
	circle1.color = Color(1, 0.3, 0.4)
	circle1.custom_minimum_size = Vector2(10, 10)
	circle1.position = Vector2(-5, -5)
	shape.add_child(circle1)

	var circle2 := ColorRect.new()
	circle2.color = Color(1, 0.3, 0.4)
	circle2.custom_minimum_size = Vector2(10, 10)
	circle2.position = Vector2(5, -5)
	shape.add_child(circle2)

	var triangle := ColorRect.new()
	triangle.color = Color(1, 0.3, 0.4)
	triangle.custom_minimum_size = Vector2(16, 12)
	triangle.position = Vector2(-8, 2)
	shape.add_child(triangle)

	heart.add_child(shape)
	heart.custom_minimum_size = Vector2(20, 20)

	return heart

func _spawn_stars(position: Vector2, parent: Node, count: int) -> void:
	for i in count:
		var star := _create_star_node()
		star.global_position = position

		# 随机偏移
		var offset := Vector2(randf_range(-40, 40), randf_range(-30, 10))
		star.position += offset

		parent.add_child(star)

		# 动画
		var tween := parent.create_tween()
		tween.set_parallel(true)

		# 闪烁效果
		tween.tween_property(star, "modulate:a", 0.0, 0.8).set_delay(0.3)
		tween.tween_property(star, "scale", Vector2(1.5, 1.5), 0.5)
		tween.tween_property(star, "rotation", PI, 0.8)

		await parent.get_tree().create_timer(randf_range(0, 0.15)).timeout

func _create_star_node() -> Control:
	var star := Control.new()
	star.name = "Star"

	var rect := ColorRect.new()
	rect.color = Color(1, 0.9, 0.3)
	rect.custom_minimum_size = Vector2(12, 12)
	star.add_child(rect)

	star.custom_minimum_size = Vector2(12, 12)

	return star

func _spawn_popup(position: Vector2, parent: Node, _reaction: int) -> void:
	var popup := Control.new()
	popup.name = "Popup"
	popup.global_position = position
	popup.position.y -= 30

	var label := Label.new()
	label.text = "..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)

	popup.add_child(label)
	parent.add_child(popup)

	# 动画
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 40, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0).set_delay(0.5)

	tween.tween_callback(popup.queue_free)

func _spawn_droplets(position: Vector2, parent: Node, count: int) -> void:
	for i in count:
		var droplet := Control.new()
		droplet.name = "Droplet"
		droplet.global_position = position

		var offset := Vector2(randf_range(-20, 20), randf_range(-10, 10))
		droplet.position += offset

		var rect := ColorRect.new()
		rect.color = Color(0.6, 0.8, 1, 0.8)
		rect.custom_minimum_size = Vector2(6, 10)
		droplet.add_child(rect)

		parent.add_child(droplet)

		# 动画 - 下落
		var tween := parent.create_tween()
		tween.tween_property(droplet, "position:y", droplet.position.y + 50, 0.8).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(droplet, "modulate:a", 0.0, 0.8).set_delay(0.3)
		tween.tween_callback(droplet.queue_free)

		await parent.get_tree().create_timer(randf_range(0, 0.1)).timeout

func _spawn_broken(position: Vector2, parent: Node) -> void:
	# 破碎效果
	for i in 6:
		var piece := Control.new()
		piece.name = "BrokenPiece"
		piece.global_position = position

		var rect := ColorRect.new()
		rect.color = Color(0.5, 0.5, 0.5)
		rect.custom_minimum_size = Vector2(8, 8)
		piece.add_child(rect)

		parent.add_child(piece)

		# 动画 - 飞散
		var direction := Vector2(randf_range(-1, 1), randf_range(-1, 0.5)).normalized()

		var tween := parent.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", piece.position + direction * 50, 0.6)
		tween.tween_property(piece, "rotation", randf_range(-PI, PI), 0.6)
		tween.tween_property(piece, "modulate:a", 0.0, 0.6)
		tween.tween_callback(piece.queue_free)

		await parent.get_tree().create_timer(0.05).timeout

## 播放好友度变化动画
func play_friendship_change(parent: Node, start_pos: Vector2, change: int) -> void:
	var indicator := Control.new()
	indicator.global_position = start_pos
	indicator.position.y -= 60

	var label := Label.new()
	label.text = "%+d" % change
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)

	if change > 0:
		label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)

	indicator.add_child(label)
	parent.add_child(indicator)

	# 动画
	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "position:y", indicator.position.y - 30, 1.0)
	tween.tween_property(indicator, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.tween_callback(indicator.queue_free)

## 播放心形增加动画
func play_heart_gained(parent: Node, position: Vector2, count: int) -> void:
	for i in count:
		var heart := _create_heart_node()
		heart.global_position = position
		heart.position += Vector2(randf_range(-20, 20), randf_range(-10, 10))

		parent.add_child(heart)

		var tween := parent.create_tween()
		tween.set_parallel(true)
		tween.tween_property(heart, "position:y", heart.position.y - 80, 1.2)
		tween.tween_property(heart, "modulate:a", 0.0, 1.2).set_delay(0.4)
		tween.tween_callback(heart.queue_free)

		await parent.get_tree().create_timer(0.1).timeout