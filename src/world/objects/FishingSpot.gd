extends Area2D
class_name FishingSpot

signal fishing_started(spot: FishingSpot)
signal fishing_ended(spot: FishingSpot, success: bool, fish_id: String)

## FishingSpot - 钓鱼点
## 玩家可以在这里使用鱼竿钓鱼

@export var location_type: String = "lake"  # lake, river, beach, pond
@export var fishing_rod_scene: PackedScene = null

var is_player_in_range: bool = false
var current_player: Player = null

# 钓鱼UI
var fishing_ui: Control = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 钓鱼竿场景通过 @export editor 配置
	
	print("[FishingSpot] Fishing spot initialized: ", location_type)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = true
		current_player = body
		_show_fishing_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = false
		current_player = null
		_hide_fishing_prompt()

func _show_fishing_prompt() -> void:
	print("[FishingSpot] Press F to fish here")
	var prompt := Label.new()
	prompt.name = "FishingPrompt"
	prompt.text = "[F] 钓鱼"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.z_index = 10
	# 显示在钓鱼点上方
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.position = Vector2(0, -40)
	add_child(prompt)

func _hide_fishing_prompt() -> void:
	print("[FishingSpot] Left fishing spot")
	var existing := get_node_or_null("FishingPrompt")
	if existing:
		existing.queue_free()

func _input(event: InputEvent) -> void:
	if not is_player_in_range:
		return
	
	if event.is_action_pressed("interact"):
		_start_fishing()

func _start_fishing() -> void:
	if not current_player:
		return
	
	# 检查玩家是否装备了鱼竿
	if current_player.tool_manager:
		var current_tool = current_player.tool_manager.get_current_tool()
		if current_tool is FishingRod:
			var rod = current_tool as FishingRod
			if rod.current_state == FishingRod.FishingState.IDLE:
				rod.use(global_position, location_type)
				fishing_started.emit(self)
				print("[FishingSpot] Started fishing at ", location_type)
		else:
			print("[FishingSpot] Need to equip fishing rod first!")
			# 可以在这里显示提示UI
