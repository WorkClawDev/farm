extends Node

## SaveManager - 版本化 JSON 存档。

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_error(error_message: String)
signal load_error(error_message: String)

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves/"
const MAX_SAVE_SLOTS := 3

var _current_slot := -1
var _play_time := 0.0


func _ready() -> void:
	_ensure_save_directory()
	print("[SaveManager] Initialized (JSON v%d)" % SAVE_VERSION)


func _process(delta: float) -> void:
	if GameManager.is_game_active:
		_play_time += delta


func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot


func has_save(slot: int) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(get_save_path(slot))


func has_any_save() -> bool:
	for slot in range(MAX_SAVE_SLOTS):
		if has_save(slot):
			return true
	return false


func save_game(slot: int = -1) -> bool:
	if slot < 0:
		slot = _current_slot
	if not _is_valid_slot(slot):
		return _fail_save("Invalid save slot: %d" % slot)

	var snapshot := _gather_snapshot()
	var json_text := JSON.stringify(snapshot, "\t")
	var temp_path := get_save_path(slot) + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail_save("Cannot open temporary save file")
	file.store_string(json_text)
	file.flush()
	file.close()

	var verify := _read_snapshot_file(temp_path)
	if verify.is_empty():
		DirAccess.remove_absolute(temp_path)
		return _fail_save("Temporary save verification failed")

	var final_path := get_save_path(slot)
	var backup_path := final_path + ".bak"
	var had_existing_save := FileAccess.file_exists(final_path)
	if had_existing_save:
		if FileAccess.file_exists(backup_path):
			var stale_backup_error := DirAccess.remove_absolute(backup_path)
			if stale_backup_error != OK:
				DirAccess.remove_absolute(temp_path)
				return _fail_save("Cannot remove stale save backup: %s" % error_string(stale_backup_error))
		var backup_error := DirAccess.rename_absolute(final_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _fail_save("Cannot back up existing save: %s" % error_string(backup_error))

	var rename_error := DirAccess.rename_absolute(temp_path, final_path)
	if rename_error != OK:
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		var recovery_error := OK
		if had_existing_save and FileAccess.file_exists(backup_path):
			recovery_error = DirAccess.rename_absolute(backup_path, final_path)
		if recovery_error != OK:
			return _fail_save(
				"Failed to finalize save (%s); previous save remains at %s (%s)"
				% [error_string(rename_error), backup_path, error_string(recovery_error)]
			)
		return _fail_save("Failed to finalize save: %s" % error_string(rename_error))

	if had_existing_save and FileAccess.file_exists(backup_path):
		var cleanup_error := DirAccess.remove_absolute(backup_path)
		if cleanup_error != OK:
			push_warning("[SaveManager] Could not remove save backup: " + error_string(cleanup_error))

	_current_slot = slot
	game_saved.emit(slot)
	print("[SaveManager] Saved slot %d" % slot)
	return true


func load_snapshot(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		_fail_load("Invalid save slot: %d" % slot)
		return {}
	var snapshot := _read_snapshot_file(get_save_path(slot))
	if snapshot.is_empty():
		_fail_load("Save is missing, corrupt, or unsupported")
		return {}
	_current_slot = slot
	return snapshot


func mark_loaded(slot: int) -> void:
	_current_slot = slot
	game_loaded.emit(slot)


func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {"exists": false}
	var snapshot := _read_snapshot_file(get_save_path(slot))
	if snapshot.is_empty():
		return {"exists": false, "corrupt": true}
	var metadata: Dictionary = snapshot.get("metadata", {})
	var time: Dictionary = snapshot.get("time", {})
	var game: Dictionary = snapshot.get("game", {})
	var money: Dictionary = snapshot.get("money", {})
	var season_index := clampi(int(time.get("current_season", 0)), 0, TimeManager.SEASONS.size() - 1)
	return {
		"exists": true,
		"slot": slot,
		"timestamp": metadata.get("saved_at", 0),
		"play_time": metadata.get("play_time", 0.0),
		"season": season_index,
		"season_name": TimeManager.SEASONS[season_index],
		"day": int(time.get("current_day", 1)),
		"year": int(time.get("current_year", 1)),
		"money": int(money.get("money", 0)),
		"scene_path": str(game.get("scene_path", "")),
		"location": _scene_display_name(str(game.get("scene_path", ""))),
		"date": "Year %d, %s %d" % [
			int(time.get("current_year", 1)),
			TimeManager.SEASONS[season_index],
			int(time.get("current_day", 1)),
		],
	}


func get_all_save_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(MAX_SAVE_SLOTS):
		var info := get_save_info(slot)
		info["slot"] = slot
		result.append(info)
	return result


func get_latest_save_info() -> Dictionary:
	var latest: Dictionary = {}
	for info in get_all_save_summaries():
		if not info.get("exists", false):
			continue
		if latest.is_empty() or int(info.get("timestamp", 0)) > int(latest.get("timestamp", 0)):
			latest = info
	return latest


func get_latest_save_slot() -> int:
	return int(get_latest_save_info().get("slot", -1))


func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	var error := DirAccess.remove_absolute(get_save_path(slot))
	if error == OK and _current_slot == slot:
		_current_slot = -1
	return error == OK


func get_current_slot() -> int:
	return _current_slot


func get_play_time() -> float:
	return _play_time


func get_formatted_play_time() -> String:
	var total_seconds := int(_play_time)
	return "%02d:%02d:%02d" % [
		total_seconds / 3600,
		(total_seconds % 3600) / 60,
		total_seconds % 60,
	]


func reset_session(slot: int) -> void:
	_current_slot = slot
	_play_time = 0.0


func apply_global_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != SAVE_VERSION:
		return false
	TimeManager.load_state(snapshot.get("time", {}))
	MoneySystem.load_state(snapshot.get("money", {}))
	Inventory.load_state(snapshot.get("inventory", {}))
	StaminaManager.load_state(snapshot.get("stamina", {}))
	ShippingSystem.load_state(snapshot.get("shipping", {}))
	if not FarmState.load_save_state(snapshot.get("farm", {})):
		return false
	if snapshot.has("quest"):
		QuestSystem.load_state(snapshot.get("quest", {}))
	if snapshot.has("gift"):
		GiftSystem.load_save_data(snapshot.get("gift", {}))
	if snapshot.has("friendship"):
		Friendship.load_state(snapshot.get("friendship", {}))
	if snapshot.has("npc"):
		NPCManager.load_state(snapshot.get("npc", {}))
	if snapshot.has("house"):
		HouseUpgradeSystem.load_state(snapshot.get("house", {}))
	if snapshot.has("achievements"):
		AchievementSystem.load_state(snapshot.get("achievements", {}))
	if snapshot.has("festival"):
		FestivalSystem.load_state(snapshot.get("festival", {}))
	if snapshot.has("weather"):
		GameSession.weather.load_state(snapshot.get("weather", {}))
	if snapshot.has("dialogue"):
		DialogueManager.load_state(snapshot.get("dialogue", {}))
	if snapshot.has("foraging"):
		ForagingSystem.load_state(snapshot.get("foraging", {}))
	if snapshot.has("crafting"):
		CraftingSystem.load_save_data(snapshot.get("crafting", {}))
	if snapshot.has("cooking"):
		CookingManager.load_save_data(snapshot.get("cooking", {}))
	else:
		CookingManager.reset()
	if snapshot.has("fishing"):
		FishingSystem.load_state(snapshot.get("fishing", {}))
	if snapshot.has("season"):
		GameSession.season.load_state(snapshot.get("season", {}))
	var metadata: Dictionary = snapshot.get("metadata", {})
	_play_time = float(metadata.get("play_time", 0.0))
	return true


func _gather_snapshot() -> Dictionary:
	var player_data: Dictionary = {}
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player_data = {
			"position_x": player.global_position.x,
			"position_y": player.global_position.y,
			"direction": int(player.current_direction),
		}
	var current_scene := "res://src/world/maps/Farm.tscn"
	if get_tree().current_scene and not get_tree().current_scene.scene_file_path.is_empty():
		current_scene = get_tree().current_scene.scene_file_path
	return {
		"version": SAVE_VERSION,
		"metadata": {
			"saved_at": Time.get_unix_time_from_system(),
			"play_time": _play_time,
		},
		"game": {
			"scene_path": current_scene,
			"spawn_point": GameManager.current_spawn_point,
		},
		"time": TimeManager.save_state(),
		"player": player_data,
		"inventory": Inventory.save_state(),
		"money": MoneySystem.save_state(),
		"stamina": StaminaManager.save_state(),
		"farm": FarmState.get_save_state(),
		"shipping": ShippingSystem.save_state(),
		"quest": QuestSystem.save_state(),
		"gift": GiftSystem.get_save_data(),
		"friendship": Friendship.save_state(),
		"npc": NPCManager.save_state(),
		"house": HouseUpgradeSystem.save_state(),
		"achievements": AchievementSystem.save_state(),
		"festival": FestivalSystem.save_state(),
		"weather": GameSession.weather.save_state(),
		"dialogue": DialogueManager.save_state(),
		"foraging": ForagingSystem.save_state(),
		"crafting": CraftingSystem.get_save_data(),
		"cooking": CookingManager.get_save_data(),
		"fishing": FishingSystem.save_state(),
		"season": GameSession.season.save_state(),
	}


func _read_snapshot_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.data
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		return {}
	for required in ["metadata", "game", "time", "inventory", "money", "stamina", "farm", "shipping"]:
		if not data.has(required):
			return {}
	return data


func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < MAX_SAVE_SLOTS


func _fail_save(message: String) -> bool:
	push_error("[SaveManager] " + message)
	save_error.emit(message)
	return false


func _fail_load(message: String) -> void:
	push_error("[SaveManager] " + message)
	load_error.emit(message)


func _scene_display_name(scene_path: String) -> String:
	var filename := scene_path.get_file().get_basename()
	return {
		"Farm": "农场",
		"PlayerHouse": "家",
		"Village": "村庄",
		"Beach": "海滩",
		"Forest": "森林",
		"Mine": "矿洞",
	}.get(filename, "农场")
