extends SceneTree
## Village night: villagers walk to their doors, rest overnight (time runs on past
## midnight to 2:00 without script errors, BUG-48), and reappear at their doors at 6:00
## (BUG-47). Runs through the real SceneTransition and TimeManager.

const VILLAGE := "res://src/world/maps/Village.tscn"
const DOOR_TOLERANCE := 8.0
const WALK_TIME_SCALE := 3.0
const OUTDOOR := {"Farm": "res://src/world/maps/Farm.tscn", "Forest": "res://src/world/maps/Forest.tscn", "Beach": "res://src/world/maps/Beach.tscn"}
const INDOOR := {"PlayerHouse": "res://src/world/maps/PlayerHouse.tscn", "Mine": "res://src/world/maps/Mine.tscn"}

class ErrorLog extends Logger:
	var messages: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])

var _errors := ErrorLog.new()
var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_saves_before := _real_save_stamps()
	var save_manager := root.get_node("SaveManager")
	var tmp_save_dir := "user://night_cycle_saves_%d/" % Time.get_ticks_usec()
	save_manager.save_dir = tmp_save_dir
	var gm := root.get_node("GameManager")
	var tm := root.get_node("TimeManager")
	await gm.start_new_game(1)
	await _frames(10)
	OS.add_logger(_errors)
	tm.current_time = 19.9
	var st := root.get_node("SceneTransition")
	st.transition_to(VILLAGE, "from_beach")
	await process_frame
	while st.is_transitioning:
		await process_frame
	_record("经场景切换进入村庄", current_scene != null and current_scene.name == "Village")
	var npcs := {}
	for n in current_scene.get_node("NPCs").get_children():
		if "npc_id" in n:
			npcs[n.npc_id] = n
	# 20:00 -> Joe, Tom, Mary; 21:00 -> mayor, Lily.
	await _watch_walk_home(npcs, ["farmer_joe", "blacksmith_tom", "doctor_mary"])
	tm.current_time = 20.98
	await _watch_walk_home(npcs, ["mayor", "shopkeeper_lily"])

	# Let the night run fast through midnight to the forced 2:00 day end.
	var day := int(tm.current_day)
	var errors_before := _errors.messages.size()
	tm.set_time_scale(60.0)
	var tint := current_scene.get_node_or_null("DayNightTint") as CanvasModulate
	var midnight_tint := Color.WHITE
	var all_rest_after_midnight := true
	var saw_after_midnight := false
	var t0 := Time.get_ticks_msec()
	while int(tm.current_day) == day and Time.get_ticks_msec() - t0 < 20000:
		await physics_frame
		if tm.current_time >= 24.2 and tm.current_time < 26.0:
			saw_after_midnight = true
			if tint:
				midnight_tint = tint.color
			for id in npcs:
				all_rest_after_midnight = all_rest_after_midnight and npcs[id].is_resting and not npcs[id].visible
	var night_errors := _errors.messages.slice(errors_before)
	_record("时间跑过午夜到 2:00 无脚本错误（BUG-48）%s" % ("" if night_errors.is_empty() else "：" + "; ".join(night_errors.slice(0, 3))), night_errors.is_empty())
	_record("0:00–2:00 期间所有村民都在家休息", saw_after_midnight and all_rest_after_midnight)
	_record("2:00 结束当天并到第二天 6:00", int(tm.current_day) == day + 1 and is_equal_approx(tm.current_time, 6.0))
	_record("村庄半夜有夜晚色调（%s），白天恢复（%s）" % [midnight_tint, tint.get_class() + " " + str(tint.color) if tint else "无 DayNightTint"],
		tint != null and midnight_tint.v < 0.8 and tint.call("color_for_time", 12.0) == Color.WHITE)

	# 6:00: everybody comes back out at their own door.
	await _frames(3, true)
	var bad: Array[String] = []
	for id in npcs:
		var n: Node2D = npcs[id]
		var door: Dictionary = n._door_here()
		if door.is_empty() or n.is_resting or not n.visible or n.global_position.distance_to(door["position"]) > DOOR_TOLERANCE + 3.0:
			bad.append("%s@%s door %s resting=%s visible=%s" % [id, n.global_position.round(), door.get("position"), n.is_resting, n.visible])
	_record("6:00 五位村民都在自家门口重新出现%s" % ("" if bad.is_empty() else "：" + ", ".join(bad)), bad.is_empty())
	tm.set_time_scale(1.0)
	# Morning errands are back at normal walking speed (only the walk home is slow).
	var top_speed := 0.0
	var any_home := false
	for i in 60:
		await physics_frame
		for id in npcs:
			any_home = any_home or npcs[id].is_going_home
			if npcs[id].is_walking:
				top_speed = maxf(top_speed, npcs[id].velocity.length())
	_record("早上去日程地点用正常速度（最快 %.0f px/s），没人还在回家" % top_speed, not any_home and top_speed >= 70.0)

	await _check_tints(st, tm)

	_wipe_user_dir(tmp_save_dir)
	_record("过夜测试没有改写真实存档的内容或修改时间", _real_save_stamps() == real_saves_before)
	print("RESULTS: %d/%d passed" % [_passed, _passed + _failed])
	print("NIGHT CYCLE TESTS PASSED" if _failed == 0 else "NIGHT CYCLE TESTS FAILED")
	OS.remove_logger(_errors)
	gm.quit_game()


