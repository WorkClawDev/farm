extends Area2D
class_name ShippingBin

const PHYSICS_LAYERS = preload("res://src/core/constants/PhysicsLayers.gd")

const TextureLoader := preload("res://src/core/utils/RuntimeTextureLoader.gd")
const DepthAnchor := preload("res://src/world/objects/WorldDepthAnchor.gd")
const SHIPPING_BIN_TEXTURE_PATH := "res://assets/ui/world/shipping_bin.svg"
const SHIPPING_BIN_DISPLAY_SIZE := Vector2(92, 74)

## ShippingBin - 出货箱
## 玩家可以将物品放入出货箱，次日自动结算获得金钱

signal bin_interacted(bin_node: ShippingBin)

# 交互提示
@export var interaction_prompt: String = "Press E to open shipping bin"

# 是否可以被交互
@export var is_interactable: bool = true

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else self
@onready var prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null

# 玩家是否在范围内
var _player_in_range: bool = false
var _depth_anchor_offset := 0.0


func _ready() -> void:
	_setup_visual()
	_setup_solid_collision()
	_apply_depth_anchor()
	_setup_interaction()
	_connect_signals()
	print("[ShippingBin] Initialized at position: ", global_position)


func _setup_visual() -> void:
	var texture := TextureLoader.load_texture(SHIPPING_BIN_TEXTURE_PATH)
	if texture == null:
		push_warning("[ShippingBin] Could not load texture: " + SHIPPING_BIN_TEXTURE_PATH)
		return
	var texture_size := Vector2(texture.get_size())
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2(
		SHIPPING_BIN_DISPLAY_SIZE.x / texture_size.x,
		SHIPPING_BIN_DISPLAY_SIZE.y / texture_size.y
	)
	sprite.z_index = 0
	var collision := $CollisionShape2D as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	if shape:
		shape.size = Vector2(118, 96)
		collision.position.y = 4


func _setup_solid_collision() -> void:
	if has_node("SolidBody"):
		return
	var body := StaticBody2D.new()
	body.name = "SolidBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position.y = 12
	var shape := RectangleShape2D.new()
	shape.size = Vector2(68, 44)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _apply_depth_anchor() -> void:
	var solid_collision := get_node_or_null("SolidBody/CollisionShape2D") as CollisionShape2D
	var shape := solid_collision.shape as RectangleShape2D if solid_collision else null
	if solid_collision == null or shape == null:
		return
	var foundation_bottom := solid_collision.position.y + shape.size.y * 0.5
	_depth_anchor_offset = DepthAnchor.apply(
		self,
		foundation_bottom,
		_depth_anchor_offset
	)


func get_depth_anchor_offset() -> float:
	return _depth_anchor_offset


func _setup_interaction() -> void:
	# 设置碰撞层
	collision_layer = PHYSICS_LAYERS.ITEMS
	collision_mask = PHYSICS_LAYERS.PLAYER

	# 创建精灵（如果不存在）
	if not has_node("Sprite2D"):
		var new_sprite := Sprite2D.new()
		new_sprite.name = "Sprite2D"
		add_child(new_sprite)
		sprite = new_sprite

	# 创建碰撞形状（如果不存在）
	if not has_node("CollisionShape2D"):
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32, 32)
		collision.shape = shape
		add_child(collision)

	# 创建提示标签
	if not has_node("PromptLabel") and prompt_label == null:
		var label := Label.new()
		label.name = "PromptLabel"
		label.position = Vector2(-50, -50)
		label.size = Vector2(100, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		add_child(label)
		prompt_label = label


func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		_show_prompt()
		print("[ShippingBin] Player entered interaction range")


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_hide_prompt()
		print("[ShippingBin] Player left interaction range")


func _show_prompt() -> void:
	if prompt_label:
		prompt_label.text = interaction_prompt
		prompt_label.visible = true


func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false


func _input(event: InputEvent) -> void:
	if not _player_in_range or not is_interactable:
		return

	# 检测交互按键（E键）
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_interact()
		get_viewport().set_input_as_handled()


## 执行交互
func _interact() -> void:
	print("[ShippingBin] Interacted!")
	bin_interacted.emit(self)
	UIManager.open_screen("shipping_bin", {"pause_game": true})


## 显示出货箱状态
func _show_bin_status() -> void:
	var shipping_system = get_node_or_null("/root/ShippingSystem")
	if not shipping_system:
		push_warning("[ShippingBin] ShippingSystem not available")
		return

	var contents = shipping_system.get_bin_contents()
	var value_info = shipping_system.calculate_total_value()

	print("=== Shipping Bin ===")
	print("Items: ", shipping_system.get_total_items())
	print("Slots used: ", shipping_system.get_slot_count(), "/", shipping_system.MAX_BIN_SLOTS)
	print("Total value: $", value_info.total_value)
	print("Items will be sold tomorrow at 6:00 AM")

	if contents.is_empty():
		print("Bin is empty")
	else:
		print("Contents:")
		for slot in contents:
			var item_database = get_node_or_null("/root/ItemDatabase")
			var item_data = item_database.get_item(slot.item_id) if item_database else null
			var item_name = item_data.name if item_data else slot.item_id
			print("  - ", item_name, " x", slot.quantity, " (Q", slot.quality, ")")

## 添加物品到出货箱
func add_item_to_bin(item_id: String, quantity: int = 1, quality: int = 0) -> bool:
	var shipping_system = get_node_or_null("/root/ShippingSystem")
	if not shipping_system:
		push_warning("[ShippingBin] ShippingSystem not available")
		return false

	return shipping_system.add_item(item_id, quantity, quality)


## 检查是否可以交互
func can_interact() -> bool:
	return is_interactable and _player_in_range


## 设置交互状态
func set_interactable(value: bool) -> void:
	is_interactable = value
	if not value:
		_hide_prompt()
