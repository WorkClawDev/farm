extends Node

## QuestSystem - 任务系统
## 管理任务的接受、进度追踪、完成和奖励发放

signal quest_accepted(quest_id: String)
signal quest_progress_updated(quest_id: String, objective_index: int, current: int, required: int)
signal quest_completed(quest_id: String)
signal quest_turned_in(quest_id: String, rewards: Dictionary)
signal objective_completed(quest_id: String, objective_index: int)
signal quest_failed(quest_id: String, reason: String)

## 任务状态枚举
enum QuestState {
	LOCKED,      # 未解锁
	AVAILABLE,   # 可接受
	ACTIVE,      # 进行中
	COMPLETED,   # 已完成（待提交）
	TURNED_IN,   # 已提交
	FAILED       # 失败
}

## 目标类型枚举
enum ObjectiveType {
	COLLECT,     # 收集物品
	DELIVER,     # 交付物品给NPC
	TALK_TO,     # 与NPC对话
	GIFT_TO,     # 送礼给NPC
	REACH_HEARTS, # 达到好感度等级
	VISIT,       # 访问地点
	HARVEST,     # 收获作物
	FISH,        # 钓鱼
	MINE,        # 挖矿
	CUSTOM       # 自定义目标
}

## 任务数据类
class QuestData extends RefCounted:
	var id: String = ""
	var title: String = ""
	var description: String = ""
	var quest_giver: String = ""  # NPC ID
	var prerequisites: Array[String] = []  # 前置任务ID
	var objectives: Array[Dictionary] = []
	var rewards: Dictionary = {}
	var time_limit: int = -1  # 时间限制（天数），-1表示无限制
	var repeatable: bool = false
	var priority: int = 0  # 任务优先级（用于显示排序）

	func _to_string() -> String:
		return "[Quest: %s - %s]" % [id, title]

## 任务进度类
class QuestProgress extends RefCounted:
	var quest_id: String = ""
	var state: QuestState = QuestState.LOCKED
	var objective_progress: Array[int] = []
	var start_day: int = 0
	var start_season: int = 0
	var start_year: int = 0

	func _init(qid: String = "") -> void:
		quest_id = qid

	func _to_string() -> String:
		return "[Progress: %s - State: %d]" % [quest_id, state]

# 任务数据库
var _quest_database: Dictionary = {}

# 玩家任务进度
var _player_progress: Dictionary = {}

# 当前活跃任务列表（用于快速访问）
var _active_quests: Array[String] = []

# 已完成任务列表（用于追踪历史）
var _completed_quests: Array[String] = []

# 追踪的最大任务数量
const MAX_TRACKED_QUESTS: int = 5

# 经验系统
signal experience_gained(amount: int, total: int)
signal level_up(new_level: int)

const XP_BASE: int = 100          # 1级所需经验
const XP_MULTIPLIER: float = 1.5  # 每级倍数

var _player_xp: int = 0
var _player_level: int = 1

# NPC 数据库缓存
var _npc_database: Dictionary = {}

func _ready() -> void:
	print("[QuestSystem] Initialized")
	_load_quest_database()
	_load_npc_database()
	_connect_signals()

## 加载 NPC 数据库
func _load_npc_database() -> void:
	var npc_file_path := "res://data/npcs.json"
	if not FileAccess.file_exists(npc_file_path):
		push_warning("[QuestSystem] NPC database not found: " + npc_file_path)
		return

	var npc_file := FileAccess.open(npc_file_path, FileAccess.READ)
	if not npc_file:
		push_error("[QuestSystem] Failed to open NPC database")
		return

	var npc_json_text := npc_file.get_as_text()
	npc_file.close()

	var npc_json := JSON.new()
	if npc_json.parse(npc_json_text) != OK:
		push_error("[QuestSystem] Failed to parse NPC database: " + npc_json.get_error_message())
		return

	var npc_data_dict: Dictionary = npc_json.data
	for npc_entry in npc_data_dict.get("npcs", []):
		var npc_id: String = npc_entry.get("id", "")
		if npc_id != "":
			_npc_database[npc_id] = npc_entry

	print("[QuestSystem] Loaded %d NPCs from database" % _npc_database.size())


