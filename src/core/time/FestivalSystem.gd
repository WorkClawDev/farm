extends Node

enum FestivalType {
	SPRING_FLOWER,
	SUMMER_NIGHT,
	FALL_HARVEST,
	WINTER_SNOW,
}

const FESTIVALS := {
	FestivalType.SPRING_FLOWER: {
		"id": "spring_flower",
		"name": "Spring Flower Festival",
		"description": "A spring celebration focused on flowers and gathering.",
		"season": "Spring",
		"day": 14,
		"start_hour": 9,
		"end_hour": 18,
		"location": "village",
		"rewards": {
			"participation": {"money": 500, "items": {"flower_seed": 5}},
			"winner": {"money": 2000, "items": {"golden_flower": 1}},
		},
		"mini_game": "egg_hunt",
		"npc_participants": ["mayor", "farmer", "shopkeeper"],
	},
	FestivalType.SUMMER_NIGHT: {
		"id": "summer_night",
		"name": "Summer Night Festival",
		"description": "An evening festival by the beach with lights and games.",
		"season": "Summer",
		"day": 21,
		"start_hour": 18,
		"end_hour": 24,
		"location": "beach",
		"rewards": {
			"participation": {"money": 300, "items": {"firework": 3}},
			"winner": {"money": 1500, "items": {"golden_firework": 1}},
		},
		"mini_game": "fishing_tournament",
		"npc_participants": ["blacksmith", "doctor"],
	},
	FestivalType.FALL_HARVEST: {
		"id": "fall_harvest",
		"name": "Fall Harvest Festival",
		"description": "A village harvest celebration with farming contests.",
		"season": "Fall",
		"day": 16,
		"start_hour": 10,
		"end_hour": 20,
		"location": "village",
		"rewards": {
			"participation": {"money": 800, "items": {"quality_fertilizer": 10}},
			"winner": {"money": 5000, "items": {"golden_scythe": 1}},
		},
		"mini_game": "pumpkin_carving",
		"npc_participants": ["mayor", "farmer", "shopkeeper", "blacksmith"],
	},
	FestivalType.WINTER_SNOW: {
		"id": "winter_snow",
		"name": "Winter Snow Festival",
		"description": "A winter celebration with snow games in the village square.",
		"season": "Winter",
		"day": 25,
		"start_hour": 12,
		"end_hour": 22,
		"location": "village",
		"rewards": {
			"participation": {"money": 400, "items": {"hot_cocoa": 5}},
			"winner": {"money": 3000, "items": {"winter_star": 1}},
		},
		"mini_game": "snowball_fight",
		"npc_participants": ["doctor", "shopkeeper"],
	},
}

const MINIGAME_SCENES := {
	"egg_hunt": preload("res://src/minigames/EggHuntMinigame.gd"),
	"fishing_tournament": preload("res://src/minigames/FishingTournamentMinigame.gd"),
	"pumpkin_carving": preload("res://src/minigames/PumpkinCarvingMinigame.gd"),
	"snowball_fight": preload("res://src/minigames/SnowballFightMinigame.gd"),
}

const FESTIVAL_ACTIVITIES := {
	"spring_flower": [
		{
			"id": "spring_flower_main",
			"name": "Egg Hunt",
			"description": "Join the seasonal egg hunt.",
			"minigame": "egg_hunt",
		},
	],
	"summer_night": [
		{
			"id": "summer_night_main",
			"name": "Fishing Tournament",
			"description": "Compete in the summer fishing event.",
			"minigame": "fishing_tournament",
		},
	],
	"fall_harvest": [
		{
			"id": "fall_harvest_main",
			"name": "Pumpkin Carving",
			"description": "Show off your carving skills.",
			"minigame": "pumpkin_carving",
		},
	],
	"winter_snow": [
		{
			"id": "winter_snow_main",
			"name": "Snowball Fight",
			"description": "Take part in the snowball challenge.",
			"minigame": "snowball_fight",
		},
	],
}

signal festival_started(festival_type: int, festival_data: Dictionary)
signal festival_ended(festival_type: int)
signal festival_reward_given(rewards: Dictionary)

var current_festival: int = -1
var is_festival_active: bool = false
var festival_participation: Dictionary = {}
var festival_scores: Dictionary = {}
var festival_completed_activities: Dictionary = {}
var festival_claimed_rewards: Dictionary = {}
var _current_minigame: Node = null

