extends Node

## Core Unit Tests - 核心系统单元测试
## 使用公共 API 进行测试

var total_tests = 0
var passed_tests = 0
var failed_tests = 0

func _ready() -> void:
	print("==================================================")
	print("CORE UNIT TESTS - Pastoral Tales")
	print("==================================================")
	
	run_item_database_tests()
	run_inventory_tests()
	run_time_manager_tests()
	run_growth_system_tests()
	run_crafting_system_tests()
	run_money_system_tests()
	run_shipping_system_tests()
	run_gift_system_tests()
	run_quest_system_tests()
	run_player_visual_tests()
	run_map_editor_resource_tests()
	
	print("==================================================")
	print("RESULTS: %d/%d passed" % [passed_tests, total_tests])
	print("==================================================")
	
	if failed_tests == 0:
		print("ALL TESTS PASSED!")
	else:
		print("FAILED: %d tests" % failed_tests)
	
	get_tree().quit()

func run_item_database_tests():
	print("\n[ItemDatabase Tests]")
	
	var db = ItemDatabase
	
	# Test: Database is loaded
	var item = db.get_item("turnip")
	assert_true(item != null, "Should get turnip item")
	
	# Test: Item properties
	assert_true(item.name == "防风草", "Turnip name should be 防风草")
	assert_true(item.type == ItemDatabase.ItemType.CROP, "Turnip should be CROP type")
	assert_true(item.sell_price > 0, "Turnip should have sell price")
	
	# Test: Get icon path
	var icon_path = db.get_icon_path("turnip")
	assert_true(icon_path != "", "Turnip should have icon path")
	
	# Test: Get multiple items
	var potato = db.get_item("potato")
	assert_true(potato != null, "Should get potato item")
	
	# Test: Get items by type
	var seeds = db.get_items_by_type(ItemDatabase.ItemType.SEED)
	assert_true(seeds.size() > 0, "Should have seed items")
	
	# Test: Get all items
	var all_items = db.get_all_items()
	assert_true(all_items.size() >= 100, "Should have many items in database")
	
	print("  ItemDatabase: All tests completed")

func run_inventory_tests():
	print("\n[Inventory Tests]")
	
	var inv = Inventory
	
	# Test: Add item
	inv.add_item("turnip", 5)
	assert_true(inv.get_item_count("turnip") == 5, "Should have 5 turnips")
	
	# Test: Has item
	assert_true(inv.has_item("turnip", 3), "Should have at least 3 turnips")
	assert_true(inv.has_item("turnip", 5), "Should have at least 5 turnips")
	assert_true(not inv.has_item("turnip", 100), "Should not have 100 turnips")
	
	# Test: Remove item
	inv.remove_item("turnip", 2)
	assert_true(inv.get_item_count("turnip") == 3, "Should have 3 turnips after removal")
	
	# Test: Add more
	inv.add_item("turnip", 10)
	assert_true(inv.get_item_count("turnip") == 13, "Should have 13 turnips after adding more")
	
	# Test: Remove all
	inv.remove_item("turnip", inv.get_item_count("turnip"))
	assert_true(inv.get_item_count("turnip") == 0, "Should have 0 turnips after removal")
	
	# Test: Multiple item types
	inv.add_item("potato", 3)
	inv.add_item("tomato", 7)
	assert_true(inv.get_item_count("potato") == 3, "Should have 3 potatoes")
	assert_true(inv.get_item_count("tomato") == 7, "Should have 7 tomatoes")
	
	# Clean up
	inv.remove_item("potato", inv.get_item_count("potato"))
	inv.remove_item("tomato", inv.get_item_count("tomato"))
	
	print("  Inventory: All tests completed")

