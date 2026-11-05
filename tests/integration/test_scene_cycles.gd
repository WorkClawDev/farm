extends SceneTree

## Repeated real scene switches (BUG-30). Each hop uses the same call the map
## exits use: Farm -> Village goes through GameManager.change_location (no
## SceneTransition, so NPCManager is not told), the other hops go through
## SceneTransition.transition_to. NPCs spawned by NPCManager are freed together
## with their scene; a stale reference used to crash the next despawn (signal 11).
## Usage: godot --headless --path . --script res://tests/integration/test_scene_cycles.gd

const FARM := "res://src/world/maps/Farm.tscn"
const VILLAGE := "res://src/world/maps/Village.tscn"
const HOUSE := "res://src/world/maps/PlayerHouse.tscn"
const BEACH := "res://src/world/maps/Beach.tscn"
const FOREST := "res://src/world/maps/Forest.tscn"
const MINE := "res://src/world/maps/Mine.tscn"
const CYCLES := 6

var _passed := 0
var _failed := 0
# BUG-44: per scene name, hops checked / hops where some NPC id had != 1 instance.
var _instance_checks := {}
var _instance_bad := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_saves_before := _real_save_stamps()
	var save_manager := root.get_node("SaveManager")
	var tmp_save_dir := "user://scene_cycle_saves_%d/" % Time.get_ticks_usec()
	save_manager.save_dir = tmp_save_dir
	var gm := root.get_node("GameManager")
	await gm.start_new_game(1)
	await _settle(10)
	_record("新游戏进入农场", current_scene != null and current_scene.name == "Farm")
	await _exercise_village_exits()
	# Each cycle: Farm -> Village -> Farm -> Village -> <other map> -> Village -> Farm
	var others := [HOUSE, BEACH, FOREST, MINE]
	var back_spawn := {BEACH: "from_beach", FOREST: "from_forest", MINE: "from_mine"}
	for cycle in CYCLES:
		var other: String = others[cycle % others.size()]
		var hops := [
			["change_location", VILLAGE, "from_farm", "Village"],
			["transition", FARM, "from_village", "Farm"],
			["change_location", VILLAGE, "from_farm", "Village"],
		]
		if other == HOUSE:
			# The house is entered from the village and left onto the farm.
			hops.append(["transition", HOUSE, "house_entrance", "PlayerHouse"])
			hops.append(["change_location", FARM, "house_exit", "Farm"])
		else:
			hops.append(["transition", other, "from_village", _scene_name(other)])
			hops.append(["transition", VILLAGE, back_spawn[other], "Village"])
			hops.append(["transition", FARM, "from_village", "Farm"])
		var ok := true
		for hop in hops:
			if not await _hop(hop[0], hop[1], hop[2], hop[3]):
				ok = false
				break
		_record("第 %d 轮场景往返（经 %s）无崩溃、NPC 引用有效" % [cycle + 1, _scene_name(other)], ok)
		if not ok:
			break
	# Same hops at night: villagers (and NPCManager's farm NPC) spawn already resting.
	root.get_node("TimeManager").current_time = 20.5
	var night_ok := true
	for i in 3:
		night_ok = night_ok and await _hop("change_location", VILLAGE, "from_farm", "Village")
		if night_ok:
			var awake: Array = current_scene.get_node("NPCs").get_children().filter(func(n): return "npc_id" in n and n.npc_id in ["farmer_joe", "blacksmith_tom", "doctor_mary"] and (n.visible or not n.is_resting))
			night_ok = awake.is_empty()
		night_ok = night_ok and await _hop("transition", FARM, "from_village", "Farm")
		if night_ok:
			for npc in root.get_node("NPCManager")._spawned_npcs.values():
				night_ok = night_ok and npc.is_resting and not npc.visible
	_record("20:30 农场↔村庄 3 轮：睡觉的 NPC 一进场景就隐藏，NPC 引用有效", night_ok)
	for scene_name in _instance_checks.keys():
		_record("BUG-44 %s：%d 次进入后每个 NPC id 都正好 1 个实例" % [scene_name, _instance_checks[scene_name]], not _instance_bad.has(scene_name))
	_record("BUG-44 村庄被检查过（含 SceneTransition 进入）", _instance_checks.get("Village", 0) >= CYCLES)
	await _exercise_forced_overnight()
	_wipe_user_dir(tmp_save_dir)
	_record("场景往返没有改写真实存档的内容或修改时间", _real_save_stamps() == real_saves_before)
	print("RESULTS: %d/%d passed" % [_passed, _passed + _failed])
	print("SCENE CYCLE TESTS PASSED" if _failed == 0 else "SCENE CYCLE TESTS FAILED")
	# Let pending NPC idle-action timers (1.5 s) run out so quitting leaks nothing.
	await create_timer(1.6).timeout
	quit(0 if _failed == 0 else 1)