func _load_quest_database() -> void:
	var file_path: String = "res://data/quests.json"

	if not FileAccess.file_exists(file_path):
		push_warning("[QuestSystem] Quest database file not found: " + file_path)
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[QuestSystem] Failed to open quest database")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: int = json.parse(json_text)

	if error != OK:
		push_error("[QuestSystem] Failed to parse quest database: " + json.get_error_message())
		return

	var data: Dictionary = json.data

	for quest_data in data.get("quests", []):
		var quest: QuestData = _parse_quest(quest_data)
		if quest.id != "":
			_quest_database[quest.id] = quest
			print("[QuestSystem] Loaded quest: " + quest.id)

	print("[QuestSystem] Loaded %d quests" % _quest_database.size())

func _parse_quest(data: Dictionary) -> QuestData:
	var quest: QuestData = QuestData.new()
	quest.id = data.get("id", "")
	quest.title = data.get("title", "")
	quest.description = data.get("description", "")
	quest.quest_giver = data.get("quest_giver", "")
	quest.time_limit = data.get("time_limit", -1)
	quest.repeatable = data.get("repeatable", false)
	quest.priority = data.get("priority", 0)

	# 解析前置任务
	for prereq in data.get("prerequisites", []):
		quest.prerequisites.append(str(prereq))

	# 解析目标
	for obj_data in data.get("objectives", []):
		var objective: Dictionary = {
			"type": _parse_objective_type(obj_data.get("type", "collect")),
			"target": obj_data.get("target", ""),
			"required": obj_data.get("required", 1),
			"description": obj_data.get("description", ""),
			"npc_id": obj_data.get("npc_id", ""),
			"location": obj_data.get("location", "")
		}
		quest.objectives.append(objective)

	# 解析奖励
	quest.rewards = data.get("rewards", {})

	return quest

func _parse_objective_type(type_str: String) -> ObjectiveType:
	match type_str.to_lower():
		"collect": return ObjectiveType.COLLECT
		"deliver": return ObjectiveType.DELIVER
		"talk_to": return ObjectiveType.TALK_TO
		"gift_to": return ObjectiveType.GIFT_TO
		"reach_hearts": return ObjectiveType.REACH_HEARTS
		"visit": return ObjectiveType.VISIT
		"harvest": return ObjectiveType.HARVEST
		"fish": return ObjectiveType.FISH
		"mine": return ObjectiveType.MINE
		"custom": return ObjectiveType.CUSTOM
		_: return ObjectiveType.COLLECT

func _connect_signals() -> void:
	# 连接背包事件（收集任务）
	if EventBus:
		get_node("/root/EventBus").item_added.connect(_on_item_added)
		get_node("/root/EventBus").dialogue_ended.connect(_on_dialogue_ended)
		get_node("/root/EventBus").gift_given.connect(_on_gift_given)
		get_node("/root/EventBus").friendship_changed.connect(_on_friendship_changed)
		get_node("/root/EventBus").crop_harvested.connect(_on_crop_harvested)

	# 连接时间事件（检查时间限制）
	if TimeManager:
		get_node("/root/TimeManager").day_changed.connect(_on_day_changed)

## 获取所有可用任务
func get_available_quests() -> Array[QuestData]:
	var available: Array[QuestData] = []

	for quest_id in _quest_database:
		var quest: QuestData = _quest_database[quest_id]
		if can_accept_quest(quest_id):
			available.append(quest)

	# 按优先级排序
	available.sort_custom(func(a: QuestData, b: QuestData): return a.priority > b.priority)

	return available

## 获取所有活跃任务
func get_active_quests() -> Array[QuestData]:
	var active: Array[QuestData] = []

	for quest_id in _active_quests:
		if _quest_database.has(quest_id):
			active.append(_quest_database[quest_id])

	return active

## 获取任务数据
func get_quest(quest_id: String) -> QuestData:
	return _quest_database.get(quest_id, null)

