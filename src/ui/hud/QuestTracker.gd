extends Control
class_name QuestTracker

## QuestTracker - 任务追踪器UI
## 显示当前活跃任务和进度

@onready var quest_list: VBoxContainer = $MarginContainer/VBoxContainer/QuestList
@onready var toggle_button: Button = $MarginContainer/VBoxContainer/ToggleButton
@onready var panel: MarginContainer = $MarginContainer

var is_visible: bool = true
var quest_items: Dictionary = {}  # quest_id -> UI节点

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_refresh_quest_list()

func _setup_ui() -> void:
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	
	# 初始显示状态
	if panel:
		panel.visible = is_visible

func _connect_signals() -> void:
	# 连接任务系统信号
	if QuestSystem:
		QuestSystem.quest_accepted.connect(_on_quest_accepted)
		QuestSystem.quest_progress_updated.connect(_on_quest_progress_updated)
		QuestSystem.quest_completed.connect(_on_quest_completed)
		QuestSystem.quest_turned_in.connect(_on_quest_turned_in)
		QuestSystem.objective_completed.connect(_on_objective_completed)

func _on_toggle_pressed() -> void:
	is_visible = !is_visible
	if panel:
		panel.visible = is_visible
	if toggle_button:
		toggle_button.text = "▼" if is_visible else "▶"

func _on_quest_accepted(quest_id: String) -> void:
	_refresh_quest_list()

func _on_quest_progress_updated(quest_id: String, objective_index: int, current: int, required: int) -> void:
	_update_quest_item(quest_id)

func _on_quest_completed(quest_id: String) -> void:
	_update_quest_item(quest_id)

func _on_quest_turned_in(quest_id: String, _rewards: Dictionary) -> void:
	_remove_quest_item(quest_id)

func _on_objective_completed(quest_id: String, _objective_index: int) -> void:
	_update_quest_item(quest_id)

func _refresh_quest_list() -> void:
	if not QuestSystem or not quest_list:
		return
	
	# 清除现有列表
	for child in quest_list.get_children():
		child.queue_free()
	quest_items.clear()
	
	# 获取活跃任务
	var active_quests = QuestSystem.get_active_quests()
	
	for quest in active_quests:
		var quest_item = _create_quest_item(quest)
		quest_list.add_child(quest_item)
		quest_items[quest.id] = quest_item

func _create_quest_item(quest: QuestSystem.QuestData) -> Control:
	var container = VBoxContainer.new()
	container.name = "Quest_" + quest.id
	
	# 任务标题
	var title_label = Label.new()
	title_label.text = quest.title
	title_label.add_theme_font_size_override("font_size", 16)
	container.add_child(title_label)
	
	# 获取任务进度
	var progress = QuestSystem.get_quest_progress(quest.id)
	var is_completed = QuestSystem.get_quest_state(quest.id) == QuestSystem.QuestState.COMPLETED
	
	if is_completed:
		# 显示完成提示
		var complete_label = Label.new()
		complete_label.text = "✓ 已完成 - 去找 " + quest.quest_giver + " 提交"
		complete_label.add_theme_color_override("font_color", Color.GREEN)
		container.add_child(complete_label)
	else:
		# 显示目标列表
		for i in quest.objectives.size():
			var objective = quest.objectives[i]
			var current = QuestSystem.get_objective_progress(quest.id, i)
			var required = objective.required
			var is_obj_completed = QuestSystem.is_objective_completed(quest.id, i)
			
			var obj_label = Label.new()
			var desc = QuestSystem.get_objective_description(quest.id, i)
			
			if is_obj_completed:
				obj_label.text = "  ✓ %s" % desc
				obj_label.add_theme_color_override("font_color", Color.GRAY)
			else:
				obj_label.text = "  ○ %s (%d/%d)" % [desc, current, required]
			
			obj_label.add_theme_font_size_override("font_size", 12)
			container.add_child(obj_label)
	
	return container

func _update_quest_item(quest_id: String) -> void:
	if not quest_items.has(quest_id):
		_refresh_quest_list()
		return
	
	var quest = QuestSystem.get_quest(quest_id)
	if not quest:
		return
	
	# 重新创建该任务项
	var old_item = quest_items[quest_id]
	var new_item = _create_quest_item(quest)
	
	var index = old_item.get_index()
	quest_list.remove_child(old_item)
	old_item.queue_free()
	
	quest_list.add_child(new_item)
	quest_list.move_child(new_item, index)
	quest_items[quest_id] = new_item

func _remove_quest_item(quest_id: String) -> void:
	if quest_items.has(quest_id):
		var item = quest_items[quest_id]
		quest_list.remove_child(item)
		item.queue_free()
		quest_items.erase(quest_id)

func toggle_visibility() -> void:
	_on_toggle_pressed()
