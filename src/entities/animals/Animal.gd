extends CharacterBody2D
class_name Animal

## Animal - 动物基类
## 处理动物的基本行为：移动、喂养、产出、好感度

# 动物配置
@export var animal_id: String = "animal_001"
@export var animal_name: String = "Animal"
@export var animal_type: String = "generic"  # chicken, cow, sheep, etc.
@export var move_speed: float = 30.0

# 好感度系统
@export var max_friendship: int = 1000
var friendship: int = 0

# 饥饿系统
@export var max_hunger: int = 100
var hunger: int = 100
var days_without_food: int = 0

# 产出系统
@export var production_interval: int = 1  # 产出间隔（天）
var days_until_production: int = 1
var has_product: bool = false
var product_quality: int = 0  # 0=普通, 1=银星, 2=金星

# 动物状态
enum AnimalState { IDLE, WALKING, EATING, SLEEPING, PRODUCING }
var current_state: AnimalState = AnimalState.IDLE
var is_outside: bool = false

# 移动相关
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2 = Vector2.ZERO

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else null
@onready var product_spawn_point: Marker2D = $ProductSpawnPoint if has_node("ProductSpawnPoint") else null

# 信号
signal friendship_changed(animal: Animal, new_value: int)
signal fed(animal: Animal)
signal product_ready(animal: Animal, product_id: String)
signal product_collected(animal: Animal, product_id: String, quality: int)

# 常量
const WANDER_RANGE: float = 50.0
const WANDER_INTERVAL_MIN: float = 3.0
const WANDER_INTERVAL_MAX: float = 8.0

func _ready() -> void:
	_setup_interaction()
	home_position = global_position
	_reset_production_timer()
	print("[Animal] %s initialized with ID: %s" % [animal_name, animal_id])

func _physics_process(delta: float) -> void:
	match current_state:
		AnimalState.IDLE:
			_process_idle(delta)
		AnimalState.WALKING:
			_process_walking(delta)
		AnimalState.EATING:
			_process_eating(delta)
		AnimalState.SLEEPING:
			pass  # 夜晚不活动

	_update_animation()
	move_and_slide()

## 设置交互区域
func _setup_interaction() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

## 空闲状态处理
func _process_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		_start_wander()

## 开始漫游
func _start_wander() -> void:
	if not is_outside:
		return

	current_state = AnimalState.WALKING
	var random_offset := Vector2(
		randf_range(-WANDER_RANGE, WANDER_RANGE),
		randf_range(-WANDER_RANGE, WANDER_RANGE)
	)
	wander_target = home_position + random_offset
	wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

## 漫游状态处理
func _process_walking(_delta: float) -> void:
	var direction := wander_target - global_position
	var distance := direction.length()

	if distance < 5.0:
		current_state = AnimalState.IDLE
		velocity = Vector2.ZERO
		return

	velocity = direction.normalized() * move_speed

## 进食状态处理
func _process_eating(_delta: float) -> void:
	velocity = Vector2.ZERO

## 更新动画
func _update_animation() -> void:
	if not animation_player:
		return

	var anim_name: String = ""
	match current_state:
		AnimalState.IDLE:
			anim_name = "idle"
		AnimalState.WALKING:
			anim_name = "walk"
		AnimalState.EATING:
			anim_name = "eat"
		AnimalState.SLEEPING:
			anim_name = "sleep"

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

## 喂养动物
func feed(food_item_id: String = "") -> bool:
	if hunger >= max_hunger:
		print("[Animal] %s is not hungry" % animal_name)
		return false

	# 基础喂养恢复
	var hunger_restore: int = 50

	# 根据食物类型调整效果
	match food_item_id:
		"hay", "grass":
			hunger_restore = 50
		"quality_feed":
			hunger_restore = 100
		_:
			hunger_restore = 50

	hunger = mini(hunger + hunger_restore, max_hunger)
	days_without_food = 0

	# 喂养增加好感度
	_add_friendship(5)

	current_state = AnimalState.EATING
	get_tree().create_timer(1.5).timeout.connect(_finish_eating, CONNECT_ONE_SHOT)

	fed.emit(self)
	if EventBus:
		get_node("/root/EventBus").ui.notification_shown.emit("%s吃饱了！" % animal_name, 0)
	
	print("[Animal] %s fed, hunger: %d" % [animal_name, hunger])
	return true

func _finish_eating() -> void:
	current_state = AnimalState.IDLE

## 增加好感度
func _add_friendship(amount: int) -> void:
	var old_value := friendship
	friendship = mini(friendship + amount, max_friendship)

	if friendship != old_value:
		friendship_changed.emit(self, friendship)
		_check_product_quality_upgrade()

## 检查产品品质升级
func _check_product_quality_upgrade() -> void:
	# 好感度越高，高品质产品概率越高
	if friendship >= 800:
		product_quality = 2  # 金星
	elif friendship >= 500:
		product_quality = randi_range(1, 2)  # 银星或金星
	elif friendship >= 200:
		product_quality = randi_range(0, 1)  # 普通或银星
	else:
		product_quality = 0  # 普通