## BUG-32: walk (real movement + collision) from the village spawn to each exit.
## Forest: north end of the middle road; Beach: east edge; Mine: band along the
## bottom edge below the blue-roof house (BUG-36); Farm: west end of the main road.
func _exercise_village_exits() -> void:
	var routes := [
		["ToForestArea", "Forest", [Vector2(500, 500), Vector2(500, 230), Vector2(430, 200), Vector2(430, -110)]],
		["ToBeachArea", "Beach", [Vector2(500, 500), Vector2(500, 620), Vector2(1110, 620), Vector2(1200, 690)]],
		["ToMineArea", "Mine", [Vector2(345, 500), Vector2(345, 950), Vector2(180, 950)]],
		["ToFarmArea", "Farm", [Vector2(500, 500), Vector2(500, 400), Vector2(330, 400), Vector2(330, 300), Vector2(90, 300)]],
	]
	for route in routes:
		await _hop("change_location", VILLAGE, "", "Village")
		var player := current_scene.get_node_or_null("Player") as Node2D
		var area := current_scene.get_node_or_null("TransitionAreas/%s" % route[0]) as Area2D
		if player == null or area == null:
			_record("村庄出口 %s 存在" % route[0], false)
			continue
		var exit_center := area.global_position
		var outside_buildings := true
		var space := player.get_world_2d().direct_space_state
		var query := PhysicsPointQueryParameters2D.new()
		query.position = exit_center
		query.collision_mask = 1
		outside_buildings = space.intersect_point(query).is_empty()
		_record("村庄出口 %s 中心 %s 不在任何碰撞体里" % [route[0], exit_center], outside_buildings)
		# NPCs wander; this test is about the static map, so let the player pass through them.
		for npc in current_scene.find_children("*", "CharacterBody2D", true, false):
			if npc != player:
				npc.collision_layer = 0
		player.global_position = Vector2(420, 500)
		await physics_frame
		var reached := await _walk(player, route[2], route[1])
		_release_moves()
		await _settle(8)
		while root.get_node("SceneTransition").is_transitioning:
			await process_frame
		await _settle(4)
		_record("从村庄出生点走到 %s 并进入 %s" % [route[0], route[1]], reached and current_scene != null and current_scene.name == route[1])
	# BUG-33: the roof wings and peak of the north-west house stick out past the walls.
	await _hop("change_location", VILLAGE, "", "Village")
	var space := (current_scene as Node2D).get_world_2d().direct_space_state
	var roof_points := [Vector2(56, 60), Vector2(334, 60), Vector2(195, 0), Vector2(80, 84)]
	var solid := 0
	for point in roof_points:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = point
		q.collision_mask = 1
		if not space.intersect_point(q).is_empty():
			solid += 1
	_record("西北房子的屋檐和屋脊有碰撞（%d/%d 个点）" % [solid, roof_points.size()], solid == roof_points.size())


func _walk(player: Node2D, waypoints: Array, target_scene: String) -> bool:
	for wp in waypoints:
		var best := INF
		var stuck := 0
		var frames := 0
		while frames < 900:
			frames += 1
			if not is_instance_valid(player) or not player.is_inside_tree():
				return current_scene != null and current_scene.name == target_scene or root.get_node("SceneTransition").is_transitioning
			if root.get_node("SceneTransition").is_transitioning:
				return true
			var to: Vector2 = wp - player.global_position
			if to.length() < 6.0:
				break
			if to.length() < best - 0.5:
				best = to.length()
				stuck = 0
			else:
				stuck += 1
				if stuck > 90:
					print("[FAIL] stuck at %s heading to %s" % [player.global_position, wp])
					return false
			var dir := to.normalized()
			_release_moves()
			if dir.x > 0.05: Input.action_press("move_right", dir.x)
			if dir.x < -0.05: Input.action_press("move_left", -dir.x)
			if dir.y > 0.05: Input.action_press("move_down", dir.y)
			if dir.y < -0.05: Input.action_press("move_up", -dir.y)
			await physics_frame
	# Final waypoint lies inside the exit; give the area a few frames to fire.
	for i in 30:
		if root.get_node("SceneTransition").is_transitioning or current_scene == null or current_scene.name == target_scene:
			return true
		await physics_frame
	return root.get_node("SceneTransition").is_transitioning


func _release_moves() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _hop(kind: String, path: String, spawn: String, expected: String) -> bool:
	var transition := root.get_node("SceneTransition")
	if kind == "change_location":
		await root.get_node("GameManager").change_location(path, spawn)
	else:
		var bus = root.get_node("EventBus").game
		transition.transition_to(path, spawn)
		var frames := 0
		while transition.is_transitioning and frames < 600:
			await process_frame
			frames += 1
		if frames >= 600:
			print("[FAIL] transition to %s timed out" % path)
			return false
	await _settle(8)
	if current_scene == null or current_scene.name != expected:
		print("[FAIL] expected scene %s, got %s" % [expected, current_scene.name if current_scene else "null"])
		return false
	var npc_manager := root.get_node("NPCManager")
	for npc_id in npc_manager._spawned_npcs.keys():
		var npc = npc_manager._spawned_npcs[npc_id]
		if not is_instance_valid(npc):
			print("[FAIL] NPCManager still holds freed NPC %s after entering %s" % [npc_id, expected])
			return false
		if not npc.is_inside_tree() or not current_scene.is_ancestor_of(npc):
			print("[FAIL] NPC %s is not part of the current scene %s" % [npc_id, expected])
			return false
	_check_npc_instances(expected, kind == "transition")
	return true


