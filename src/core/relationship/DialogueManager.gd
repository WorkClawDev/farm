extends Node

## DialogueManager - 对话管理器
## 负责加载对话数据、条件检测、触发对话、处理分支

signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal dialogue_line_displayed(speaker: String, text: String)
signal choice_made(choice_index: int, choice_data: Dictionary)
signal effect_triggered(effect_type: String, effect_data: Dictionary)

# 对话数据
var _dialogue_data: Dictionary = {}
var _npc_data: Dictionary = {}

# 当前对话状态
var _current_npc_id: String = ""
var _current_dialogue_id: String = ""
var _current_branch: String = ""
var _current_line_index: int = 0
var _is_in_dialogue: bool = false

# 玩家状态（用于条件检测）
var _player_flags: Dictionary = {}
var _player_stats: Dictionary = {}

# 好感度数据
var _friendship_data: Dictionary = {}

# DialogueBox 引用
var _dialogue_box: DialogueBox = null

# 数据路径
const DIALOGUE_DATA_PATH: String = "res://data/dialogues.json"
const DIALOGUE_BOX_SCENE := preload("res://src/ui/dialogs/DialogueBox.tscn")
const DIALOGUE_ID_ALIASES := {
	"farmer_joe": "farmer",
	"shopkeeper_lily": "merchant",
	"blacksmith_tom": "blacksmith",
	"doctor_mary": "doctor",
}

func _ready() -> void:
	print("[DialogueManager] Initialized")
	_load_dialogue_data()
	_connect_event_bus()
	_ensure_dialogue_box()

func _ensure_dialogue_box() -> void:
	if _dialogue_box:
		return
	var canvas := CanvasLayer.new()
	canvas.name = "DialogueCanvas"
	canvas.layer = 80
	add_child(canvas)
	var box := DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(box)
	set_dialogue_box(box)

func _connect_event_bus() -> void:
	if EventBus:
		get_node("/root/EventBus").social.dialogue_started.connect(_on_event_dialogue_started)
		get_node("/root/EventBus").social.dialogue_ended.connect(_on_event_dialogue_ended)

