extends Control
class_name SettingsUI

signal settings_closed

const TAB_IDS := ["audio", "display", "controls", "accessibility"]
const TAB_KEYS := [
	"ui.settings.audio",
	"ui.settings.display",
	"ui.settings.controls",
	"ui.settings.accessibility",
]

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _active_tab := 0
var _status: Label
var _waiting_action: StringName = &""
var _binding_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	_build_ui()
	_show_tab(0)
	await get_tree().process_frame
	if not _tab_buttons.is_empty():
		_tab_buttons[0].grab_focus()


func configure(context: Dictionary) -> void:
	_show_tab(int(context.get("tab", 0)))


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func open() -> void:
	show()


func close() -> void:
	_waiting_action = &""
	UserSettings.set_value("input", "bindings", InputManager.serialize_bindings(), false)
	UserSettings.save()
	settings_closed.emit()
	queue_free()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	add_child(shade)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 54)
	safe.add_theme_constant_override("margin_top", 40)
	safe.add_theme_constant_override("margin_right", 54)
	safe.add_theme_constant_override("margin_bottom", 40)
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1040, 610))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UIFactory.title(UIStyles.tr_key("ui.settings.title", "设置"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	outer.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	outer.add_child(body)

	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 190
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for index in range(TAB_IDS.size()):
		var tab := UIFactory.button(UIStyles.tr_key(TAB_KEYS[index], TAB_IDS[index]), &"TabButton", Vector2(0, 50))
		tab.pressed.connect(_show_tab.bind(index))
		tabs.add_child(tab)
		_tab_buttons.append(tab)

	var page_panel := PanelContainer.new()
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(page_panel)
	var page_stack := Control.new()
	page_stack.name = "PageStack"
	page_stack.custom_minimum_size = Vector2(720, 430)
	page_panel.add_child(page_stack)

	_add_page(page_stack, _build_audio_page())
	_add_page(page_stack, _build_display_page())
	_add_page(page_stack, _build_controls_page())
	_add_page(page_stack, _build_accessibility_page())

	var footer := HBoxContainer.new()
	outer.add_child(footer)
	_status = UIFactory.subtitle("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	var reset := UIFactory.button(UIStyles.tr_key("ui.common.reset", "恢复默认"), &"DangerButton", Vector2(150, 46))
	reset.pressed.connect(_confirm_reset)
	footer.add_child(reset)
	var done := UIFactory.button(UIStyles.tr_key("ui.common.apply", "应用"), &"PrimaryButton", Vector2(150, 46))
	done.pressed.connect(_save_and_close)
	footer.add_child(done)


func _add_page(stack: Control, page: Control) -> void:
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(page)
	_pages.append(page)


func _build_audio_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.settings.audio", "声音")))
	page.add_child(_make_slider("ui.settings.master_volume", "audio", "master_volume"))
	page.add_child(_make_slider("ui.settings.music_volume", "audio", "music_volume"))
	page.add_child(_make_slider("ui.settings.sfx_volume", "audio", "sfx_volume"))
	return page


func _build_display_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.settings.display", "显示")))
	page.add_child(_make_option("ui.settings.window_mode", [
		["ui.settings.windowed", "windowed"],
		["ui.settings.fullscreen", "fullscreen"],
		["ui.settings.borderless", "borderless"],
	], "display", "window_mode"))
	page.add_child(_make_option("ui.settings.resolution", [
		["1280 × 720", "1280x720"],
		["1366 × 768", "1366x768"],
		["1600 × 900", "1600x900"],
		["1920 × 1080", "1920x1080"],
		["2560 × 1440", "2560x1440"],
		["3840 × 2160", "3840x2160"],
	], "display", "resolution"))
	page.add_child(_make_option("ui.settings.ui_scale", [
		["85%", 0.85], ["100%", 1.0], ["115%", 1.15], ["130%", 1.3],
	], "display", "ui_scale"))
	page.add_child(_make_check("ui.settings.vsync", "display", "vsync"))
	return page


func _build_controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.settings.controls", "操作")))
	page.add_child(UIFactory.subtitle(UIStyles.tr_key("ui.settings.remap_hint", "选择操作后按下新按键；有冲突时不会保存。")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for action in InputManager.REMAPPABLE_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = InputManager.get_action_display_name(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var binding := UIFactory.button(InputManager.get_action_prompt(action, InputManager.DeviceType.KEYBOARD_MOUSE), &"", Vector2(190, 42))
		binding.pressed.connect(_begin_remap.bind(action))
		row.add_child(binding)
		_binding_buttons[action] = binding
		rows.add_child(row)
	return page


func _build_accessibility_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.settings.accessibility", "辅助功能")))
	page.add_child(_make_check("ui.settings.high_contrast", "accessibility", "high_contrast"))
	page.add_child(_make_check("ui.settings.reduce_motion", "accessibility", "reduce_motion"))
	page.add_child(_make_check("ui.settings.show_hints", "accessibility", "show_hints"))
	page.add_child(_make_option("ui.settings.text_speed", [
		["立即显示", 0.0], ["慢", 0.7], ["标准", 1.0], ["快", 1.5], ["很快", 2.0],
	], "accessibility", "text_speed"))
	page.add_child(_make_option("ui.settings.gamepad_icons", [
		["自动识别", "auto"], ["Xbox", "xbox"], ["PlayStation", "playstation"], ["Nintendo", "nintendo"],
	], "input", "gamepad_icons"))
	return page


func _make_slider(label_key: String, section: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = UIStyles.tr_key(label_key, key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 320
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = float(UserSettings.get_value(section, key, 1.0))
	value_label.text = "%d%%" % int(slider.value * 100)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value * 100)
		UserSettings.set_value(section, key, value)
	)
	row.add_child(slider)
	return row


func _make_option(label_key: String, options: Array, section: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = UIStyles.tr_key(label_key, key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(300, 44)
	var current = UserSettings.get_value(section, key)
	var selected := 0
	for index in range(options.size()):
		option.add_item(UIStyles.tr_key(str(options[index][0]), str(options[index][0])))
		option.set_item_metadata(index, options[index][1])
		if options[index][1] == current:
			selected = index
	option.select(selected)
	option.item_selected.connect(func(index: int) -> void:
		UserSettings.set_value(section, key, option.get_item_metadata(index))
	)
	row.add_child(option)
	return row


func _make_check(label_key: String, section: String, key: String) -> Control:
	var check := CheckButton.new()
	check.text = UIStyles.tr_key(label_key, key)
	check.button_pressed = bool(UserSettings.get_value(section, key, false))
	check.toggled.connect(func(value: bool) -> void:
		UserSettings.set_value(section, key, value)
		if key == "high_contrast":
			refresh_theme()
	)
	return check


func _show_tab(index: int) -> void:
	if _pages.is_empty():
		return
	_active_tab = wrapi(index, 0, _pages.size())
	for page_index in range(_pages.size()):
		_pages[page_index].visible = page_index == _active_tab
		_tab_buttons[page_index].button_pressed = page_index == _active_tab


func _begin_remap(action: StringName) -> void:
	_waiting_action = action
	_status.text = "请按下“%s”的新按键…" % InputManager.get_action_display_name(action)
	_binding_buttons[action].text = "等待输入…"


func _confirm_reset() -> void:
	UIManager.show_confirmation({
		"title": "ui.settings.reset_title",
		"message": "ui.settings.reset_message",
		"danger": true,
		"on_confirm": _reset_settings,
	})


func _reset_settings() -> void:
	UserSettings.reset_defaults()
	_status.text = "设置已恢复默认；重新打开此页面可查看全部默认值。"
	refresh_theme()


func _save_and_close() -> void:
	UserSettings.set_value("input", "bindings", InputManager.serialize_bindings(), false)
	UserSettings.save()
	UIManager.show_toast("ui.settings.saved", {}, "success")
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			_finish_remap(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			_finish_remap(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_finish_remap(event)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_left"):
		_show_tab(_active_tab - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_right"):
		_show_tab(_active_tab + 1)
		get_viewport().set_input_as_handled()


func _finish_remap(event: InputEvent) -> void:
	var action := _waiting_action
	_waiting_action = &""
	if InputManager.remap_action(action, event):
		_binding_buttons[action].text = InputManager.get_action_prompt(action)
		_status.text = "已更新“%s”" % InputManager.get_action_display_name(action)
	else:
		var conflict := InputManager.find_binding_conflict(action, event)
		_binding_buttons[action].text = InputManager.get_action_prompt(action)
		_status.text = "按键冲突：已用于“%s”" % InputManager.get_action_display_name(conflict)
