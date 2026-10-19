extends Node

signal screen_opened(screen_id: String, screen: Control)
signal screen_closed(screen_id: String)
signal modal_stack_changed(depth: int)

const SCREEN_PATHS := {
	"journal": "res://src/ui/menus/FarmJournal.tscn",
	"inventory": "res://src/ui/menus/FarmJournal.tscn",
	"pause": "res://src/ui/menus/PauseMenu.tscn",
	"settings": "res://src/ui/menus/SettingsUI.tscn",
	"save_load": "res://src/ui/menus/SaveLoadMenu.tscn",
	"shop": "res://src/ui/menus/ShopUI.tscn",
	"cooking": "res://src/ui/menus/CookingUI.tscn",
	"shipping_bin": "res://src/ui/menus/ShippingBinUI.tscn",
}

var _overlay_layer: CanvasLayer
var _screen_root: Control
var _toast_root: VBoxContainer
var _stack: Array[Dictionary] = []
var _confirmation: Control
var _confirmation_owns_pause := false
var _pause_owned := false

const MAX_VISIBLE_TOASTS := 4
const TOAST_DURATION := 3.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	get_tree().root.window_input.connect(_on_root_window_input)


## Godot's GUI treats Esc as "hide the tooltip" and marks the event handled while a
## tooltip popup exists, so with the mouse resting on a slot the first Esc only hid the
## tooltip and the journal/pause menu needed a second press. Free the tooltip before
## the GUI sees the key (freeing clears the viewport's tooltip pointer) so one Esc does both.
func _on_root_window_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not (event.is_action("ui_cancel") or event.is_action("pause")):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return
	for child in hovered.get_children(true):
		if child is Popup:
			child.free()


func open_screen(screen_id: String, context := {}) -> Control:
	if is_screen_open(screen_id):
		var existing := _find_entry(screen_id)
		var existing_node := existing.get("node") as Control
		if is_instance_valid(existing_node) and existing_node.has_method("configure"):
			existing_node.configure(context)
		return existing_node
	var path := str(context.get("scene_path", SCREEN_PATHS.get(screen_id, "")))
	if path.is_empty() or not ResourceLoader.exists(path):
		show_toast("ui.error.screen_missing", {"screen": screen_id}, "error")
		return null

	if not bool(context.get("allow_multiple_main", false)) and not _stack.is_empty():
		close_all()

	var scene := load(path) as PackedScene
	if scene == null:
		show_toast("ui.error.screen_missing", {"screen": screen_id}, "error")
		return null
	var instance := scene.instantiate() as Control
	if instance == null:
		return null
	instance.process_mode = Node.PROCESS_MODE_ALWAYS
	instance.set_meta("ui_screen_id", screen_id)
	instance.add_to_group("themed_ui_root")
	instance.theme = UIStyles.active_theme()
	_screen_root.add_child(instance)

	var previous_focus := get_viewport().gui_get_focus_owner()
	_stack.append({
		"id": screen_id,
		"node": instance,
		"focus": previous_focus,
		"pause": bool(context.get("pause_game", true)),
	})
	if bool(context.get("pause_game", true)):
		_acquire_pause()
	_connect_close_signal(instance)
	if instance.has_method("configure"):
		instance.configure(context)
	elif screen_id == "inventory" and instance.has_method("open_tab"):
		instance.open_tab("inventory")
	await get_tree().process_frame
	UIFactory.focus_first(instance)
	screen_opened.emit(screen_id, instance)
	modal_stack_changed.emit(_stack.size())
	return instance


func close_top_screen() -> void:
	if _confirmation:
		_close_confirmation()
		return
	if _stack.is_empty():
		return
	var entry: Dictionary = _stack.pop_back()
	var node := entry.get("node") as Control
	var previous_focus := entry.get("focus") as Control
	if is_instance_valid(node):
		node.queue_free()
	screen_closed.emit(str(entry.get("id", "")))
	modal_stack_changed.emit(_stack.size())
	if _stack.is_empty():
		_release_pause()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
	else:
		var top_node := _stack.back().get("node") as Control
		if is_instance_valid(top_node):
			UIFactory.focus_first(top_node)


func close_all() -> void:
	_close_confirmation()
	while not _stack.is_empty():
		var entry: Dictionary = _stack.pop_back()
		var node := entry.get("node") as Control
		if is_instance_valid(node):
			node.queue_free()
		screen_closed.emit(str(entry.get("id", "")))
	_release_pause()
	modal_stack_changed.emit(0)