func run_time_manager_tests():
	print("\n[TimeManager Tests]")
	
	var tm = TimeManager
	
	# Test: Get current time
	var time = tm.get_formatted_time()
	assert_true(time != "", "Should get formatted time")
	
	# Test: Get season
	var season = tm.get_season_name()
	assert_true(season == "Spring" or season == "Summer" or season == "Fall" or season == "Winter", 
		"Season should be valid")
	
	# Test: Day number
	var day = tm.current_day
	assert_true(day > 0, "Day should be positive")
	
	# Test: Time pause/resume
	tm.pause_time()
	var is_paused = tm.is_paused
	tm.resume_time()
	assert_true(is_paused and not tm.is_paused, "Pause/resume should work")

	# 6:00 to 2:00 is GAME_HOURS_PER_DAY hours. Real length must be 12 to 15 minutes.
	var day_real_seconds: float = tm.REAL_SECONDS_PER_GAME_MINUTE * float(tm.GAME_HOURS_PER_DAY) * 60.0
	assert_true(day_real_seconds >= 12.0 * 60.0 and day_real_seconds <= 15.0 * 60.0,
		"6:00 to 2:00 should take 12 to 15 real minutes")

	var saved_time: float = tm.current_time
	var saved_day: int = tm.current_day
	var saved_paused: bool = tm.is_paused
	var saved_scale: float = tm.time_scale
	var saved_acc: float = tm._time_accumulator
	var saved_count: int = tm._pause_count
	var saved_active: bool = GameManager.is_game_active
	var saved_engine: float = Engine.time_scale

	tm.current_time = 6.0
	tm.current_day = 1
	tm.is_paused = false
	tm._pause_count = 0
	tm.time_scale = 1.0
	tm._time_accumulator = 0.0
	tm._update_time(tm.REAL_SECONDS_PER_GAME_MINUTE)
	assert_true(is_equal_approx(tm.current_time, 6.0 + 1.0 / 60.0),
		"One interval advances exactly one game minute")

	GameManager.is_game_active = true
	tm.pause_time()
	var frozen: float = tm.current_time
	tm._process(30.0)
	assert_true(is_equal_approx(tm.current_time, frozen), "Paused clock ignores _process")
	tm.resume_time()
	assert_true(not tm.is_paused, "One pause and one resume clears the pause")

	Engine.time_scale = 4.0
	var before_scale: float = tm.current_time
	tm._process(tm.REAL_SECONDS_PER_GAME_MINUTE * 4.0)
	assert_true(is_equal_approx(tm.current_time, before_scale + 1.0 / 60.0),
		"Engine.time_scale does not speed the clock")
	Engine.time_scale = saved_engine

	var dup = load("res://src/autoload/TimeManager.gd").new()
	add_child(dup)
	var before_dup: float = tm.current_time
	dup.current_time = 6.0
	dup.is_paused = false
	dup._process(100.0)
	assert_true(is_equal_approx(dup.current_time, 6.0) and is_equal_approx(tm.current_time, before_dup),
		"A second TimeManager does not advance time")
	dup.queue_free()

	# Day-end emits day_end_requested. Keep the game inactive so that does not save.
	GameManager.is_game_active = false
	tm.current_time = 6.0
	tm._time_accumulator = 0.0
	tm.is_paused = false
	tm._pause_count = 0
	tm._update_time(tm.REAL_SECONDS_PER_GAME_MINUTE * float(tm.GAME_HOURS_PER_DAY) * 60.0)
	assert_true(tm.current_time >= 26.0 and tm.is_paused, "A full day reaches 2:00 and pauses")
	var ended: float = tm.current_time
	tm._update_time(tm.REAL_SECONDS_PER_GAME_MINUTE * 60.0)
	assert_true(is_equal_approx(tm.current_time, ended), "Time does not keep running after 2:00")

	tm.current_time = saved_time
	tm.current_day = saved_day
	tm.is_paused = saved_paused
	tm._pause_count = saved_count
	tm.time_scale = saved_scale
	tm._time_accumulator = saved_acc
	GameManager.is_game_active = saved_active
	Engine.time_scale = saved_engine
	
	# Test: Get current time value
	var current_time = tm.current_time
	assert_true(current_time >= 0 and current_time <= 1440, "Time should be in valid range (0-1440)")
	
	print("  TimeManager: All tests completed")

