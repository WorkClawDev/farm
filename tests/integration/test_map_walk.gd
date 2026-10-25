extends SceneTree

## Map geometry and exits, with real physics (map colliders + boundary walls).
## 1. Every NPC schedule point, home door / door waypoint and scene spawn point on
##    the maps the NPC appears on is clear of buildings and colliders, and every
##    door route segment can be walked in a straight line.
## 2. Every exit is walked to (real Input, real collision, boundary walls kept)
##    from the spot you arrive at, and leads to the right map (BUG-35/36/37/40).
## Usage: godot --headless --path . --script res://tests/integration/test_map_walk.gd

const FARM := "res://src/world/maps/Farm.tscn"
const VILLAGE := "res://src/world/maps/Village.tscn"
const HOUSE := "res://src/world/maps/PlayerHouse.tscn"
const BEACH := "res://src/world/maps/Beach.tscn"
const FOREST := "res://src/world/maps/Forest.tscn"
const MINE := "res://src/world/maps/Mine.tscn"
## NPC body (NPC.tscn: 24x24 rect at (0,4)) grown by a small safety margin.
const NPC_BODY := Vector2(32, 32)
const NPC_BODY_OFFSET := Vector2(0, 4)

## Arrival spot per map + spawn point (what the exit leading there should give).
const ARRIVALS := {
	"Village/from_farm": Vector2(150, 300),
	"Village/from_forest": Vector2(410, -20),
	"Village/from_beach": Vector2(1110, 690),
	"Village/from_mine": Vector2(520, 880),
	"Village/from_house": Vector2(470, 575),
	"Forest/from_village": Vector2(440, 790),
	"Beach/from_village": Vector2(0, -100),
	"Mine/from_village": Vector2(400, 300),
	"Farm/from_village": Vector2(1320, 608),
}

var _passed := 0
var _failed := 0


## Collects engine errors (BUG-45: physics state changed while flushing queries).
class ErrorLog extends Logger:
	var messages: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s %s (%s:%d %s)" % [code, rationale, file, line, function])

var _errors := ErrorLog.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# This run must not read or write the real user:// save slots.
	var real_saves_before := _real_save_stamps()
	var save_manager := root.get_node("SaveManager")
	var tmp_save_dir := "user://mapwalk_test_saves_%d/" % Time.get_ticks_usec()
	save_manager.save_dir = tmp_save_dir
	var gm := root.get_node("GameManager")
	await gm.start_new_game(1)
	await _settle(10)
	await _check_npc_points()
	await _check_exits()
	await _check_prompts()
	await _check_mine_floors()
	_check_dialogue_data()
	_remove_save_files(tmp_save_dir.trim_suffix("/"))
	_remove_empty_dir(tmp_save_dir.trim_suffix("/"))
	_record("地图行走没有改写真实存档的内容或修改时间", _real_save_stamps() == real_saves_before)
	print("RESULTS: %d/%d passed" % [_passed, _passed + _failed])
	print("MAP WALK TESTS PASSED" if _failed == 0 else "MAP WALK TESTS FAILED")
	quit(0 if _failed == 0 else 1)


# ---------------------------------------------------------------- NPC points