## 鍏煎 API锛氳幏鍙栦换鍔℃暟鎹?
func get_quest_data(quest_id: String) -> Dictionary:
	var quest := get_quest(quest_id)
	if quest == null:
		return {}
	return {
		"id": quest.id,
		"title": quest.title,
		"description": quest.description,
		"quest_giver": quest.quest_giver,
		"prerequisites": quest.prerequisites.duplicate(),
		"objectives": quest.objectives.duplicate(true),
		"rewards": quest.rewards.duplicate(true),
		"time_limit": quest.time_limit,
		"repeatable": quest.repeatable,
		"priority": quest.priority,
	}

## 鍏煎 API锛氳幏鍙栨墍鏈変换鍔D
func get_all_quest_ids() -> Array:
	return _quest_database.keys()

## 鍏煎 API锛氭寜 NPC 鑾峰彇浠诲姟
func get_quests_by_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest_id in _quest_database.keys():
		var quest: QuestData = _quest_database[quest_id]
		if quest.quest_giver == npc_id:
			result.append(get_quest_data(quest_id))
	return result

## 鍏煎 API锛氭鏌ヤ换鍔℃槸鍚﹀瓨鍦?
func has_quest(quest_id: String) -> bool:
	return _quest_database.has(quest_id)

## 获取任务状态
func get_quest_state(quest_id: String) -> QuestState:
	if _player_progress.has(quest_id):
		return _player_progress[quest_id].state
	return QuestState.LOCKED

## 检查是否可以接受任务
func can_accept_quest(quest_id: String) -> bool:
	if not _quest_database.has(quest_id):
		return false

	var quest: QuestData = _quest_database[quest_id]
	var state: QuestState = get_quest_state(quest_id)

	# 已经是活跃或已完成状态
	if state == QuestState.ACTIVE:
		return false

	# 如果任务可重复，检查是否可以再次接受
	if quest.repeatable and state == QuestState.TURNED_IN:
		pass  # 允许再次接受
	elif state != QuestState.LOCKED and state != QuestState.AVAILABLE:
		return false

	# 检查前置任务
	for prereq_id in quest.prerequisites:
		var prereq_state: QuestState = get_quest_state(prereq_id)
		if prereq_state != QuestState.TURNED_IN:
			return false

	return true

## 接受任务
func accept_quest(quest_id: String) -> bool:
	if not can_accept_quest(quest_id):
		push_warning("[QuestSystem] Cannot accept quest: " + quest_id)
		return false

	var quest: QuestData = _quest_database[quest_id]

	# 创建任务进度
	var progress: QuestProgress = QuestProgress.new(quest_id)
	progress.state = QuestState.ACTIVE
	progress.objective_progress.clear()

	for i in quest.objectives.size():
		progress.objective_progress.append(0)

	# 记录开始时间
	if TimeManager:
		progress.start_day = get_node("/root/TimeManager").current_day
		progress.start_season = get_node("/root/TimeManager").current_season
		progress.start_year = get_node("/root/TimeManager").current_year

	_player_progress[quest_id] = progress
	_active_quests.append(quest_id)

	quest_accepted.emit(quest_id)
	print("[QuestSystem] Accepted quest: " + quest_id)

	# 检查收集类目标的初始进度
	_check_initial_progress(quest_id)

	return true

## 检查初始进度（针对收集类目标）
func _check_initial_progress(quest_id: String) -> void:
	var quest: QuestData = get_quest(quest_id)
	if not quest:
		return

	for i in quest.objectives.size():
		var objective: Dictionary = quest.objectives[i]
		if objective.type == ObjectiveType.COLLECT:
			var item_id: String = objective.target
			var required: int = objective.required

			# 检查玩家背包中是否已有该物品
			var current: int = _get_item_count(item_id)
			if current > 0:
				update_objective_progress(quest_id, i, current)

## 获取物品数量
func _get_item_count(item_id: String) -> int:
	if Inventory:
		return get_node("/root/Inventory").get_item_count(item_id)
	return 0

