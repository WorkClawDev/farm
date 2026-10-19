extends Control
class_name QuestTracker

var _panel: PanelContainer
var _title: Label
var _objective: Label
var _expanded := false
var _toggle_button: Button


func _ready() -> void:
	UIStyles.follow_theme(self)
	_build_ui()
	_connect_signals()
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
	if not QuestSystem:
		return
	for signal_name in ["quest_accepted", "quest_progress_updated", "quest_completed", "quest_turned_in", "objective_completed"]:
		if QuestSystem.has_signal(signal_name):
			QuestSystem.connect(signal_name, _on_quest_changed)


func _refresh() -> void:
	var quests = QuestSystem.get_active_quests() if QuestSystem else []
	visible = not quests.is_empty()
	if quests.is_empty():
		return
	var quest = quests[0]
	_title.text = str(quest.title)
	var lines: Array[String] = []
	for index in range(quest.objectives.size()):
		if not _expanded and index > 0:
			break
		var current := QuestSystem.get_objective_progress(quest.id, index)
		var required := int(quest.objectives[index].required)
		lines.append(UIFactory.no_orphan("%s %s  %d/%d" % [
			"✓" if current >= required else "○",
			QuestSystem.get_objective_description(quest.id, index),
			current,
			required,
		]))
	_objective.text = "\n".join(lines)


func _toggle() -> void:
	_expanded = not _expanded
	_toggle_button.text = "－" if _expanded else "＋"
	_refresh()


func _on_quest_changed(_a = null, _b = null, _c = null, _d = null) -> void:
	_refresh()


func toggle_visibility() -> void:
	visible = not visible