func run_growth_system_tests():
	print("\n[GrowthSystem Tests]")
	
	var gs = GrowthSystem
	
	# Test: Get crop data
	var turnip = gs.get_crop_data("turnip")
	assert_true(turnip != null, "Should get turnip crop data")
	
	# Test: Crop data is a valid resource
	assert_true(turnip is Resource, "CropData should be a Resource")
	
	# Test: Get another crop
	var potato = gs.get_crop_data("potato")
	assert_true(potato != null, "Should get potato crop data")
	
	# Test: Get all crop IDs
	var crop_ids = gs.get_all_crop_ids()
	assert_true(crop_ids.size() > 0, "Should have crop IDs")
	
	# Test: Crop exists check
	assert_true(gs.has_crop("turnip"), "Should recognize turnip crop")
	assert_true(not gs.has_crop("nonexistent_crop"), "Should reject nonexistent crop")
	
	print("  GrowthSystem: All tests completed")

func run_crafting_system_tests():
	print("\n[CraftingSystem Tests]")
	
	var cs = CraftingSystem
	
	# Test: Get recipe
	var fried_egg = cs.get_recipe("fried_egg")
	assert_true(fried_egg != null, "Should get fried_egg recipe")
	
	# Test: Recipe properties
	assert_true(fried_egg.get("name") != "" or fried_egg.name != "", "Recipe should have name")
	assert_true(fried_egg.get("ingredients").size() > 0 or fried_egg.ingredients.size() > 0, "Recipe should have ingredients")
	
	# Test: Get result item
	assert_true(fried_egg.get("result_item") != "" or fried_egg.result_item != "", "Recipe should have result item")
	
	# Test: Get all recipes
	var all_recipes = cs.get_all_recipes()
	assert_true(all_recipes.size() > 0, "Should have recipes")
	
	# Test: Recipe exists check
	assert_true(cs.has_recipe("fried_egg"), "Should recognize fried_egg recipe")
	assert_true(not cs.has_recipe("nonexistent_recipe"), "Should reject nonexistent recipe")
	
	print("  CraftingSystem: All tests completed")

func run_money_system_tests():
	print("\n[MoneySystem Tests]")
	
	var ms = MoneySystem
	
	# Test: Get initial money
	var initial_money = ms.get_money()
	assert_true(initial_money >= 0, "Money should be non-negative")
	
	# Test: Can afford check
	assert_true(ms.can_afford(100), "Should be able to afford 100")
	assert_true(ms.can_afford(0), "Should be able to afford 0")
	assert_true(not ms.can_afford(9999999), "Should not be able to afford 9999999")
	
	# Test: Add money
	var before_add = ms.get_money()
	ms.add_money(100, ms.IncomeSource.OTHER, "test")
	assert_true(ms.get_money() == before_add + 100, "Money should increase by 100")
	
	# Test: Spend money
	var before_spend = ms.get_money()
	ms.spend_money(50, ms.ExpenseType.OTHER, "test")
	assert_true(ms.get_money() == before_spend - 50, "Money should decrease by 50")
	
	# Test: Get transactions
	var transactions = ms.get_transactions(5)
	assert_true(transactions is Array, "Transactions should be an array")
	
	# Test: Get stats
	var stats = ms.get_stats()
	assert_true(stats is Dictionary, "Stats should be a dictionary")
	
	print("  MoneySystem: All tests completed")

func run_shipping_system_tests():
	print("\n[ShippingSystem Tests]")
	
	var ss = ShippingSystem
	
	# Test: Add item to shipping bin
	var added = ss.add_item("turnip", 5, 0)
	assert_true(added, "Should add turnip to shipping bin")
	
	# Test: Get bin contents
	var contents = ss.get_bin_contents()
	assert_true(contents.size() > 0, "Should have contents in shipping bin")
	
	# Test: Get total items
	var total = ss.get_total_items()
	assert_true(total >= 5, "Should have at least 5 items")
	
	# Test: Calculate total value
	var value_info = ss.calculate_total_value()
	assert_true(value_info is Dictionary, "Value info should be a dictionary")
	
	# Test: Clear bin
	ss.clear_bin()
	assert_true(ss.get_total_items() == 0, "Shipping bin should be empty after clear")
	
	print("  ShippingSystem: All tests completed")

