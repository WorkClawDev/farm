extends Area2D
class_name ForageItem

## ForageItem - 可采集物品场景节点
## 放置在场景中，玩家交互后可采集

signal collected(item_id: String, quantity: int)

## 可采集物品ID
@export var forage_id: String = "wild_berry"

## 采集点位置（用于注册到ForagingSystem）
@export var grid_position: Vector2i = Vector2i.ZERO

## 是否已被采集
var is_collected: bool = false

## 物品数据缓存
var _forage_data: RefCounted = null

## 精灵节点
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

## 碰撞形状
@onready var collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

## 动画播放器
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

## 交互提示
@onready var interact_label: Label = $InteractLabel if has_node("InteractLabel") else null

## 玩家是否在范围内
var _player_in_range: bool = false

## 采集动画持续时间
const COLLECT_ANIMATION_DURATION: float = 0.5
const FORAGE_DISPLAY_SIZE := Vector2(36, 36)


func _ready() -> void:
	add_to_group("forage_items")
	_setup_forage()
	_connect_signals()
	_setup_interaction()


func _setup_forage() -> void:
	# 等待ForagingSystem初始化
	if ForagingSystem and ForagingSystem._is_initialized:
		_load_forage_data()
	else:
		await get_tree().process_frame
		_load_forage_data()

	# 注册到ForagingSystem
	if ForagingSystem:
		ForagingSystem.register_forage_point(global_position, forage_id, _get_location_name())
		ForagingSystem.register_forage_node(global_position, self)

	_update_visuals()


func _load_forage_data() -> void:
	if ForagingSystem:
		_forage_data = ForagingSystem.get_forage_data(forage_id)
		if _forage_data == null:
			push_warning("[ForageItem] Unknown forage_id: " + forage_id)


func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_interaction() -> void:
	# 创建交互提示标签（如果不存在）
	if interact_label == null:
		interact_label = Label.new()
		interact_label.name = "InteractLabel"
		interact_label.position = Vector2(-40, -50)
		interact_label.size = Vector2(80, 20)
		interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interact_label.visible = false
		add_child(interact_label)

	interact_label.text = "[E] 采集"


func _process(_delta: float) -> void:
	# 检测玩家交互输入
	if _player_in_range and Input.is_action_just_pressed("interact"):
		_try_collect()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if not is_collected and interact_label:
			interact_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if interact_label:
			interact_label.visible = false


## 尝试采集
func _try_collect() -> void:
	if is_collected:
		return

	if not ForagingSystem:
		return

	var result: Dictionary = ForagingSystem.collect_forage(global_position)

	if result.get("success", false):
		_on_collect_success(result)
	else:
		_on_collect_failed(result.get("message", "Unknown error"))


## 采集成功处理
func _on_collect_success(result: Dictionary) -> void:
	is_collected = true

	var item_id: String = result.get("item_id", "")
	var quantity: int = result.get("quantity", 1)

	# 播放采集动画
	_play_collect_animation()

	# 发射信号
	collected.emit(item_id, quantity)

	# 隐藏交互提示
	if interact_label:
		interact_label.visible = false

	# 播放音效
	_play_collect_sound()

	print("[ForageItem] Collected: ", item_id, " x", quantity)


## 采集失败处理
func _on_collect_failed(message: String) -> void:
	print("[ForageItem] Collection failed: ", message)
	# 可以显示提示消息


## 播放采集动画
func _play_collect_animation() -> void:
	if animation_player and animation_player.has_animation("collect"):
		animation_player.play("collect")
		await animation_player.animation_finished
	else:
		# 默认动画：缩小并消失
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, COLLECT_ANIMATION_DURATION)
		tween.tween_callback(_hide_item)
		await tween.finished


## 隐藏物品
func _hide_item() -> void:
	visible = false
	if collision:
		collision.disabled = true


## 播放采集音效
func _play_collect_sound() -> void:
	if AudioManager:
		AudioManager.play_sfx("forage_collect")


## 刷新（重新出现）
func respawn() -> void:
	is_collected = false
	visible = true

	if collision:
		collision.disabled = false

	# 播放出现动画
	_play_spawn_animation()
	_update_visuals()


## 播放出现动画
func _play_spawn_animation() -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)


## 更新视觉效果
func _update_visuals() -> void:
	if _forage_data == null:
		return

	if sprite:
		var texture := _load_forage_texture()
		if texture:
			var texture_size := Vector2(texture.get_size())
			sprite.texture = texture
			sprite.scale = Vector2(
				FORAGE_DISPLAY_SIZE.x / texture_size.x,
				FORAGE_DISPLAY_SIZE.y / texture_size.y
			)
			sprite.modulate = Color.WHITE
		else:
			sprite.modulate = _get_type_color()


## 获取类型颜色（临时方案）
func _get_type_color() -> Color:
	if _forage_data == null:
		return Color.WHITE

	match _forage_data.type:
		ForagingSystem.ForageType.WILD_FRUIT:
			return Color(1.0, 0.4, 0.4)  # 红色系
		ForagingSystem.ForageType.MUSHROOM:
			return Color(0.8, 0.7, 0.5)  # 棕色系
		ForagingSystem.ForageType.FLOWER:
			return Color(1.0, 0.8, 0.9)  # 粉色系
		ForagingSystem.ForageType.HERB:
			return Color(0.4, 0.8, 0.4)  # 绿色系
		ForagingSystem.ForageType.BRANCH:
			return Color(0.6, 0.4, 0.2)  # 棕色
		ForagingSystem.ForageType.STONE:
			return Color(0.7, 0.7, 0.7)  # 灰色
		ForagingSystem.ForageType.SHELL:
			return Color(1.0, 0.9, 0.8)  # 贝壳色
		_:
			return Color.WHITE

func _load_forage_texture() -> Texture2D:
	if _forage_data == null:
		return null

	if _forage_data.icon_path != "":
		var direct_texture := load(_forage_data.icon_path)
		if direct_texture is Texture2D:
			return direct_texture

	var item_database = get_node_or_null("/root/ItemDatabase")
	if item_database and item_database.has_method("load_icon_texture"):
		var item_id: String = _forage_data.item_id if _forage_data.item_id != "" else forage_id
		var db_texture = item_database.load_icon_texture(item_id)
		if db_texture is Texture2D:
			return db_texture

	return null


## 获取位置名称
func _get_location_name() -> String:
	# 从场景名称或父节点推断位置
	var scene_name: String = get_tree().current_scene.name.to_lower()

	if "farm" in scene_name:
		return "farm"
	elif "forest" in scene_name:
		return "forest"
	elif "village" in scene_name:
		return "village"
	elif "beach" in scene_name:
		return "beach"
	else:
		return "forest"


## 获取显示名称
func get_display_name() -> String:
	if _forage_data:
		return _forage_data.name
	return forage_id


## 获取描述
func get_description() -> String:
	if _forage_data:
		return _forage_data.description
	return ""


## 检查是否可以采集
func can_collect() -> bool:
	return not is_collected


## 保存状态
func save_state() -> Dictionary:
	return {
		"forage_id": forage_id,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"is_collected": is_collected
	}


## 加载状态
func load_state(data: Dictionary) -> void:
	forage_id = data.get("forage_id", forage_id)
	is_collected = data.get("is_collected", false)

	_load_forage_data()

	if is_collected:
		_hide_item()


func _exit_tree() -> void:
	# 从ForagingSystem注销
	if ForagingSystem:
		ForagingSystem.unregister_forage_node(global_position)
