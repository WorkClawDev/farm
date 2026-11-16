extends Area2D
class_name Ore

## Ore - 矿石基类
## 可被挖掘的矿石资源，不同类型有不同的属性

# 信号
signal ore_mined(ore_type: String, quantity: int, quality: int)
signal ore_depleted
signal ore_respawned

# 矿石类型枚举
enum OreType {
	COPPER,
	IRON,
	SILVER,
	GOLD,
	GEM,
	CRYSTAL
}

# 矿石配置
@export var ore_type: OreType = OreType.COPPER
@export var max_health: int = 5
@export var base_quantity: int = 1
@export var quality_modifier: float = 1.0

# 当前状态
var current_health: int = 0:
	set(value):
		current_health = clampi(value, 0, max_health)
		if current_health == 0 and _was_active:
			_on_depleted()

var _was_active: bool = false

# 矿石数据
var ore_data: Dictionary = {}

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var particles: GPUParticles2D = $Particles if has_node("Particles") else null
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var solid_collision: CollisionShape2D = $SolidBody/CollisionShape2D if has_node("SolidBody/CollisionShape2D") else null
@onready var interaction_hint: Label = $InteractionHint if has_node("InteractionHint") else null

const OreIllustrationScene = preload("res://src/world/objects/OreIllustration.gd")


func _ready() -> void:
	_setup_ore_data()
	_setup_visuals()
	current_health = max_health
	_was_active = true
	if health_bar:
		health_bar.visible = false
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.z_index = 2  # 同层 Y 排序时血条也画在玩家上面
		_style_health_bar()
	_setup_interaction_hint()
	print("[Ore] Initialized: ", ore_data.get(ore_type, {}).get("name", "Unknown Ore"))


## 「挖掘」提示：玩家脚底进入能挖到这块矿石的范围时显示，离开或挖完隐藏。
## 每个物理帧按距离判断，不靠 Area2D 进出信号（传送、读档、出生点落在区域里都不会漏）。
## 农场把矿石放到和玩家同层按 Y 排序，提示再抬高两层，带深色底，玩家站在矿石南边（人在前）时
## 挪到玩家头顶，不再压在 132px 高角色的白衬衫上看不清。
## 范围是十字形：正对矿石的一条带里才显示，和镐子的面向判定（面前 32px 落进 88x88 感应区）一致。
const HINT_BAND_HALF := 44.0      # 横/竖带的半宽（= 感应区半边）
const HINT_REACH_SIDE := 60.0     # 东西两侧脚底离中心最远多少还显示（站停在 ±38）
const HINT_REACH_NORTH := 60.0    # 北侧（站停在 -22）
const HINT_REACH_SOUTH := 72.0    # 南侧：脚在实体碰撞下方，站停在 +38～+42
const HINT_ABOVE_FEET := 158.0    # 玩家在南侧时，提示顶边在脚底上方多少（角色约 124px 高）
var _hint_player: Node2D = null
var _hint_base_y := 0.0


func _setup_interaction_hint() -> void:
	if interaction_hint == null:
		return
	interaction_hint.visible = false
	interaction_hint.z_index = 2
	interaction_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	interaction_hint.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05))
	interaction_hint.add_theme_constant_override("outline_size", 4)
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.07, 0.05, 0.78)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 5.0
	pill.content_margin_right = 5.0
	pill.content_margin_bottom = 1.0
	interaction_hint.add_theme_stylebox_override("normal", pill)
	_hint_base_y = interaction_hint.position.y


func _physics_process(_delta: float) -> void:
	if interaction_hint == null:
		return
	var show := is_player_in_hint_reach()
	interaction_hint.visible = show
	if show:
		var d := _hint_player.global_position - global_position
		var in_front := d.y > 0.0 and absf(d.x) <= HINT_BAND_HALF  # 正南、人画在矿石前面
		interaction_hint.position.y = minf(_hint_base_y, d.y - HINT_ABOVE_FEET) if in_front else _hint_base_y