func run_gift_system_tests():
	print("\n[GiftSystem Tests]")
	
	var gs = GiftSystem
	
	# Test: Get NPC list
	var npcs = gs.get_all_npc_ids()
	assert_true(npcs.size() > 0, "Should have NPCs in gift system")
	
	# Test: Check if NPC exists
	var first_npc = npcs[0] if npcs.size() > 0 else ""
	if first_npc != "":
		assert_true(gs.has_npc(first_npc), "Should recognize NPC")
		assert_true(not gs.has_npc("nonexistent_npc"), "Should reject nonexistent NPC")
	
	# Test: Can give gift check
	if first_npc != "":
		var can_give = gs.can_give_gift(first_npc, "turnip")
		assert_true(can_give is Dictionary, "Can give gift should return dictionary")
	
	# Test: Get reaction type (without actually giving gift)
	if first_npc != "":
		var reaction = gs.get_reaction_type(first_npc, "turnip")
		assert_true(reaction >= 0, "Reaction should be non-negative")
	
	print("  GiftSystem: All tests completed")

func run_quest_system_tests():
	print("\n[QuestSystem Tests]")
	
	var qs = QuestSystem
	
	# Test: Get available quests
	var available = qs.get_available_quests()
	assert_true(available.size() > 0, "Should have available quests")
	
	# Test: Get all quest IDs
	var quest_ids = qs.get_all_quest_ids()
	assert_true(quest_ids.size() >= 10, "Should have multiple quests")
	
	# Test: Get quest data
	var first_quest = qs.get_quest_data(quest_ids[0]) if quest_ids.size() > 0 else null
	assert_true(first_quest != null, "Should get quest data")
	
	# Test: Has quest check
	if quest_ids.size() > 0:
		assert_true(qs.has_quest(quest_ids[0]), "Should recognize existing quest")
		assert_true(not qs.has_quest("nonexistent_quest"), "Should reject nonexistent quest")
	
	# Test: Get quest by NPC
	if first_quest != null:
		var npc_id = first_quest.get("quest_giver") if first_quest else ""
		if npc_id != "":
			var npc_quests = qs.get_quests_by_npc(npc_id)
			assert_true(npc_quests.size() > 0, "NPC should have quests")
	
	print("  QuestSystem: All tests completed")

func run_player_visual_tests():
	print("\n[Player Visual Tests]")

	var player_scene: PackedScene = load("res://src/entities/player/Player.tscn")
	assert_true(player_scene != null, "Player scene should load")

	if player_scene == null:
		print("  Player visuals: Scene load failed")
		return

	var player := player_scene.instantiate()
	var player_sprite := player.get_node_or_null("Sprite2D") as Sprite2D

	assert_true(player_sprite != null, "Player sprite should exist")
	if player_sprite:
		var frame_width: int = int(player_sprite.texture.get_width() / player_sprite.hframes)
		var frame_height: int = int(player_sprite.texture.get_height() / player_sprite.vframes)
		assert_true(frame_width == 64, "Player sprite frame width should be 64 (16px art ×4)")
		assert_true(frame_height == 64, "Player sprite frame height should be 64 (16px art ×4)")
		assert_true(player_sprite.scale == Vector2(1, 1), "Player sprite scale should be 1x (sheet already 64px)")

	player.free()
	print("  Player visuals: All tests completed")


