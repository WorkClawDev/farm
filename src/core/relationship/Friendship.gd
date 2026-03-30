extends Node

## Friendship - 好感度系统
## 管理玩家与NPC之间的关系，包括心数、点数和事件触发

signal friendship_points_changed(npc_id: String, points: int, delta: int)
signal friendship_hearts_changed(npc_id: String, hearts: int)
signal friendship_event_triggered(npc_id: String, event_id: String)
signal new_heart_unlocked(npc_id: String, hearts: int)

# 好感度配置
const MAX_HEARTS: int = 10
const POINTS_PER_HEART: int = 250  # 每颗心需要250点
const MAX_POINTS: int = MAX_HEARTS * POINTS_PER_HEART  # 最大2500点

# 好感度来源
enum FriendshipSource {
	DIALOGUE,       # 对话
	GIFT_LOVE,      # 最爱的礼物
	GIFT_LIKE,      # 喜欢的礼物
	GIFT_NEUTRAL,   # 普通礼物
	GIFT_DISLIKE,   # 不喜欢的礼物
	EVENT,          # 事件
	QUEST,          # 任务
	BIRTHDAY,       # 生日礼物
	FESTIVAL        # 节日
}

# 好感度变化数值
const FRIENDSHIP_VALUES = {
	FriendshipSource.DIALOGUE: 10,
	FriendshipSource.GIFT_LOVE: 80,
	FriendshipSource.GIFT_LIKE: 45,
	FriendshipSource.GIFT_NEUTRAL: 20,
	FriendshipSource.GIFT_DISLIKE: -20,
	FriendshipSource.EVENT: 50,
	FriendshipSource.QUEST: 100,
	FriendshipSource.BIRTHDAY: 200,  # 生日礼物有额外加成
	FriendshipSource.FESTIVAL: 30
}

# NPC好感度数据
# {npc_id: {"points": int, "hearts": int, "met": bool, "gifted_today": bool, "last_gift_date": String}}
var _friendship_data: Dictionary = {}

# NPC礼物偏好缓存
var _gift_preferences_cache: Dictionary = {}

# 好感度事件配置
# 心数触发的事件
var _heart_events: Dictionary = {
	# npc_id: {heart_level: event_id}
}

# 每日对话记录（每天只能通过对话增加一次好感）
var _daily_dialogue: Dictionary = {}  # {npc_id: bool}


func _ready() -> void:
	print("[Friendship] Initialized")
	_load_gift_preferences()


## 加载NPC礼物偏好
func _load_gift_preferences() -> void:
	var data_path = "res://data/npcs.json"
	if not ResourceLoader.exists(data_path):
		return

	var file = FileAccess.open(data_path, FileAccess.READ)
	if not file:
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		print("[Friendship] Failed to parse npcs.json for gift preferences")
		return

	var data = json.get_data()
	if not data.has("npcs"):
		return

	for npc_data in data["npcs"]:
		var npc_id = npc_data.get("id", "")
		if npc_id.is_empty():
			continue

		if npc_data.has("gift_preferences"):
			_gift_preferences_cache[npc_id] = npc_data["gift_preferences"]

	print("[Friendship] Loaded gift preferences for %d NPCs" % _gift_preferences_cache.size())


## 获取NPC好感度点数
func get_points(npc_id: String) -> int:
	if not _friendship_data.has(npc_id):
		return 0
	return _friendship_data[npc_id].get("points", 0)


## 获取NPC心数
func get_hearts(npc_id: String) -> int:
	if not _friendship_data.has(npc_id):
		return 0
	return _friendship_data[npc_id].get("hearts", 0)


## 获取NPC好感度信息
func get_friendship_info(npc_id: String) -> Dictionary:
	if not _friendship_data.has(npc_id):
		return {
			"points": 0,
			"hearts": 0,
			"met": false,
			"points_to_next_heart": POINTS_PER_HEART
		}

	var data = _friendship_data[npc_id]
	var points = data.get("points", 0)
	var hearts = data.get("hearts", 0)
	var points_in_current_heart = points % POINTS_PER_HEART
	var points_to_next = POINTS_PER_HEART - points_in_current_heart

	return {
		"points": points,
		"hearts": hearts,
		"met": data.get("met", false),
		"points_in_current_heart": points_in_current_heart,
		"points_to_next_heart": points_to_next if hearts < MAX_HEARTS else 0,
		"progress": float(points_in_current_heart) / float(POINTS_PER_HEART)
	}


