extends Node2D
class_name InteractPrompt

## Small "E" bubble above whatever the player would interact with.
## Add one to an interactable with InteractPrompt.attach(owner, text, offset, is_available).
## Every prompt registers here; each frame only the winner is shown: the highest
## priority available prompt (NPC > building > other, matching Player._handle_interaction),
## nearest to the player on ties (Player picks the nearest NPC the same way).
## Hidden outside PLAYING (dialogue, shop, menus, cutscenes), while paused or a modal is open.
## Styled by the active theme (InteractPromptBubble / KeyCap / Key / Text variations).

const PRIORITY_NPC := 2
const PRIORITY_BUILDING := 1
const PRIORITY_OBJECT := 0

# No self-typed references below: a script must load even before the editor has
# registered this class_name in the global class cache (BUG-29).
const SCRIPT_PATH := "res://src/ui/components/InteractPrompt.gd"
# Registry is a node group and the per-frame winner is cached on the SceneTree:
# static vars on this script kept it (and both themes) alive at exit
# ("resources still in use").
const GROUP := &"interact_prompts"
const CACHE_META := &"interact_prompt_winner"
## HUD panels (quest tracker) a bubble must not hide behind; it flips below its target then.
const AVOID_GROUP := &"interact_prompt_avoid"

## Short verb after the key, e.g. "出货"; empty = key only (NPCs).
var action_text := ""
var priority := PRIORITY_OBJECT
var action: StringName = &"interact"
## Returns true while the player could interact with this target.
var is_available: Callable = Callable()

var bubble: PanelContainer
var key_label: Label
var text_label: Label


static func attach(target: Node2D, text: String, offset: Vector2, available: Callable, prompt_priority := PRIORITY_OBJECT) -> Node2D:
	var prompt = load(SCRIPT_PATH).new()
	prompt.name = "InteractPrompt"
	prompt.action_text = text
	prompt.position = offset
	prompt.is_available = available
	prompt.priority = prompt_priority
	target.add_child(prompt)
	return prompt


## Top-centre of target's "Sprite2D" in target space, lifted by margin; fallback above the origin.
static func sprite_top(target: Node2D, margin := 6.0) -> Vector2:
	var sprite := target.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null or not sprite.visible:
		return Vector2(0, -32)
	var rect := sprite.get_rect()
	var top := rect.position.y
	# Skip transparent padding at the top of the art (e.g. the coop sheet).
	if not sprite.region_enabled and sprite.hframes * sprite.vframes == 1:
		var image := sprite.texture.get_image()
		if image:
			var used := image.get_used_rect()
			if used.size.y > 0:
				top += float(used.position.y) * rect.size.y / float(image.get_height())
	return sprite.transform * Vector2(rect.position.x + rect.size.x * 0.5, top) - Vector2(0, margin)


func set_action_text(text: String) -> void:
	action_text = text
	if text_label:
		text_label.text = text
		text_label.visible = not text.is_empty()


## The prompt currently shown (or null). Recomputed at most once per frame.
static func current() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var frame := Engine.get_process_frames()
	var cache: Array = tree.get_meta(CACHE_META, [-1, 0])
	if int(cache[0]) != frame:
		var picked = _pick_winner(tree)
		cache = [frame, picked.get_instance_id() if picked else 0]
		tree.set_meta(CACHE_META, cache)
	var winner = instance_from_id(int(cache[1])) if int(cache[1]) != 0 else null
	return winner if is_instance_valid(winner) else null


static func _pick_winner(tree: SceneTree) -> Node2D:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return null
	if UIManager and UIManager.has_open_modal():
		return null
	var best = null
	var best_distance := INF
	for prompt in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(prompt) or not prompt.is_inside_tree() or prompt.get_tree().paused:
			continue
		if not prompt.available():
			continue
		var player := prompt.get_tree().get_first_node_in_group("player") as Node2D
		var target := prompt.get_parent() as Node2D
		var distance := player.global_position.distance_squared_to(target.global_position) if player and target else 0.0
		if best == null or prompt.priority > best.priority or (prompt.priority == best.priority and distance < best_distance):
			best = prompt
			best_distance = distance
	return best


func _ready() -> void:
	z_as_relative = false
	z_index = 100  # above y-sorted actors and map props
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.theme_type_variation = &"InteractPromptBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyles.follow_theme(bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(row)
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"InteractPromptKeyCap"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cap)
	key_label = Label.new()
	key_label.name = "Key"
	key_label.theme_type_variation = &"InteractPromptKey"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(key_label)
	text_label = Label.new()
	text_label.name = "Text"
	text_label.theme_type_variation = &"InteractPromptText"
	text_label.text = action_text
	text_label.visible = not action_text.is_empty()
	row.add_child(text_label)
	add_child(bubble)
	bubble.resized.connect(_place_bubble)
	_refresh_key()
	if InputManager:
		InputManager.bindings_changed.connect(func(_a): _refresh_key())
		InputManager.input_device_changed.connect(func(_d): _refresh_key())
	visible = false


func _enter_tree() -> void:
	add_to_group(GROUP)


func available() -> bool:
	if is_available.is_valid() and not bool(is_available.call()):
		return false
	var target := get_parent() as CanvasItem
	return target == null or target.is_visible_in_tree()


func _process(_delta: float) -> void:
	visible = current() == self
	if visible and bubble:
		_avoid_hud()


## The coop sits under the quest panel when the camera is at the farm's top-left
## corner; show the bubble below the target instead of behind the panel.
func _avoid_hud() -> void:
	var above := Vector2(-bubble.size.x * 0.5, -bubble.size.y)
	var on_screen := get_global_transform_with_canvas() * Rect2(above, bubble.size)
	for panel in get_tree().get_nodes_in_group(AVOID_GROUP):
		if panel is Control and panel.is_visible_in_tree() and panel.get_global_rect().intersects(on_screen):
			bubble.position = Vector2(above.x, _below_target_y())
			return
	bubble.position = above


## Just under the target's drawn sprite (BUG-43: the old 2x mirror of the top
## offset put the coop bubble out over the pond); fallback below this node.
func _below_target_y() -> float:
	var target := get_parent() as Node2D
	var sprite := target.get_node_or_null("Sprite2D") as Sprite2D if target else null
	if sprite and sprite.texture and sprite.visible:
		var rect := sprite.get_rect()
		var bottom := (sprite.transform * Vector2(rect.get_center().x, rect.end.y)).y
		return bottom - position.y + 2.0
	return 8.0


func _refresh_key() -> void:
	if key_label:
		key_label.text = InputManager.get_action_short_prompt(action) if InputManager else "E"


## Bubble sits centred above this node's position (its bottom edge on the anchor).
func _place_bubble() -> void:
	bubble.position = Vector2(-bubble.size.x * 0.5, -bubble.size.y)