func _ready() -> void:
	print("[FestivalSystem] Initialized")
	_connect_time_signals()

func _connect_time_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.hour_changed.connect(_on_hour_changed)
		time_manager.day_changed.connect(_on_day_changed)

func check_current_festival() -> int:
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return -1

	var current_season = time_manager.get_season_name()
	var current_day = time_manager.current_day
	var current_hour = int(time_manager.current_time)

	for festival_type in FESTIVALS.keys():
		var festival: Dictionary = FESTIVALS[festival_type]
		if festival.get("season", "") == current_season and festival.get("day", -1) == current_day:
			if current_hour >= festival.get("start_hour", 0) and current_hour < festival.get("end_hour", 24):
				return festival_type

	return -1

func _on_hour_changed(new_hour: int) -> void:
	if is_festival_active:
		if current_festival >= 0:
			var festival: Dictionary = FESTIVALS[current_festival]
			if new_hour >= festival.get("end_hour", 24):
				end_festival()
		return

	var festival_type := check_current_festival()
	if festival_type >= 0:
		start_festival(festival_type)

func _on_day_changed(_new_day: int) -> void:
	festival_participation.clear()
	festival_scores.clear()
	festival_completed_activities.clear()
	festival_claimed_rewards.clear()

func start_festival(festival_type: int) -> void:
	if is_festival_active or not FESTIVALS.has(festival_type):
		return

	current_festival = festival_type
	is_festival_active = true

	var festival: Dictionary = FESTIVALS[festival_type]
	var festival_id: String = festival.get("id", "")
	festival_started.emit(festival_type, festival)
	print("[FestivalSystem] Festival started: ", festival.get("name", "Unknown"))

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		if event_bus.festival:
			event_bus.festival.festival_started.emit(festival_id, get_festival_data(festival_id))
		if event_bus.ui:
			event_bus.ui.notification_shown.emit("%s started." % festival.get("name", "Festival"), 2)

	_open_festival_minigame(festival)

func end_festival() -> void:
	if not is_festival_active or current_festival < 0:
		return

	var festival: Dictionary = FESTIVALS[current_festival]
	var festival_id: String = festival.get("id", "")

	if _current_minigame != null:
		_cleanup_minigame(_current_minigame)

	_give_participation_rewards()
	_determine_winner()

	is_festival_active = false
	festival_ended.emit(current_festival)
	print("[FestivalSystem] Festival ended: ", festival.get("name", "Unknown"))

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.festival:
		event_bus.festival.festival_ended.emit(festival_id, get_festival_data(festival_id))

	current_festival = -1

func participate_in_festival() -> void:
	if not is_festival_active:
		return

	festival_participation["player"] = true
	print("[FestivalSystem] Player joined the festival")

func add_festival_score(points: int) -> void:
	if not is_festival_active:
		return

	festival_scores["player"] = festival_scores.get("player", 0) + points
	print("[FestivalSystem] Festival score +", points, " total=", festival_scores["player"])

func get_player_festival_score() -> int:
	return festival_scores.get("player", 0)

func _give_participation_rewards() -> void:
	if current_festival < 0:
		return

	var festival_id := _get_current_festival_id()
	if _is_reward_claimed(festival_id, "participation_reward"):
		return

	var festival: Dictionary = FESTIVALS[current_festival]
	var rewards: Dictionary = festival.get("rewards", {}).get("participation", {})
	_mark_reward_claimed(festival_id, "participation_reward")
	_give_rewards(rewards)

func _determine_winner() -> void:
	if current_festival < 0:
		return

	var festival: Dictionary = FESTIVALS[current_festival]
	var festival_id: String = festival.get("id", "")
	var winner := "player"
	var max_score := 0

	for participant in festival_scores.keys():
		var participant_score: int = festival_scores[participant]
		if participant_score > max_score:
			max_score = participant_score
			winner = participant

	if winner == "player" and max_score > 0 and not _is_reward_claimed(festival_id, "winner_reward"):
		var rewards: Dictionary = festival.get("rewards", {}).get("winner", {})
		_mark_reward_claimed(festival_id, "winner_reward")
		_give_rewards(rewards)
		print("[FestivalSystem] Player won the festival")

