extends Area2D
class_name Kitchen
const InteractPromptScript = preload("res://src/ui/components/InteractPrompt.gd")  # preload: works before the class cache knows the class_name

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
	InteractPromptScript.attach(self, "烹饪", InteractPromptScript.sprite_top(self), func(): return is_player_in_range)
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
	if UIManager == null:
		push_warning("[Kitchen] UIManager unavailable")
		return
	UIManager.open_screen("cooking", {"pause_game": true})
	cooking_ui = UIManager.get_screen("cooking")
	print("[Kitchen] 打开烹饪界面")