## Each villager starts walking, is seen strolling home for 15-30 game seconds
## (= game minutes), and rests at its door. Runs at WALK_TIME_SCALE to save time.
func _watch_walk_home(npcs: Dictionary, ids: Array) -> void:
	var walked := {}
	var start := {}
	for id in ids:
		walked[id] = 0.0
		start[id] = (npcs[id] as Node2D).global_position
	Engine.time_scale = WALK_TIME_SCALE
	var dt := WALK_TIME_SCALE / Engine.physics_ticks_per_second
	var game_seconds := 0.0
	while game_seconds < 90.0:
		await physics_frame
		game_seconds += dt
		var done := true
		for id in ids:
			var n = npcs[id]
			if n.is_going_home and n.is_walking:
				walked[id] += dt
			done = done and n.is_resting
		if done:
			break
	Engine.time_scale = 1.0
	for id in ids:
		var n = npcs[id]
		var door: Dictionary = n._door_here()
		var at_door: bool = not door.is_empty() and n.global_position.distance_to(door["position"]) <= DOOR_TOLERANCE
		var limit: float = n.GO_HOME_TIMEOUT
		_record("%s 从 %s 慢慢走回家门 %s（走了 %.1f s，超时 %.0f s）后休息" % [id, start[id].round(), door.get("position"), walked[id], limit],
			n.is_resting and at_door and walked[id] >= 14.0 and walked[id] <= 32.0 and walked[id] < limit - 10.0)


## Round 8: Farm/Forest/Beach darken at night like the village and are back to
## daylight at noon; PlayerHouse/Mine have no tint; the HUD is never tinted.
func _check_tints(st: Node, tm: Node) -> void:
	for map_name in OUTDOOR.keys() + INDOOR.keys():
		var path: String = OUTDOOR.get(map_name, INDOOR.get(map_name, ""))
		tm.current_time = 23.0
		st.transition_to(path, "house_entrance" if map_name == "PlayerHouse" else "from_village")
		await process_frame
		while st.is_transitioning:
			await process_frame
		await _frames(3)
		var scene := current_scene
		var tint := scene.find_children("*", "CanvasModulate", true, false)
		if INDOOR.has(map_name):
			_record("%s 没有昼夜色调" % map_name, scene.name == map_name and tint.is_empty())
			continue
		var night: Color = tint[0].color if tint.size() == 1 else Color.WHITE
		tm.current_time = 12.0
		tm.time_changed.emit(12.0)
		await _frames(2)
		var noon: Color = tint[0].color if tint.size() == 1 else Color.BLACK
		# The HUD and the dialogue box live on their own CanvasLayers; a CanvasModulate
		# only tints the canvas it is in (the world's).
		var hud := scene.find_child("HUD", true, false) as CanvasLayer
		var box_layer = root.get_node("DialogueManager")._dialogue_box.get_canvas_layer_node() if root.get_node("DialogueManager")._dialogue_box else null
		var ui_ok: bool = tint.size() == 1 and hud != null and hud.get_canvas() != (tint[0] as CanvasModulate).get_canvas() \
			and box_layer != null and box_layer.get_canvas() != (tint[0] as CanvasModulate).get_canvas()
		_record("%s 晚上变暗（%s），中午恢复白天（%s），HUD 不受色调影响%s" % [map_name, night, noon, "" if ui_ok else "：HUD/对话框在世界画布上"],
			scene.name == map_name and tint.size() == 1 and night.v < 0.8 and noon == Color.WHITE and ui_ok)


func _frames(count: int, physics := false) -> void:
	for i in count:
		if physics:
			await physics_frame
		else:
			await process_frame


func _record(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % name)
	else:
		_failed += 1
		print("[FAIL] %s" % name)

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