func _check_npc_points() -> void:
	var npcs: Array = root.get_node("NPCManager")._npc_data.values()
	for map in [["Village", VILLAGE], ["Farm", FARM], ["Beach", BEACH]]:
		await _enter(map[1], "")
		var scene := current_scene as Node2D
		for body in scene.find_children("*", "CharacterBody2D", true, false):
			body.collision_layer = 0  # only the static map counts here
		await physics_frame
		await physics_frame
		var space := scene.get_world_2d().direct_space_state
		var in_scene := {}
		var npc_parent := scene.get_node_or_null("NPCs")
		if npc_parent:
			for n in npc_parent.get_children():
				if "npc_id" in n:
					in_scene[n.npc_id] = n
		var bad: Array[String] = []
		var count := 0
		var points := {}  # npc id -> schedule points on this map
		for data in npcs:
			var id: String = data.get("id", "")
			var here: bool = in_scene.has(id) or root.get_node("NPCManager")._should_npc_be_in_scene(id, map[0])
			if not here:
				continue
			for entry in data.get("schedule", []):
				var p := _vec(entry.get("location_position", {}))
				count += 1
				if not _npc_fits(space, p):
					bad.append("%s %s@%s" % [id, entry.get("location_id", "?"), p])
				points[id] = points.get(id, []) + [p]
			var door: Dictionary = data.get("home_door", {}).get(map[0].to_lower(), {})
			if not door.is_empty():
				var route: Array[Vector2] = []
				for v in door.get("via", []):
					route.append(_vec(v))
				route.append(_vec(door))
				for i in route.size():
					count += 1
					if not _npc_fits(space, route[i]):
						bad.append("%s door/via@%s" % [id, route[i]])
					if i > 0 and not _npc_can_walk(space, route[i - 1], route[i]):
						bad.append("%s door route %s->%s blocked" % [id, route[i - 1], route[i]])
				# BUG-47: the walk home starts wherever the villager stands when its sleep entry begins.
				var sched: Array = data.get("schedule", [])
				for s in sched:
					if int(s.get("activity", -1)) != 0:
						continue
					for e in sched:
						if int(e.get("activity", -1)) != 0 and is_equal_approx(float(e.get("end_time", -1.0)), float(s.get("start_time", -2.0))):
							count += 1
							var start := _vec(e.get("location_position", {}))
							if not _npc_can_walk(space, start, route[0]):
								bad.append("%s go-home start %s->%s blocked" % [id, start, route[0]])
		# Where the scene file itself places its villagers.
		if map[0] == "Village":
			var packed := (load(VILLAGE) as PackedScene).get_state()
			for i in packed.get_node_count():
				var path := str(packed.get_node_path(i))
				if not path.begins_with("./NPCs/"):
					continue
				for k in packed.get_node_property_count(i):
					if packed.get_node_property_name(i, k) == "position":
						var sp: Vector2 = packed.get_node_property_value(i, k)
						count += 1
						if not _npc_fits(space, sp):
							bad.append("%s scene spawn@%s" % [path, sp])
		_record("%s：%d 个 NPC 日程点/门口/途经点/出生点都不在建筑或碰撞体里%s" % [map[0], count, "" if bad.is_empty() else "，问题：" + ", ".join(bad)], bad.is_empty())
		# Two villagers must never be sent to the same spot (round 7: mayor/Lily, Joe/Tom stacked).
		var stacked: Array[String] = []
		var ids := points.keys()
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				for pa in points[ids[a]]:
					for pb in points[ids[b]]:
						if pa.distance_to(pb) < 28.0:
							stacked.append("%s/%s@%s" % [ids[a], ids[b], pa])
		_record("%s：不同 NPC 的日程点互不重叠（≥28px）%s" % [map[0], "" if stacked.is_empty() else "，重叠：" + ", ".join(stacked)], stacked.is_empty())
	# Tom's door is near the mine exit band: standing at or just below it must not leave the village.
	await _enter(VILLAGE, "")
	var mine_area := current_scene.get_node("TransitionAreas/ToMineArea") as Area2D
	var player := current_scene.get_node("Player") as Node2D
	var tom_door := Vector2(178, 829)
	var stayed := true
	for dy in [16, 40, 66]:
		player.global_position = tom_door + Vector2(0, dy)
		await _physics(10)
		stayed = stayed and current_scene != null and current_scene.name == "Village" and not root.get_node("SceneTransition").is_transitioning
	_record("站在汤姆家门口及门下 66px 内不会进矿洞（出口带 y≥%d）" % int(_area_rect(mine_area).position.y), stayed)


func _npc_fits(space: PhysicsDirectSpaceState2D, p: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = NPC_BODY
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, p + NPC_BODY_OFFSET)
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()


func _npc_can_walk(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, from + NPC_BODY_OFFSET)
	q.motion = to - from
	q.collision_mask = 1
	var r := space.cast_motion(q)
	return r.size() == 2 and r[0] >= 1.0


func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))


# ---------------------------------------------------------------- prompts

