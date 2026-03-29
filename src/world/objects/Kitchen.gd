extends Area2D
class_name Kitchen

## Kitchen - 厨房工作台
## 玩家可以在这里进行烹饪

@export var kitchen_name: String = "厨房"

var is_player_in_range: bool = false
var current_player: Player = null

# 烹饪UI
var cooking_ui: Control = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[Kitchen] Kitchen initialized")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = true
		current_player = body
		_show_interact_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = false
		current_player = null
		_hide_interact_prompt()

func _show_interact_prompt() -> void:
	print("[Kitchen] 按 E 键使用厨房")

func _hide_interact_prompt() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not is_player_in_range:
		return
	
	if event.is_action_pressed("interact"):
		_open_cooking_ui()

func _open_cooking_ui() -> void:
	if cooking_ui == null:
		# 加载烹饪UI场景
		var cooking_ui_scene = load("res://src/ui/menus/CookingUI.tscn")
		if cooking_ui_scene:
			cooking_ui = cooking_ui_scene.instantiate()
			get_tree().current_scene.add_child(cooking_ui)
	
	if cooking_ui:
		cooking_ui.show()
		print("[Kitchen] 打开烹饪界面")