## 玩家脚底（Player 原点）相对矿石原点是否在提示范围内。
func is_player_in_hint_reach() -> bool:
	if not can_mine() or not is_inside_tree():
		return false
	if _hint_player == null or not is_instance_valid(_hint_player) or not _hint_player.is_inside_tree():
		_hint_player = get_tree().get_first_node_in_group("player") as Node2D
	if _hint_player == null:
		return false
	var d := _hint_player.global_position - global_position
	var vertical := absf(d.x) <= HINT_BAND_HALF and d.y >= -HINT_REACH_NORTH and d.y <= HINT_REACH_SOUTH
	var horizontal := absf(d.y) <= HINT_BAND_HALF and absf(d.x) <= HINT_REACH_SIDE
	return vertical or horizontal


## 全局主题的进度条是绿色，压在草地上看不见。矿石血条换成深底琥珀色。
func _style_health_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.06, 0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.96, 0.72, 0.25)
	health_bar.add_theme_stylebox_override("background", bg)
	health_bar.add_theme_stylebox_override("fill", fill)


## 设置矿石（由Mine场景调用）
func setup(type: String, floor: int) -> void:
	ore_type = _string_to_ore_type(type)
	_setup_ore_data()

	# 根据层级调整属性
	max_health = ore_data.get("base_health", 5) + floor / 2
	base_quantity = ore_data.get("base_quantity", 1) + floor / 5
	quality_modifier = 1.0 + floor * 0.1

	current_health = max_health
	_was_active = true


## 矿石数据配置
func _setup_ore_data() -> void:
	ore_data = {
		OreType.COPPER: {
			"id": "copper_ore",
			"name": "铜矿",
			"base_health": 3,
			"base_quantity": 1,
			"max_quantity": 3,
			"color": Color(0.8, 0.5, 0.3),
			"value": 10
		},
		OreType.IRON: {
			"id": "iron_ore",
			"name": "铁矿",
			"base_health": 5,
			"base_quantity": 1,
			"max_quantity": 4,
			"color": Color(0.5, 0.5, 0.55),
			"value": 25
		},
		OreType.SILVER: {
			"id": "silver_ore",
			"name": "银矿",
			"base_health": 7,
			"base_quantity": 1,
			"max_quantity": 3,
			"color": Color(0.85, 0.85, 0.9),
			"value": 50
		},
		OreType.GOLD: {
			"id": "gold_ore",
			"name": "金矿",
			"base_health": 10,
			"base_quantity": 1,
			"max_quantity": 3,
			"color": Color(1.0, 0.85, 0.3),
			"value": 100
		},
		OreType.GEM: {
			"id": "gem",
			"name": "宝石",
			"base_health": 8,
			"base_quantity": 1,
			"max_quantity": 2,
			"color": Color(0.8, 0.2, 0.8),
			"value": 200
		},
		OreType.CRYSTAL: {
			"id": "crystal",
			"name": "水晶",
			"base_health": 12,
			"base_quantity": 1,
			"max_quantity": 2,
			"color": Color(0.3, 0.7, 1.0),
			"value": 300
		}
	}


## 设置视觉效果
func _setup_visuals() -> void:
	var data: Dictionary = ore_data.get(ore_type, {})
	if sprite:
		sprite.visible = false
	var illustration = get_node_or_null("OreIllustration")
	if illustration == null:
		illustration = OreIllustrationScene.new()
		add_child(illustration)
	illustration.setup(data.get("color", Color.WHITE))


## 检查是否可以挖掘
func can_mine() -> bool:
	return current_health > 0


## 检查是否已耗尽
func is_depleted() -> bool:
	return current_health <= 0


## 受到伤害
func take_damage(amount: int) -> Dictionary:
	if not can_mine():
		return {"destroyed": false, "current_health": 0, "max_health": max_health}

	_was_active = true
	current_health -= amount
	if health_bar:
		health_bar.visible = true
		health_bar.max_value = max_health
		health_bar.value = current_health

	# 播放受击动画
	_play_hit_animation()

	# 检查是否被摧毁
	if current_health <= 0:
		return _on_destroyed()

	return {
		"destroyed": false,
		"current_health": current_health,
		"max_health": max_health
	}


## 矿石被摧毁
func _on_destroyed() -> Dictionary:
	var data: Dictionary = ore_data.get(ore_type, {})
	var item_id: String = data.get("id", "ore")
	var quantity: int = _calculate_quantity()
	var quality: int = _calculate_quality()

	print("[Ore] Destroyed: ", item_id, " x", quantity, " quality:", quality)

	ore_mined.emit(item_id, quantity, quality)
	ore_depleted.emit()

	# 播放破坏效果
	_play_destroy_animation()

	return {
		"destroyed": true,
		"item_id": item_id,
		"quantity": quantity,
		"quality": quality,
		"current_health": 0,
		"max_health": max_health
	}