## BUG-38/39 + kitchen range + coop bubble vs quest panel.
func _check_prompts() -> void:
	var prompt_script = load("res://src/ui/components/InteractPrompt.gd")
	# Forest forage: bubble while standing on it, E collects it.
	await _enter(FOREST, "")
	var forage = null
	for f in current_scene.get_tree().get_nodes_in_group("forage_items"):
		if current_scene.is_ancestor_of(f) and not f.is_collected:
			forage = f
			break
	var player := current_scene.get_node("Player") as Node2D
	if forage == null:
		_record("森林里有可采集物", false)
	else:
		player.global_position = forage.global_position + Vector2(0, 10)
		await _physics(6)
		await _settle(2)
		var shown: bool = prompt_script.current() == forage.get_node_or_null("InteractPrompt")
		Input.action_press("interact")
		await _physics(2)
		await _settle(2)
		Input.action_release("interact")
		await _settle(30)
		_record("森林采集物：站上去出现气泡 %s，按 E 采集 %s" % [shown, forage.is_collected], shown and forage.is_collected)
	# Farm pond with the hoe equipped: bubble "钓鱼", E explains the rod.
	await _enter(FARM, "")
	player = current_scene.get_node("Player") as Node2D
	var spot := current_scene.find_child("FishingSpot", true, false) as Area2D
	player.global_position = spot.global_position + Vector2(0, -36)
	await _physics(6)
	await _settle(2)
	var fish_prompt = spot.get_node_or_null("InteractPrompt")
	var shown_fish: bool = fish_prompt != null and prompt_script.current() == fish_prompt
	_record("农场池塘（拿着锄头）：出现 E 气泡“%s”" % (fish_prompt.action_text if fish_prompt else "?"), shown_fish and fish_prompt.action_text == "钓鱼")
	# Coop near the farm's top-left corner: its bubble must not sit under the quest panel.
	var coop := current_scene.find_child("Coop", true, false) as Node2D
	player.global_position = coop.global_position + Vector2(0, 60)
	await _physics(8)
	await _settle(3)
	var coop_prompt = coop.get_node_or_null("InteractPrompt")
	var overlap := true
	var gap := INF
	if coop_prompt and prompt_script.current() == coop_prompt:
		var bubble: Control = coop_prompt.bubble
		var rect: Rect2 = coop_prompt.get_global_transform_with_canvas() * Rect2(bubble.position, bubble.size)
		overlap = false
		for panel in get_nodes_in_group("interact_prompt_avoid"):
			if panel.is_visible_in_tree() and panel.get_global_rect().intersects(rect):
				overlap = true
		# BUG-43: the bubble stays on the coop (touching its drawn sprite), not out by the pond.
		var sprite := coop.get_node("Sprite2D") as Sprite2D
		var sprite_rect: Rect2 = sprite.get_global_transform_with_canvas() * sprite.get_rect()
		gap = maxf(0.0, maxf(rect.position.y - sprite_rect.end.y, sprite_rect.position.y - rect.end.y))
	_record("鸡舍气泡显示、不被任务面板挡住、贴着鸡舍（间距 %.0f px）" % gap, not overlap and gap <= 12.0)
	# Kitchen: the bubble shows beside the stove too, not only right below it.
	await _enter(HOUSE, "house_entrance")
	player = current_scene.get_node("Player") as Node2D
	var kitchen := current_scene.get_node("InteractionZones/Kitchen") as Node2D
	var spots_ok := []
	for spot_pos in [Vector2(128, 364), Vector2(268, 364), Vector2(200, 428)]:
		player.global_position = spot_pos
		await _physics(6)
		await _settle(2)
		spots_ok.append(prompt_script.current() == kitchen.get_node_or_null("InteractPrompt"))
	_record("厨房：灶台左、右、下方都出现气泡 %s" % [spots_ok], not spots_ok.has(false))
	# ... but not one tile off diagonally above the stove's corners (range was too large).
	var spots_off := []
	for spot_pos in [Vector2(117, 287), Vector2(278, 287)]:
		player.global_position = spot_pos
		await _physics(6)
		await _settle(2)
		spots_off.append(prompt_script.current() == kitchen.get_node_or_null("InteractPrompt"))
	_record("厨房：灶台左上、右上斜一格不出气泡 %s" % [spots_off], not spots_off.has(true))


# ---------------------------------------------------------------- dialogue

## BUG-46: every villager in npcs.json has dialogue data (directly or via alias).
func _check_dialogue_data() -> void:
	var dm := root.get_node("DialogueManager")
	var missing: Array[String] = []
	for npc_id in root.get_node("NPCManager")._npc_data.keys():
		if not dm._dialogue_data.has(dm.DIALOGUE_ID_ALIASES.get(npc_id, npc_id)):
			missing.append(npc_id)
	_record("每个 NPC 都有对话数据%s" % ("" if missing.is_empty() else "，缺少：" + ", ".join(missing)), missing.is_empty())