## 每日更新（由时间系统调用）
func on_new_day() -> void:
	# 检查饥饿
	if hunger <= 0:
		days_without_food += 1
		# 饥饿降低好感度
		_add_friendship(-10)
		print("[Animal] %s is starving!" % animal_name)
	else:
		# 正常消耗饥饿值
		hunger = maxi(hunger - 25, 0)

	# 检查产出
	_check_production()

	# 重置状态
	if TimeManager and get_node("/root/TimeManager").current_time >= 18.0:
		# 夜晚回屋睡觉
		go_inside()
	else:
		go_outside()

	print("[Animal] %s new day: hunger=%d, friendship=%d" % [animal_name, hunger, friendship])

## 检查产出
func _check_production() -> void:
	if hunger < 50:
		# 太饿了不产出
		days_until_production = maxi(days_until_production, 1)
		return

	days_until_production -= 1
	if days_until_production <= 0:
		has_product = true
		_calculate_product_quality()
		var product_id := get_product_id()
		product_ready.emit(self, product_id)
		_reset_production_timer()
		print("[Animal] %s produced %s" % [animal_name, product_id])

## 计算产品品质
func _calculate_product_quality() -> void:
	# 基于好感度计算品质
	var quality_roll := randf()
	if friendship >= 800:
		# 高好感度：80%金星，20%银星
		product_quality = 2 if quality_roll < 0.8 else 1
	elif friendship >= 500:
		# 中好感度：50%银星，50%普通
		product_quality = 1 if quality_roll < 0.5 else 0
	elif friendship >= 200:
		# 低好感度：20%银星，80%普通
		product_quality = 1 if quality_roll < 0.2 else 0
	else:
		product_quality = 0

## 重置产出计时器
func _reset_production_timer() -> void:
	days_until_production = production_interval

## 获取产品ID（子类重写）
func get_product_id() -> String:
	return ""

## 收集产品
func collect_product() -> Dictionary:
	if not has_product:
		return {}

	var product_id := get_product_id()
	if product_id.is_empty():
		return {}

	has_product = false

	var result := {
		"item_id": product_id,
		"quantity": 1,
		"quality": product_quality
	}

	product_collected.emit(self, product_id, product_quality)
	print("[Animal] Collected %s x%d (quality %d) from %s" % [product_id, 1, product_quality, animal_name])

	return result

## 是否可收集产品
func can_collect_product() -> bool:
	return has_product

## 让动物外出
func go_outside() -> void:
	is_outside = true
	current_state = AnimalState.IDLE
	print("[Animal] %s went outside" % animal_name)

## 让动物回屋
func go_inside() -> void:
	is_outside = false
	current_state = AnimalState.SLEEPING
	global_position = home_position
	velocity = Vector2.ZERO
	print("[Animal] %s went inside to sleep" % animal_name)

## 设置动物位置
func set_home_position(pos: Vector2) -> void:
	home_position = pos
	global_position = pos

## 玩家进入交互区域
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.animal_in_range = self
		print("[Animal] Player in range of %s" % animal_name)

## 玩家离开交互区域
func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is Player:
		if body.animal_in_range == self:
			body.animal_in_range = null
		print("[Animal] Player left range of %s" % animal_name)

## 获取交互提示文本
func get_interaction_text() -> String:
	if has_product:
		return "收集%s的%s" % [animal_name, get_product_name()]
	elif hunger < 50:
		return "喂养%s" % animal_name
	else:
		return "查看%s" % animal_name

## 获取产品名称（子类重写）
func get_product_name() -> String:
	return "产品"

## 获取动物信息
func get_info() -> Dictionary:
	return {
		"id": animal_id,
		"name": animal_name,
		"type": animal_type,
		"friendship": friendship,
		"max_friendship": max_friendship,
		"hunger": hunger,
		"max_hunger": max_hunger,
		"has_product": has_product,
		"product_quality": product_quality,
		"days_until_production": days_until_production,
		"is_outside": is_outside
	}

## 获取好感度等级（心数）
func get_hearts() -> int:
	return friendship / 100  # 每100点一颗心

## 保存动物状态
func save_state() -> Dictionary:
	return {
		"animal_id": animal_id,
		"animal_name": animal_name,
		"animal_type": animal_type,
		"friendship": friendship,
		"hunger": hunger,
		"days_without_food": days_without_food,
		"days_until_production": days_until_production,
		"has_product": has_product,
		"product_quality": product_quality,
		"position": {
			"x": global_position.x,
			"y": global_position.y
		},
		"home_position": {
			"x": home_position.x,
			"y": home_position.y
		},
		"is_outside": is_outside
	}

## 加载动物状态
func load_state(data: Dictionary) -> void:
	animal_name = data.get("animal_name", animal_name)
	friendship = data.get("friendship", 0)
	hunger = data.get("hunger", max_hunger)
	days_without_food = data.get("days_without_food", 0)
	days_until_production = data.get("days_until_production", production_interval)
	has_product = data.get("has_product", false)
	product_quality = data.get("product_quality", 0)

	if data.has("position"):
		global_position = Vector2(data["position"]["x"], data["position"]["y"])
	if data.has("home_position"):
		home_position = Vector2(data["home_position"]["x"], data["home_position"]["y"])

	is_outside = data.get("is_outside", false)
	print("[Animal] %s state loaded" % animal_name)
