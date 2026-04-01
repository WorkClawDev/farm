extends CanvasLayer
class_name FestivalNotification

var _notification_queue: Array[Dictionary] = []
var _is_showing := false
var _current_notification: Control = null

const NOTIFICATION_DURATION: float = 5.0

func _ready() -> void:
	_connect_signals()
	print("[FestivalNotification] Initialized")

func _connect_signals() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null or event_bus.festival == null:
		return

	event_bus.festival.festival_started.connect(_on_festival_started)
	event_bus.festival.festival_ended.connect(_on_festival_ended)
	event_bus.festival.festival_upcoming.connect(_on_festival_upcoming)

func show_notification(festival_id: String, notification_type: String, days_until: int = 0) -> void:
	var festival_data: Dictionary = FestivalSystem.get_festival_data(festival_id)
	if festival_data.is_empty():
		return

	_notification_queue.append({
		"festival_name": festival_data.get("name", "Unknown Festival"),
		"description": _get_notification_description(notification_type, days_until),
	})

	if not _is_showing:
		_show_next_notification()

func _get_notification_description(notification_type: String, days_until: int) -> String:
	match notification_type:
		"started":
			return "The festival has started."
		"ended":
			return "The festival has ended."
		"upcoming":
			return "Festival starts tomorrow." if days_until == 1 else "Festival starts in %d days." % days_until
		_:
			return ""

func _show_next_notification() -> void:
	if _notification_queue.is_empty():
		_is_showing = false
		return

	_is_showing = true
	_create_notification_popup(_notification_queue.pop_front())

func _create_notification_popup(data: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(0, 100)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = data.get("festival_name", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = data.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	current_scene.add_child(panel)
	_current_notification = panel
	panel.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

	get_tree().create_timer(NOTIFICATION_DURATION).timeout.connect(func(): _close_notification(panel))

func _close_notification(panel: Control) -> void:
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		_current_notification = null
		_show_next_notification()
	)

func _on_festival_started(festival_id: String, _data: Dictionary) -> void:
	show_notification(festival_id, "started")

func _on_festival_ended(festival_id: String, _data: Dictionary) -> void:
	show_notification(festival_id, "ended")

func _on_festival_upcoming(festival_id: String, days_until: int) -> void:
	show_notification(festival_id, "upcoming", days_until)