## 是否见过该NPC
func has_met(npc_id: String) -> bool:
	if not _friendship_data.has(npc_id):
		return false
	return _friendship_data[npc_id].get("met", false)


## 标记见过NPC
func set_met(npc_id: String) -> void:
	if not _friendship_data.has(npc_id):
		_initialize_npc(npc_id)

	_friendship_data[npc_id]["met"] = true
	print("[Friendship] Met NPC: %s" % npc_id)


## 增加好感度（通过来源类型）
func add_friendship(npc_id: String, source: FriendshipSource, amount_override: int = 0) -> int:
	var amount: int = amount_override if amount_override > 0 else FRIENDSHIP_VALUES.get(source, 0)
	return add_friendship_points(npc_id, amount, source)


## 增加好感度点数
func add_friendship_points(npc_id: String, points: int, source: FriendshipSource = FriendshipSource.EVENT) -> int:
	if points == 0:
		return 0

	# 确保NPC数据存在
	if not _friendship_data.has(npc_id):
		_initialize_npc(npc_id)

	var old_points: int = _friendship_data[npc_id]["points"]
	var old_hearts: int = _friendship_data[npc_id]["hearts"]

	# 计算新点数（限制在0-MAX_POINTS范围内）
	var new_points: int = clampi(old_points + points, 0, MAX_POINTS)
	var delta: int = new_points - old_points

	if delta == 0:
		return 0

	# 更新点数
	_friendship_data[npc_id]["points"] = new_points

	# 计算新心数
	var new_hearts: int = mini(new_points / POINTS_PER_HEART, MAX_HEARTS)
	_friendship_data[npc_id]["hearts"] = new_hearts

	# 发射信号
	friendship_points_changed.emit(npc_id, new_points, delta)

	# 检查心数变化
	if new_hearts != old_hearts:
		friendship_hearts_changed.emit(npc_id, new_hearts)

		if new_hearts > old_hearts:
			new_heart_unlocked.emit(npc_id, new_hearts)
			_check_heart_event(npc_id, new_hearts)
			print("[Friendship] %s reached %d hearts!" % [npc_id, new_hearts])

	# 发射EventBus信号
	if EventBus:
		get_node("/root/EventBus").friendship_changed.emit(npc_id, new_hearts)

	print("[Friendship] %s: %+d points (source: %s), total: %d points, %d hearts" % [
		npc_id, delta, FriendshipSource.keys()[source], new_points, new_hearts
	])

	return delta


## 减少好感度
func remove_friendship_points(npc_id: String, points: int) -> int:
	return add_friendship_points(npc_id, -points, FriendshipSource.EVENT)


## 对话增加好感
func add_dialogue_friendship(npc_id: String) -> int:
	# 每天每个NPC只能通过对话获得一次好感
	if _daily_dialogue.has(npc_id) and _daily_dialogue[npc_id]:
		return 0

	_daily_dialogue[npc_id] = true
	return add_friendship(npc_id, FriendshipSource.DIALOGUE)


## 送礼增加好感
func give_gift(npc_id: String, item_id: String, is_birthday: bool = false) -> Dictionary:
	# 检查是否已送过礼（每周限制）
	var today = TimeManager.get_formatted_date() if TimeManager else "Unknown"
	var last_gift_date = ""
	if _friendship_data.has(npc_id):
		last_gift_date = _friendship_data[npc_id].get("last_gift_date", "")

	if last_gift_date == today:
		return {"success": false, "reason": "already_gifted_today"}

	# 获取礼物偏好
	var reaction: int = _get_gift_reaction(npc_id, item_id)

	# 计算好感度
	var source: FriendshipSource
	var multiplier: float = 1.0

	match reaction:
		2:  # Love
			source = FriendshipSource.GIFT_LOVE
		1:  # Like
			source = FriendshipSource.GIFT_LIKE
		-1:  # Dislike
			source = FriendshipSource.GIFT_DISLIKE
		_:  # Neutral
			source = FriendshipSource.GIFT_NEUTRAL

	# 生日加成
	if is_birthday:
		source = FriendshipSource.BIRTHDAY
		multiplier = 2.0

	var base_points: int = FRIENDSHIP_VALUES.get(source, 20)
	var actual_points: int = int(base_points * multiplier)

	# 增加好感度
	add_friendship_points(npc_id, actual_points, source)

	# 记录送礼日期
	if not _friendship_data.has(npc_id):
		_initialize_npc(npc_id)
	_friendship_data[npc_id]["last_gift_date"] = today
	_friendship_data[npc_id]["gifted_today"] = true

	# 发射EventBus信号
	if EventBus:
		get_node("/root/EventBus").gift_given.emit(npc_id, item_id, reaction)

	return {
		"success": true,
		"points": actual_points,
		"reaction": reaction,
		"reaction_name": _get_reaction_name(reaction)
	}