# ---------------------------------------------------------------- mine floors

## BUG-45: walking onto a ladder changes the floor (new ores) without physics errors.
func _check_mine_floors() -> void:
	await _enter(MINE, "from_village")
	var mine := current_scene
	var player := mine.get_node("Player") as Node2D
	OS.add_logger(_errors)
	var steps := [["下梯子到第 2 层", "move_right", 2], ["上梯子回第 1 层", "move_left", 1]]
	for step in steps:
		for body in mine.get_node("Ores").find_children("*", "CollisionObject2D", true, false):
			body.collision_layer = 0  # random ores are not walls here
		_errors.messages.clear()
		# Real input from the middle of the floor onto the ladder.
		Input.action_press(step[1])
		var frames := 0
		while mine.current_floor != step[2] and frames < 900:
			await physics_frame
			frames += 1
		_release_moves()
		await _physics(10)
		await _settle(4)
		var ores := mine.get_node("Ores").get_children().filter(func(o): return not o.is_queued_for_deletion())
		var flush_errors := _errors.messages.filter(func(m): return "flushing queries" in m)
		_record("矿洞%s：第 %d 层，%d 块矿石，物理报错 %d 条%s" % [step[0], mine.current_floor, ores.size(), flush_errors.size(), "" if flush_errors.is_empty() else "：" + flush_errors[0]],
			mine.current_floor == step[2] and ores.size() == 5 + step[2] * 2 and _errors.messages.is_empty())
		# Round 7: the signs say where each ladder goes; only the exit says village.
		var up_text := str(mine.get_node("Ladders/LadderUp/LadderSign").text)
		var down_text := str(mine.get_node("Ladders/LadderDown/LadderSign").text)
		var want_up := "↑ 第 %d 层" % (step[2] - 1) if step[2] > 1 else "↑"
		var want_down := "↓ 第 %d 层" % (step[2] + 1)
		var exit_text := str(mine.get_node("Ladders/ExitArea/ExitSign").text)
		_record("矿洞第 %d 层梯子标签：上「%s」下「%s」出口「%s」" % [step[2], up_text, down_text, exit_text], up_text == want_up and down_text == want_down and exit_text == "← 村庄")
		# Round 8: the up-ladder triggers on every floor, so it is visible on every floor too.
		_record("矿洞第 %d 层上梯子可见（它总能踩）" % step[2], mine.get_node("Ladders/LadderUp").is_visible_in_tree())
		# Step off the ladder before the next one (the other ladder is far away).
		player.global_position = Vector2(400, 300)
		await _physics(4)
	OS.remove_logger(_errors)
	# Back on floor 1 after coming up: the (visible) up-ladder leads to the village.
	for body in mine.get_node("Ores").find_children("*", "CollisionObject2D", true, false):
		body.collision_layer = 0  # this floor's new random ores
	await _physics(2)
	Input.action_press("move_left")
	var left := 0
	while current_scene == mine and left < 900:
		await physics_frame
		left += 1
	_release_moves()
	while root.get_node("SceneTransition").is_transitioning:
		await process_frame
	await _settle(4)
	_record("从第 2 层回到第 1 层后，走上可见的上梯子回到村庄（%d 帧，%s）" % [left, current_scene.name if current_scene else "-"], current_scene != null and current_scene.name == "Village")


# ---------------------------------------------------------------- exits

