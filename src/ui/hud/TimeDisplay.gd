extends Control
class_name TimeDisplay

## TimeDisplay - 时间显示UI组件
## 显示当前游戏时间和日期

@onready var time_label: Label = $TimeLabel
@onready var date_label: Label = $DateLabel

func _ready() -> void:
	_connect_signals()
	_update_display()

func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.time_changed.connect(_on_time_changed)
		time_manager.day_changed.connect(_on_day_changed)
		time_manager.season_changed.connect(_on_season_changed)
		time_manager.year_changed.connect(_on_year_changed)

func _on_time_changed(_new_time: float) -> void:
	_update_time_display()

func _on_day_changed(_new_day: int) -> void:
	_update_date_display()

func _on_season_changed(_new_season: int, _season_name: String) -> void:
	_update_date_display()

func _on_year_changed(_new_year: int) -> void:
	_update_date_display()

func _update_display() -> void:
	_update_time_display()
	_update_date_display()

func _update_time_display() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_label and time_manager:
		time_label.text = time_manager.get_formatted_time()

func _update_date_display() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if date_label and time_manager:
		date_label.text = time_manager.get_formatted_date()