## 更新目标进度
func update_objective_progress(quest_id: String, objective_index: int, amount: int = 1) -> void:
	if not _player_progress.has(quest_id):
		return

	var progress: QuestProgress = _player_progress[quest_id]
	if progress.state != QuestState.ACTIVE:
		return

	var quest: QuestData = get_quest(quest_id)
	if not quest or objective_index >= quest.objectives.size():
		return

	var objective: Dictionary = quest.objectives[objective_index]
	var required: int = objective.required
	var current: int = progress.objective_progress[objective_index]

	# 更新进度（不超过所需数量）
	var new_progress: int = mini(current + amount, required)
	progress.objective_progress[objective_index] = new_progress

	# 发射进度更新信号
	quest_progress_updated.emit(quest_id, objective_index, new_progress, required)

	print("[QuestSystem] Quest %s objective %d progress: %d/%d" % [quest_id, objective_index, new_progress, required])

	# 检查目标是否完成
	if new_progress >= required and current < required:
		objective_completed.emit(quest_id, objective_index)
		print("[QuestSystem] Objective %d completed for quest: %s" % [objective_index, quest_id])

	# 检查整个任务是否完成
	_check_quest_completion(quest_id)

## 设置目标进度（用于特殊目标如对话、访问等）
func set_objective_progress(quest_id: String, objective_index: int, value: int) -> void:
	if not _player_progress.has(quest_id):
		return

	var progress: QuestProgress = _player_progress[quest_id]
	if progress.state != QuestState.ACTIVE:
		return

	var quest: QuestData = get_quest(quest_id)
	if not quest or objective_index >= quest.objectives.size():
		return

	var objective: Dictionary = quest.objectives[objective_index]
	var required: int = objective.required

	# 设置进度（不超过所需数量）
	progress.objective_progress[objective_index] = mini(value, required)

	# 发射进度更新信号
	quest_progress_updated.emit(quest_id, objective_index, progress.objective_progress[objective_index], required)

	# 检查目标是否完成
	if progress.objective_progress[objective_index] >= required:
		objective_completed.emit(quest_id, objective_index)

	# 检查整个任务是否完成
	_check_quest_completion(quest_id)

## 检查任务是否完成
func _check_quest_completion(quest_id: String) -> void:
	if not _player_progress.has(quest_id):
		return

	var progress: QuestProgress = _player_progress[quest_id]
	var quest: QuestData = get_quest(quest_id)

	if not quest:
		return

	# 检查所有目标是否完成
	for i in quest.objectives.size():
		if progress.objective_progress[i] < quest.objectives[i].required:
			return  # 还有未完成的目标

	# 所有目标完成，标记任务为已完成状态
	progress.state = QuestState.COMPLETED
	quest_completed.emit(quest_id)
	print("[QuestSystem] Quest completed: " + quest_id)

## 提交任务并获取奖励
func turn_in_quest(quest_id: String) -> bool:
	if not _player_progress.has(quest_id):
		return false

	var progress: QuestProgress = _player_progress[quest_id]
	if progress.state != QuestState.COMPLETED:
		return false

	var quest: QuestData = get_quest(quest_id)
	if not quest:
		return false

	# 发放奖励
	_grant_rewards(quest.rewards)

	# 更新状态
	progress.state = QuestState.TURNED_IN

	# 从活跃列表移除
	var idx: int = _active_quests.find(quest_id)
	if idx >= 0:
		_active_quests.remove_at(idx)

	# 添加到已完成列表
	if not _completed_quests.has(quest_id):
		_completed_quests.append(quest_id)

	# 发射信号
	quest_turned_in.emit(quest_id, quest.rewards)
	print("[QuestSystem] Quest turned in: " + quest_id)

	return true

## 经验系统：计算指定等级所需总经验
func get_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(float(XP_BASE) * (pow(XP_MULTIPLIER, level - 1) - 1.0) / (XP_MULTIPLIER - 1.0))


## 经验系统：根据总经验计算当前等级
func get_level_from_xp(total_xp: int) -> int:
	var level := 1
	while get_xp_for_level(level + 1) <= total_xp:
		level += 1
	return level


## 经验系统：获取当前等级所需经验
func get_xp_for_current_level() -> int:
	return get_xp_for_level(_player_level)


## 经验系统：获取下一级所需经验
func get_xp_for_next_level() -> int:
	return get_xp_for_level(_player_level + 1)


