extends Area2D
class_name Workbench

## Workbench - 工作台
## 提供制作功能的交互对象

signal workbench_interacted(workbench_node: Workbench)

# 工作台类型
enum WorkbenchType {
	WORKBENCH,  # 普通工作台
	FURNACE,    # 熔炉
	KITCHEN,    # 厨房
	ANVIL       # 铁砧
}

# 配置
@export var workbench_type: WorkbenchType = WorkbenchType.WORKBENCH
@export var workbench_name: String = "工作台"
@export var interaction_prompt: String = "按 E 键打开制作界面"
@export var is_interactable: bool = true

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null

# 玩家是否在范围内
var _player_in_range: bool = false

# CraftingUI 引用
var _crafting_ui: CraftingUI = null


func _ready() -> void:
	_setup_interaction()
	_connect_signals()
	_find_crafting_ui()
	print("[Workbench] %s initialized at position: %s" % [workbench_name, global_position])


func _setup_interaction() -> void:
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 1  # 检测玩家层

	# 创建精灵（如果不存在）
	if not has_node("Sprite2D"):
		var new_sprite := Sprite2D.new()
		new_sprite.name = "Sprite2D"
		new_sprite.modulate = _get_workbench_color()
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
		label.position = Vector2(-60, -50)
		label.size = Vector2(120, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		label.visible = false
		add_child(label)
		prompt_label = label


func _get_workbench_color() -> Color:
	match workbench_type:
		WorkbenchType.WORKBENCH: return Color(0.6, 0.4, 0.2)  # 木色
		WorkbenchType.FURNACE: return Color(0.5, 0.3, 0.3)    # 红砖色
		WorkbenchType.KITCHEN: return Color(0.4, 0.4, 0.5)    # 灰白色
		WorkbenchType.ANVIL: return Color(0.3, 0.3, 0.4)      # 深灰色
		_: return Color(0.5, 0.5, 0.5)


func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _find_crafting_ui() -> void:
	# 在场景树中查找 CraftingUI
	_crafting_ui = get_tree().get_first_node_in_group("crafting_ui") as CraftingUI

	# 如果没有找到，尝试从父节点查找
	if _crafting_ui == null:
		var parent := get_parent()
		while parent:
			for child in parent.get_children():
				if child is CraftingUI:
					_crafting_ui = child
					return
			parent = parent.get_parent()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		_show_prompt()
		print("[Workbench] Player entered interaction range")


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		_hide_prompt()
		print("[Workbench] Player left interaction range")


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
	print("[Workbench] Interacted!")
	workbench_interacted.emit(self)

	# 打开制作界面
	open_crafting_ui()


## 打开制作界面
func open_crafting_ui() -> void:
	if _crafting_ui == null:
		# 尝试再次查找
		_find_crafting_ui()

	if _crafting_ui:
		_crafting_ui.open(get_workbench_type_string())
	else:
		push_warning("[Workbench] CraftingUI not found in scene")
		print("[Workbench] Available recipes for %s:" % get_workbench_type_string())
		# 显示可用配方（调试用）
		_show_available_recipes()


## 显示可用配方（调试用）
func _show_available_recipes() -> void:
	if CraftingSystem == null:
		print("[Workbench] CraftingSystem not available")
		return

	var recipes := CraftingSystem.get_recipes_by_workbench(get_workbench_type_string())
	print("=== %s Recipes ===" % workbench_name)
	if recipes.is_empty():
		print("No recipes available")
	else:
		for recipe in recipes:
			print("  - %s (requires: %s)" % [recipe.name, _get_ingredient_summary(recipe)])


func _get_ingredient_summary(recipe: CraftingSystem.Recipe) -> String:
	var summary := []
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var quantity: int = ingredient.get("quantity", 1)
		summary.append("%s x%d" % [item_id, quantity])
	return ", ".join(summary)


## 获取工作台类型字符串
func get_workbench_type_string() -> String:
	match workbench_type:
		WorkbenchType.WORKBENCH: return "workbench"
		WorkbenchType.FURNACE: return "furnace"
		WorkbenchType.KITCHEN: return "kitchen"
		WorkbenchType.ANVIL: return "anvil"
		_: return ""


## 检查是否可以交互
func can_interact() -> bool:
	return is_interactable and _player_in_range


## 设置交互状态
func set_interactable(value: bool) -> void:
	is_interactable = value
	if not value:
		_hide_prompt()


## 设置工作台类型
func set_workbench_type(type: WorkbenchType) -> void:
	workbench_type = type
	workbench_name = _get_default_name()
	interaction_prompt = "按 E 键打开%s" % workbench_name

	if sprite:
		sprite.modulate = _get_workbench_color()


func _get_default_name() -> String:
	match workbench_type:
		WorkbenchType.WORKBENCH: return "工作台"
		WorkbenchType.FURNACE: return "熔炉"
		WorkbenchType.KITCHEN: return "厨房"
		WorkbenchType.ANVIL: return "铁砧"
		_: return "工作台"
