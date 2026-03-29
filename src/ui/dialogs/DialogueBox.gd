extends Control
class_name DialogueBox

## DialogueBox - 对话框界面
## 显示NPC对话、打字机效果和分支选项

signal dialogue_finished
signal dialogue_advanced
signal choice_selected(choice_index: int)

# 节点引用
@onready var background: NinePatchRect = $NinePatchRect
@onready var name_label: Label = $NinePatchRect/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $NinePatchRect/VBoxContainer/TextLabel
@onready var continue_indicator: Label = $NinePatchRect/VBoxContainer/ContinueIndicator
@onready var choices_container: VBoxContainer = $NinePatchRect/VBoxContainer/ChoicesContainer

# 对话数据
var dialogue_lines: Array = []
var current_line_index: int = 0
var current_character: String = ""
var current_choices: Array = []

# 打字机效果
var is_typing: bool = false
var typewriter_speed: float = 0.03
var _typewriter_timer: float = 0.0
var _current_text: String = ""
var _visible_characters: int = 0

# 当前选择
var selected_choice_index: int = 0
var has_choices: bool = false


func _ready() -> void:
	hide_dialogue()
	continue_indicator.visible = false
	_hide_choices()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if has_choices:
		_handle_choice_input(event)
	else:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_handle_input()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_typing:
		_update_typewriter(delta)


## 显示对话（简单模式 - 只有文本行）
func show_dialogue(character_name: String, lines: Array) -> void:
	current_character = character_name
	dialogue_lines = lines
	current_line_index = 0
	current_choices = []
	has_choices = false

	visible = true
	_display_current_line()
	print("[DialogueBox] Showing dialogue for: ", character_name)


## 显示对话（高级模式 - 支持条件分支）
func show_dialogue_advanced(dialogue_data: Dictionary) -> void:
	current_character = dialogue_data.get("speaker", "???")
	dialogue_lines = dialogue_data.get("lines", [])
	current_line_index = 0

	visible = true
	_display_current_line()
	print("[DialogueBox] Showing advanced dialogue for: ", current_character)


## 隐藏对话
func hide_dialogue() -> void:
	visible = false
	is_typing = false
	dialogue_lines.clear()
	current_line_index = 0
	_hide_choices()


## 显示选项
func show_choices(choices: Array) -> void:
	current_choices = choices
	has_choices = true
	selected_choice_index = 0

	# 清空现有选项按钮
	for child in choices_container.get_children():
		child.queue_free()

	# 创建选项按钮
	for i in range(choices.size()):
		var choice_data = choices[i]
		var choice_text = choice_data if typeof(choice_data) == TYPE_STRING else choice_data.get("text", "...")
		var button = Button.new()
		button.text = choice_text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 30)

		# 设置按钮样式
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style_normal.border_color = Color(0.4, 0.4, 0.4)
		style_normal.set_border_width_all(2)
		button.add_theme_stylebox_override("normal", style_normal)

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.3, 0.4, 0.5, 0.9)
		style_hover.border_color = Color(0.6, 0.7, 0.8)
		style_hover.set_border_width_all(2)
		button.add_theme_stylebox_override("hover", style_hover)

		var style_focus = StyleBoxFlat.new()
		style_focus.bg_color = Color(0.3, 0.5, 0.3, 0.9)
		style_focus.border_color = Color(0.5, 0.8, 0.5)
		style_focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", style_focus)

		# 连接信号
		button.pressed.connect(_on_choice_button_pressed.bind(i))
		button.focus_entered.connect(_on_choice_focus_entered.bind(i))

		choices_container.add_child(button)

	# 设置第一个选项为焦点
	await get_tree().process_frame
	if choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()

	choices_container.visible = true
	continue_indicator.visible = false


## 隐藏选项
func _hide_choices() -> void:
	has_choices = false
	current_choices.clear()
	choices_container.visible = false

	# 清空选项按钮
	for child in choices_container.get_children():
		child.queue_free()


## 处理选项输入
func _handle_choice_input(event: InputEvent) -> void:
	var choice_count = choices_container.get_child_count()
	if choice_count == 0:
		return

	if event.is_action_pressed("ui_up"):
		selected_choice_index = wrapi(selected_choice_index - 1, 0, choice_count)
		choices_container.get_child(selected_choice_index).grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		selected_choice_index = wrapi(selected_choice_index + 1, 0, choice_count)
		choices_container.get_child(selected_choice_index).grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_select_choice(selected_choice_index)
		get_viewport().set_input_as_handled()


## 选择选项
func _select_choice(index: int) -> void:
	if index < 0 or index >= current_choices.size():
		return

	has_choices = false
	_hide_choices()
	choice_selected.emit(index)
	print("[DialogueBox] Choice selected: ", index)


## 选项按钮按下
func _on_choice_button_pressed(index: int) -> void:
	_select_choice(index)


## 选项获得焦点
func _on_choice_focus_entered(index: int) -> void:
	selected_choice_index = index


## 显示当前对话行
func _display_current_line() -> void:
	if current_line_index >= dialogue_lines.size():
		_end_dialogue()
		return

	var line_data = dialogue_lines[current_line_index]

	# 支持字符串或字典格式
	if typeof(line_data) == TYPE_STRING:
		_current_text = line_data
	else:
		current_character = line_data.get("speaker", current_character)
		_current_text = line_data.get("text", "...")

		# 检查是否有选项
		if line_data.has("choices"):
			# 延迟显示选项，等待打字机效果完成
			current_choices = line_data["choices"]

	name_label.text = current_character
	text_label.text = ""
	_visible_characters = 0
	is_typing = true
	continue_indicator.visible = false


## 更新打字机效果
func _update_typewriter(delta: float) -> void:
	_typewriter_timer += delta

	if _typewriter_timer >= typewriter_speed:
		_typewriter_timer = 0.0

		if _visible_characters < _current_text.length():
			text_label.text = _current_text.substr(0, _visible_characters + 1)
			_visible_characters += 1
		else:
			_finish_typewriter()


## 完成打字机效果
func _finish_typewriter() -> void:
	is_typing = false
	text_label.text = _current_text

	# 如果有选项，显示选项
	if current_choices.size() > 0:
		show_choices(current_choices)
	else:
		continue_indicator.visible = true


## 处理输入
func _handle_input() -> void:
	if is_typing:
		# 立即显示全部文本
		_finish_typewriter()
	else:
		# 显示下一行
		_advance_dialogue()


## 前进对话
func _advance_dialogue() -> void:
	current_line_index += 1
	emit_signal("dialogue_advanced")

	if current_line_index >= dialogue_lines.size():
		_end_dialogue()
	else:
		_display_current_line()


## 结束对话
func _end_dialogue() -> void:
	_hide_choices()
	emit_signal("dialogue_finished")
	hide_dialogue()
	print("[DialogueBox] Dialogue ended")


## 设置打字机速度
func set_typewriter_speed(speed: float) -> void:
	typewriter_speed = max(0.001, speed)


## 检查是否有选项
func is_showing_choices() -> bool:
	return has_choices


## 获取当前选项数量
func get_choice_count() -> int:
	return current_choices.size()