## 经验系统：获取当前进度 (0.0 - 1.0)
func get_xp_progress() -> float:
	var current_level_xp: int = get_xp_for_current_level()
	var next_level_xp: int = get_xp_for_next_level()
	if next_level_xp == current_level_xp:
		return 1.0
	return float(_player_xp - current_level_xp) / float(next_level_xp - current_level_xp)


## 经验系统：添加经验值
func add_experience(amount: int) -> void:
	if amount <= 0:
		return

	var old_level: int = _player_level
	_player_xp += amount
	_player_level = get_level_from_xp(_player_xp)

	print("[QuestSystem] +%d XP (Total: %d, Level: %d)" % [amount, _player_xp, _player_level])
	experience_gained.emit(amount, _player_xp)

	if _player_level > old_level:
		print("[QuestSystem] 🎉 Level Up! %d → %d" % [old_level, _player_level])
		level_up.emit(_player_level)


## 经验系统：获取当前经验
func get_current_xp() -> int:
	return _player_xp


## 经验系统：获取当前等级
func get_current_level() -> int:
	return _player_level


## 经验系统：设置经验值（用于加载存档）
func set_xp_and_level(xp: int, level: int) -> void:
	_player_xp = xp
	_player_level = level


## 发放奖励
func _grant_rewards(rewards: Dictionary) -> void:
	# 金钱奖励
	var money: int = rewards.get("money", 0)
	if money > 0 and MoneySystem:
		get_node("/root/MoneySystem").add_money(money)
		print("[QuestSystem] Reward: %d gold" % money)

	# 物品奖励
	var items: Array = rewards.get("items", [])
	for item in items:
		var item_id: String = item.get("id", "")
		var quantity: int = item.get("quantity", 1)
		if item_id != "" and Inventory:
			get_node("/root/Inventory").add_item(item_id, quantity)
			print("[QuestSystem] Reward: %dx %s" % [quantity, item_id])

	# 经验奖励
	var experience: int = rewards.get("experience", 0)
	if experience > 0:
		add_experience(experience)

## 放弃任务
func abandon_quest(quest_id: String) -> bool:
	if not _player_progress.has(quest_id):
		return false

	var progress: QuestProgress = _player_progress[quest_id]
	if progress.state != QuestState.ACTIVE:
		return false

	# 从活跃列表移除
	var idx: int = _active_quests.find(quest_id)
	if idx >= 0:
		_active_quests.remove_at(idx)

	# 删除进度
	_player_progress.erase(quest_id)

	print("[QuestSystem] Abandoned quest: " + quest_id)
	return true

## 标记任务失败
func fail_quest(quest_id: String, reason: String = "") -> void:
	if not _player_progress.has(quest_id):
		return

	var progress: QuestProgress = _player_progress[quest_id]
	progress.state = QuestState.FAILED

	# 从活跃列表移除
	var idx: int = _active_quests.find(quest_id)
	if idx >= 0:
		_active_quests.remove_at(idx)

	quest_failed.emit(quest_id, reason)
	print("[QuestSystem] Quest failed: %s, reason: %s" % [quest_id, reason])

## 获取任务进度
func get_quest_progress(quest_id: String) -> QuestProgress:
	return _player_progress.get(quest_id, null)

## 获取目标进度
func get_objective_progress(quest_id: String, objective_index: int) -> int:
	var progress: QuestProgress = get_quest_progress(quest_id)
	if progress and objective_index < progress.objective_progress.size():
		return progress.objective_progress[objective_index]
	return 0

## 获取目标是否完成
func is_objective_completed(quest_id: String, objective_index: int) -> bool:
	var progress: QuestProgress = get_quest_progress(quest_id)
	var quest: QuestData = get_quest(quest_id)

	if not progress or not quest:
		return false

	if objective_index >= quest.objectives.size():
		return false

	return progress.objective_progress[objective_index] >= quest.objectives[objective_index].required

## 获取任务完成百分比
func get_quest_completion_percent(quest_id: String) -> float:
	var progress: QuestProgress = get_quest_progress(quest_id)
	var quest: QuestData = get_quest(quest_id)

	if not progress or not quest:
		return 0.0

	var completed: int = 0
	for i in quest.objectives.size():
		if is_objective_completed(quest_id, i):
			completed += 1

	return float(completed) / float(quest.objectives.size()) * 100.0

