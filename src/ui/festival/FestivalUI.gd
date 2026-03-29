extends Control
class_name FestivalUI

signal closed
signal activity_selected(activity_id: String)
signal reward_claimed(reward_id: String)

@onready var title_label: Label = $PanelContainer/VBoxContainer/Header/TitleLabel
@onready var description_label: Label = $PanelContainer/VBoxContainer/Header/DescriptionLabel
@onready var time_label: Label = $PanelContainer/VBoxContainer/Header/TimeLabel
@onready var progress_bar: ProgressBar = $PanelContainer/VBoxContainer/ProgressBox/ProgressBar
@onready var progress_label: Label = $PanelContainer/VBoxContainer/ProgressBox/ProgressLabel
@onready var activities_container: VBoxContainer = $PanelContainer/VBoxContainer/ActivitiesBox/ScrollContainer/ActivitiesList
@onready var rewards_container: VBoxContainer = $PanelContainer/VBoxContainer/RewardsBox/RewardsList
@onready var close_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var shop_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/ShopButton

var current_festival_id := ""
var festival_data: Dictionary = {}

func _ready() -> void:
	visible = false
	_connect_signals()
	_setup_buttons()

func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null:
		return

	if event_bus.has_signal("festival_started"):
		event_bus.festival_started.connect(_on_festival_started)
	if event_bus.has_signal("festival_ended"):
		event_bus.festival_ended.connect(_on_festival_ended)
	if event_bus.has_signal("festival_activity_completed"):
		event_bus.festival_activity_completed.connect(_on_activity_completed)
	if event_bus.has_signal("festival_reward_claimed"):
		event_bus.festival_reward_claimed.connect(_on_reward_claimed)

func _setup_buttons() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)

func open_festival(festival_id: String) -> void:
	current_festival_id = festival_id
	festival_data = FestivalSystem.get_festival_data(festival_id)
	if festival_data.is_empty():
		push_warning("[FestivalUI] Festival not found: " + festival_id)
		return

	_update_display()
	visible = true

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("ui_opened"):
		event_bus.ui_opened.emit("festival_ui")

func close() -> void:
	visible = false
	current_festival_id = ""
	festival_data = {}

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("ui_closed"):
		event_bus.ui_closed.emit("festival_ui")

	closed.emit()

func _update_display() -> void:
	if festival_data.is_empty():
		return

	title_label.text = festival_data.get("name", "Unknown Festival")
	description_label.text = festival_data.get("description", "")

	var start_hour: int = festival_data.get("start_hour", 10)
	var end_hour: int = festival_data.get("end_hour", 22)
	time_label.text = "Hours: %02d:00 - %02d:00" % [start_hour, end_hour]

	_update_progress()
	_update_activities()
	_update_rewards()

	if shop_button:
		var vendors: Array = festival_data.get("vendors", [])
		shop_button.visible = not vendors.is_empty()

func _update_progress() -> void:
	var progress: Dictionary = FestivalSystem.get_festival_progress(current_festival_id)
	var total: int = max(progress.get("total_activities", 0), 1)
	var completed: int = progress.get("completed_activities", 0)
	progress_bar.max_value = total
	progress_bar.value = completed
	progress_label.text = "Progress: %d/%d" % [completed, total]

func _update_activities() -> void:
	for child in activities_container.get_children():
		child.queue_free()

	for activity in FestivalSystem.get_available_activities(current_festival_id):
		_create_activity_button(activity)

func _create_activity_button(activity: Dictionary) -> void:
	var button := Button.new()
	button.text = activity.get("name", "Unknown Activity")
	if activity.get("completed", false):
		button.text += " [Done]"
		button.disabled = true
		button.modulate = Color(0.7, 0.7, 0.7)

	button.tooltip_text = activity.get("description", "")
	var activity_id: String = activity.get("id", "")
	button.pressed.connect(_on_activity_button_pressed.bind(activity_id, activity))
	activities_container.add_child(button)

func _update_rewards() -> void:
	for child in rewards_container.get_children():
		child.queue_free()

	var rewards: Array = festival_data.get("rewards", [])
	for reward in rewards:
		_create_reward_button(reward)