func show_toast(message_key: String, args := {}, variant := "info") -> void:
	if _toast_root == null:
		return
	var text := _format_message(message_key, args)
	# BUG-10: merge identical live toasts instead of stacking duplicates.
	for child in _toast_root.get_children():
		if child.is_queued_for_deletion() or bool(child.get_meta("toast_dismissing", false)):
			continue
		if str(child.get_meta("toast_text", "")) == text and str(child.get_meta("toast_variant", "")) == variant:
			var count := int(child.get_meta("toast_count", 1)) + 1
			child.set_meta("toast_count", count)
			var existing_label := child.get_meta("toast_label") as Label
			if is_instance_valid(existing_label):
				existing_label.text = UIFactory.no_orphan("%s ×%d" % [text, count])
			child.modulate.a = 1.0
			_schedule_toast_dismiss(child)
			return
	# BUG-10: cap visible toasts, dropping the oldest.
	var live: Array[Node] = []
	for child in _toast_root.get_children():
		if not child.is_queued_for_deletion():
			live.append(child)
	while live.size() >= MAX_VISIBLE_TOASTS:
		var oldest: Node = live.pop_front()
		_toast_root.remove_child(oldest)
		oldest.queue_free()
	var panel := UIFactory.hud_panel()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var marker := Label.new()
	marker.theme_type_variation = &"HUDText"
	marker.text = {"info": "●", "success": "✓", "warning": "!", "error": "×"}.get(variant, "●")
	marker.modulate = {
		"success": Color("#92C96C"),
		"warning": Color("#F2C14E"),
		"error": Color("#F0806A"),
	}.get(variant, Color("#86C7E5"))
	row.add_child(marker)
	var label := Label.new()
	label.theme_type_variation = &"HUDText"
	label.text = UIFactory.no_orphan(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # use the whole toast width before wrapping
	row.add_child(label)
	panel.set_meta("toast_text", text)
	panel.set_meta("toast_variant", variant)
	panel.set_meta("toast_count", 1)
	panel.set_meta("toast_label", label)
	_toast_root.add_child(panel)

	var reduce_motion: bool = bool(UserSettings.get_value("accessibility", "reduce_motion", false))
	if reduce_motion:
		panel.modulate.a = 1.0
	else:
		var intro := panel.create_tween()
		intro.tween_property(panel, "modulate:a", 1.0, 0.12)
	_schedule_toast_dismiss(panel)


func get_visible_toast_count() -> int:
	if _toast_root == null:
		return 0
	var n := 0
	for child in _toast_root.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n


func _schedule_toast_dismiss(panel: Control) -> void:
	var gen := int(panel.get_meta("toast_gen", 0)) + 1
	panel.set_meta("toast_gen", gen)
	var reduce_motion: bool = bool(UserSettings.get_value("accessibility", "reduce_motion", false))
	var timer := get_tree().create_timer(TOAST_DURATION, true, false, true)
	timer.timeout.connect(_on_toast_timeout.bind(panel, gen, reduce_motion))


func _on_toast_timeout(panel: Variant, gen: int, reduce_motion: bool) -> void:
	# panel 不能写成 Control 类型：被挤掉（BUG-10 上限）的旧 Toast 已经释放，计时器到点时
	# 绑定参数是个已释放的对象，带类型的参数会在进函数前报 "Cannot convert argument 1"。
	if not is_instance_valid(panel) or int((panel as Control).get_meta("toast_gen", 0)) != gen:
		return
	_dismiss_toast(panel as Control, reduce_motion)


func show_confirmation(config: Dictionary) -> Control:
	_close_confirmation()
	_confirmation_owns_pause = _stack.is_empty() and not _pause_owned
	if _confirmation_owns_pause:
		_acquire_pause()
	var shade := ColorRect.new()
	shade.name = "ConfirmationOverlay"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.process_mode = Node.PROCESS_MODE_ALWAYS
	shade.theme = UIStyles.active_theme()
	_screen_root.add_child(shade)
	_confirmation = shade
	shade.set_meta("confirm_config", config)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(500, 0))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(content)
	content.add_child(UIFactory.title(_format_message(str(config.get("title", "ui.confirm.title")), config.get("args", {})), HORIZONTAL_ALIGNMENT_CENTER))
	var body := Label.new()
	body.text = _format_message(str(config.get("message", "ui.confirm.message")), config.get("args", {}))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	content.add_child(buttons)
	var cancel := UIFactory.button(
		UIStyles.tr_key(str(config.get("cancel_key", "ui.common.cancel")), "取消")
	)
	var confirm := UIFactory.button(
		UIStyles.tr_key(str(config.get("confirm_key", "ui.common.confirm")), "确认"),
		&"DangerButton" if bool(config.get("danger", false)) else &"PrimaryButton"
	)
	buttons.add_child(cancel)
	buttons.add_child(confirm)
	cancel.pressed.connect(_on_confirmation_result.bind(false, config))
	confirm.pressed.connect(_on_confirmation_result.bind(true, config))
	cancel.grab_focus()
	return shade