## 获取目标描述
func get_objective_description(quest_id: String, objective_index: int) -> String:
	var quest: QuestData = get_quest(quest_id)
	if not quest or objective_index >= quest.objectives.size():
		return ""

	var objective: Dictionary = quest.objectives[objective_index]

	# 如果有自定义描述，直接返回
	if objective.description != "":
		return objective.description

	# 根据目标类型生成描述
	return _generate_objective_description(objective)

## 生成目标描述
func _generate_objective_description(objective: Dictionary) -> String:
	var target: String = objective.target
	var required: int = objective.required
	var npc_id: String = objective.get("npc_id", "")

	var target_name: String = _get_target_display_name(target)

	match objective.type:
		ObjectiveType.COLLECT:
			return "收集 %d 个 %s" % [required, target_name]
		ObjectiveType.DELIVER:
			return "将 %d 个 %s 交给 %s" % [required, target_name, _get_npc_name(npc_id)]
		ObjectiveType.TALK_TO:
			return "与 %s 对话" % [_get_npc_name(target)]
		ObjectiveType.GIFT_TO:
			return "送给 %s 一件礼物" % [_get_npc_name(target)]
		ObjectiveType.REACH_HEARTS:
			return "与 %s 达到 %d 心好感度" % [_get_npc_name(npc_id), required]
		ObjectiveType.VISIT:
			return "访问 %s" % [target_name]
		ObjectiveType.HARVEST:
			return "收获 %d 个 %s" % [required, target_name]
		ObjectiveType.FISH:
			return "钓到 %d 条鱼" % [required]
		ObjectiveType.MINE:
			return "在矿洞中挖掘 %d 次" % [required]
		ObjectiveType.CUSTOM:
			return target

	return "完成目标"

## 获取目标显示名称
func _get_target_display_name(target: String) -> String:
	if ItemDatabase:
		var item = get_node("/root/ItemDatabase").get_item(target)
		if item:
			return item.name
	return target

## 获取NPC名称
func _get_npc_name(npc_id: String) -> String:
	if _npc_database.has(npc_id):
		return _npc_database[npc_id].get("name", npc_id)
	# Fallback to hardcoded
	match npc_id:
		"mayor": return "镇长·威廉"
		"shopkeeper_lily": return "店主·莉莉"
		"blacksmith_tom": return "铁匠·汤姆"
		"doctor_mary": return "医生·玛丽"
		"fisherman_jack": return "渔夫·杰克"
		"farmer_joe": return "农夫·乔"
		_: return npc_id


## 根据 NPC ID 获取 NPC 数据
func get_npc_data(npc_id: String) -> Dictionary:
	return _npc_database.get(npc_id, {})


## 根据 NPC ID 获取 NPC 当前地点
func get_npc_location(npc_id: String) -> String:
	if _npc_database.has(npc_id):
		return _npc_database[npc_id].get("default_location", "")
	return ""


## 检查 NPC 是否在数据库中
func has_npc(npc_id: String) -> bool:
	return _npc_database.has(npc_id)

# ===== 事件处理 =====

func _on_item_added(item_id: String, quantity: int) -> void:
	# 检查所有活跃任务的收集目标
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		if not quest:
			continue

		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.type == ObjectiveType.COLLECT and objective.target == item_id:
				# 计算新增数量（总数量 - 已记录进度）
				var total: int = _get_item_count(item_id)
				var progress: QuestProgress = get_quest_progress(quest_id)
				var recorded: int = progress.objective_progress[i] if progress else 0
				var new_items: int = total - recorded

				if new_items > 0:
					update_objective_progress(quest_id, i, new_items)

func _on_dialogue_ended(npc_id: String) -> void:
	# 检查对话目标
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		if not quest:
			continue

		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.type == ObjectiveType.TALK_TO and objective.target == npc_id:
				set_objective_progress(quest_id, i, 1)