## 获取礼物反应等级
func _get_gift_reaction(npc_id: String, item_id: String) -> int:
	if not _gift_preferences_cache.has(npc_id):
		return 0  # Neutral

	var prefs = _gift_preferences_cache[npc_id]

	# Love
	if prefs.has("love") and item_id in prefs["love"]:
		return 2
	# Like
	if prefs.has("like") and item_id in prefs["like"]:
		return 1
	# Dislike
	if prefs.has("dislike") and item_id in prefs["dislike"]:
		return -1

	return 0  # Neutral


## 获取反应名称
func _get_reaction_name(reaction: int) -> String:
	match reaction:
		2: return "love"
		1: return "like"
		-1: return "dislike"
		_: return "neutral"


## 初始化NPC数据
func _initialize_npc(npc_id: String) -> void:
	_friendship_data[npc_id] = {
		"points": 0,
		"hearts": 0,
		"met": false,
		"gifted_today": false,
		"last_gift_date": ""
	}


## 检查心数事件
func _check_heart_event(npc_id: String, hearts: int) -> void:
	# 触发特定心数的事件
	# 例如：2心、4心、6心、8心、10心事件
	var event_hearts = [2, 4, 6, 8, 10]
	if hearts in event_hearts:
		var event_id = "%s_heart_%d" % [npc_id, hearts]
		friendship_event_triggered.emit(npc_id, event_id)
		print("[Friendship] Heart event triggered: %s" % event_id)


## 重置每日数据（在每天开始时调用）
func reset_daily_data() -> void:
	_daily_dialogue.clear()

	# 重置每日送礼标记
	for npc_id in _friendship_data:
		_friendship_data[npc_id]["gifted_today"] = false

	print("[Friendship] Daily data reset")


## 是否今天已送礼
func has_gifted_today(npc_id: String) -> bool:
	if not _friendship_data.has(npc_id):
		return false
	return _friendship_data[npc_id].get("gifted_today", false)


## 获取所有NPC好感度数据
func get_all_friendship_data() -> Dictionary:
	return _friendship_data.duplicate()


## 设置好感度数据（用于加载存档）
func set_friendship_data(data: Dictionary) -> void:
	_friendship_data = data.duplicate()
	print("[Friendship] Loaded friendship data for %d NPCs" % _friendship_data.size())


## 获取NPC列表（按好感度排序）
func get_npcs_by_friendship() -> Array:
	var result: Array = []
	for npc_id in _friendship_data:
		result.append({
			"npc_id": npc_id,
			"hearts": _friendship_data[npc_id].get("hearts", 0),
			"points": _friendship_data[npc_id].get("points", 0)
		})

	result.sort_custom(func(a, b): return a["hearts"] > b["hearts"])
	return result


## 注册心数事件
func register_heart_event(npc_id: String, heart_level: int, event_id: String) -> void:
	if not _heart_events.has(npc_id):
		_heart_events[npc_id] = {}
	_heart_events[npc_id][heart_level] = event_id


## 获取心数事件
func get_heart_event(npc_id: String, heart_level: int) -> String:
	if not _heart_events.has(npc_id):
		return ""
	if not _heart_events[npc_id].has(heart_level):
		return ""
	return _heart_events[npc_id][heart_level]


## 检查是否满足好感度条件
func meets_friendship_requirement(npc_id: String, min_hearts: int) -> bool:
	return get_hearts(npc_id) >= min_hearts


## 序列化保存
func save_state() -> Dictionary:
	return {
		"friendship_data": _friendship_data,
		"daily_dialogue": _daily_dialogue
	}


## 反序列化加载
func load_state(data: Dictionary) -> void:
	if data.has("friendship_data"):
		_friendship_data = data["friendship_data"]
	if data.has("daily_dialogue"):
		_daily_dialogue = data["daily_dialogue"]

	print("[Friendship] Loaded state: %d NPCs tracked" % _friendship_data.size())


## 重置到初始状态
func reset() -> void:
	_friendship_data.clear()
	_daily_dialogue.clear()
	print("[Friendship] Reset to initial state")