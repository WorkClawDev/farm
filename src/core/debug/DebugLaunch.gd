extends RefCounted

## Debug-only boot switches from OS.get_cmdline_user_args().
## Ignored unless OS.is_debug_build() (release exports never apply these).
##
##   godot --path . -- --load-slot=3 --spawn=village_west
##   godot --path . -- --new-game
##   godot --path . -- --new-game --start-day=14 --season=summer --debug-crops
##
## --load-slot=N uses the menu number N (1..3). The save file is slot N-1.
## --spawn= selects an entry in SPAWNS and is applied after that save loads.
## --new-game starts a new game. Each launch gets its own save_dir under
## user://debug_tmp_saves_<id>/, never user://saves/.
## --start-day, --season and --debug-crops are read with --new-game and ignored
## otherwise. They never touch user://saves/. --debug-crops takes no value.

## Old fixed directory. Cleared on --new-game so a previous autosave cannot be loaded from it.
const DEBUG_NEW_GAME_SAVE_DIR := "user://debug_tmp_saves/"

## --start-day=N is 1..28, matching TimeManager.DAYS_PER_SEASON.
const START_DAY_MIN := 1
const START_DAY_MAX := 28
const SEASON_NAMES := {
	"spring": 0,
	"summer": 1,
	"fall": 2,
	"winter": 3,
}

const SPAWNS := {
	# West road, just east of ToFarmArea. Same spot Village uses for from_farm,
	# outside the exit trigger (the trigger's right edge is about x=120).
	"village_west": {
		"scene": "res://src/world/maps/Village.tscn",
		"spawn_point": "village_west",
		"position": Vector2(150, 300),
	},
}


static func from_cmdline() -> Dictionary:
	return parse(OS.get_cmdline_user_args(), OS.is_debug_build())


static func apply_debug_new_game_save_dir() -> void:
	_clear_legacy_debug_saves()
	SaveManager.save_dir = "user://debug_tmp_saves_%d_%d/" % [Time.get_ticks_usec(), randi()]


static func _clear_legacy_debug_saves() -> void:
	var dir := DirAccess.open(DEBUG_NEW_GAME_SAVE_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != ".." and not dir.current_is_dir():
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for name in names:
		dir.remove(name)


static func parse(args: PackedStringArray, debug_build: bool) -> Dictionary:
	var result := {
		"slot": -1,
		"spawn": "",
		"new_game": false,
		"start_day": 0,
		"season": "",
		"debug_crops": false,
	}
	if not debug_build:
		return result
	for arg in args:
		var text := str(arg).strip_edges()
		if text == "--new-game":
			result["new_game"] = true
		elif text.begins_with("--load-slot="):
			var raw := text.substr("--load-slot=".length())
			if raw.is_valid_int():
				var ui_slot := int(raw)
				if ui_slot >= 1 and ui_slot <= 3:
					result["slot"] = ui_slot - 1
		elif text.begins_with("--spawn="):
			var spawn_id := text.substr("--spawn=".length())
			if SPAWNS.has(spawn_id):
				result["spawn"] = spawn_id
		elif text.begins_with("--start-day="):
			var day_text := text.substr("--start-day=".length()).strip_edges()
			if day_text.is_valid_int():
				var day := int(day_text)
				if day >= START_DAY_MIN and day <= START_DAY_MAX:
					result["start_day"] = day
		elif text.begins_with("--season="):
			var season_name := text.substr("--season=".length()).strip_edges().to_lower()
			if SEASON_NAMES.has(season_name):
				result["season"] = season_name
		elif text == "--debug-crops":
			result["debug_crops"] = true
	# These three only take effect on a debug new game. Drop them otherwise,
	# including when they were passed before --new-game was seen.
	if not bool(result["new_game"]):
		result["start_day"] = 0
		result["season"] = ""
		result["debug_crops"] = false
	return result


## Called from GameManager.start_new_game after the new-game resets, and only
## when this process was launched with --new-game. Menu "创建农场" does not pass
## that flag, so a normal new game stays on day 1 / spring / empty field.
static func apply_new_game_options(launch: Dictionary) -> void:
	if not bool(launch.get("new_game", false)):
		return
	var day := int(launch.get("start_day", 0))
	var season_name := str(launch.get("season", ""))
	var plant_crops := bool(launch.get("debug_crops", false))
	if day <= 0 and season_name == "" and not plant_crops:
		return
	if day >= START_DAY_MIN and day <= START_DAY_MAX:
		TimeManager.current_day = day
		TimeManager.current_time = 9.0
	if SEASON_NAMES.has(season_name):
		var season_index := int(SEASON_NAMES[season_name])
		TimeManager.current_season = season_index
		if GameSession != null and GameSession.season != null:
			GameSession.season.current_season = season_index
	var placed := false
	if plant_crops:
		var tomato_ok := FarmState.place_debug_crop_before_mature("tomato", FarmState.DEBUG_FIRST_RIDGE)
		var bean_ok := FarmState.place_debug_crop_before_mature("green_bean", FarmState.DEBUG_SECOND_RIDGE)
		placed = tomato_ok and bean_ok
		if not placed:
			push_warning("[DebugLaunch] --debug-crops failed tomato=%s green_bean=%s" % [tomato_ok, bean_ok])
	print("[DebugLaunch] --new-game day=%s season=%s crops=%s time=9:00" % [
		str(day) if day >= START_DAY_MIN else "-",
		season_name if season_name != "" else "-",
		"tomato,green_bean" if placed else "-",
	])


static func spawn_spec(spawn_id: String) -> Dictionary:
	if not SPAWNS.has(spawn_id):
		return {}
	return SPAWNS[spawn_id]
