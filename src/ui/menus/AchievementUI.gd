extends Control
class_name AchievementUI

## AchievementUI - 成就界面
## 显示所有成就和解锁状态

@onready var achievement_list: ItemList = $Panel/AchievementList
@onready var achievement_name: Label = $Panel/Details/NameLabel
@onready var achievement_desc: Label = $Panel/Details/DescLabel
@onready var progress_bar: ProgressBar = $Panel/Details/ProgressBar
@onready var progress_label: Label = $Panel/Details/ProgressLabel
@onready var status_label: Label = $Panel/Details/StatusLabel
@onready var close_button: Button = $Panel/CloseButton

var selected_achievement: Dictionary = {}

func _ready() -> void:
	_setup_signals()
	_populate_achievements()

func _setup_signals() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if achievement_list:
		achievement_list.item_selected.connect(_on_achievement_selected)

func _populate_achievements() -> void:
	if not achievement_list:
		return
	
	achievement_list.clear()
	
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	if not achievement_system:
		return
	
	for achievement_id in achievement_system.get_all_achievements().keys():
		var data = achievement_system.get_all_achievements()[achievement_id]
		var is_unlocked = achievement_system.is_achievement_unlocked(achievement_id)
		var prefix = "✓ " if is_unlocked else "○ "
		var display_text = prefix + data.get("name", achievement_id)
		achievement_list.add_item(display_text)
		
		# 设置颜色
		var idx = achievement_list.item_count - 1
		if is_unlocked:
			achievement_list.set_item_custom_fg_color(idx, Color.GREEN)
		else:
			achievement_list.set_item_custom_fg_color(idx, Color.GRAY)

func _on_achievement_selected(index: int) -> void:
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	if not achievement_system:
		return
	
	var achievement_ids = achievement_system.get_all_achievements().keys()
	if index >= 0 and index < achievement_ids.size():
		selected_achievement = achievement_system.get_all_achievements()[achievement_ids[index]]
		_update_details()

func _update_details() -> void:
	if selected_achievement.is_empty():
		return
	
	if achievement_name:
		achievement_name.text = selected_achievement.get("name", "")
	
	if achievement_desc:
		achievement_desc.text = selected_achievement.get("description", "")
	
	# 更新进度
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	if achievement_system and achievement_system.has_method("get_achievement_progress"):
		var progress = achievement_system.get_achievement_progress(selected_achievement.get("id", ""))
		if progress.has("current"):
			if progress_bar:
				progress_bar.value = progress.get("progress", 0.0) * 100
			if progress_label:
				progress_label.text = "%d / %d" % [progress.current, progress.required]
	
	# 更新状态
	if status_label:
		var achievement_id = selected_achievement.get("id", "")
		if achievement_system and achievement_system.is_achievement_unlocked(achievement_id):
			status_label.text = "已解锁 ✓"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			status_label.text = "未解锁"
			status_label.add_theme_color_override("font_color", Color.GRAY)

func _on_close_pressed() -> void:
	hide()

func open() -> void:
	show()
	_populate_achievements()