func _give_rewards(rewards: Dictionary) -> void:
	var money_system = get_node_or_null("/root/MoneySystem")
	var inventory = get_node_or_null("/root/Inventory")

	if rewards.has("money") and money_system and money_system.has_method("add_money"):
		money_system.add_money(rewards["money"], money_system.IncomeSource.OTHER, "Festival reward")
		print("[FestivalSystem] Money awarded: ", rewards["money"])

	if rewards.has("items") and inventory and inventory.has_method("add_item"):
		var items: Dictionary = rewards["items"]
		for item_id in items.keys():
			var quantity: int = items[item_id]
			inventory.add_item(item_id, quantity)
			print("[FestivalSystem] Item awarded: ", item_id, " x", quantity)

	festival_reward_given.emit(rewards)

func get_current_festival_name() -> String:
	if current_festival < 0:
		return ""
	return FESTIVALS[current_festival].get("name", "")

func get_current_festival_description() -> String:
	if current_festival < 0:
		return ""
	return FESTIVALS[current_festival].get("description", "")

func is_in_festival() -> bool:
	return is_festival_active

func get_next_festival() -> Dictionary:
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return {}

	var current_season = time_manager.get_season_name()
	var current_day = time_manager.current_day

	for festival_type in FESTIVALS.keys():
		var festival: Dictionary = FESTIVALS[festival_type]
		if festival.get("season", "") == current_season and festival.get("day", 0) > current_day:
			return {"type": festival_type, "data": festival}

	return {}

func get_all_festivals() -> Dictionary:
	return FESTIVALS.duplicate(true)

func get_festival_data(festival_id: String) -> Dictionary:
	var festival := _get_festival_by_id(festival_id)
	if festival.is_empty():
		return {}

	var data := festival.duplicate(true)
	data["activities"] = get_available_activities(festival_id)
	data["rewards"] = _build_reward_entries(festival_id)
	data["vendors"] = []
	return data

func get_festival_progress(festival_id: String) -> Dictionary:
	var activities = FESTIVAL_ACTIVITIES.get(festival_id, [])
	var completed_map: Dictionary = festival_completed_activities.get(festival_id, {})
	var completed := 0
	for activity in activities:
		var activity_id: String = activity.get("id", "")
		if completed_map.get(activity_id, false):
			completed += 1

	return {
		"completed_activities": completed,
		"total_activities": activities.size(),
	}

func get_available_activities(festival_id: String) -> Array:
	var activities: Array = []
	var source: Array = FESTIVAL_ACTIVITIES.get(festival_id, [])
	var completed_map: Dictionary = festival_completed_activities.get(festival_id, {})

	for activity in source:
		var entry: Dictionary = activity.duplicate(true)
		entry["completed"] = completed_map.get(entry.get("id", ""), false)
		activities.append(entry)

	return activities

func save_state() -> Dictionary:
	return {
		"current_festival": current_festival,
		"is_festival_active": is_festival_active,
		"festival_participation": festival_participation.duplicate(true),
		"festival_scores": festival_scores.duplicate(true),
		"festival_completed_activities": festival_completed_activities.duplicate(true),
		"festival_claimed_rewards": festival_claimed_rewards.duplicate(true),
	}

func load_state(data: Dictionary) -> void:
	current_festival = data.get("current_festival", -1)
	is_festival_active = data.get("is_festival_active", false)
	festival_participation = data.get("festival_participation", {}).duplicate(true)
	festival_scores = data.get("festival_scores", {}).duplicate(true)
	festival_completed_activities = data.get("festival_completed_activities", {}).duplicate(true)
	festival_claimed_rewards = data.get("festival_claimed_rewards", {}).duplicate(true)
	print("[FestivalSystem] State loaded")

func _open_festival_minigame(festival: Dictionary) -> void:
	var mini_game_name: String = festival.get("mini_game", "")
	if mini_game_name.is_empty() or not MINIGAME_SCENES.has(mini_game_name):
		print("[FestivalSystem] No minigame configured for festival: ", festival.get("name", "Unknown"))
		return

	var minigame_script = MINIGAME_SCENES[mini_game_name]
	if not minigame_script:
		return

	var minigame := Node.new()
	minigame.set_script(minigame_script)
	minigame.name = "FestivalMinigame"

	if minigame.has_signal("completed"):
		minigame.completed.connect(_on_minigame_completed.bind(minigame))
	if minigame.has_signal("cancelled"):
		minigame.cancelled.connect(_on_minigame_cancelled.bind(minigame))

	var root = get_tree().current_scene
	if root:
		root.add_child(minigame)
		_current_minigame = minigame
		if minigame.has_method("start_game"):
			minigame.start_game()
		print("[FestivalSystem] Opened minigame: ", mini_game_name)
	else:
		minigame.queue_free()

