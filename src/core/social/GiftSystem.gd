extends Node

## GiftSystem - 送礼系统
## 处理礼物偏好、好感度变化、送礼反应等

# 反应类型枚举
enum ReactionType {
	LOVE,       # 非常喜欢 (+3 好感)
	LIKE,       # 喜欢 (+2 好感)
	NEUTRAL,    # 一般 (+1 好感)
	DISLIKE,    # 不喜欢 (-1 好感)
	HATE        # 讨厌 (-3 好感)
}

# 好感度变化值
const FRIENDSHIP_CHANGE = {
	ReactionType.LOVE: 3,
	ReactionType.LIKE: 2,
	ReactionType.NEUTRAL: 1,
	ReactionType.DISLIKE: -1,
	ReactionType.HATE: -3
}

# 生日加成
const BIRTHDAY_MULTIPLIER = 2

# NPC数据缓存
var _npc_data_cache: Dictionary = {}

# NPC好感度数据
var _friendship_data: Dictionary = {}

# 送礼记录（每周每个NPC只能送一次）
# 格式: {npc_id: {week: {item_id: bool}}}
var _gift_history: Dictionary = {}

# 信号
signal gift_reaction(npc_id: String, item_id: String, reaction: int, friendship_change: int)
signal friendship_updated(npc_id: String, new_hearts: int)

# 数据库引用
var _item_database: ItemDatabase = null

func _ready() -> void:
	_load_npc_data()
	_connect_signals()
	print("[GiftSystem] Initialized")

func _connect_signals() -> void:
	_item_database = get_node_or_null("/root/ItemDatabase")

## 加载NPC数据
func _load_npc_data() -> void:
	var path := "res://data/npcs.json"

	if not FileAccess.file_exists(path):
		push_warning("[GiftSystem] npcs.json not found at: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[GiftSystem] Failed to open npcs.json")
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("[GiftSystem] Failed to parse npcs.json")
		return

	var data: Dictionary = json.get_data()
	if not data.has("npcs"):
		return

	for npc_data in data["npcs"]:
		var npc_id: String = npc_data.get("id", "")
		if npc_id != "":
			_npc_data_cache[npc_id] = npc_data
			# 初始化好感度
			if not _friendship_data.has(npc_id):
				_friendship_data[npc_id] = npc_data.get("default_friendship", 0)

	print("[GiftSystem] Loaded %d NPCs" % _npc_data_cache.size())

## 检查是否可以送礼
func can_give_gift(npc_id: String, item_id: String) -> Dictionary:
	var result := {
		"can_give": false,
		"reason": ""
	}

	# 检查NPC是否存在
	if not _npc_data_cache.has(npc_id):
		result.reason = "未知的NPC"
		return result

	# 检查物品是否存在
	if _item_database and not _item_database.has_item(item_id):
		result.reason = "未知的物品"
		return result

	# 检查是否已经送过礼物（本周）
	var current_week := _get_current_week()
	if _has_gifted_this_week(npc_id, item_id, current_week):
		result.reason = "本周已经送过这个礼物了"
		return result

	# 检查是否是可赠送物品
	var item := _item_database.get_item(item_id)
	if item and item.type == ItemDatabase.ItemType.TOOL:
		result.reason = "工具不能作为礼物"
		return result

	result.can_give = true
	return result

## 送出礼物
func give_gift(npc_id: String, item_id: String) -> Dictionary:
	var result := {
		"success": false,
		"reaction": ReactionType.NEUTRAL,
		"friendship_change": 0,
		"dialogue": "",
		"hearts": 0
	}

	# 检查是否可以送礼
	var check := can_give_gift(npc_id, item_id)
	if not check.can_give:
		push_warning("[GiftSystem] Cannot give gift: " + check.reason)
		return result

	# 获取反应类型
	var reaction := get_reaction_type(npc_id, item_id)
	result.reaction = reaction

	# 计算好感度变化
	var friendship_change: int = FRIENDSHIP_CHANGE.get(reaction, 0)

	# 检查是否是生日
	if is_npc_birthday(npc_id):
		friendship_change *= BIRTHDAY_MULTIPLIER

	result.friendship_change = friendship_change

	# 更新好感度
	_update_friendship(npc_id, friendship_change)
	result.hearts = get_friendship_hearts(npc_id)

	# 获取对话
	result.dialogue = get_reaction_dialogue(npc_id, reaction)

	# 记录送礼历史
	_record_gift(npc_id, item_id)

	# 发射事件
	result.success = true
	gift_reaction.emit(npc_id, item_id, reaction, friendship_change)

	if EventBus:
		get_node("/root/EventBus").social.gift_given.emit(npc_id, item_id, reaction)

	return result