## BUG-44: count live NPC nodes per id in the scene. Every id at most once; after a
## SceneTransition (NPCManager told) every id NPCManager places here exactly once,
## and in the village every villager (authored or spawned) exactly once.
func _check_npc_instances(scene_name: String, manager_told: bool) -> void:
	var npc_manager := root.get_node("NPCManager")
	var counts := {}
	for node in current_scene.find_children("*", "CharacterBody2D", true, false):
		if "npc_id" in node and node.npc_id != "" and not node.is_queued_for_deletion():
			counts[node.npc_id] = counts.get(node.npc_id, 0) + 1
	var bad: Array = []
	for npc_id in counts.keys():
		if counts[npc_id] != 1:
			bad.append("%s x%d" % [npc_id, counts[npc_id]])
	for npc_id in npc_manager._npc_data.keys():
		var expected_here: bool = (manager_told and npc_manager._should_npc_be_in_scene(npc_id, scene_name)) \
			or (scene_name == "Village" and npc_manager._npc_data[npc_id].get("default_location", "") == "village")
		if expected_here and counts.get(npc_id, 0) != 1 and not counts.has(npc_id):
			bad.append("%s missing" % npc_id)
	_instance_checks[scene_name] = _instance_checks.get(scene_name, 0) + 1
	if not bad.is_empty():
		_instance_bad[scene_name] = true
		print("[FAIL] %s NPC instances: %s" % [scene_name, ", ".join(bad)])


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _scene_name(path: String) -> String:
	return path.get_file().get_basename()


## Real map hop: 2am on the farm charges 10%, pays the bin, refills stamina, and loads the house spawn.
func _exercise_forced_overnight() -> void:
	var gm := root.get_node("GameManager")
	var time := root.get_node("TimeManager")
	var money := root.get_node("MoneySystem")
	var stamina := root.get_node("StaminaManager")
	var shipping := root.get_node("ShippingSystem")
	if current_scene == null or current_scene.name != "Farm":
		_record("强制过夜从农场开始", false)
		return
	_record("强制过夜从农场开始", true)
	shipping.clear_bin()
	money.set_money(800)
	stamina.set_stamina(5.0)
	var day_before: int = time.current_day
	await gm.advance_day("sleep")
	_record(
		"睡觉留在农场、不扣钱、体力回满",
		current_scene != null
			and current_scene.name == "Farm"
			and money.get_money() == 800
			and is_equal_approx(stamina.current_stamina, stamina.max_stamina)
	)
	shipping.clear_bin()
	var added: bool = shipping.add_item("turnip", 2, 0)
	var sale := int(shipping.calculate_total_value().get("total_value", 0))
	money.set_money(800)
	stamina.set_stamina(4.0)
	await gm.advance_day("forced_2am")
	await _settle(4)
	var player := current_scene.find_child("Player", true, false) if current_scene else null
	var at_spawn := false
	if player != null and current_scene.has_method("get_spawn_position"):
		at_spawn = player.global_position.distance_to(current_scene.get_spawn_position()) < 1.0
	_record("出货箱里的作物有售价", added and sale > 0)
	_record(
		"凌晨2点扣10%后仍把出货全额入账",
		money.get_money() == 800 - gm.forced_overnight_fee(800) + sale
	)
	_record("凌晨2点体力回满", is_equal_approx(stamina.current_stamina, stamina.max_stamina))
	# Time resumes at 6:00 and a few frames pass during the house load.
	_record(
		"凌晨2点日期前进且回到早晨",
		time.current_day != day_before and time.current_time >= 6.0 and time.current_time < 7.0
	)
	_record("凌晨2点场景是农舍", current_scene != null and current_scene.name == "PlayerHouse")
	_record("玩家站在农舍出生点", at_spawn)
	_record("次日提示带出货到账金额", _toast_contains("出货到账 %d 金" % sale))
	_record("次日提示带凌晨扣除", _toast_contains("扣除 %d 金" % gm.forced_overnight_fee(800)))


func _toast_contains(fragment: String) -> bool:
	var root_ui := root.get_node_or_null("UIManager")
	if root_ui == null:
		return false
	var toast_root := root_ui.get_node_or_null("UIOverlay/ToastRoot")
	if toast_root == null:
		return false
	for child in toast_root.get_children():
		if child.is_queued_for_deletion():
			continue
		if str(child.get_meta("toast_text", "")).find(fragment) >= 0:
			return true
	return false


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