## 矿石耗尽（非破坏状态）
func _on_depleted() -> void:
	_set_depleted_visual()


## 计算掉落数量
func _calculate_quantity() -> int:
	var data: Dictionary = ore_data.get(ore_type, {})
	var base: int = data.get("base_quantity", 1)
	var max_q: int = data.get("max_quantity", 3)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	return rng.randi_range(base, max_q)


## 计算品质
func _calculate_quality() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# 品质范围 0-3 (普通、良好、优秀、完美)
	var base_quality: float = quality_modifier * rng.randf()
	return clampi(int(base_quality * 4), 0, 3)


## 播放受击动画
func _play_hit_animation() -> void:
	var visual := get_node_or_null("OreIllustration")
	if animation_player and animation_player.has_animation("hit"):
		animation_player.play("hit")
	elif visual:
		# 闪烁效果
		var tween := create_tween()
		tween.tween_property(visual, "modulate:v", 2.0, 0.05)
		tween.tween_property(visual, "modulate:v", 1.0, 0.05)


## 播放破坏动画
func _play_destroy_animation() -> void:
	if particles:
		particles.emitting = true

	# 矿石消失动画
	var visual := get_node_or_null("OreIllustration")
	var tween := create_tween()
	if visual:
		tween.tween_property(visual, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(_set_depleted_visual)


## 设置耗尽状态的视觉效果
func _set_depleted_visual() -> void:
	if interaction_hint:
		interaction_hint.visible = false
	if sprite:
		sprite.visible = false
	var visual := get_node_or_null("OreIllustration")
	if visual:
		visual.visible = false
	if health_bar:
		health_bar.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if solid_collision:
		solid_collision.set_deferred("disabled", true)


## 重生矿石
func respawn() -> void:
	current_health = max_health
	_was_active = true

	if sprite:
		sprite.visible = false
		sprite.scale = Vector2.ONE
	var visual := get_node_or_null("OreIllustration")
	if visual:
		visual.visible = true
		visual.scale = Vector2.ONE
	if health_bar:
		health_bar.visible = false
		health_bar.max_value = max_health
		health_bar.value = current_health
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if solid_collision:
		solid_collision.set_deferred("disabled", false)

	# 播放重生动画
	if visual:
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector2.ONE * 1.2, 0.1)
		tween.tween_property(visual, "scale", Vector2.ONE, 0.1)

	print("[Ore] Respawned: ", ore_data.get(ore_type, {}).get("name", "Unknown"))
	ore_respawned.emit()


## 获取矿石信息
func get_ore_info() -> Dictionary:
	var data: Dictionary = ore_data.get(ore_type, {})
	return {
		"id": data.get("id", "ore"),
		"name": data.get("name", "Unknown"),
		"type": ore_type,
		"current_health": current_health,
		"max_health": max_health,
		"value": data.get("value", 10),
		"is_depleted": is_depleted()
	}


## 字符串转OreType
func _string_to_ore_type(type: String) -> OreType:
	match type.to_lower():
		"copper": return OreType.COPPER
		"iron": return OreType.IRON
		"silver": return OreType.SILVER
		"gold": return OreType.GOLD
		"gem": return OreType.GEM
		"crystal": return OreType.CRYSTAL
		_: return OreType.COPPER


## OreType转字符串
func _ore_type_to_string() -> String:
	match ore_type:
		OreType.COPPER: return "copper"
		OreType.IRON: return "iron"
		OreType.SILVER: return "silver"
		OreType.GOLD: return "gold"
		OreType.GEM: return "gem"
		OreType.CRYSTAL: return "crystal"
		_: return "copper"


## 保存状态
func save_state() -> Dictionary:
	return {
		"ore_type": _ore_type_to_string(),
		"current_health": current_health,
		"max_health": max_health,
		"is_depleted": is_depleted()
	}


## 加载状态
func load_state(data: Dictionary) -> void:
	ore_type = _string_to_ore_type(data.get("ore_type", "copper"))
	current_health = data.get("current_health", max_health)
	max_health = data.get("max_health", 5)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if is_depleted():
		_set_depleted_visual()