## 获取反应类型
func get_reaction_type(npc_id: String, item_id: String) -> int:
	if not _npc_data_cache.has(npc_id):
		return ReactionType.NEUTRAL

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	var preferences: Dictionary = npc_data.get("gift_preferences", {})

	# 检查各等级偏好
	if _is_item_in_preference_list(item_id, preferences, "love"):
		return ReactionType.LOVE
	elif _is_item_in_preference_list(item_id, preferences, "like"):
		return ReactionType.LIKE
	elif _is_item_in_preference_list(item_id, preferences, "hate"):
		return ReactionType.HATE
	elif _is_item_in_preference_list(item_id, preferences, "dislike"):
		return ReactionType.DISLIKE

	return ReactionType.NEUTRAL

## 检查物品是否在偏好列表中
func _is_item_in_preference_list(item_id: String, preferences: Dictionary, preference_type: String) -> bool:
	if not preferences.has(preference_type):
		return false

	var list: Array = preferences[preference_type]
	return item_id in list

## 获取反应对话
func get_reaction_dialogue(npc_id: String, reaction: int) -> String:
	if not _npc_data_cache.has(npc_id):
		return "..."

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	var dialogues: Dictionary = npc_data.get("dialogues", {})

	var dialogue_key := "gift_neutral"
	match reaction:
		ReactionType.LOVE: dialogue_key = "gift_love"
		ReactionType.LIKE: dialogue_key = "gift_like"
		ReactionType.DISLIKE: dialogue_key = "gift_dislike"
		ReactionType.HATE: dialogue_key = "gift_hate"

	if not dialogues.has(dialogue_key):
		return "..."

	var dialogue_list: Array = dialogues[dialogue_key]
	if dialogue_list.is_empty():
		return "..."

	# 随机选择一条对话
	var random_index := randi() % dialogue_list.size()
	var dialogue_data = dialogue_list[random_index]

	if typeof(dialogue_data) == TYPE_STRING:
		return dialogue_data
	else:
		return dialogue_data.get("text", "...")

## 获取NPC名称
func get_npc_name(npc_id: String) -> String:
	if not _npc_data_cache.has(npc_id):
		return "???"

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	return npc_data.get("name", "???")

## 获取NPC描述
func get_npc_description(npc_id: String) -> String:
	if not _npc_data_cache.has(npc_id):
		return ""

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	return npc_data.get("description", "")

## 获取NPC角色
func get_npc_role(npc_id: String) -> String:
	if not _npc_data_cache.has(npc_id):
		return ""

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	return npc_data.get("role", "")

## 更新好感度
func _update_friendship(npc_id: String, change: int) -> void:
	if not _friendship_data.has(npc_id):
		_friendship_data[npc_id] = 0

	var max_friendship := get_max_friendship(npc_id)
	_friendship_data[npc_id] = clampi(_friendship_data[npc_id] + change, 0, max_friendship)

	var hearts := get_friendship_hearts(npc_id)
	friendship_updated.emit(npc_id, hearts)

	if EventBus:
		get_node("/root/EventBus").social.friendship_changed.emit(npc_id, hearts)

## 获取好感度值
func get_friendship(npc_id: String) -> int:
	return _friendship_data.get(npc_id, 0)

## 获取好感度心数
func get_friendship_hearts(npc_id: String) -> int:
	var friendship := get_friendship(npc_id)
	# 每10点好感度等于1颗心
	return friendship / 10

