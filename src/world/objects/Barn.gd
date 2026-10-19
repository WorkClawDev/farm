extends StaticBody2D
class_name Barn
const InteractPromptScript = preload("res://src/ui/components/InteractPrompt.gd")  # preload: works before the class cache knows the class_name

const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const DepthAnchor := preload("res://src/world/objects/WorldDepthAnchor.gd")
const COLLISION_WIDTH_RATIO := 0.58
const COLLISION_HEIGHT_RATIO := 0.34
const COLLISION_Y_RATIO := 0.34

## Barn - 牛棚
## 可以容纳最多2头牛的建筑

@export var building_name: String = "牛棚"
@export var max_animals: int = 2

const BARN_TEXTURE_PATH := "res://assets/sprites/houses/barn_clean.png"
const BARN_DISPLAY_SIZE := Vector2(208, 156)

var animals: Array[Animal] = []
var _depth_anchor_offset := 0.0

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var animal_container: Node2D = $AnimalContainer
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	_setup_sprite()
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	InteractPromptScript.attach(self, "收集", InteractPromptScript.sprite_top(self), _is_prompt_available, InteractPromptScript.PRIORITY_BUILDING)
	print("[Barn] Barn initialized")

func _setup_sprite() -> void:
	if sprite == null:
		return

	var texture := TextureLoader.load_texture(BARN_TEXTURE_PATH)
	if texture == null:
		push_warning("[Barn] Could not load texture: " + BARN_TEXTURE_PATH)
		return

	var texture_size := Vector2(texture.get_size())
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2(
		BARN_DISPLAY_SIZE.x / texture_size.x,
		BARN_DISPLAY_SIZE.y / texture_size.y
	)
	sprite.z_index = 0
	_update_collision_shape(BARN_DISPLAY_SIZE)

func _update_collision_shape(display_size: Vector2) -> void:
	if collision_shape == null:
		return

	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	shape.size = Vector2(
		display_size.x * COLLISION_WIDTH_RATIO,
		display_size.y * COLLISION_HEIGHT_RATIO
	)
	collision_shape.position = Vector2(0, display_size.y * COLLISION_Y_RATIO)
	var foundation_bottom := collision_shape.position.y + shape.size.y * 0.5
	_depth_anchor_offset = DepthAnchor.apply(
		self,
		foundation_bottom,
		_depth_anchor_offset
	)

func get_depth_anchor_offset() -> float:
	return _depth_anchor_offset

## Player.building_in_range is what E acts on (after NPCs).
func _is_prompt_available() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and "building_in_range" in player and player.building_in_range == self

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.building_in_range = self
		print("[Barn] 按 E 键进入牛棚")

func _on_body_exited(body: Node2D) -> void:
	if body is Player and body.building_in_range == self:
		body.building_in_range = null

func interact() -> void:
	var inventory = get_node_or_null("/root/Inventory")
	var event_bus = get_node_or_null("/root/EventBus")
	var collected = collect_all_products()
	if not collected.is_empty():
		var summary: Array[String] = []
		for item_id in collected.keys():
			var count: int = collected[item_id]["count"]
			if inventory:
				inventory.add_item(item_id, count)
			summary.append("%s x%d" % [item_id, count])
		if event_bus and event_bus.ui:
			event_bus.ui.notification_shown.emit("已收集: " + ", ".join(summary), 0)
		return

	var hungry_animals := _get_hungry_animals()
	if not hungry_animals.is_empty():
		var fed_count := _feed_animals(inventory)
		if event_bus and event_bus.ui:
			if fed_count > 0:
				event_bus.ui.notification_shown.emit("已喂养%d头牛" % fed_count, 0)
			else:
				event_bus.ui.notification_shown.emit("需要干草或优质饲料", 0)
		return

	if event_bus and event_bus.ui:
		event_bus.ui.notification_shown.emit("牛棚: %d/%d 头动物" % [animals.size(), max_animals], 0)

func _get_hungry_animals() -> Array[Animal]:
	var result: Array[Animal] = []
	for animal in animals:
		if animal.hunger < 50:
			result.append(animal)
	return result

func _feed_animals(inventory) -> int:
	if inventory == null:
		return 0

	var feed_item := ""
	if inventory.has_item("quality_feed", 1):
		feed_item = "quality_feed"
	elif inventory.has_item("hay", 1):
		feed_item = "hay"

	if feed_item == "":
		return 0

	var hungry_animals := _get_hungry_animals()
	var feed_count: int = mini(hungry_animals.size(), inventory.get_item_count(feed_item))
	if feed_count <= 0:
		return 0

	if not inventory.remove_item(feed_item, feed_count):
		return 0

	for i in range(feed_count):
		hungry_animals[i].feed(feed_item)

	return feed_count

## 添加动物到牛棚
func add_animal(animal: Animal) -> bool:
	if animals.size() >= max_animals:
		print("[Barn] 牛棚已满")
		return false
	
	animals.append(animal)
	if animal_container:
		animal.get_parent().remove_child(animal)
		animal_container.add_child(animal)
	
	print("[Barn] 添加动物: ", animal.animal_name)
	return true

## 移除动物
func remove_animal(animal: Animal) -> void:
	animals.erase(animal)

## 获取当前动物数量
func get_animal_count() -> int:
	return animals.size()

## 获取所有产品
func collect_all_products() -> Dictionary:
	var collected = {}
	for animal in animals:
		if animal.has_product:
			var product = animal.collect_product()
			if not product.is_empty():
				var product_id = product.get("product_id", "")
				var quality = product.get("quality", 0)
				if not collected.has(product_id):
					collected[product_id] = {"count": 0, "qualities": []}
				collected[product_id]["count"] += 1
				collected[product_id]["qualities"].append(quality)
	
	return collected