## True while a UIManager screen (save/load, settings, journal...) or a
## confirmation dialog is on top. Scene-level Esc handlers (Farm, PauseMenu)
## must yield to it: they run before this autoload in _unhandled_input order,
## so without this check they would swallow the Esc meant for the sub-screen.
func has_open_modal() -> bool:
	if is_instance_valid(_confirmation):
		return true
	for entry in _stack:
		if is_instance_valid(entry.get("node")):
			return true
	return false


## True while a confirmation dialog is open. It is the topmost layer, so screens
## (save/load, settings) must leave Esc to it: being children of the overlay they
## see _unhandled_input before this autoload and would otherwise close themselves
## underneath the dialog (BUG-19).
func has_open_confirmation() -> bool:
	return is_instance_valid(_confirmation)


func is_screen_open(screen_id: String) -> bool:
	return not _find_entry(screen_id).is_empty()


func get_screen(screen_id: String) -> Control:
	return _find_entry(screen_id).get("node") as Control


func _unhandled_input(event: InputEvent) -> void:
	# Esc on a confirmation dialog means "cancel" (screens handle their own Esc).
	if is_instance_valid(_confirmation) and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		var config: Dictionary = _confirmation.get_meta("confirm_config", {})
		_on_confirmation_result(false, config)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "UIOverlay"
	_overlay_layer.layer = 90
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	_screen_root = Control.new()
	_screen_root.name = "ScreenRoot"
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_screen_root)
	_toast_root = VBoxContainer.new()
	_toast_root.name = "ToastRoot"
	# Top-center, clear of the top-left quest panel, the top-right date/gold
	# panel and the bottom hotbar/tool display (BUG-4). Width stays 356px as before.
	_toast_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_root.offset_left = -178
	_toast_root.offset_top = 32
	_toast_root.offset_right = 178
	_toast_root.offset_bottom = 400
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_root.add_theme_constant_override("separation", 10)
	UIStyles.follow_theme(_toast_root)
	_overlay_layer.add_child(_toast_root)


func _connect_close_signal(screen: Control) -> void:
	for signal_name in ["menu_closed", "settings_closed", "inventory_closed", "shipping_closed", "shop_closed", "cooking_ui_closed"]:
		if screen.has_signal(signal_name):
			var callable := _on_screen_requested_close.bind(screen)
			if not screen.is_connected(signal_name, callable):
				screen.connect(signal_name, callable)
			return


func _on_screen_requested_close(screen: Control) -> void:
	if _stack.is_empty() or _stack.back().get("node") != screen:
		return
	var entry: Dictionary = _stack.pop_back()
	var previous_focus := entry.get("focus") as Control
	if is_instance_valid(screen) and not screen.is_queued_for_deletion():
		screen.queue_free()
	screen_closed.emit(str(entry.get("id", "")))
	if _stack.is_empty():
		_release_pause()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
	else:
		var top_node := _stack.back().get("node") as Control
		if is_instance_valid(top_node):
			UIFactory.focus_first(top_node)
	modal_stack_changed.emit(_stack.size())


func _find_entry(screen_id: String) -> Dictionary:
	for entry in _stack:
		if str(entry.get("id", "")) == screen_id and is_instance_valid(entry.get("node")):
			return entry
	return {}


func _acquire_pause() -> void:
	if _pause_owned:
		return
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.pause_game()
		_pause_owned = true


func _release_pause() -> void:
	if _pause_owned and GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.resume_game()
	_pause_owned = false


func _on_confirmation_result(confirmed: bool, config: Dictionary) -> void:
	var callback: Variant = config.get("on_confirm" if confirmed else "on_cancel")
	_close_confirmation()
	if callback is Callable and callback.is_valid():
		callback.call()


func _close_confirmation() -> void:
	if is_instance_valid(_confirmation):
		_confirmation.queue_free()
	_confirmation = null
	if _confirmation_owns_pause and _stack.is_empty():
		_release_pause()
	_confirmation_owns_pause = false


func _dismiss_toast(panel: Control, reduce_motion: bool) -> void:
	if not is_instance_valid(panel):
		return
	panel.set_meta("toast_dismissing", true)
	if reduce_motion:
		panel.queue_free()
		return
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.16)
	tween.finished.connect(panel.queue_free)


func _format_message(key: String, args: Dictionary) -> String:
	var text := UIStyles.tr_key(key, key)
	for name in args:
		text = text.replace("{%s}" % name, str(args[name]))
	return text