## 获取最大好感度
func get_max_friendship(npc_id: String) -> int:
	if not _npc_data_cache.has(npc_id):
		return 100

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	var max_hearts: int = npc_data.get("max_friendship", 10)
	return max_hearts * 10

## 检查是否是NPC生日
func is_npc_birthday(npc_id: String) -> bool:
	if not _npc_data_cache.has(npc_id):
		return false

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	var birthday: Dictionary = npc_data.get("birthday", {})

	if birthday.is_empty():
		return false

	if not TimeManager:
		return false

	var current_season: String = get_node("/root/TimeManager").get_season_name().to_lower()
	var current_day: int = get_node("/root/TimeManager").current_day

	var birthday_season: String = birthday.get("season", "").to_lower()
	var birthday_day: int = birthday.get("day", 0)

	return current_season == birthday_season and current_day == birthday_day

## 获取NPC生日信息
func get_npc_birthday(npc_id: String) -> Dictionary:
	if not _npc_data_cache.has(npc_id):
		return {}

	var npc_data: Dictionary = _npc_data_cache[npc_id]
	return npc_data.get("birthday", {})

## 获取当前周数
func _get_current_week() -> int:
	if not TimeManager:
		return 1

	var day: int = get_node("/root/TimeManager").current_day
	return (day - 1) / 7 + 1

## 检查本周是否已送礼
func _has_gifted_this_week(npc_id: String, item_id: String, week: int) -> bool:
	if not _gift_history.has(npc_id):
		return false

	var npc_history: Dictionary = _gift_history[npc_id]
	if not npc_history.has(week):
		return false

	var week_history: Dictionary = npc_history[week]
	return week_history.has(item_id)

## 记录送礼
func _record_gift(npc_id: String, item_id: String) -> void:
	var week := _get_current_week()

	if not _gift_history.has(npc_id):
		_gift_history[npc_id] = {}

	var npc_history: Dictionary = _gift_history[npc_id]
	if not npc_history.has(week):
		npc_history[week] = {}

	var week_history: Dictionary = npc_history[week]
	week_history[item_id] = true

## 获取NPC偏好预览
func get_preference_preview(npc_id: String, item_id: String) -> String:
	var reaction := get_reaction_type(npc_id, item_id)

	match reaction:
		ReactionType.LOVE: return "最爱"
		ReactionType.LIKE: return "喜欢"
		ReactionType.DISLIKE: return "不喜欢"
		ReactionType.HATE: return "讨厌"
		_: return "一般"

## 获取所有NPC ID列表
func get_all_npc_ids() -> Array:
	return _npc_data_cache.keys()

## 妫€鏌?NPC 鏄惁瀛樺湪
func has_npc(npc_id: String) -> bool:
	return _npc_data_cache.has(npc_id)

## 获取NPC数据
func get_npc_data(npc_id: String) -> Dictionary:
	return _npc_data_cache.get(npc_id, {})

## 获取反应类型名称
func get_reaction_name(reaction: int) -> String:
	match reaction:
		ReactionType.LOVE: return "love"
		ReactionType.LIKE: return "like"
		ReactionType.NEUTRAL: return "neutral"
		ReactionType.DISLIKE: return "dislike"
		ReactionType.HATE: return "hate"
		_: return "neutral"

## 保存送礼系统数据
func get_save_data() -> Dictionary:
	return {
		"friendship": _friendship_data.duplicate(),
		"gift_history": _gift_history.duplicate()
	}

## 加载送礼系统数据
func load_save_data(data: Dictionary) -> void:
	if data.has("friendship"):
		_friendship_data = data["friendship"].duplicate()
	if data.has("gift_history"):
		_gift_history = data["gift_history"].duplicate()

	print("[GiftSystem] Loaded save data")


func reset() -> void:
	_friendship_data.clear()
	_gift_history.clear()
	for npc_id in _npc_data_cache:
		_friendship_data[npc_id] = _npc_data_cache[npc_id].get("default_friendship", 0)
