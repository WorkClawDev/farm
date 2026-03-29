extends Control
class_name SaveLoadMenu

signal save_completed(slot: int)
signal load_completed(slot: int)
signal menu_closed

enum Mode {
	SAVE,
	LOAD,
}

@export var mode: Mode = Mode.SAVE

const SLOT_COUNT: int = 3

var slot_container: VBoxContainer
var button_container: HBoxContainer
var close_button: Button
var title_label: Label
var slot_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []

func _ready() -> void:
	_setup_ui()
	_refresh_slots()

func _setup_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(main_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	main_vbox.add_child(title_label)
	_update_title()

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)

	slot_container = VBoxContainer.new()
	slot_container.name = "SlotContainer"
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(slot_container)

	for i in range(SLOT_COUNT):
		var slot_hbox := HBoxContainer.new()
		slot_hbox.name = "SlotHBox%d" % i
		slot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var slot_button := Button.new()
		slot_button.name = "SlotButton%d" % i
		slot_button.custom_minimum_size = Vector2(400, 80)
		slot_button.pressed.connect(_on_slot_pressed.bind(i))
		slot_hbox.add_child(slot_button)
		slot_buttons.append(slot_button)

		var delete_button := Button.new()
		delete_button.name = "DeleteButton%d" % i
		delete_button.text = "X"
		delete_button.custom_minimum_size = Vector2(40, 80)
		delete_button.pressed.connect(_on_delete_pressed.bind(i))
		slot_hbox.add_child(delete_button)
		delete_buttons.append(delete_button)

		slot_container.add_child(slot_hbox)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer2)

	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_container)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(close_button)

	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -250
	offset_right = 250
	offset_top = -200
	offset_bottom = 200

func _update_title() -> void:
	title_label.text = "Save Game" if mode == Mode.SAVE else "Load Game"

func _refresh_slots() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	for i in range(SLOT_COUNT):
		var info: Dictionary = save_manager.get_save_info(i) if save_manager else {}
		var button: Button = slot_buttons[i]
		var delete_button: Button = delete_buttons[i]

		if info.get("exists", false):
			var play_time: float = info.get("play_time", 0.0)
			var hours: int = int(play_time) / 3600
			var minutes: int = (int(play_time) % 3600) / 60
			var time_str: String = "%02d:%02d" % [hours, minutes]
			button.text = "Slot %d\n%s\nPlay Time: %s" % [i + 1, info.get("date", "Unknown"), time_str]
			button.disabled = mode == Mode.LOAD and save_manager != null and not save_manager.has_save(i)
			delete_button.disabled = false
			delete_button.visible = true
		else:
			button.text = "Slot %d\n- Empty -" % (i + 1)
			button.disabled = mode == Mode.LOAD
			delete_button.disabled = true
			delete_button.visible = false

func _on_slot_pressed(slot: int) -> void:
	if mode == Mode.SAVE:
		_save_game(slot)
	else:
		_load_game(slot)

func _save_game(slot: int) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	var success: bool = save_manager.save_game(slot) if save_manager else false
	if success:
		save_completed.emit(slot)
		_refresh_slots()
		_show_message("Saved to slot %d." % (slot + 1))
	else:
		_show_message("Save failed.")

func _load_game(slot: int) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	var success: bool = save_manager.load_game(slot) if save_manager else false
	if success:
		load_completed.emit(slot)
		_show_message("Loaded slot %d." % (slot + 1))
		await get_tree().create_timer(0.5).timeout
		close()
	else:
		_show_message("Load failed.")

func _on_delete_pressed(slot: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Delete save slot %d?" % (slot + 1)
	dialog.title = "Delete Save"
	dialog.confirmed.connect(_confirm_delete.bind(slot))
	add_child(dialog)
	dialog.popup_centered()

func _confirm_delete(slot: int) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager:
		save_manager.delete_save(slot)
	_refresh_slots()
	_show_message("Slot %d deleted." % (slot + 1))

func _on_close_pressed() -> void:
	close()

func close() -> void:
	menu_closed.emit()
	queue_free()

func _show_message(message: String) -> void:
	print("[SaveLoadMenu] ", message)

func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if title_label:
		_update_title()
		_refresh_slots()