func _on_gift_given(npc_id: String, _item_id: String, _reaction: int) -> void:
	# 检查送礼目标
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		if not quest:
			continue

		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.type == ObjectiveType.GIFT_TO and objective.target == npc_id:
				set_objective_progress(quest_id, i, 1)

func _on_friendship_changed(npc_id: String, hearts: int) -> void:
	# 检查好感度目标
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		if not quest:
			continue

		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.type == ObjectiveType.REACH_HEARTS and objective.get("npc_id", "") == npc_id:
				set_objective_progress(quest_id, i, hearts)

func _on_crop_harvested(crop_type: String, _quality: int, quantity: int) -> void:
	# 检查收获目标
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		if not quest:
			continue

		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.type == ObjectiveType.HARVEST and objective.target == crop_type:
				update_objective_progress(quest_id, i, quantity)

func _on_day_changed(_new_day: int) -> void:
	# 检查任务时间限制
	for quest_id in _active_quests:
		var quest: QuestData = get_quest(quest_id)
		var progress: QuestProgress = get_quest_progress(quest_id)

		if not quest or not progress:
			continue

		if quest.time_limit > 0 and TimeManager:
			var days_passed: int = _calculate_days_passed(progress)
			if days_passed >= quest.time_limit:
				fail_quest(quest_id, "时间已用尽")

## 计算已过去的天数
func _calculate_days_passed(progress: QuestProgress) -> int:
	if not TimeManager:
		return 0

	var days: int = 0
	days += (get_node("/root/TimeManager").current_year - progress.start_year) * 112  # 4季 x 28天
	days += (get_node("/root/TimeManager").current_season - progress.start_season) * 28
	days += get_node("/root/TimeManager").current_day - progress.start_day

	return days

# ===== 存档系统支持 =====

## 保存状态
func save_state() -> Dictionary:
	var data: Dictionary = {}

	# 保存所有任务进度
	for quest_id in _player_progress:
		var progress: QuestProgress = _player_progress[quest_id]
		data[quest_id] = {
			"state": progress.state,
			"objective_progress": progress.objective_progress,
			"start_day": progress.start_day,
			"start_season": progress.start_season,
			"start_year": progress.start_year
		}

	return {
		"progress": data,
		"active_quests": _active_quests,
		"completed_quests": _completed_quests,
		"player_xp": _player_xp,
		"player_level": _player_level
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	# 清空现有数据
	_player_progress.clear()
	_active_quests.clear()
	_completed_quests.clear()

	# 加载进度
	var progress_data: Dictionary = data.get("progress", {})
	for quest_id in progress_data:
		var p_data: Dictionary = progress_data[quest_id]
		var progress: QuestProgress = QuestProgress.new(quest_id)
		progress.state = p_data.get("state", QuestState.LOCKED)
		progress.objective_progress = p_data.get("objective_progress", [])
		progress.start_day = p_data.get("start_day", 1)
		progress.start_season = p_data.get("start_season", 0)
		progress.start_year = p_data.get("start_year", 1)
		_player_progress[quest_id] = progress

	# 加载活跃任务列表
	for qid in data.get("active_quests", []):
		_active_quests.append(str(qid))

	# 加载已完成任务列表
	for qid in data.get("completed_quests", []):
		_completed_quests.append(str(qid))

	# 加载经验数据
	_player_xp = data.get("player_xp", 0)
	_player_level = data.get("player_level", 1)

	print("[QuestSystem] Loaded %d quest progress records" % _player_progress.size())

## 获取任务总数
func get_total_quest_count() -> int:
	return _quest_database.size()

## 获取已完成任务数量
func get_completed_quest_count() -> int:
	return _completed_quests.size()

## 检查任务是否已完成
func is_quest_completed(quest_id: String) -> bool:
	return _completed_quests.has(quest_id)

## 解锁任务（用于剧情触发等）
func unlock_quest(quest_id: String) -> void:
	if not _player_progress.has(quest_id):
		var progress: QuestProgress = QuestProgress.new(quest_id)
		progress.state = QuestState.AVAILABLE
		_player_progress[quest_id] = progress
		print("[QuestSystem] Quest unlocked: " + quest_id)