func complete_festival_activity(festival_id: String, activity_id: String) -> Dictionary:
	if not is_in_festival():
		return {"success": false, "message": "No active festival."}
	if festival_id != _get_current_festival_id():
		return {"success": false, "message": "Festival id mismatch."}

	var activities: Array = FESTIVAL_ACTIVITIES.get(festival_id, [])
	var found := false
	for activity in activities:
		if activity.get("id", "") == activity_id:
			found = true
			break
	if not found:
		return {"success": false, "message": "Activity not found."}

	var completed_map: Dictionary = festival_completed_activities.get(festival_id, {})
	if completed_map.get(activity_id, false):
		return {"success": false, "message": "Activity already completed."}

	completed_map[activity_id] = true
	festival_completed_activities[festival_id] = completed_map

	var rewards := _generate_activity_rewards(activity_id)
	_give_rewards(rewards)
	add_festival_score(100)
	participate_in_festival()

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.festival:
		event_bus.festival.festival_activity_completed.emit(festival_id, activity_id, rewards)

	return {"success": true, "rewards": rewards}

func claim_festival_reward(festival_id: String, reward_id: String) -> Dictionary:
	if not is_in_festival():
		return {"success": false, "message": "No active festival."}
	if festival_id != _get_current_festival_id():
		return {"success": false, "message": "Festival id mismatch."}
	if _is_reward_claimed(festival_id, reward_id):
		return {"success": false, "message": "Reward already claimed."}

	var reward := _get_reward_by_id(festival_id, reward_id)
	if reward.is_empty():
		return {"success": false, "message": "Reward not found."}

	var progress := get_festival_progress(festival_id)
	var required_activities: int = reward.get("requirements", {}).get("activities_completed", 0)
	if progress.get("completed_activities", 0) < required_activities:
		return {"success": false, "message": "Reward requirements not met."}

	_mark_reward_claimed(festival_id, reward_id)
	var payload: Dictionary = reward.get("payload", {})
	_give_rewards(payload)

	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.festival:
		event_bus.festival.festival_reward_claimed.emit(festival_id, reward_id)

	return {"success": true, "items": payload}

func _get_current_festival_id() -> String:
	if current_festival < 0 or not FESTIVALS.has(current_festival):
		return ""
	return FESTIVALS[current_festival].get("id", "")

func _generate_activity_rewards(_activity_id: String) -> Dictionary:
	return {"money": 50, "items": {}}

func _get_reward_by_id(festival_id: String, reward_id: String) -> Dictionary:
	for reward in _build_reward_entries(festival_id):
		if reward.get("id", "") == reward_id:
			return reward
	return {}

func _on_minigame_completed(score: int, success: bool, minigame: Node) -> void:
	print("[FestivalSystem] Minigame completed: score=", score, " success=", success)
	if success:
		add_festival_score(score)
	participate_in_festival()
	_cleanup_minigame(minigame)

func _on_minigame_cancelled(minigame: Node) -> void:
	print("[FestivalSystem] Minigame cancelled")
	_cleanup_minigame(minigame)

func _cleanup_minigame(minigame: Node) -> void:
	if minigame and is_instance_valid(minigame):
		minigame.queue_free()
	if _current_minigame == minigame:
		_current_minigame = null

func _get_festival_by_id(festival_id: String) -> Dictionary:
	for festival_type in FESTIVALS.keys():
		var festival: Dictionary = FESTIVALS[festival_type]
		if festival.get("id", "") == festival_id:
			return festival
	return {}

func _build_reward_entries(festival_id: String) -> Array:
	var festival := _get_festival_by_id(festival_id)
	if festival.is_empty():
		return []

	return [
		{
			"id": "participation_reward",
			"name": "Participation Reward",
			"description": "Complete the festival activity to claim this reward.",
			"requirements": {"activities_completed": 1},
			"payload": festival.get("rewards", {}).get("participation", {}),
		},
	]

func _is_reward_claimed(festival_id: String, reward_id: String) -> bool:
	var claimed: Dictionary = festival_claimed_rewards.get(festival_id, {})
	return claimed.get(reward_id, false)

func _mark_reward_claimed(festival_id: String, reward_id: String) -> void:
	var claimed: Dictionary = festival_claimed_rewards.get(festival_id, {})
	claimed[reward_id] = true
	festival_claimed_rewards[festival_id] = claimed