func _check_exits() -> void:
	# [label, map, arrival spawn, waypoints, expected scene, expected arrival key]
	var routes := [
		# North edge of the west road (y=256). The old 40×60 exit sat on the sign
		# and left this lane free, so the player walked into the west wall.
		["村庄 → 农场（西路）", VILLAGE, "from_farm", [Vector2(220, 256), Vector2(-150, 256)], "Farm", "Farm/from_village"],
		["村庄 → 森林（北路）", VILLAGE, "from_forest", [Vector2(410, -110)], "Forest", "Forest/from_village"],
		["村庄 → 海滩（东路）", VILLAGE, "from_beach", [Vector2(1205, 690)], "Beach", "Beach/from_village"],
		["村庄 → 矿洞（从矿洞落点往下）", VILLAGE, "from_mine", [Vector2(520, 958), Vector2(200, 958)], "Mine", "Mine/from_village"],
		["村庄 → 矿洞（从出生点沿蓝顶房子右侧下去，再沿最下沿往左）", VILLAGE, "", [Vector2(345, 500), Vector2(345, 958), Vector2(150, 958)], "Mine", "Mine/from_village"],
		["村庄 → 小屋（下路）", VILLAGE, "", [Vector2(470, 575), Vector2(400, 580)], "PlayerHouse", ""],
		["森林 → 村庄（南路）", FOREST, "from_village", [Vector2(440, 915)], "Village", "Village/from_forest"],
		["森林 → 村庄（西路）", FOREST, "from_village", [Vector2(440, 365), Vector2(55, 360)], "Village", "Village/from_forest"],
		["海滩 → 村庄（北路）", BEACH, "from_village", [Vector2(0, -205)], "Village", "Village/from_beach"],
		["矿洞 → 村庄（上梯子）", MINE, "from_village", [Vector2(100, 300)], "Village", "Village/from_mine"],
		["矿洞 → 村庄（左边出口）", MINE, "from_village", [Vector2(150, 300), Vector2(150, 240), Vector2(50, 240), Vector2(50, 292)], "Village", "Village/from_mine"],
		["农场 → 村庄（东边出口）", FARM, "from_village", [Vector2(1400, 608)], "Village", "Village/from_farm"],
		["小屋（从村庄进）→ 村庄", HOUSE, "village_house_entrance", [Vector2(400, 455)], "Village", "Village/from_house"],
		["小屋（从农场进）→ 农场", HOUSE, "house_entrance", [Vector2(400, 455)], "Farm", ""],
	]
	for route in routes:
		await _enter(route[1], route[2])
		var scene := current_scene as Node2D
		var player := scene.get_node_or_null("Player") as Node2D
		if player == null:
			_record("%s：找到玩家" % route[0], false)
			continue
		var key := "%s/%s" % [scene.name, route[2]]
		if ARRIVALS.has(key):
			_record("%s：落点 %s（应为 %s）" % [route[0], player.global_position.round(), ARRIVALS[key]], player.global_position.distance_to(ARRIVALS[key]) < 4.0)
		_check_exit_visible(scene, player)
		for npc in scene.find_children("*", "CharacterBody2D", true, false):
			if npc != player:
				npc.collision_layer = 0  # wandering villagers are not part of the map
		var ores := scene.get_node_or_null("Ores")
		if ores:
			# Ores are placed at random each floor (and kept off the ladders/exit);
			# they are mined away, so they do not count as map walls here.
			for body in ores.find_children("*", "CollisionObject2D", true, false):
				body.collision_layer = 0
		var reached := await _walk(player, route[3], route[4])
		_release_moves()
		await _wait_transition()
		var ok: bool = reached and current_scene != null and current_scene.name == route[4]
		var arrival := ""
		if ok and not route[5].is_empty():
			var p2 := current_scene.get_node_or_null("Player") as Node2D
			arrival = " 落在 %s" % (p2.global_position.round() if p2 else "?")
			ok = p2 != null and p2.global_position.distance_to(ARRIVALS[route[5]]) < 4.0
		_record("%s：走到出口并进入 %s%s" % [route[0], route[4], arrival], ok)
	# BUG-37: holding → while walking into the farm's exit must not carry the
	# player away from the village arrival spot.
	await _enter(FARM, "from_village")
	var player := current_scene.get_node("Player") as Node2D
	Input.action_press("move_right")
	var frames := 0
	while current_scene.name != "Village" and frames < 600:
		await physics_frame
		frames += 1
	await _physics(45)  # key still held
	var p := current_scene.get_node("Player") as Node2D
	var held_pos := p.global_position
	_release_moves()
	await _physics(5)
	Input.action_press("move_right")
	await _physics(20)
	var moved := p.global_position.x - held_pos.x
	_release_moves()
	_record("农场→村庄时一直按着 →：停在落点 %s，松开再按才走（走了 %d）" % [held_pos.round(), int(moved)], held_pos.distance_to(ARRIVALS["Village/from_farm"]) < 4.0 and moved > 8.0)