## 加载对话数据
func _load_dialogue_data() -> void:
	var file = FileAccess.open(DIALOGUE_DATA_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result == OK:
			_dialogue_data = json.data.get("dialogues", {})
			_npc_data = json.data.get("npcs", {})
			print("[DialogueManager] Loaded dialogue data for ", _dialogue_data.size(), " NPCs")
		else:
			push_error("[DialogueManager] Failed to parse dialogue data: " + json.get_error_message())
	else:
		push_warning("[DialogueManager] Dialogue data file not found at: " + DIALOGUE_DATA_PATH)

## 设置 DialogueBox 引用
func set_dialogue_box(dialogue_box: DialogueBox) -> void:
	if _dialogue_box:
		_disconnect_dialogue_box_signals()

	_dialogue_box = dialogue_box

	if _dialogue_box:
		_connect_dialogue_box_signals()

func _connect_dialogue_box_signals() -> void:
	if _dialogue_box:
		_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
		_dialogue_box.choice_selected.connect(_on_choice_selected)

func _disconnect_dialogue_box_signals() -> void:
	if _dialogue_box:
		if _dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
			_dialogue_box.dialogue_finished.disconnect(_on_dialogue_finished)
		if _dialogue_box.choice_selected.is_connected(_on_choice_selected):
			_dialogue_box.choice_selected.disconnect(_on_choice_selected)

## 开始与 NPC 对话
func start_dialogue(npc_id: String, dialogue_key: String = "") -> bool:
	if _is_in_dialogue:
		push_warning("[DialogueManager] Already in dialogue")
		return false

	var source_npc_id: String = DIALOGUE_ID_ALIASES.get(npc_id, npc_id)
	if not _dialogue_data.has(source_npc_id):
		push_warning("[DialogueManager] No dialogue data for NPC: " + npc_id)
		return false

	# 查找合适的对话
	var dialogue = _find_dialogue(source_npc_id, dialogue_key)
	if dialogue.is_empty():
		push_warning("[DialogueManager] No valid dialogue found for: " + npc_id)
		return false

	# 设置当前对话状态
	_current_npc_id = npc_id
	_current_dialogue_id = dialogue.get("id", "")
	_current_branch = ""
	_current_line_index = 0
	_is_in_dialogue = true

	# 获取 NPC 名称
	var npc_name = _get_npc_name(source_npc_id)

	# 显示对话
	if _dialogue_box:
		_dialogue_box.show_dialogue_advanced({
			"speaker": npc_name,
			"lines": dialogue.get("lines", [])
		})

	dialogue_started.emit(npc_id)
	if EventBus:
		get_node("/root/EventBus").social.dialogue_started.emit(npc_id)

	print("[DialogueManager] Started dialogue: ", _current_dialogue_id)
	GameManager.current_state = GameManager.GameState.DIALOGUE
	return true

## 查找可用的对话
func _find_dialogue(npc_id: String, preferred_key: String = "") -> Dictionary:
	var npc_dialogues = _dialogue_data.get(npc_id, {})

	if npc_dialogues.is_empty():
		return {}

	# 如果指定了对话键，优先使用
	if preferred_key != "" and npc_dialogues.has(preferred_key):
		var dialogue = npc_dialogues[preferred_key]
		if _check_conditions(dialogue.get("conditions", [])):
			return dialogue

	# 按优先级排序找到最高优先级的可用对话
	var best_dialogue: Dictionary = {}
	var best_priority: int = -999

	for key in npc_dialogues.keys():
		var dialogue = npc_dialogues[key]
		var priority = dialogue.get("priority", 0)

		if priority > best_priority:
			if _check_conditions(dialogue.get("conditions", [])):
				best_dialogue = dialogue
				best_priority = priority

	return best_dialogue

## 检查对话条件
func _check_conditions(conditions: Array) -> bool:
	for condition in conditions:
		if not _check_single_condition(condition):
			return false
	return true

## 检查单个条件
func _check_single_condition(condition: Dictionary) -> bool:
	var condition_type = condition.get("type", "")

	match condition_type:
		"flag":
			var key = condition.get("key", "")
			var expected = condition.get("value", true)
			return _player_flags.get(key, false) == expected

		"time":
			var current_time = get_node("/root/TimeManager").current_time if TimeManager else 6.0
			var min_time = condition.get("min", 0.0)
			var max_time = condition.get("max", 24.0)
			return current_time >= min_time and current_time < max_time

		"season":
			var current_season = get_node("/root/TimeManager").get_season_name() if TimeManager else "Spring"
			var expected_season = condition.get("value", "Spring")
			return current_season == expected_season

		"day":
			var current_day = get_node("/root/TimeManager").current_day if TimeManager else 1
			var expected_day = condition.get("value", 1)
			return current_day == expected_day

		"friendship":
			var npc = condition.get("npc", "")
			var min_hearts = condition.get("min", 0)
			var hearts = get_friendship_hearts(npc)
			return hearts >= min_hearts

		"player_energy":
			var max_energy = condition.get("max", 100)
			var current_energy = StaminaManager.current_stamina if StaminaManager else 100.0
			return current_energy <= max_energy

		"money":
			var min_money = condition.get("min", 0)
			var current_money = MoneySystem.get_money() if MoneySystem else 0
			return current_money >= min_money

		"weather":
			# WeatherSystem 未实现，始终返回 true
			return true

		"random":
			var chance = condition.get("chance", 1.0)
			return randf() < chance

		_:
			push_warning("[DialogueManager] Unknown condition type: " + condition_type)
			return true

	return true

## 获取 NPC 名称
func _get_npc_name(npc_id: String) -> String:
	if _npc_data.has(npc_id):
		return _npc_data[npc_id].get("name", npc_id)
	return npc_id

## 对话结束回调
func _on_dialogue_finished() -> void:
	if not _is_in_dialogue:
		return

	var npc_id = _current_npc_id
	_is_in_dialogue = false
	_current_npc_id = ""
	_current_dialogue_id = ""

	dialogue_ended.emit(npc_id)
	if EventBus:
		get_node("/root/EventBus").social.dialogue_ended.emit(npc_id)

	print("[DialogueManager] Dialogue ended")
	if GameManager.is_game_active:
		GameManager.current_state = GameManager.GameState.PLAYING

## 选项选择回调
func _on_choice_selected(choice_index: int) -> void:
	print("[DialogueManager] Choice selected: ", choice_index)

	# 获取当前对话的分支数据
	var current_dialogue = _get_current_dialogue()
	if current_dialogue.is_empty():
		return

	var lines = current_dialogue.get("lines", [])
	if _current_line_index >= lines.size():
		return

	var current_line = lines[_current_line_index]
	var choices = current_line.get("choices", [])

	if choice_index >= choices.size():
		return

	var choice_data = choices[choice_index]

	# 触发选项效果
	choice_made.emit(choice_index, choice_data)

	# 处理分支
	if choice_data.has("next"):
		_show_branch(choice_data["next"])

## 显示分支对话
func _show_branch(branch_id: String) -> void:
	var current_dialogue = _get_current_dialogue()
	if current_dialogue.is_empty():
		return

	var branches = current_dialogue.get("branches", {})
	if not branches.has(branch_id):
		push_warning("[DialogueManager] Branch not found: " + branch_id)
		return

	var branch_data = branches[branch_id]

	# 触发分支效果
	_trigger_effects(branch_data.get("effects", []))

	# 显示分支对话
	if _dialogue_box and branch_data.has("lines"):
		var npc_name = _get_npc_name(_current_npc_id)
		_dialogue_box.show_dialogue_advanced({
			"speaker": npc_name,
			"lines": branch_data["lines"]
		})

## 获取当前对话数据
func _get_current_dialogue() -> Dictionary:
	if _current_npc_id.is_empty() or _current_dialogue_id.is_empty():
		return {}

	var source_npc_id: String = DIALOGUE_ID_ALIASES.get(_current_npc_id, _current_npc_id)
	var npc_dialogues = _dialogue_data.get(source_npc_id, {})
	for key in npc_dialogues.keys():
		if npc_dialogues[key].get("id", "") == _current_dialogue_id:
			return npc_dialogues[key]

	return {}

## 触发效果
func _trigger_effects(effects: Array) -> void:
	for effect in effects:
		_trigger_single_effect(effect)

## 触发单个效果
func _trigger_single_effect(effect: Dictionary) -> void:
	var effect_type = effect.get("type", "")

	match effect_type:
		"set_flag":
			var key = effect.get("key", "")
			var value = effect.get("value", true)
			_player_flags[key] = value
			print("[DialogueManager] Set flag: ", key, " = ", value)

		"add_friendship":
			var npc = effect.get("npc", "")
			var amount = effect.get("amount", 0)
			add_friendship_points(npc, amount)

		"add_money":
			var amount = effect.get("amount", 0)
			if MoneySystem:
				MoneySystem.add_money(amount, MoneySystem.IncomeSource.OTHER, "dialogue_reward")

		"remove_money":
			var amount = effect.get("amount", 0)
			if MoneySystem:
				MoneySystem.spend_money(amount, MoneySystem.ExpenseType.OTHER, "dialogue_cost")

		"complete_quest":
			var quest_id = effect.get("quest_id", "")
			if QuestSystem and QuestSystem.has_method("turn_in_quest"):
				var ok = QuestSystem.turn_in_quest(quest_id)
				print("[DialogueManager] Complete quest: %s -> %s" % [quest_id, "ok" if ok else "failed"])
			else:
				print("[DialogueManager] Complete quest (no system): ", quest_id)

		"unlock_shop":
			var shop_id = effect.get("shop", "")
			# ShopSystem 未实现，记录日志
			print("[DialogueManager] Unlock shop (no system): ", shop_id)

		"trigger_dialogue":
			var npc = effect.get("npc", "")
			var dialogue = effect.get("dialogue", "")
			# 延迟触发下一个对话
			call_deferred("start_dialogue", npc, dialogue)

		_:
			push_warning("[DialogueManager] Unknown effect type: " + effect_type)

	effect_triggered.emit(effect_type, effect)

## 好感度系统
func add_friendship_points(npc_id: String, points: int) -> void:
	if not _friendship_data.has(npc_id):
		_friendship_data[npc_id] = {"hearts": 0, "points": 0}

	var data = _friendship_data[npc_id]
	data["points"] += points

	# 每250点增加一颗心
	var new_hearts = data["points"] / 250
	if new_hearts > data["hearts"]:
		data["hearts"] = min(new_hearts, 10)
		print("[DialogueManager] Friendship with ", npc_id, " increased to ", data["hearts"], " hearts")

	if EventBus:
		get_node("/root/EventBus").social.friendship_changed.emit(npc_id, data["hearts"])

func get_friendship_hearts(npc_id: String) -> int:
	if _friendship_data.has(npc_id):
		return _friendship_data[npc_id].get("hearts", 0)
	return 0

func get_friendship_points(npc_id: String) -> int:
	if _friendship_data.has(npc_id):
		return _friendship_data[npc_id].get("points", 0)
	return 0

## 设置玩家标志
func set_flag(key: String, value: Variant) -> void:
	_player_flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return _player_flags.get(key, default)

func has_flag(key: String) -> bool:
	return _player_flags.has(key)

## 检查是否在对话中
func is_in_dialogue() -> bool:
	return _is_in_dialogue

## 强制结束对话
func force_end_dialogue() -> void:
	if _dialogue_box:
		_dialogue_box.hide_dialogue()
	_on_dialogue_finished()

## 保存状态
func save_state() -> Dictionary:
	return {
		"flags": _player_flags.duplicate(),
		"friendship": _friendship_data.duplicate()
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	_player_flags = data.get("flags", {})
	_friendship_data = data.get("friendship", {})
	print("[DialogueManager] State loaded")


func reset() -> void:
	_player_flags.clear()
	_friendship_data.clear()
	_current_npc_id = ""
	_current_dialogue_id = ""
	_current_branch = ""
	_current_line_index = 0
	_is_in_dialogue = false
	if _dialogue_box:
		_dialogue_box.hide_dialogue()

## 事件总线回调
func _on_event_dialogue_started(npc_id: String) -> void:
	if not _is_in_dialogue:
		start_dialogue(npc_id)

func _on_event_dialogue_ended(npc_id: String) -> void:
	# 由 DialogueManager 自身触发，这里不需要额外处理
	pass

## 获取 NPC 数据
func get_npc_data(npc_id: String) -> Dictionary:
	return _npc_data.get(npc_id, {})

## 获取所有 NPC 列表
func get_all_npcs() -> Dictionary:
	return _npc_data.duplicate()

## 获取 NPC 好感度信息
func get_npc_friendship_info(npc_id: String) -> Dictionary:
	var base_data = _npc_data.get(npc_id, {})
	var friendship = _friendship_data.get(npc_id, {"hearts": 0, "points": 0})

	return {
		"id": npc_id,
		"name": base_data.get("name", npc_id),
		"hearts": friendship.get("hearts", 0),
		"points": friendship.get("points", 0),
		"max_hearts": 10
	}