func _create_reward_button(reward: Dictionary) -> void:
	var button := Button.new()
	button.text = reward.get("name", "Unknown Reward")
	button.tooltip_text = reward.get("description", "")

	var reward_id: String = reward.get("id", "")
	var requirements: Dictionary = reward.get("requirements", {})
	var required_activities: int = requirements.get("activities_completed", 0)
	var progress: Dictionary = FestivalSystem.get_festival_progress(current_festival_id)
	var completed: int = progress.get("completed_activities", 0)

	if completed < required_activities:
		button.disabled = true
		button.text += " (Need %d activities)" % required_activities
	else:
		button.text += " [Claim]"

	button.pressed.connect(_on_reward_button_pressed.bind(reward_id))
	rewards_container.add_child(button)

func _on_festival_started(festival_id: String, _data: Dictionary) -> void:
	if visible and festival_id == current_festival_id:
		_update_display()

func _on_festival_ended(festival_id: String, _data: Dictionary) -> void:
	if visible and festival_id == current_festival_id:
		close()

func _on_activity_completed(festival_id: String, _activity_id: String, _rewards: Dictionary) -> void:
	if festival_id == current_festival_id:
		festival_data = FestivalSystem.get_festival_data(current_festival_id)
		_update_display()

func _on_reward_claimed(festival_id: String, _reward_id: String) -> void:
	if festival_id == current_festival_id:
		festival_data = FestivalSystem.get_festival_data(current_festival_id)
		_update_display()

func _on_activity_button_pressed(activity_id: String, activity: Dictionary) -> void:
	activity_selected.emit(activity_id)
	var minigame_id: String = activity.get("minigame", "")
	if not minigame_id.is_empty():
		_start_minigame(minigame_id, activity_id)
		return

	var result: Dictionary = FestivalSystem.complete_festival_activity(current_festival_id, activity_id)
	if result.get("success", false):
		_show_result_dialog("Activity completed", result.get("rewards", {}))
	else:
		_show_error_dialog(result.get("message", "Could not complete activity."))

func _start_minigame(_minigame_id: String, activity_id: String) -> void:
	var result: Dictionary = FestivalSystem.complete_festival_activity(current_festival_id, activity_id)
	if result.get("success", false):
		_show_result_dialog("Activity completed", result.get("rewards", {}))
	else:
		_show_error_dialog(result.get("message", "Could not complete activity."))

func _on_reward_button_pressed(reward_id: String) -> void:
	var result: Dictionary = FestivalSystem.claim_festival_reward(current_festival_id, reward_id)
	if result.get("success", false):
		reward_claimed.emit(reward_id)
		_show_result_dialog("Reward claimed", result.get("items", {}))
	else:
		_show_error_dialog(result.get("message", "Could not claim reward."))

func _show_result_dialog(title: String, rewards: Dictionary) -> void:
	var lines: Array[String] = []
	if rewards.has("money"):
		lines.append("Money: %s" % rewards["money"])
	if rewards.has("items"):
		var items: Dictionary = rewards["items"]
		for item_id in items.keys():
			lines.append("%s x%s" % [item_id, items[item_id]])

	var reward_text := "No items" if lines.is_empty() else "\n".join(lines)
	var dialog := AcceptDialog.new()
	dialog.window_title = "Festival"
	dialog.dialog_text = "%s\n\n%s" % [title, reward_text]
	dialog.ok_button_text = "OK"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _show_error_dialog(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.window_title = "Festival"
	dialog.dialog_text = message
	dialog.ok_button_text = "OK"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _on_dialog_confirmed(dialog: AcceptDialog) -> void:
	dialog.queue_free()

func _on_close_pressed() -> void:
	close()

func _on_shop_pressed() -> void:
	var vendors: Array = festival_data.get("vendors", [])
	if vendors.is_empty():
		return

	var shop_id: String = vendors[0].get("id", "")
	var event_bus = get_node_or_null("/root/EventBus")
	if not shop_id.is_empty() and event_bus and event_bus.has_signal("shop_opened"):
		event_bus.shop_opened.emit(shop_id)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
