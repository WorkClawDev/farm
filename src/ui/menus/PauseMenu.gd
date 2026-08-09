extends Control
class_name PauseMenu

signal resume_requested
signal save_requested
signal load_requested
signal quit_to_menu_requested
signal quit_game_requested

var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIFactory.paper_panel(Vector2(430, 0))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	content.add_child(UIFactory.title(UIStyles.tr_key("ui.pause.title", "农场小憩"), HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(UIFactory.subtitle("时间在门外等候，慢慢来。", HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(HSeparator.new())

	_resume_button = _add_button(content, "ui.pause.resume", "继续", &"PrimaryButton", _resume)
	_add_button(content, "ui.pause.save", "保存", &"", _open_save)
	_add_button(content, "ui.pause.load", "读取", &"", _open_load)
	_add_button(content, "ui.pause.settings", "设置", &"", _open_settings)
	content.add_child(HSeparator.new())
	_add_button(content, "ui.pause.menu", "返回主菜单", &"", _confirm_menu)
	_add_button(content, "ui.pause.quit", "退出游戏", &"DangerButton", _confirm_quit)


func _add_button(parent: VBoxContainer, key: String, fallback: String, variation: StringName, callback: Callable) -> Button:
	var button := UIFactory.button(UIStyles.tr_key(key, fallback), variation, Vector2(0, 48))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _resume() -> void:
	resume_requested.emit()


func _open_save() -> void:
	save_requested.emit()
	await UIManager.open_screen("save_load", {
		"pause_game": false,
		"mode": SaveLoadMenu.Mode.SAVE,
	})


func _open_load() -> void:
	load_requested.emit()
	await UIManager.open_screen("save_load", {
		"pause_game": false,
		"mode": SaveLoadMenu.Mode.LOAD,
	})


func _open_settings() -> void:
	await UIManager.open_screen("settings", {"pause_game": false})


func _confirm_menu() -> void:
	UIManager.show_confirmation({
		"title": "ui.pause.menu",
		"message": "ui.pause.menu_confirm",
		"danger": true,
		"on_confirm": _return_to_menu,
	})


func _return_to_menu() -> void:
	UIManager.close_all()
	quit_to_menu_requested.emit()


func _confirm_quit() -> void:
	UIManager.show_confirmation({
		"title": "ui.pause.quit",
		"message": "ui.pause.quit_confirm",
		"danger": true,
		"on_confirm": quit_game_requested.emit,
	})


func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		await get_tree().process_frame
		_resume_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
