extends Control
class_name QuestTracker

## Center overlays (tool upgrade and anything else that opts in) join this group.
## A visible member hides the quest bar the same way a pause or UIManager modal does.
const BLOCKER_GROUP := &"quest_bar_blockers"

var _panel: PanelContainer
var _title: Label
var _objective: Label
var _expanded := false
var _toggle_button: Button


## No active quest stays hidden. Pause, a UIManager modal, or a center overlay also hide it.
static func should_show(has_active_quest: bool, blocked: bool) -> bool:
	return has_active_quest and not blocked


static func blocks_bar(tree_paused: bool, game_paused: bool, modal_open: bool, center_open: bool) -> bool:
	return tree_paused or game_paused or modal_open or center_open


## Active quests are oldest-first. The bar follows the most recently accepted
## quest instead of index 0. Numeric priority is the wrong key here: the farm
## tutorial is 100 and village_introduction is 95, so a priority sort stays on
## 「农场入门」. If the newest entry is that tutorial while the village guide is
## also active, the guide wins so accepting it actually switches the bar.
static func select_featured_quest(quests: Variant) -> Variant:
	if quests == null or int(quests.size()) == 0:
		return null
	var newest: Variant = quests[int(quests.size()) - 1]
	if newest != null and str(newest.id) == "tutorial_farming":
		for quest in quests:
			if quest != null and str(quest.id) == "village_introduction":
				return quest
	return newest


## Collapsed bar shows this objective: the first one that is not finished yet.
static func first_incomplete_objective(objectives: Variant, progress: Variant) -> int:
	if objectives == null:
		return 0
	var count := int(objectives.size())
	for index in range(count):
		var required := int(objectives[index].required)
		var current := 0
		if progress != null and index < int(progress.size()):
			current = int(progress[index])
		if current < required:
			return index
	return 0


func _ready() -> void:
	UIStyles.follow_theme(self)
	_build_ui()
	_connect_signals()
	_refresh()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PAUSED and what != NOTIFICATION_UNPAUSED:
		return
	if not is_node_ready():
		return
	_refresh()


func _build_ui() -> void:
	_panel = UIFactory.hud_panel()
	# Top-wide: keep the 340px width but let the height hug the content instead
	# of a fixed 170px box that was mostly empty with a single objective.
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(_panel)
	_panel.add_to_group(&"interact_prompt_avoid")  # InteractPrompt bubbles flip below instead
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var caption := Label.new()
	caption.theme_type_variation = &"HUDSmall"
	caption.modulate.a = 0.88
	caption.text = "当前任务"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var toggle := UIFactory.button("＋", &"HUDButton", Vector2(34, 28))
	toggle.tooltip_text = "展开/收起全部目标"
	toggle.focus_mode = Control.FOCUS_NONE  # a focused HUD button would eat Space (tool use)
	_toggle_button = toggle
	toggle.pressed.connect(_toggle)
	header.add_child(toggle)
	_title = Label.new()
	_title.theme_type_variation = &"HUDTitle"
	content.add_child(_title)
	_objective = Label.new()
	_objective.theme_type_variation = &"HUDSmall"
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_objective)


func _connect_signals() -> void:
	if QuestSystem:
		for signal_name in ["quest_accepted", "quest_progress_updated", "quest_completed", "quest_turned_in", "objective_completed"]:
			if QuestSystem.has_signal(signal_name) and not QuestSystem.is_connected(signal_name, _on_quest_changed):
				QuestSystem.connect(signal_name, _on_quest_changed)
	if GameManager:
		if not GameManager.game_paused.is_connected(_refresh):
			GameManager.game_paused.connect(_refresh)
		if not GameManager.game_resumed.is_connected(_refresh):
			GameManager.game_resumed.connect(_refresh)
	if UIManager and UIManager.has_signal("modal_stack_changed"):
		if not UIManager.modal_stack_changed.is_connected(_on_modal_stack_changed):
			UIManager.modal_stack_changed.connect(_on_modal_stack_changed)
	if EventBus and EventBus.has_signal("ui_opened"):
		if not EventBus.ui_opened.is_connected(_on_ui_bus):
			EventBus.ui_opened.connect(_on_ui_bus)
		if not EventBus.ui_closed.is_connected(_on_ui_bus):
			EventBus.ui_closed.connect(_on_ui_bus)


func _refresh() -> void:
	if _title == null:
		return
	var quests: Array = QuestSystem.get_active_quests() if QuestSystem else []
	var quest: Variant = select_featured_quest(quests)
	var has_quest := quest != null
	if has_quest:
		_title.text = str(quest.title)
		var progress_values: Array = []
		var quest_progress = QuestSystem.get_quest_progress(str(quest.id)) if QuestSystem else null
		if quest_progress != null:
			for value in quest_progress.objective_progress:
				progress_values.append(int(value))
		var focus := first_incomplete_objective(quest.objectives, progress_values)
		var lines: Array[String] = []
		for index in range(quest.objectives.size()):
			if not _expanded and index != focus:
				continue
			var current := QuestSystem.get_objective_progress(quest.id, index)
			var required := int(quest.objectives[index].required)
			lines.append(UIFactory.no_orphan("%s %s  %d/%d" % [
				"✓" if current >= required else "○",
				QuestSystem.get_objective_description(quest.id, index),
				current,
				required,
			]))
		_objective.text = "\n".join(lines)
	_sync_visible(has_quest)


func _sync_visible(has_active_quest: bool) -> void:
	visible = should_show(has_active_quest, _is_blocked())


func _is_blocked() -> bool:
	var tree_paused := false
	var center_open := false
	if is_inside_tree():
		tree_paused = get_tree().paused
		center_open = _center_modal_open()
	var game_paused := GameManager.is_paused() if GameManager else false
	var modal_open := UIManager.has_open_modal() if UIManager else false
	return blocks_bar(tree_paused, game_paused, modal_open, center_open)


func _center_modal_open() -> bool:
	for node in get_tree().get_nodes_in_group(BLOCKER_GROUP):
		if not is_instance_valid(node):
			continue
		if "visible" in node and bool(node.visible):
			return true
	return false


func _toggle() -> void:
	_expanded = not _expanded
	_toggle_button.text = "－" if _expanded else "＋"
	_refresh()


func _on_quest_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_refresh()


func _on_modal_stack_changed(_depth: int) -> void:
	_refresh()


func _on_ui_bus(_ui_name: String) -> void:
	_refresh()


func toggle_visibility() -> void:
	visible = not visible