func run_map_editor_resource_tests():
	print("\n[Map Editor Resource Tests]")

	var profile = load("res://data/maps/farm/farm_profile.tres")
	var library = load("res://data/maps/farm/farm_asset_library.tres")
	var tile_set = load("res://assets/tiles/farm_tileset.tres")
	var packed_map = load("res://src/world/maps/content/FarmMap.tscn")
	assert_true(profile != null, "Farm map profile should deserialize")
	assert_true(profile.layer_specs.size() == 6, "Farm profile should define six layers")
	assert_true(profile.collision_presets.size() == 3, "Farm profile should define three collision presets")
	assert_true(library != null and library.entries.size() == 8, "Farm asset library should deserialize eight entries")
	assert_true(tile_set != null and tile_set.get_terrain_sets_count() >= 3, "Farm TileSet should persist terrain sets")
	assert_true(tile_set != null and tile_set.get_physics_layers_count() >= 1, "Farm TileSet should persist collision data")

	var map = packed_map.instantiate()
	assert_true(map.size_in_tiles == Vector2i(50, 35), "Farm map should be 50 x 35")
	assert_true(map.get_layer(&"ground").get_used_cells().size() == 1750, "Farm ground should cover every tile")
	assert_true(map.get_layer(&"objects").get_child_count() == 8, "Farm map should contain eight migrated objects")
	assert_true(map.get_marker(&"player_spawn") != null, "Farm map should expose the player spawn marker")
	var custom_decoration_layer := MapLayer2D.new()
	custom_decoration_layer.layer_id = &"seasonal_decorations"
	custom_decoration_layer.layer_kind = MapLayerSpec.LayerKind.DECORATION
	map.add_child(custom_decoration_layer)
	var custom_spec: MapLayerSpec = map.get_layer_spec(&"seasonal_decorations")
	assert_true(
		custom_spec != null and custom_spec.accepts_asset_kind(MapAssetEntry.AssetKind.DECORATION),
		"Custom editor layers should retain resource type restrictions"
	)
	custom_decoration_layer.free()

	var camera := Camera2D.new()
	map.apply_camera_limits(camera)
	assert_true(
		camera.limit_left == 0 and camera.limit_top == 0
			and camera.limit_right == 3200 and camera.limit_bottom == 2240,
		"Farm camera limits should match the authored map rectangle"
	)
	assert_true(map.camera_limits_match(camera), "Map should recognize matching camera limits")
	camera.free()

	var north_boundary := map.get_node("Collision/NorthBoundary") as MapCollisionBody2D
	north_boundary.position.y -= 64.0
	var found_boundary_geometry := false
	for issue in map.validate():
		if issue.code == &"world_boundary_geometry":
			found_boundary_geometry = true
			break
	assert_true(found_boundary_geometry, "Map validation should report stale world boundary geometry")
	assert_true(map.rebuild_world_boundaries(), "Map should rebuild all four world boundaries")
	var boundary_error_after_rebuild := false
	for issue in map.validate():
		if issue.code in [&"world_boundary_geometry", &"world_boundary_missing", &"world_boundary_duplicate"]:
			boundary_error_after_rebuild = true
			break
	assert_true(not boundary_error_after_rebuild, "Rebuilt world boundaries should match the map size")

	var duplicate_marker = load("res://src/world/map_editor/MapMarker2D.gd").new()
	duplicate_marker.marker_id = &"player_spawn"
	map.get_layer(&"markers").add_child(duplicate_marker)
	var found_duplicate := false
	for issue in map.validate():
		if issue.code == &"marker_id_duplicate":
			found_duplicate = true
			break
	assert_true(found_duplicate, "Map validation should report duplicate marker ids")
	duplicate_marker.free()

	var invalid_body = load("res://src/world/map_editor/MapCollisionBody2D.gd").new()
	invalid_body.collision_layer = 1
	var invalid_polygon := CollisionPolygon2D.new()
	invalid_polygon.polygon = PackedVector2Array([Vector2.ZERO, Vector2(64, 64)])
	invalid_body.add_child(invalid_polygon)
	map.get_layer(&"collision").add_child(invalid_body)
	var found_invalid_polygon := false
	for issue in map.validate():
		if issue.code == &"collision_polygon_invalid":
			found_invalid_polygon = true
			break
	assert_true(found_invalid_polygon, "Map validation should report invalid collision polygons")
	invalid_body.free()

	var library_copy = library.duplicate(true)
	var source_path: String = library_copy.entries[0].resource.resource_path
	assert_true(library_copy.unregister(library_copy.entries[0].asset_id), "Asset library should unregister entries")
	assert_true(ResourceLoader.exists(source_path), "Unregistering should not delete the source resource")
	map.free()

	var agent_api = load("res://tools/map_editor/MapAgentAPI.gd").new()
	var agent_recipe := {
		"version": 1,
		"expected_map_id": "farm_main",
		"allowed_region": {"x": 44, "y": 29, "width": 4, "height": 4},
		"operations": [
			{"op": "paint_rect", "layer": "ground", "from": [44, 29], "to": [45, 30], "tile": {"source": 0, "atlas": [0, 0]}},
			{"op": "place_asset", "asset": "ore", "at": [45, 30], "space": "tile", "name": "AgentOre", "properties": {"ore_type": 0}},
			{"op": "collision_rect", "at": [46, 30], "space": "tile", "size": [32, 32], "preset": "world_solid"},
			{"op": "marker", "id": "agent_test_anchor", "at": [45, 31], "space": "tile"},
		],
	}
	var agent_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", agent_recipe, "", true
	)
	assert_true(agent_result.ok, "Agent API should apply a valid recipe transactionally")
	assert_true(agent_result.get("changes", []).size() == 4, "Agent API should report every applied operation")
	var rejected_recipe := agent_recipe.duplicate(true)
	rejected_recipe.operations[0].from = [1, 1]
	rejected_recipe.operations[0].to = [1, 1]
	var rejected_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", rejected_recipe, "", true
	)
	assert_true(not rejected_result.ok, "Agent API should reject edits outside allowed_region")
	var stale_recipe := agent_recipe.duplicate(true)
	stale_recipe["expected_scene_sha256"] = "stale-map-hash"
	var stale_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", stale_recipe, "", true
	)
	assert_true(not stale_result.ok, "Agent API should reject a stale scene hash")
	var unsafe_recipe := agent_recipe.duplicate(true)
	unsafe_recipe.operations = [
		{"op": "place_asset", "asset": "ore", "at": [45, 30], "space": "tile", "properties": {"position": [0, 0]}},
	]
	var unsafe_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", unsafe_recipe, "", true
	)
	assert_true(not unsafe_result.ok, "Agent API should reject non-whitelisted object properties")
	var resize_recipe := {
		"version": 1,
		"expected_map_id": "farm_main",
		"operations": [
			{"op": "resize_map", "size": [52, 36], "fill": {"source": 0, "atlas": [0, 0]}},
		],
	}
	var resize_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", resize_recipe, "", true
	)
	assert_true(resize_result.ok, "Agent API should resize, fill, and rebuild map boundaries transactionally")
	var restricted_resize := resize_recipe.duplicate(true)
	restricted_resize["allowed_region"] = {"x": 0, "y": 0, "width": 2, "height": 2}
	var restricted_resize_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", restricted_resize, "", true
	)
	assert_true(not restricted_resize_result.ok, "Agent API should reject whole-map resizing inside allowed_region")
	var metadata_recipe := {
		"version": 1,
		"expected_map_id": "farm_main",
		"operations": [
			{"op": "set_map_metadata", "map_id": "agent_named_map", "display_name": "Agent Named Map"},
		],
	}
	var metadata_result: Dictionary = agent_api.apply_recipe(
		"res://src/world/maps/content/FarmMap.tscn", metadata_recipe, "", true
	)
	assert_true(metadata_result.ok, "Agent API should update map identity transactionally")

	var example_packed := load("res://src/world/maps/content/PastoralValleyMap.tscn") as PackedScene
	assert_true(example_packed != null, "Pastoral Valley example map should deserialize")
	var example_map := example_packed.instantiate() as EditableMap2D
	assert_true(example_map.map_id == &"pastoral_valley", "Example map should use an independent map id")
	assert_true(example_map.get_layer(&"objects").get_child_count() == 10, "Example map should contain ten authored objects")
	assert_true(example_map.get_layer(&"markers").get_child_count() == 5, "Example map should contain five semantic markers")
	var example_errors := 0
	for issue in example_map.validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			example_errors += 1
	assert_true(example_errors == 0, "Example map should pass complete map validation")
	example_map.free()

	print("  Map editor resources: All tests completed")


func assert_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % message)
	else:
		failed_tests += 1
		print("  [FAIL] %s" % message)
