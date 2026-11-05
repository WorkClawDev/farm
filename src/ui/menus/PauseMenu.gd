extends Control
class_name PauseMenu

signal resume_requested
signal save_requested
signal load_requested
signal quit_to_menu_requested
signal quit_game_requested

var _resume_button: Button
var _menu_buttons: Array[Button] = []


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
	_wire_menu_focus()


func _add_button(parent: VBoxContainer, key: String, fallback: String, variation: StringName, callback: Callable) -> Button:
	var button := UIFactory.button(UIStyles.tr_key(key, fallback), variation, Vector2(0, 48))
	# Keep the variation chosen here. Without this UIThemeBridge sees "保存" in the
	# text and turns it into a second green PrimaryButton next to "继续".
	button.set_meta("preserve_theme_overrides", true)
	button.pressed.connect(callback)
	parent.add_child(button)
	_menu_buttons.append(button)
	_install_visible_focus(button)
	return button


## PrimaryButton's inherited focus ring is the same green as 继续, so the
## first row looked unfocused and arrow-key moves were easy to miss.
func _install_visible_focus(button: Button) -> void:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.73, 0.9, 0.55, 1)
	focus.border_color = Color(1.0, 0.86, 0.28, 1)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(6)
	focus.content_margin_left = 14.0
	focus.content_margin_top = 8.0
	focus.content_margin_right = 14.0
	focus.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("focus", focus)
	button.focus_mode = Control.FOCUS_ALL
	button.focus_entered.connect(_paint_menu_focus)
	button.focus_exited.connect(_paint_menu_focus)


func _paint_menu_focus(_arg: Variant = null) -> void:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for button in _menu_buttons:
		if not is_instance_valid(button):
			continue
		button.modulate = Color(1.12, 1.2, 0.9) if button == owner else Color.WHITE


## Explicit chain so a direction key cannot land on a hotbar slot or a zero-rect
## neighbor. Left/right stay on the same row; the list does not wrap.
func _wire_menu_focus() -> void:
	var count := _menu_buttons.size()
	for i in count:
		var button := _menu_buttons[i]
		button.focus_mode = Control.FOCUS_ALL
		var previous: Button = _menu_buttons[i - 1] if i > 0 else button
		var next: Button = _menu_buttons[i + 1] if i + 1 < count else button
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(button)


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
	# Input is flushed before process_frame. Waiting a frame to grab focus
	# drops every ui_down already queued in that frame (a hitch batches several),
	# then snaps the highlight back to 继续.
	# visibility_changed runs before children report is_visible_in_tree.
	# grab_focus does not need that flag; a later deferred grab would
	# race the first direction key and snap back to 继续.
	if visible and is_inside_tree():
		_focus_resume()


func _focus_resume() -> void:
	if _resume_button == null or not is_instance_valid(_resume_button):
		return
	if not _resume_button.is_inside_tree():
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and owner != _resume_button and is_ancestor_of(owner):
		return
	if _resume_button.focus_mode == Control.FOCUS_NONE:
		_resume_button.focus_mode = Control.FOCUS_ALL
	_resume_button.grab_focus()
	_paint_menu_focus()


## Arrow keys are also move_*. Handle them before the viewport's spatial search
## so the first press moves even when the button rects are still zero.
func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree() or UIManager.has_open_modal():
		return
	if event is InputEventJoypadMotion:
		return
	var down := event.is_action_pressed("ui_down", true)
	var up := event.is_action_pressed("ui_up", true)
	var lateral := event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")
	if down:
		_move_menu_focus(1)
	elif up:
		_move_menu_focus(-1)
	elif lateral:
		_ensure_menu_focus()
	elif not (event.is_action("ui_down") or event.is_action("ui_up") or event.is_action("ui_left") or event.is_action("ui_right")):
		return
	get_viewport().set_input_as_handled()


func _move_menu_focus(delta: int) -> void:
	if _menu_buttons.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := _menu_buttons.find(current)
	# No menu focus yet: treat 继续 as the start, then apply this key.
	if index < 0:
		index = 0
	index = clampi(index + delta, 0, _menu_buttons.size() - 1)
	var target := _menu_buttons[index]
	if target != current:
		target.grab_focus()
	_paint_menu_focus()


func _ensure_menu_focus() -> void:
	var current := get_viewport().gui_get_focus_owner()
	if current != null and _menu_buttons.find(current) >= 0:
		return
	_focus_resume()


func _unhandled_input(event: InputEvent) -> void:
	# A sub-screen opened from here (save/load, settings) or a confirmation is
	# on top: let its own handler take the Esc instead of closing the pause menu.
	if UIManager.has_open_modal():
		return
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