## The exit areas lie inside the camera limits (visible) and inside the boundary walls.
func _check_exit_visible(scene: Node2D, player: Node2D) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var view := Rect2(Vector2(cam.limit_left, cam.limit_top), Vector2(cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top))
	var bad: Array[String] = []
	for area in _exit_areas(scene):
		if not view.has_point(area.global_position):
			bad.append("%s@%s" % [area.name, area.global_position])
	_record("%s：所有出口都在镜头范围内%s" % [scene.name, "" if bad.is_empty() else "，超出：" + ", ".join(bad)], bad.is_empty())


func _exit_areas(scene: Node) -> Array:
	var out := []
	for n in scene.find_children("*", "Area2D", true, false):
		if n.name in ["ToFarmArea", "ToPlayerHouseArea", "ToBeachArea", "ToForestArea", "ToMineArea", "ToVillageSouthArea", "ExitToVillage", "ExitArea", "LadderUp", "VillageExit", "HouseEntrance"]:
			out.append(n)
	return out


func _area_rect(area: Area2D) -> Rect2:
	var cs := area.get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (cs.shape as RectangleShape2D).size
	return Rect2(cs.global_position - size / 2, size)


func _walk(player: Node2D, waypoints: Array, target_scene: String) -> bool:
	var start_scene := current_scene
	for wp in waypoints:
		var best := INF
		var stuck := 0
		var frames := 0
		while frames < 1200:
			frames += 1
			if current_scene != start_scene or root.get_node("SceneTransition").is_transitioning or not is_instance_valid(player) or not player.is_inside_tree():
				return true
			var to: Vector2 = wp - player.global_position
			if to.length() < 5.0:
				break
			if to.length() < best - 0.5:
				best = to.length()
				stuck = 0
			else:
				stuck += 1
				if stuck > 90:
					print("[FAIL] stuck at %s heading to %s" % [player.global_position, wp])
					_release_moves()
					return false
			var dir := to.normalized()
			_release_moves()
			if dir.x > 0.05: Input.action_press("move_right", dir.x)
			if dir.x < -0.05: Input.action_press("move_left", -dir.x)
			if dir.y > 0.05: Input.action_press("move_down", dir.y)
			if dir.y < -0.05: Input.action_press("move_up", -dir.y)
			await physics_frame
	_release_moves()
	for i in 30:
		if current_scene != start_scene or root.get_node("SceneTransition").is_transitioning:
			return true
		await physics_frame
	print("[FAIL] reached the last waypoint at %s but no exit fired" % player.global_position)
	return false


func _wait_transition() -> void:
	await _settle(4)
	var frames := 0
	while root.get_node("SceneTransition").is_transitioning and frames < 600:
		await process_frame
		frames += 1
	await _settle(8)


func _enter(path: String, spawn: String) -> void:
	_release_moves()
	await root.get_node("GameManager").change_location(path, spawn)
	await _settle(8)


func _release_moves() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await physics_frame


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


func _save_slot_md5s() -> Dictionary:
	var stamps := {}
	var save_manager := root.get_node("SaveManager")
	for slot in range(int(save_manager.MAX_SAVE_SLOTS)):
		var path := str(save_manager.get_save_path(slot))
		stamps[slot] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return stamps


func _relocate_save_files(from_dir: String, to_dir: String) -> bool:
	var from := DirAccess.open(from_dir)
	if from == null:
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to_dir))
	var names: Array[String] = []
	from.list_dir_begin()
	var entry := from.get_next()
	while entry != "":
		if not from.current_is_dir():
			names.append(entry)
		entry = from.get_next()
	from.list_dir_end()
	for name in names:
		var src := from_dir.path_join(name)
		var dst := to_dir.path_join(name)
		var bytes := FileAccess.get_file_as_bytes(src)
		var out := FileAccess.open(dst, FileAccess.WRITE)
		if out == null:
			push_error("Cannot copy save %s" % src)
			return false
		out.store_buffer(bytes)
		out.close()
		if FileAccess.get_md5(dst) != FileAccess.get_md5(src):
			push_error("Save copy mismatch %s" % src)
			return false
		from.remove(name)
	return true


func _remove_save_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
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


func _remove_empty_dir(dir_path: String) -> void:
	var parent := DirAccess.open("user://")
	if parent != null:
		parent.remove(dir_path.get_file())
