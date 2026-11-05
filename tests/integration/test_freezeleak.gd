extends SceneTree

## Beach -> Village with TimeManager frozen the same way as --freeze-time
## (_time_frozen), then the same hop with the clock running.
## Prints time and day/night values before the hop, on the first process frame
## after Village becomes current, and on the 10th.
## Usage: godot --headless --path . --script res://tests/integration/test_freezeleak.gd

const BEACH := "res://src/world/maps/Beach.tscn"
const VILLAGE := "res://src/world/maps/Village.tscn"
## 21:15, night tint. Not the 9:00 new-game default or the 6:00 day-start default.
const SENTINEL_TIME := 21.25
const SENTINEL_DAY := 12
const SENTINEL_SEASON := 1
const SENTINEL_YEAR := 2
const SENTINEL_ACC := 0.25


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_before := _real_save_stamps()
	var save_manager := root.get_node("SaveManager")
	var tmp_save_dir := "user://freezeleak_saves_%d/" % Time.get_ticks_usec()
	save_manager.save_dir = tmp_save_dir
	var gm := root.get_node("GameManager")
	await gm.start_new_game(1)
	await _frames(8)
	if not await _go(BEACH, "from_village", "Beach"):
		_finish(1, real_before, tmp_save_dir)
		return
	var frozen_changed := await _measure("frozen", true)
	if not await _go(BEACH, "from_village", "Beach"):
		_finish(1, real_before, tmp_save_dir)
		return
	var live_changed := await _measure("live", false)
	_wipe_user_dir(tmp_save_dir)
	var saves_ok := _real_save_stamps() == real_before
	print("FREEZELEAK frozen_changed=%s live_changed=%s saves_ok=%s" % [frozen_changed, live_changed, saves_ok])
	print("FREEZELEAK DONE")
	quit(0 if saves_ok else 1)


## Returns true when time, calendar, freeze flag, accumulator, or tint moved.
func _measure(label: String, frozen: bool) -> bool:
	var tm := root.get_node("TimeManager")
	tm.current_time = SENTINEL_TIME
	tm.current_day = SENTINEL_DAY
	tm.current_season = SENTINEL_SEASON
	tm.current_year = SENTINEL_YEAR
	tm._time_accumulator = SENTINEL_ACC
	tm._time_frozen = frozen
	tm.time_changed.emit(tm.current_time)
	var before := _sample()
	_print_sample(label, "before", before)
	var st := root.get_node("SceneTransition")
	var frame1 := {}
	var frame10 := {}
	var seen := 0
	st.transition_to(VILLAGE, "from_beach")
	var guard := 0
	while seen < 10 and guard < 900:
		await process_frame
		guard += 1
		if current_scene == null or current_scene.name != "Village":
			continue
		seen += 1
		if seen == 1:
			frame1 = _sample()
			_print_sample(label, "frame1", frame1)
		elif seen == 10:
			frame10 = _sample()
			_print_sample(label, "frame10", frame10)
	if frame1.is_empty() or frame10.is_empty():
		print("FREEZELEAK %s TIMEOUT scene=%s" % [label, current_scene.name if current_scene else "null"])
		return true
	while st.is_transitioning and guard < 1200:
		await process_frame
		guard += 1
	var changed := not _same_clock(before, frame1) or not _same_clock(before, frame10)
	print("FREEZELEAK %s changed=%s" % [label, changed])
	return changed


func _go(path: String, spawn: String, expected: String) -> bool:
	var st := root.get_node("SceneTransition")
	var guard := 0
	while st.is_transitioning and guard < 600:
		await process_frame
		guard += 1
	st.transition_to(path, spawn)
	guard = 0
	while st.is_transitioning and guard < 900:
		await process_frame
		guard += 1
	await _frames(2)
	var ok := current_scene != null and current_scene.name == expected
	if not ok:
		print("FREEZELEAK hop failed want %s got %s" % [expected, current_scene.name if current_scene else "null"])
	return ok


func _sample() -> Dictionary:
	var tm := root.get_node("TimeManager")
	var tint_text := "none"
	var scene_name := "null"
	if current_scene != null:
		scene_name = str(current_scene.name)
		var tint := current_scene.get_node_or_null("DayNightTint")
		if tint != null:
			tint_text = str(tint.color)
	var season_now := -1
	var season_node := root.get_node_or_null("GameSession/SeasonSystem")
	if season_node != null and "current_season" in season_node:
		season_now = int(season_node.current_season)
	var weather := ""
	var weather_node := root.get_node_or_null("GameSession/WeatherSystem")
	if weather_node != null and "current_weather" in weather_node:
		weather = str(weather_node.current_weather)
	return {
		"time": float(tm.current_time),
		"clock": str(tm.get_formatted_time()),
		"date": str(tm.get_formatted_date()),
		"day": int(tm.current_day),
		"season": int(tm.current_season),
		"year": int(tm.current_year),
		"paused": bool(tm.is_paused),
		"frozen": bool(tm._time_frozen),
		"acc": float(tm._time_accumulator),
		"scale": float(tm.time_scale),
		"tint": tint_text,
		"scene": scene_name,
		"season_sys": season_now,
		"weather": weather,
	}


func _print_sample(label: String, when: String, sample: Dictionary) -> void:
	print("FREEZELEAK %s %s scene=%s time=%.6f clock=%s date=%s day=%d season=%d year=%d paused=%s frozen=%s acc=%.6f scale=%.3f tint=%s season_sys=%s weather=%s" % [
		label, when, sample["scene"], sample["time"], sample["clock"], sample["date"],
		sample["day"], sample["season"], sample["year"], sample["paused"], sample["frozen"],
		sample["acc"], sample["scale"], sample["tint"], sample["season_sys"], sample["weather"],
	])


func _same_clock(a: Dictionary, b: Dictionary) -> bool:
	return is_equal_approx(float(a["time"]), float(b["time"])) \
		and int(a["day"]) == int(b["day"]) \
		and int(a["season"]) == int(b["season"]) \
		and int(a["year"]) == int(b["year"]) \
		and is_equal_approx(float(a["acc"]), float(b["acc"])) \
		and bool(a["frozen"]) == bool(b["frozen"]) \
		and bool(a["paused"]) == bool(b["paused"]) \
		and str(a["tint"]) == str(b["tint"]) \
		and int(a["season_sys"]) == int(b["season_sys"]) \
		and str(a["weather"]) == str(b["weather"])


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _finish(code: int, real_before: Dictionary, tmp_save_dir: String) -> void:
	_wipe_user_dir(tmp_save_dir)
	var saves_ok := _real_save_stamps() == real_before
	print("FREEZELEAK aborted saves_ok=%s" % saves_ok)
	quit(code if saves_ok else 1)


func _real_save_stamps() -> Dictionary:
	var stamps := {}
	for slot in 3:
		var path := "user://saves/save_%d.json" % slot
		if FileAccess.file_exists(path):
			stamps[path] = "%s:%d" % [FileAccess.get_md5(path), FileAccess.get_modified_time(path)]
		else:
			stamps[path] = "missing"
	return stamps


func _wipe_user_dir(dir_path: String) -> void:
	var trimmed := dir_path.trim_suffix("/")
	var dir := DirAccess.open(trimmed)
	if dir != null:
		var names: Array[String] = []
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				names.append(entry)
			entry = dir.get_next()
		dir.list_dir_end()
		for name in names:
			dir.remove(name)
	var parent := DirAccess.open("user://")
	if parent != null:
		parent.remove(trimmed.get_file())
