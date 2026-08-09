extends Control
class_name DialogueBox

signal dialogue_finished
signal dialogue_advanced
signal choice_selected(choice_index: int)

@onready var background: PanelContainer = $NinePatchRect
@onready var portrait: TextureRect = $NinePatchRect/Layout/Portrait
@onready var name_label: Label = $NinePatchRect/Layout/VBoxContainer/Header/NameLabel
@onready var history_button: Button = $NinePatchRect/Layout/VBoxContainer/Header/HistoryButton
@onready var text_label: RichTextLabel = $NinePatchRect/Layout/VBoxContainer/TextLabel
@onready var continue_indicator: Label = $NinePatchRect/Layout/VBoxContainer/ContinueIndicator
@onready var choices_container: VBoxContainer = $NinePatchRect/Layout/VBoxContainer/ChoicesContainer
@onready var history_panel: PanelContainer = $HistoryPanel
@onready var history_text: RichTextLabel = $HistoryPanel/VBox/HistoryText

var dialogue_lines: Array = []
var current_line_index := 0
var current_character := ""
var current_choices: Array = []
var is_typing := false
var typewriter_speed := 0.03
var _typewriter_timer := 0.0
var _current_text := ""
var _visible_characters := 0
var selected_choice_index := 0
var has_choices := false
var _history: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	history_button.pressed.connect(_toggle_history)
	$HistoryPanel/VBox/Header/Close.pressed.connect(_toggle_history)
	if InputManager:
		InputManager.input_device_changed.connect(_update_continue_prompt)
	_update_continue_prompt(InputManager.get_current_device())
	hide_dialogue()


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func show_dialogue(character_name: String, lines: Array) -> void:
	current_character = character_name
	dialogue_lines = lines
	current_line_index = 0
	current_choices.clear()
	has_choices = false
	_history.clear()
	visible = true
	_display_current_line()
	print("[DialogueBox] Showing dialogue for: ", character_name)


func show_dialogue_advanced(dialogue_data: Dictionary) -> void:
	current_character = str(dialogue_data.get("speaker", "???"))
	dialogue_lines = dialogue_data.get("lines", [])
	current_line_index = 0
	current_choices.clear()
	has_choices = false
	_history.clear()
	visible = true
	if dialogue_data.has("portrait"):
		set_portrait(load(str(dialogue_data.portrait)))
	_display_current_line()
	print("[DialogueBox] Showing advanced dialogue for: ", current_character)


func set_portrait(texture: Texture2D) -> void:
	portrait.texture = texture
	portrait.visible = texture != null


func hide_dialogue() -> void:
	visible = false
	history_panel.visible = false
	is_typing = false
	dialogue_lines.clear()
	current_line_index = 0
	_hide_choices()


func show_choices(choices: Array) -> void:
	current_choices = choices
	has_choices = true
	selected_choice_index = 0
	for child in choices_container.get_children():
		child.queue_free()
	for index in range(choices.size()):
		var choice_data: Variant = choices[index]
		var choice_text := str(choice_data) if choice_data is String else str(choice_data.get("text", "…"))
		var button := UIFactory.button(choice_text, &"", Vector2(0, 42))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_choice.bind(index))
		button.focus_entered.connect(_on_choice_focus_entered.bind(index))
		choices_container.add_child(button)
	choices_container.visible = true
	continue_indicator.visible = false
	await get_tree().process_frame
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Button).grab_focus()


func _hide_choices() -> void:
	has_choices = false
	current_choices.clear()
	choices_container.visible = false
	for child in choices_container.get_children():
		child.queue_free()


func _display_current_line() -> void:
	if current_line_index >= dialogue_lines.size():
		_end_dialogue()
		return
	current_choices.clear()
	var line_data: Variant = dialogue_lines[current_line_index]
	if line_data is String:
		_current_text = line_data
	else:
		current_character = str(line_data.get("speaker", current_character))
		_current_text = str(line_data.get("text", "…"))
		if line_data.has("choices"):
			current_choices = line_data.choices
	name_label.text = current_character
	_history.append({"speaker": current_character, "text": _current_text})
	_refresh_history()
	text_label.text = ""
	_visible_characters = 0
	_typewriter_timer = 0.0
	var speed_setting := float(UserSettings.get_value("accessibility", "text_speed", 1.0))
	if speed_setting <= 0.0:
		_finish_typewriter()
	else:
		typewriter_speed = 0.03 / speed_setting
		is_typing = true
		continue_indicator.visible = false


func _process(delta: float) -> void:
	if not is_typing:
		return
	_typewriter_timer += delta
	while _typewriter_timer >= typewriter_speed and _visible_characters < _current_text.length():
		_typewriter_timer -= typewriter_speed
		_visible_characters += 1
		text_label.text = _current_text.substr(0, _visible_characters)
	if _visible_characters >= _current_text.length():
		_finish_typewriter()


func _finish_typewriter() -> void:
	is_typing = false
	text_label.text = _current_text
	if not current_choices.is_empty():
		show_choices(current_choices)
	else:
		continue_indicator.visible = true


func _advance_dialogue() -> void:
	current_line_index += 1
	dialogue_advanced.emit()
	_display_current_line()


func _select_choice(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return
	var choice_data: Variant = current_choices[index]
	var choice_text := str(choice_data) if choice_data is String else str(choice_data.get("text", "…"))
	_history.append({"speaker": "你", "text": choice_text})
	_refresh_history()
	_hide_choices()
	choice_selected.emit(index)
	print("[DialogueBox] Choice selected: ", index)


func _end_dialogue() -> void:
	_hide_choices()
	dialogue_finished.emit()
	hide_dialogue()
	print("[DialogueBox] Dialogue ended")


func _toggle_history() -> void:
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		$HistoryPanel/VBox/Header/Close.grab_focus()
	else:
		history_button.grab_focus()


func _refresh_history() -> void:
	var blocks: Array[String] = []
	for entry in _history:
		blocks.append("[b]%s[/b]\n%s" % [entry.speaker, entry.text])
	history_text.text = "\n\n".join(blocks)


func _update_continue_prompt(_device: int) -> void:
	continue_indicator.text = "%s 继续   ·   %s 显示全文" % [
		InputManager.get_action_prompt(&"interact"),
		InputManager.get_action_prompt(&"interact"),
	]


func set_typewriter_speed(speed: float) -> void:
	typewriter_speed = maxf(0.001, speed)


func is_showing_choices() -> bool:
	return has_choices


func get_choice_count() -> int:
	return current_choices.size()


func _on_choice_focus_entered(index: int) -> void:
	selected_choice_index = index


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if history_panel.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_toggle_history()
			get_viewport().set_input_as_handled()
		return
	if has_choices:
		if event.is_action_pressed("ui_up"):
			selected_choice_index = wrapi(selected_choice_index - 1, 0, choices_container.get_child_count())
			(choices_container.get_child(selected_choice_index) as Button).grab_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			selected_choice_index = wrapi(selected_choice_index + 1, 0, choices_container.get_child_count())
			(choices_container.get_child(selected_choice_index) as Button).grab_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_select_choice(selected_choice_index)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			_finish_typewriter()
		else:
			_advance_dialogue()
		get_viewport().set_input_as_handled()
