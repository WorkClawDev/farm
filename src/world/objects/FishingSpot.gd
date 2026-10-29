extends Area2D
class_name FishingSpot
const InteractPromptScript = preload("res://src/ui/components/InteractPrompt.gd")  # preload: works before the class cache knows the class_name

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
var _prompt = null  # InteractPrompt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var authored_hint := get_node_or_null("HintLabel") as Label
	if authored_hint:
		authored_hint.visible = false
	
	# 钓鱼竿场景通过 @export editor 配置
	
	_prompt = InteractPromptScript.attach(self, "", Vector2(0, -20), _prompt_available)
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

## Always shown at the water (BUG-38): "钓鱼" with the rod, "装水" with the
## watering can; with any other tool E explains that a rod is needed.
func _prompt_available() -> bool:
	if not is_player_in_range or current_player == null or current_player.tool_manager == null:
		return false
	var current_tool = current_player.tool_manager.get_current_tool()
	var text := "装水" if current_tool is WateringCan else "钓鱼"
	if _prompt:
		_prompt.set_action_text(text)
	return true

func _show_fishing_prompt() -> void:
	# The shared InteractPrompt bubble (see _prompt_available) replaced the
	# old "[E] 钓鱼 / 水壶装水" label that used to be created here.
	print("[FishingSpot] Player at fishing spot")

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
		elif current_tool is WateringCan:
			_refill_watering_can()
		else:
			print("[FishingSpot] Need to equip fishing rod first!")
			UIManager.show_toast("先换上鱼竿再钓鱼（按 6 或 Q/R）", {}, "info")


## 拿着水壶在水边按空格/E：把水壶装满（水量存在 FarmState）。
func _refill_watering_can() -> void:
	var refilled := FarmState.refill_watering_can()
	var message := (
		"水壶已装满（%d/%d）" % [FarmState.get_watering_can_uses_left(), FarmState.get_watering_can_max_uses()]
		if refilled else "水壶已经是满的"
	)
	UIManager.show_toast(message, {}, "info")
	print("[FishingSpot] ", message)
