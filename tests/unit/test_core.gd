extends Node
const DebugLaunchScript = preload("res://src/core/debug/DebugLaunch.gd")

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
	run_season_regrow_shop_tests()
	run_debug_launch_parse_tests()
	run_day_start_and_collapse_tests()
	run_eat_food_stamina_tests()
	run_watering_can_upgrade_and_rain_tests()
	run_debug_time_skip_tests()
	run_tool_upgrade_material_name_tests()
	run_tool_upgrade_focus_select_tests()
	run_seed_sprite_tests()
	run_quest_tracker_visibility_tests()
	run_shipping_bin_interact_tests()
	run_debris_wrong_tool_tests()
	run_tool_number_hotkey_tests()
	run_house_camera_follow_tests()
	run_shop_find_guide_tests()
	run_quest_tracker_feature_tests()
	
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

func run_season_regrow_shop_tests():
	print("\n[Season Regrow Shop Tests]")

	var farm_baseline: Dictionary = FarmState.get_save_state()
	var plot := _season_open_plot(farm_baseline)
	var saved_time: float = TimeManager.current_time
	var saved_day: int = TimeManager.current_day
	var saved_season: int = TimeManager.current_season
	var saved_year: int = TimeManager.current_year
	var saved_paused: bool = TimeManager.is_paused
	var saved_pause_count: int = TimeManager._pause_count
	var saved_scale: float = TimeManager.time_scale
	var saved_acc: float = TimeManager._time_accumulator
	var money_before: int = MoneySystem.get_money()
	var tracked := ["turnip_seed", "potato_seed", "green_bean_seed", "tomato_seed", "corn_seed", "pumpkin_seed", "green_bean", "fiber_seeds"]
	var counts := {}
	for item_id in tracked:
		counts[item_id] = Inventory.get_item_count(item_id)

	var turnip_data = GrowthSystem.get_crop_data("turnip")
	var bean_data = GrowthSystem.get_crop_data("green_bean")
	var corn_data = GrowthSystem.get_crop_data("corn")
	assert_true(turnip_data != null and bean_data != null and corn_data != null, "Season fixtures should resolve turnip, green bean, and corn")
	var saved_dies: bool = turnip_data.dies_out_of_season if turnip_data != null else true

	var young_turnip := {
		"crop_id": "turnip",
		"stage": 1,
		"days_in_stage": 0,
		"total_days": 2,
		"watered": false,
		"quality": 0,
		"mature": false,
	}
	TimeManager.current_season = 0
	TimeManager.current_day = TimeManager.DAYS_PER_SEASON
	TimeManager.current_time = 10.0
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, young_turnip, FarmState.WATERED)), "Wilt fixture should load")
	FarmState.advance_day()
	var wilted := FarmState.get_cell(plot)
	var wilted_crop := Dictionary(wilted.get("crop", {}))
	assert_true(
		str(wilted_crop.get("crop_id", "")) == "turnip"
			and bool(wilted_crop.get("dead", false))
			and not bool(wilted_crop.get("mature", true)),
		"Season change keeps an out-of-season crop and marks it dead"
	)
	assert_true(int(wilted.get("state", -1)) == FarmState.TILLED, "Wilted soil stays tilled")
	assert_true(not FarmState.can_harvest(plot) and FarmState.harvest(plot).is_empty(), "A dead crop cannot be harvested")
	var dead_round := FarmState.get_save_state()
	assert_true(FarmState.load_save_state(dead_round), "Dead crop save should load")
	var reloaded_dead := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(
		str(reloaded_dead.get("crop_id", "")) == "turnip" and bool(reloaded_dead.get("dead", false)) and reloaded_dead.has("dead"),
		"Save and load keep the dead flag"
	)
	assert_true(
		FarmState.dead_crop_sprite_path("turnip") == "res://assets/sprites/crops/turnip_stagedead.png"
			and FarmState.dead_crop_sprite_path("green_bean") == "res://assets/sprites/crops/green_bean_stagedead.png"
			and ResourceLoader.exists(FarmState.dead_crop_sprite_path("turnip")),
		"Known crops resolve their stagedead sprite"
	)
	assert_true(
		FarmState.dead_crop_sprite_path("missing_crop_id") == "res://assets/sprites/crops/crop_dead.png"
			and ResourceLoader.exists(FarmState.dead_crop_sprite_path("missing_crop_id")),
		"A crop without stagedead art falls back to crop_dead.png"
	)
	var visual := FarmPlot.new()
	add_child(visual)
	visual.setup(plot)
	var shown := ""
	if visual._crop_sprite != null and visual._crop_sprite.texture != null:
		shown = str(visual._crop_sprite.texture.resource_path)
	assert_true(shown == FarmState.dead_crop_sprite_path("turnip"), "FarmPlot draws the stagedead sprite for a dead crop")
	assert_true(
		visual._crop_sprite != null
			and visual._crop_sprite.texture != null
			and visual._crop_sprite.scale.x > 0.0
			and is_equal_approx(visual._crop_sprite.scale.x, visual._crop_sprite.scale.y)
			and is_equal_approx(visual._crop_sprite.offset.y, -visual._crop_sprite.texture.get_height() / 2.0),
		"Dead crop sprite uses the same uniform scale and ground alignment as a living crop"
	)
	visual.free()
	var crop_node := Crop.new()
	var crop_sprite := Sprite2D.new()
	crop_sprite.name = "Sprite2D"
	crop_node.add_child(crop_sprite)
	add_child(crop_node)
	crop_node.crop_id = "green_bean"
	crop_node.crop_data = bean_data
	crop_node.current_state = Crop.State.DEAD
	crop_node._update_sprite()
	var crop_shown := ""
	if crop_node.sprite != null and crop_node.sprite.texture != null:
		crop_shown = str(crop_node.sprite.texture.resource_path)
	assert_true(crop_shown == FarmState.dead_crop_sprite_path("green_bean"), "Crop.gd dead state prefers the crop stagedead sprite")
	crop_node.crop_id = "missing_crop_id"
	crop_node._update_sprite()
	var fallback_shown := ""
	if crop_node.sprite != null and crop_node.sprite.texture != null:
		fallback_shown = str(crop_node.sprite.texture.resource_path)
	assert_true(fallback_shown == "res://assets/sprites/crops/crop_dead.png", "Crop.gd dead state falls back to crop_dead.png")
	crop_node.free()
	var young_bean := {
		"crop_id": "green_bean",
		"stage": 1,
		"days_in_stage": 0,
		"total_days": 2,
		"watered": false,
		"quality": 0,
		"mature": true,
	}
	TimeManager.current_season = 0
	TimeManager.current_day = TimeManager.DAYS_PER_SEASON
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, young_bean, FarmState.WATERED)), "Green bean season fixture should load")
	FarmState.advance_day()
	var bean_wilted := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(
		str(bean_wilted.get("crop_id", "")) == "green_bean"
			and bool(bean_wilted.get("dead", false))
			and not bool(bean_wilted.get("mature", true))
			and not FarmState.can_harvest(plot),
		"Spring green beans die on summer day 1 and stay on the plot"
	)
	TimeManager.current_day = 2
	TimeManager.current_season = 1
	var bean_stage := int(bean_wilted.get("stage", -1))
	FarmState.water(plot)
	FarmState.advance_day()
	var bean_still := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(
		bool(bean_still.get("dead", false))
			and str(bean_still.get("crop_id", "")) == "green_bean"
			and int(bean_still.get("stage", -2)) == bean_stage
			and not bool(bean_still.get("mature", true)),
		"A dead crop does not grow on a later day"
	)
	var turnips_before := Inventory.get_item_count("turnip")
	var stamina_before := StaminaManager.current_stamina
	if stamina_before < 6.0:
		StaminaManager.set_stamina(StaminaManager.max_stamina)
		stamina_before = StaminaManager.current_stamina
	var farm_tools := Farm.new()
	farm_tools.perform_farm_action(plot, ToolManager.ToolType.SICKLE)
	assert_true(
		Dictionary(FarmState.get_cell(plot).get("crop", {})).is_empty()
			and int(FarmState.get_cell(plot).get("state", -1)) == FarmState.TILLED
			and Inventory.get_item_count("turnip") == turnips_before
			and is_equal_approx(StaminaManager.current_stamina, stamina_before - 2.0),
		"Sickle clears a dead crop without harvesting it"
	)
	assert_true(FarmState.load_save_state(dead_round), "Dead turnip fixture reloads for the hoe")
	farm_tools.perform_farm_action(plot, ToolManager.ToolType.HOE)
	assert_true(
		Dictionary(FarmState.get_cell(plot).get("crop", {})).is_empty()
			and int(FarmState.get_cell(plot).get("state", -1)) == FarmState.TILLED,
		"Hoe clears a dead crop and leaves tilled soil"
	)
	TimeManager.current_season = 0
	TimeManager.current_day = 2
	if Inventory.get_item_count("turnip_seed") < 1:
		Inventory.add_item("turnip_seed", 1)
	assert_true(FarmState.plant(plot, "turnip_seed"), "Tilled soil can be planted after the dead crop is cleared")
	var replanted := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(str(replanted.get("crop_id", "")) == "turnip" and not bool(replanted.get("dead", true)), "A new planting is alive")
	farm_tools.perform_farm_action(plot, ToolManager.ToolType.HOE)
	farm_tools.perform_farm_action(plot, ToolManager.ToolType.SICKLE)
	var still_alive := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(
		str(still_alive.get("crop_id", "")) == "turnip" and not bool(still_alive.get("dead", true)),
		"Hoe and sickle leave a living crop in place"
	)
	farm_tools.free()
	StaminaManager.set_stamina(stamina_before)

	TimeManager.current_season = 0
	TimeManager.current_day = 10
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, young_turnip, FarmState.WATERED)), "Mid-season fixture should load")
	FarmState.advance_day()
	var stayed := FarmState.get_cell(plot)
	assert_true(str(Dictionary(stayed.get("crop", {})).get("crop_id", "")) == "turnip", "A day that does not change season does not wilt")
	assert_true(int(stayed.get("state", -1)) == FarmState.TILLED, "A watered plot dries back to tilled overnight")

	var young_corn := {
		"crop_id": "corn",
		"stage": 1,
		"days_in_stage": 0,
		"total_days": 2,
		"watered": false,
		"quality": 0,
		"mature": false,
	}
	TimeManager.current_season = 1
	TimeManager.current_day = TimeManager.DAYS_PER_SEASON
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, young_corn, FarmState.WATERED)), "Corn fixture should load")
	FarmState.advance_day()
	var corn_cell := FarmState.get_cell(plot)
	assert_true(
		str(Dictionary(corn_cell.get("crop", {})).get("crop_id", "")) == "corn"
			and not bool(Dictionary(corn_cell.get("crop", {})).get("dead", false)),
		"Summer to fall keeps corn because fall is in its seasons"
	)

	if turnip_data != null:
		turnip_data.dies_out_of_season = false
	TimeManager.current_season = 0
	TimeManager.current_day = TimeManager.DAYS_PER_SEASON
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, young_turnip, FarmState.TILLED)), "Persistent crop fixture should load")
	FarmState.advance_day()
	var kept := FarmState.get_cell(plot)
	assert_true(str(Dictionary(kept.get("crop", {})).get("crop_id", "")) == "turnip", "dies_out_of_season false keeps the crop across a season change")
	if turnip_data != null:
		turnip_data.dies_out_of_season = saved_dies

	TimeManager.current_season = 0
	TimeManager.current_day = 5
	var mature_bean := {
		"crop_id": "green_bean",
		"stage": bean_data.growth_days.size() - 1,
		"days_in_stage": 0,
		"total_days": bean_data.get_total_growth_days(),
		"watered": true,
		"quality": 0,
		"mature": true,
	}
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, mature_bean, FarmState.TILLED)), "Regrow fixture should load")
	assert_true(Inventory.can_add_item("green_bean", bean_data.max_harvest), "Inventory should have room for a green bean harvest")
	var harvested: Dictionary = FarmState.harvest(plot)
	var after_harvest := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(not harvested.is_empty() and str(harvested.get("crop_id", "")) == "green_bean", "Harvesting a mature green bean yields the crop")
	assert_true(not bool(after_harvest.get("mature", true)) and int(after_harvest.get("regrow_days_left", -1)) == int(bean_data.regrow_days), "Harvest starts a regrow_days countdown")
	assert_true(int(after_harvest.get("stage", -1)) == bean_data.growth_days.size() - 2, "Regrow harvest steps back one stage")

	FarmState.advance_day()
	var dry := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(int(dry.get("regrow_days_left", -1)) == int(bean_data.regrow_days) and not bool(dry.get("mature", true)), "An unwatered regrow day does not decrement")

	FarmState.water(plot)
	FarmState.advance_day()
	var once := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(int(once.get("regrow_days_left", -1)) == int(bean_data.regrow_days) - 1 and not bool(once.get("mature", true)), "One watered regrow day decrements by 1")
	FarmState.water(plot)
	FarmState.advance_day()
	var twice := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(int(twice.get("regrow_days_left", -1)) == int(bean_data.regrow_days) - 2 and not bool(twice.get("mature", true)), "Two watered regrow days stay immature when regrow_days is 3")
	FarmState.water(plot)
	FarmState.advance_day()
	var ripe := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(bool(ripe.get("mature", false)) and int(ripe.get("regrow_days_left", -1)) == 0, "Regrow matures only when the countdown reaches 0")
	assert_true(int(ripe.get("stage", -1)) == bean_data.growth_days.size() - 1, "A regrown crop returns to the final stage")

	var old_save := {
		"crop_id": "green_bean",
		"stage": bean_data.growth_days.size() - 2,
		"days_in_stage": 0,
		"total_days": bean_data.get_total_growth_days(),
		"watered": false,
		"quality": 0,
		"mature": false,
	}
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, old_save, FarmState.TILLED)), "Old regrow save should load")
	FarmState.advance_day()
	var migrated := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(migrated.has("regrow_days_left") and int(migrated.get("regrow_days_left", -1)) == int(bean_data.regrow_days), "An old save without regrow_days_left starts the countdown and skips an unwatered day")
	FarmState.water(plot)
	FarmState.advance_day()
	var migrated_wet := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(int(migrated_wet.get("regrow_days_left", -1)) == int(bean_data.regrow_days) - 1 and not bool(migrated_wet.get("mature", true)), "A migrated countdown decrements only after watering")

	var fresh_bean := {
		"crop_id": "green_bean",
		"stage": 0,
		"days_in_stage": 0,
		"total_days": 0,
		"watered": true,
		"quality": 0,
		"mature": false,
	}
	assert_true(FarmState.load_save_state(_season_with_crop(farm_baseline, plot, fresh_bean, FarmState.WATERED)), "First-growth fixture should load")
	FarmState.advance_day()
	var first := Dictionary(FarmState.get_cell(plot).get("crop", {}))
	assert_true(not first.has("regrow_days_left") and int(first.get("total_days", -1)) == 1 and int(first.get("stage", -1)) == 1 and not bool(first.get("mature", true)), "First growth still uses growth_days and does not start regrow")

	if MoneySystem.get_money() < 300:
		MoneySystem.add_money(1000, MoneySystem.IncomeSource.OTHER, "season_test_pad")
	TimeManager.current_time = 10.0
	TimeManager.current_day = 10
	TimeManager.current_season = 0
	TimeManager.is_paused = false
	TimeManager._pause_count = 0
	var shop = load("res://src/core/economy/ShopSystem.gd").new()
	add_child(shop)
	var caught := {"reason": ""}
	shop.purchase_failed.connect(func(reason: String) -> void: caught["reason"] = reason)
	assert_true(shop.open_shop("seed_shop"), "Seed shop should be open at 10:00")

	var spring_ids: Array = _season_shop_ids(shop, "seed_shop")
	assert_true(spring_ids.has("green_bean_seed") and spring_ids.has("turnip_seed") and spring_ids.has("potato_seed"), "Spring seed shop lists spring seeds including green beans")
	assert_true(not spring_ids.has("fiber_seeds") and spring_ids.has("basic_fertilizer") and not spring_ids.has("sunflower") and not spring_ids.has("daffodil"), "Spring seed shop keeps fertilizer, does not sell fiber seeds, and does not sell foraged flowers")
	assert_true(not spring_ids.has("tomato_seed") and not spring_ids.has("corn_seed") and not spring_ids.has("pumpkin_seed"), "Spring seed shop hides summer and fall seeds")

	caught["reason"] = ""
	var tomato_before: int = Inventory.get_item_count("tomato_seed")
	var money_at_reject: int = MoneySystem.get_money()
	assert_true(not shop.buy_item("tomato_seed", 1), "Spring purchase of tomato seeds should fail")
	assert_true(str(caught["reason"]) == "wrong_season", "Out-of-season seed purchase reports wrong_season")
	assert_true(MoneySystem.get_money() == money_at_reject and Inventory.get_item_count("tomato_seed") == tomato_before, "A rejected seasonal purchase changes neither money nor inventory")

	var turnip_before: int = Inventory.get_item_count("turnip_seed")
	var money_at_turnip: int = MoneySystem.get_money()
	var bought_turnip: bool = shop.buy_item("turnip_seed", 1)
	assert_true(bought_turnip and Inventory.get_item_count("turnip_seed") == turnip_before + 1, "Spring turnip seeds can be bought")
	assert_true(money_at_turnip - MoneySystem.get_money() == shop.calculate_buy_price("turnip_seed", 1), "Spring turnip seeds charge the shop price")

	var bean_before: int = Inventory.get_item_count("green_bean_seed")
	var bought_bean: bool = shop.buy_item("green_bean_seed", 1)
	assert_true(bought_bean and Inventory.get_item_count("green_bean_seed") == bean_before + 1, "Spring green bean seeds can be bought")

	TimeManager.current_season = 1
	var summer_ids: Array = _season_shop_ids(shop, "seed_shop")
	assert_true(summer_ids.has("tomato_seed") and summer_ids.has("corn_seed") and not summer_ids.has("fiber_seeds"), "Summer seed shop lists summer seeds without fiber seeds")
	assert_true(not summer_ids.has("green_bean_seed") and not summer_ids.has("turnip_seed") and not summer_ids.has("potato_seed") and not summer_ids.has("pumpkin_seed"), "Summer seed shop hides spring and fall seeds")
	caught["reason"] = ""
	var summer_turnip_before: int = Inventory.get_item_count("turnip_seed")
	var money_at_summer: int = MoneySystem.get_money()
	assert_true(not shop.buy_item("turnip_seed", 1) and str(caught["reason"]) == "wrong_season", "Summer purchase of turnip seeds should fail as wrong_season")
	assert_true(MoneySystem.get_money() == money_at_summer and Inventory.get_item_count("turnip_seed") == summer_turnip_before, "Summer rejection keeps money and turnip seeds")
	var summer_tomato_before: int = Inventory.get_item_count("tomato_seed")
	assert_true(shop.buy_item("tomato_seed", 1) and Inventory.get_item_count("tomato_seed") == summer_tomato_before + 1, "Summer tomato seeds can be bought")

	var shelf_has_fiber := false
	for shop_id in shop.get_all_shop_ids():
		var shelf = shop.get_shop(str(shop_id))
		if shelf == null:
			continue
		for entry in shelf.items:
			if str(entry.get("item_id", "")) == "fiber_seeds":
				shelf_has_fiber = true
	assert_true(not shelf_has_fiber, "No shop shelf lists fiber_seeds")
	assert_true(ItemDatabase.has_item("fiber_seeds"), "fiber_seeds stays in the item database")

	shop.close_shop()
	remove_child(shop)
	shop.free()

	if turnip_data != null:
		turnip_data.dies_out_of_season = saved_dies
	FarmState.load_save_state(farm_baseline)
	TimeManager.current_time = saved_time
	TimeManager.current_day = saved_day
	TimeManager.current_season = saved_season
	TimeManager.current_year = saved_year
	TimeManager.is_paused = saved_paused
	TimeManager._pause_count = saved_pause_count
	TimeManager.time_scale = saved_scale
	TimeManager._time_accumulator = saved_acc
	var money_delta := MoneySystem.get_money() - money_before
	if money_delta > 0:
		MoneySystem.spend_money(money_delta, MoneySystem.ExpenseType.OTHER, "season_test_restore")
	elif money_delta < 0:
		MoneySystem.add_money(-money_delta, MoneySystem.IncomeSource.OTHER, "season_test_restore")
	for item_id in tracked:
		_season_restore_count(item_id, int(counts[item_id]))
	assert_true(MoneySystem.get_money() == money_before, "Season tests restore the original money")
	assert_true(Inventory.get_item_count("green_bean") == int(counts["green_bean"]), "Season tests restore harvested green beans")
	assert_true(Inventory.get_item_count("tomato_seed") == int(counts["tomato_seed"]), "Season tests restore tomato seeds")

	print("  Season regrow shop: All tests completed")


func _season_open_plot(state: Dictionary) -> Vector2i:
	for raw in state.get("cells", []):
		if str(raw.get("debris", "")) == "":
			return Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
	return Vector2i(1, 1)


func _season_with_crop(state: Dictionary, coord: Vector2i, crop: Dictionary, soil: int) -> Dictionary:
	var data := state.duplicate(true) as Dictionary
	for raw in data.get("cells", []):
		if int(raw.get("x", -1)) == coord.x and int(raw.get("y", -1)) == coord.y:
			raw["state"] = soil
			raw["debris"] = ""
			raw["debris_hits"] = 0
			raw["crop"] = crop.duplicate(true)
			break
	return data


func _season_shop_ids(shop, shop_id: String) -> Array:
	var ids: Array = []
	for entry in shop.get_shop_items(shop_id):
		ids.append(str(entry.get("item_id", "")))
	return ids


func _season_restore_count(item_id: String, before: int) -> void:
	var now := Inventory.get_item_count(item_id)
	if now > before:
		Inventory.remove_item(item_id, now - before)
	elif now < before:
		Inventory.add_item(item_id, before - now)


func run_debug_launch_parse_tests() -> void:
	print("\n[Debug Launch Parse Tests]")

	var enabled := DebugLaunchScript.parse(PackedStringArray([
		"--new-game",
		"--start-day=14",
		"--season=summer",
		"--debug-crops",
	]), true)
	assert_true(
		bool(enabled.get("new_game", false))
			and int(enabled.get("start_day", 0)) == 14
			and str(enabled.get("season", "")) == "summer"
			and bool(enabled.get("debug_crops", false))
			and int(enabled.get("slot", 0)) == -1,
		"--new-game with start-day, season and debug-crops parses all three"
	)

	var reordered := DebugLaunchScript.parse(PackedStringArray([
		"--start-day=7",
		"--season=Winter",
		"--debug-crops",
		"--new-game",
	]), true)
	assert_true(
		bool(reordered.get("new_game", false))
			and int(reordered.get("start_day", 0)) == 7
			and str(reordered.get("season", "")) == "winter"
			and bool(reordered.get("debug_crops", false)),
		"Flags before --new-game still parse, and season is case-insensitive"
	)

	var bounds := DebugLaunchScript.parse(PackedStringArray([
		"--new-game",
		"--start-day=1",
		"--start-day=28",
		"--start-day=29",
		"--season=fall",
		"--season=autumn",
		"--debug-crops",
		"--debug-crop=tomato",
		"--debug-crops=tomato",
	]), true)
	assert_true(int(bounds.get("start_day", 0)) == 28, "start-day 1 and 28 are valid; 29 does not replace 28")
	assert_true(str(bounds.get("season", "")) == "fall", "season=fall is kept and autumn is ignored")
	assert_true(bool(bounds.get("debug_crops", false)), "--debug-crops is a flag; an old --debug-crop= value does not turn it off")

	var rejected := DebugLaunchScript.parse(PackedStringArray([
		"--new-game",
		"--start-day=0",
		"--start-day=abc",
		"--start-day=",
		"--season=",
		"--season=springtime",
		"--debug-crop=tomato",
		"--debug-crops=green_bean",
	]), true)
	assert_true(
		bool(rejected.get("new_game", false))
			and int(rejected.get("start_day", -1)) == 0
			and str(rejected.get("season", "x")) == ""
			and not bool(rejected.get("debug_crops", true)),
		"Out-of-range values are ignored, and --debug-crops does not take an id"
	)

	var plain := DebugLaunchScript.parse(PackedStringArray([
		"--start-day=14",
		"--season=winter",
		"--debug-crops",
		"--load-slot=2",
	]), true)
	assert_true(
		not bool(plain.get("new_game", false))
			and int(plain.get("start_day", -1)) == 0
			and str(plain.get("season", "x")) == ""
			and not bool(plain.get("debug_crops", true))
			and int(plain.get("slot", -1)) == 1,
		"Without --new-game the day, season and debug-crops flags are dropped"
	)

	var only_new := DebugLaunchScript.parse(PackedStringArray(["--new-game"]), true)
	assert_true(
		bool(only_new.get("new_game", false))
			and int(only_new.get("start_day", -1)) == 0
			and str(only_new.get("season", "x")) == ""
			and not bool(only_new.get("debug_crops", true)),
		"--new-game alone leaves day, season and debug-crops unset"
	)

	var release := DebugLaunchScript.parse(PackedStringArray([
		"--new-game",
		"--start-day=14",
		"--season=summer",
		"--debug-crops",
	]), false)
	assert_true(
		not bool(release.get("new_game", false))
			and int(release.get("start_day", -1)) == 0
			and str(release.get("season", "x")) == ""
			and not bool(release.get("debug_crops", true)),
		"Release builds ignore --new-game and the debug calendar flags"
	)

	var last_day := DebugLaunchScript.parse(PackedStringArray([
		"--new-game",
		"--start-day=3",
		"--start-day=10",
		"--start-day=99",
	]), true)
	assert_true(int(last_day.get("start_day", 0)) == 10, "The last valid --start-day wins")

	var pinned := FarmState.progress_one_day_before_mature([2, 2, 2, 3])
	assert_true(
		int(pinned.get("stage", -1)) == 3
			and int(pinned.get("days_in_stage", -1)) == 2
			and int(pinned.get("total_days", -1)) == 8,
		"Tomato-shaped growth [2,2,2,3] is one watered day from mature"
	)
	var bean_pin := FarmState.progress_one_day_before_mature([1, 2, 2, 3])
	assert_true(
		int(bean_pin.get("stage", -1)) == 3
			and int(bean_pin.get("days_in_stage", -1)) == 2
			and int(bean_pin.get("total_days", -1)) == 7,
		"Green-bean-shaped growth [1,2,2,3] is one watered day from mature"
	)
	var single := FarmState.progress_one_day_before_mature([1])
	assert_true(
		int(single.get("stage", -1)) == 0 and int(single.get("days_in_stage", -1)) == 0,
		"A one-day crop sits at stage 0 with zero days in that stage"
	)
	assert_true(FarmState.progress_one_day_before_mature([]).is_empty(), "Empty growth_days has no debug progress")

	var saved_day := TimeManager.current_day
	var saved_season := TimeManager.current_season
	var saved_time := TimeManager.current_time
	var saved_game_season := -1
	if GameSession != null and GameSession.season != null:
		saved_game_season = int(GameSession.season.current_season)
	var farm_baseline: Dictionary = FarmState.get_save_state()
	var tomato_seeds_before := Inventory.get_item_count("tomato_seed")
	var bean_seeds_before := Inventory.get_item_count("green_bean_seed")
	var can_before := FarmState.get_watering_can_water()
	var day_before_noop := TimeManager.current_day
	DebugLaunchScript.apply_new_game_options({
		"new_game": false,
		"start_day": 14,
		"season": "winter",
		"debug_crops": true,
	})
	assert_true(TimeManager.current_day == day_before_noop, "apply without --new-game does not change the day")

	var launch := DebugLaunchScript.parse(PackedStringArray([
		"--debug-crops",
		"--season=summer",
		"--start-day=14",
		"--new-game",
	]), true)
	DebugLaunchScript.apply_new_game_options(launch)
	var tomato_cell := FarmState.get_cell(FarmState.DEBUG_FIRST_RIDGE)
	var bean_cell := FarmState.get_cell(FarmState.DEBUG_SECOND_RIDGE)
	var tomato_crop: Dictionary = tomato_cell.get("crop", {})
	var bean_crop: Dictionary = bean_cell.get("crop", {})
	var tomato = GrowthSystem.get_crop_data("tomato")
	var green_bean = GrowthSystem.get_crop_data("green_bean")
	var tomato_expected: Dictionary = {}
	var bean_expected: Dictionary = {}
	if tomato != null:
		tomato_expected = FarmState.progress_one_day_before_mature(tomato.growth_days)
	if green_bean != null:
		bean_expected = FarmState.progress_one_day_before_mature(green_bean.growth_days)
	var planted := 0
	for y in FarmState.GRID_HEIGHT:
		for x in FarmState.GRID_WIDTH:
			var other: Dictionary = FarmState.get_cell(Vector2i(x, y)).get("crop", {})
			if not other.is_empty():
				planted += 1
	assert_true(
		TimeManager.current_day == 14 and is_equal_approx(TimeManager.current_time, 9.0),
		"apply sets day 14 at 9:00"
	)
	assert_true(TimeManager.current_season == 1, "summer is season index 1")
	assert_true(
		GameSession != null and GameSession.season != null and int(GameSession.season.current_season) == 1,
		"SeasonSystem follows the debug season"
	)
	assert_true(
		int(tomato_cell.get("state", -1)) == FarmState.WATERED
			and str(tomato_cell.get("debris", "x")) == ""
			and str(tomato_crop.get("crop_id", "")) == "tomato"
			and bool(tomato_crop.get("watered", false))
			and not bool(tomato_crop.get("mature", true))
			and not tomato_crop.has("regrow_days_left")
			and int(tomato_crop.get("stage", -1)) == int(tomato_expected.get("stage", -2))
			and int(tomato_crop.get("days_in_stage", -1)) == int(tomato_expected.get("days_in_stage", -2))
			and int(tomato_crop.get("total_days", -1)) == int(tomato_expected.get("total_days", -2)),
		"First ridge holds one watered tomato one day before mature"
	)
	assert_true(
		int(bean_cell.get("state", -1)) == FarmState.WATERED
			and str(bean_cell.get("debris", "x")) == ""
			and str(bean_crop.get("crop_id", "")) == "green_bean"
			and bool(bean_crop.get("watered", false))
			and not bool(bean_crop.get("mature", true))
			and not bean_crop.has("regrow_days_left")
			and int(bean_crop.get("stage", -1)) == int(bean_expected.get("stage", -2))
			and int(bean_crop.get("days_in_stage", -1)) == int(bean_expected.get("days_in_stage", -2))
			and int(bean_crop.get("total_days", -1)) == int(bean_expected.get("total_days", -2)),
		"Next ridge holds one watered green bean one day before mature"
	)
	assert_true(planted == 2, "Debug crops plant tomato and green bean only")
	assert_true(Inventory.get_item_count("tomato_seed") == tomato_seeds_before, "Debug crops do not spend tomato seeds")
	assert_true(Inventory.get_item_count("green_bean_seed") == bean_seeds_before, "Debug crops do not spend green bean seeds")
	assert_true(FarmState.get_watering_can_water() == can_before, "Debug crops do not spend watering-can water")

	FarmState.advance_day()
	var grown_tomato: Dictionary = FarmState.get_cell(FarmState.DEBUG_FIRST_RIDGE).get("crop", {})
	var grown_bean: Dictionary = FarmState.get_cell(FarmState.DEBUG_SECOND_RIDGE).get("crop", {})
	assert_true(
		bool(grown_tomato.get("mature", false)) and not bool(grown_tomato.get("watered", true))
			and bool(grown_bean.get("mature", false)) and not bool(grown_bean.get("watered", true)),
		"One watered night matures both debug crops"
	)
	var before_unknown := FarmState.get_cell(FarmState.DEBUG_FIRST_RIDGE)
	assert_true(not FarmState.place_debug_crop_before_mature("not_a_real_crop"), "Unknown crop id is rejected")
	assert_true(
		FarmState.get_cell(FarmState.DEBUG_FIRST_RIDGE) == before_unknown,
		"Rejecting an unknown crop leaves the cell unchanged"
	)

	FarmState.load_save_state(farm_baseline)
	TimeManager.current_day = saved_day
	TimeManager.current_season = saved_season
	TimeManager.current_time = saved_time
	if saved_game_season >= 0 and GameSession != null and GameSession.season != null:
		GameSession.season.current_season = saved_game_season
	var restored_tomato := FarmState.get_cell(FarmState.DEBUG_FIRST_RIDGE)
	var restored_bean := FarmState.get_cell(FarmState.DEBUG_SECOND_RIDGE)
	var baseline_tomato := {}
	var baseline_bean := {}
	for raw in farm_baseline.get("cells", []):
		if int(raw.get("x", -1)) == FarmState.DEBUG_FIRST_RIDGE.x and int(raw.get("y", -1)) == FarmState.DEBUG_FIRST_RIDGE.y:
			baseline_tomato = raw
		if int(raw.get("x", -1)) == FarmState.DEBUG_SECOND_RIDGE.x and int(raw.get("y", -1)) == FarmState.DEBUG_SECOND_RIDGE.y:
			baseline_bean = raw
	assert_true(
		str(restored_tomato.get("debris", "")) == str(baseline_tomato.get("debris", ""))
			and str(Dictionary(restored_tomato.get("crop", {})).get("crop_id", "")) == str(Dictionary(baseline_tomato.get("crop", {})).get("crop_id", ""))
			and str(restored_bean.get("debris", "")) == str(baseline_bean.get("debris", ""))
			and str(Dictionary(restored_bean.get("crop", {})).get("crop_id", "")) == str(Dictionary(baseline_bean.get("crop", {})).get("crop_id", "")),
		"Debug crop test restores both ridge cells"
	)
	assert_true(TimeManager.current_day == saved_day and TimeManager.current_season == saved_season, "Debug crop test restores the calendar")

	print("  Debug launch parse: All tests completed")

var _day_notices: Array[String] = []

func _on_day_notice(message: String) -> void:
	_day_notices.append(message)

func run_day_start_and_collapse_tests() -> void:
	print("\n[Day Start And Collapse Tests]")

	assert_true(GameManager.forced_overnight_fee(0) == 0, "Broke players pay no collapse fee")
	assert_true(GameManager.forced_overnight_fee(-5) == 0, "Negative gold does not create a fee")
	assert_true(GameManager.forced_overnight_fee(1) == 1, "A fee below 50 takes the smaller held amount")
	assert_true(GameManager.forced_overnight_fee(30) == 30, "30 gold collapses for the whole 30")
	assert_true(GameManager.forced_overnight_fee(200) == 50, "10% under 50 still charges the 50 floor")
	assert_true(GameManager.forced_overnight_fee(499) == 50, "499 gold still uses the 50 floor")
	assert_true(GameManager.forced_overnight_fee(500) == 50, "500 gold is exactly the 10% floor")
	assert_true(GameManager.forced_overnight_fee(1000) == 100, "1000 gold charges 10%")
	assert_true(GameManager.forced_overnight_fee(2500) == 250, "2500 gold charges 10% with no extra cap")
	assert_true(GameManager.day_start_notice({}) == "新的一天开始了", "Empty shipment omits the amount")
	assert_true(
		GameManager.day_start_notice({"success": false, "reason": "empty"}) == "新的一天开始了",
		"An empty bin reason omits the amount"
	)
	assert_true(
		GameManager.day_start_notice({"total_money": 120}) == "新的一天开始了，出货到账 120 金",
		"A payout names the credited amount"
	)
	assert_true(
		GameManager.day_start_notice({"total_money": 80}, 50) == "新的一天开始了，出货到账 80 金。\n凌晨倒地，扣除 50 金",
		"Collapse notice keeps the payout and the fee"
	)

	var saved_day: int = TimeManager.current_day
	var saved_season: int = TimeManager.current_season
	var saved_year: int = TimeManager.current_year
	var saved_time: float = TimeManager.current_time
	var saved_paused: bool = TimeManager.is_paused
	var saved_pause_count: int = TimeManager._pause_count
	var saved_money: int = MoneySystem.get_money()
	var saved_stamina: float = StaminaManager.current_stamina
	var saved_active: bool = GameManager.is_game_active
	var saved_spawn: String = GameManager.current_spawn_point
	var saved_slot: int = SaveManager.get_current_slot()
	var farm_snapshot: Dictionary = FarmState.get_save_state()
	var shipping_snapshot: Dictionary = ShippingSystem.save_state()
	var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if saved_slot >= 0:
		SaveManager.reset_session(-1)
	TimeManager.current_day = 3
	TimeManager.current_time = 10.0
	GameManager.is_game_active = false
	GameManager.current_spawn_point = "farm_start"
	MoneySystem.set_money(1000)
	var idle_day := TimeManager.current_day
	GameManager.advance_day("forced_2am")
	assert_true(
		TimeManager.current_day == idle_day and MoneySystem.get_money() == 1000,
		"Inactive game does not collapse or charge"
	)

	if not GameManager.notification_requested.is_connected(_on_day_notice):
		GameManager.notification_requested.connect(_on_day_notice)
	GameManager.is_game_active = true
	ShippingSystem.clear_bin()
	assert_true(ShippingSystem.add_item("turnip", 4, 0), "Sleep fixture can fill the shipping bin")
	var sleep_sale := int(ShippingSystem.calculate_total_value().get("total_value", 0))
	StaminaManager.set_stamina(11.0)
	_day_notices.clear()
	GameManager.advance_day("sleep")
	assert_true(sleep_sale > 0, "Sleep fixture shipment is worth something")
	assert_true(MoneySystem.get_money() == 1000 + sleep_sale, "Sleep pays the bin and does not charge a fee")
	assert_true(
		is_equal_approx(StaminaManager.current_stamina, StaminaManager.max_stamina),
		"Sleep refills stamina"
	)
	assert_true(GameManager.current_spawn_point == "farm_start", "Sleep leaves the spawn point alone")
	assert_true(
		get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path,
		"Sleep does not change the current scene"
	)
	assert_true(
		_day_notices.size() == 1 and _day_notices[0] == "新的一天开始了，出货到账 %d 金" % sleep_sale,
		"Sleep notice names the shipment payout"
	)

	MoneySystem.set_money(200)
	ShippingSystem.clear_bin()
	StaminaManager.set_stamina(6.0)
	_day_notices.clear()
	GameManager.advance_day("forced_2am")
	assert_true(MoneySystem.get_money() == 150, "200 gold at 2am pays the 50 floor and stays non-negative")
	assert_true(
		is_equal_approx(StaminaManager.current_stamina, StaminaManager.max_stamina),
		"Passing out still refills stamina"
	)
	assert_true(GameManager.current_spawn_point == GameManager.PLAYER_HOUSE_SPAWN, "2am records the farmhouse spawn")
	assert_true(
		get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene_path,
		"A test runner is not swapped for the farmhouse"
	)
	assert_true(
		_day_notices.size() == 1 and _day_notices[0] == "新的一天开始了。\n凌晨倒地，扣除 50 金",
		"Empty bin at 2am names the fee and omits a payout"
	)

	MoneySystem.set_money(30)
	ShippingSystem.clear_bin()
	_day_notices.clear()
	GameManager.advance_day("forced_2am")
	assert_true(MoneySystem.get_money() == 0, "Less than 50 gold is taken entirely and not driven negative")
	assert_true(
		_day_notices.size() == 1 and _day_notices[0] == "新的一天开始了。\n凌晨倒地，扣除 30 金",
		"The smaller fee is the amount actually taken"
	)

	MoneySystem.set_money(1000)
	ShippingSystem.clear_bin()
	assert_true(ShippingSystem.add_item("turnip", 4, 0), "Collapse fixture can fill the shipping bin")
	var collapse_sale := int(ShippingSystem.calculate_total_value().get("total_value", 0))
	_day_notices.clear()
	GameManager.advance_day("forced_2am")
	assert_true(
		MoneySystem.get_money() == 1000 - 100 + collapse_sale,
		"2am takes 10% first and then credits the whole shipment"
	)
	assert_true(
		_day_notices.size() == 1
			and _day_notices[0] == "新的一天开始了，出货到账 %d 金。\n凌晨倒地，扣除 100 金" % collapse_sale,
		"2am notice names both the payout and the 10% fee"
	)
	assert_true(not GameManager._advancing_day, "Day advance releases its guard")

	if GameManager.notification_requested.is_connected(_on_day_notice):
		GameManager.notification_requested.disconnect(_on_day_notice)
	_day_notices.clear()
	TimeManager.current_day = saved_day
	TimeManager.current_season = saved_season
	TimeManager.current_year = saved_year
	TimeManager.current_time = saved_time
	TimeManager._pause_count = saved_pause_count
	TimeManager.is_paused = saved_paused
	FarmState.load_save_state(farm_snapshot)
	ShippingSystem.load_state(shipping_snapshot)
	StaminaManager.set_stamina(saved_stamina)
	MoneySystem.set_money(saved_money)
	GameManager.is_game_active = saved_active
	GameManager.current_spawn_point = saved_spawn
	GameManager._advancing_day = false
	if saved_slot >= 0:
		SaveManager.reset_session(saved_slot)
	else:
		SaveManager.reset_session(-1)

	print("  Day start and collapse: All tests completed")


func run_eat_food_stamina_tests() -> void:
	print("\n[Eat Food Stamina Tests]")
	# 体力已满时不吃：不扣物品，体力保持上限，避免浪费食物。
	# 没满时允许吃，溢出的部分被 restore_stamina 钳在上限，物品仍然消耗。
	var inv_snapshot: Dictionary = Inventory.save_state()
	var saved_stamina := StaminaManager.current_stamina
	var saved_max := StaminaManager.max_stamina

	var berry: ItemDatabase.ItemData = ItemDatabase.get_item("wild_berry")
	var bread: ItemDatabase.ItemData = ItemDatabase.get_item("bread")
	var seed: ItemDatabase.ItemData = ItemDatabase.get_item("turnip_seed")
	var stone: ItemDatabase.ItemData = ItemDatabase.get_item("stone")
	assert_true(berry != null and bread != null and seed != null and stone != null, "Eat fixtures resolve berry, bread, seed, and stone")
	assert_true(berry.use_effect.has("energy") and int(berry.use_effect["energy"]) == 8, "wild_berry restores 8 energy")
	assert_true(bread.use_effect.has("energy") and int(bread.use_effect["energy"]) == 30, "bread restores 30 energy")
	assert_true(not seed.use_effect.has("energy"), "Seeds have no energy and must not be eaten")
	assert_true(not stone.use_effect.has("energy"), "Stone has no energy and must not be eaten")

	Inventory.clear_inventory()
	Inventory.set_slot(0, "wild_berry", 2)
	Inventory.set_selected_hotbar_index(0)
	StaminaManager.set_stamina(40.0)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_ATE, "Eating wild_berry succeeds")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 48.0), "wild_berry restores 8 stamina (40 -> 48)")
	assert_true(Inventory.get_item_count("wild_berry") == 1, "Eating removes one wild_berry")
	assert_true(Inventory.get_slot(0).quantity == 1, "The selected stack drops by one")

	assert_true(Inventory.use_selected_item() == Inventory.EAT_ATE, "A second berry can be eaten")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 56.0), "Second berry restores another 8 (48 -> 56)")
	assert_true(Inventory.get_item_count("wild_berry") == 0, "Both berries are consumed")
	assert_true(Inventory.use_selected_item() == Inventory.EAT_NOT_EDIBLE, "An empty slot is not edible")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 56.0), "Empty use does not change stamina")

	Inventory.set_slot(0, "bread", 1)
	Inventory.set_selected_hotbar_index(0)
	StaminaManager.set_stamina(50.0)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_ATE, "Eating bread succeeds")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 80.0), "bread restores 30 stamina (50 -> 80)")
	assert_true(Inventory.get_item_count("bread") == 0, "Eating removes the bread")

	Inventory.set_slot(0, "bread", 1)
	StaminaManager.set_stamina(95.0)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_ATE, "Eating below the cap still consumes the food")
	assert_true(is_equal_approx(StaminaManager.current_stamina, StaminaManager.max_stamina), "Overflow is clamped to max stamina")
	assert_true(Inventory.get_item_count("bread") == 0, "Clamped eat still removes one bread")

	Inventory.set_slot(0, "wild_berry", 3)
	Inventory.set_selected_hotbar_index(0)
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_FULL, "Full stamina refuses to eat")
	assert_true(is_equal_approx(StaminaManager.current_stamina, StaminaManager.max_stamina), "Full stamina stays at the cap")
	assert_true(Inventory.get_item_count("wild_berry") == 3, "Refusing at full stamina does not remove the berry")

	Inventory.set_slot(0, "turnip_seed", 4)
	Inventory.set_selected_hotbar_index(0)
	StaminaManager.set_stamina(30.0)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_NOT_EDIBLE, "Seeds are not eaten")
	assert_true(Inventory.get_item_count("turnip_seed") == 4, "Seed count stays put")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 30.0), "Seeds do not restore stamina")

	Inventory.set_slot(0, "stone", 6)
	assert_true(Inventory.use_selected_item() == Inventory.EAT_NOT_EDIBLE, "Stone is not eaten")
	assert_true(Inventory.get_item_count("stone") == 6, "Stone count stays put")
	assert_true(is_equal_approx(StaminaManager.current_stamina, 30.0), "Stone does not restore stamina")

	Inventory.load_state(inv_snapshot)
	StaminaManager.set_max_stamina(saved_max)
	StaminaManager.set_stamina(saved_stamina)
	print("  Eat food stamina: All tests completed")

func run_watering_can_upgrade_and_rain_tests() -> void:
	print("\n[Watering Can Upgrade And Rain Tests]")

	var farm_snapshot: Dictionary = FarmState.get_save_state()
	var inv_snapshot: Dictionary = Inventory.save_state()
	var money_before: int = MoneySystem.get_money()
	var saved_time: float = TimeManager.current_time
	var saved_day: int = TimeManager.current_day
	var saved_season: int = TimeManager.current_season
	var saved_year: int = TimeManager.current_year
	var saved_paused: bool = TimeManager.is_paused
	var saved_pause_count: int = TimeManager._pause_count
	var saved_weather: String = GameSession.weather.get_current_weather()
	var saved_state: int = GameManager.current_state
	var saved_active: bool = GameManager.is_game_active
	var tree_paused: bool = get_tree().paused

	FarmState.reset()
	assert_true(FarmState.get_watering_can_max_uses() == 20, "未升级水壶是 20 次")
	assert_true(FarmState.get_watering_can_uses_left() == 20, "新水壶是满的 20 次")
	assert_true(FarmState.get_watering_can_max_water() == 100, "铜壶水量上限是 100")

	var iron_before: int = Inventory.get_item_count("iron_ingot")
	if iron_before > 0:
		Inventory.remove_item("iron_ingot", iron_before)
	var coins_before: int = Inventory.get_item_count("gold_coins")
	if coins_before > 0:
		Inventory.remove_item("gold_coins", coins_before)
	MoneySystem.set_money(0)

	var system: ToolUpgrade = ToolUpgrade.new()
	add_child(system)
	system.set_inventory(Inventory)
	assert_true(not system.upgrade_tool(ToolUpgrade.ToolType.WATERING_CAN), "没有材料和金币时不能升级水壶")
	assert_true(FarmState.get_watering_can_max_uses() == 20, "升级失败时水壶仍是 20 次")

	FarmState.set_watering_can_water(15)
	var requirements: Array = system.get_upgrade_requirements(ToolUpgrade.ToolTier.COPPER)
	var gold_cost: int = 0
	for req in requirements:
		if str(req.material_id) == "gold_coins":
			gold_cost = int(req.quantity)
			MoneySystem.set_money(gold_cost)
		else:
			Inventory.add_item(str(req.material_id), int(req.quantity))
	assert_true(gold_cost == 500, "铜升铁花费 500 金币")
	assert_true(system.upgrade_tool(ToolUpgrade.ToolType.WATERING_CAN), "材料加金币可以升级水壶")
	var upgraded = system.get_tool_data(ToolUpgrade.ToolType.WATERING_CAN)
	assert_true(upgraded != null and int(upgraded.current_tier) == ToolUpgrade.ToolTier.IRON, "水壶升到铁")
	assert_true(FarmState.get_watering_can_max_uses() == 40, "升级后水壶是 40 次")
	assert_true(FarmState.get_watering_can_max_water() == 200, "铁壶水量上限是 200")
	assert_true(FarmState.get_watering_can_uses_left() == 40, "升级后立刻灌满")
	assert_true(MoneySystem.get_money() == 0, "升级扣掉金币")
	assert_true(Inventory.get_item_count("iron_ingot") == 0, "升级消耗铁锭")
	assert_true(not system.upgrade_tool(ToolUpgrade.ToolType.WATERING_CAN), "没有下一级材料时不再升级")
	assert_true(FarmState.get_watering_can_max_uses() == 40, "下一级失败后仍是 40 次")
	system.free()

	var again: ToolUpgrade = ToolUpgrade.new()
	add_child(again)
	again.sync_watering_can_from_farm()
	var synced = again.get_tool_data(ToolUpgrade.ToolType.WATERING_CAN)
	assert_true(synced != null and int(synced.current_tier) == ToolUpgrade.ToolTier.IRON, "再次打开升级界面时铁壶不会退回铜")
	again.free()

	FarmState.set_watering_can_water(50)
	var upgraded_save: Dictionary = FarmState.get_save_state()
	FarmState.reset()
	assert_true(FarmState.get_watering_can_max_uses() == 20, "重置后回到 20 次")
	assert_true(FarmState.load_save_state(upgraded_save), "铁壶存档可以读回")
	assert_true(FarmState.get_watering_can_max_uses() == 40, "存档记住 40 次上限")
	assert_true(FarmState.get_watering_can_uses_left() == 10, "存档记住剩余水量")

	var legacy: Dictionary = upgraded_save.duplicate(true)
	legacy.erase("watering_can_max_water")
	legacy.erase("watering_can_water")
	assert_true(FarmState.load_save_state(legacy), "旧档可以读")
	assert_true(FarmState.get_watering_can_max_uses() == 20, "旧档没有上限字段时仍是 20 次")
	assert_true(FarmState.get_watering_can_uses_left() == 20, "旧档没有水量字段时按满水")

	FarmState.reset()
	TimeManager.current_season = 0
	TimeManager.current_day = 10
	var bare: Dictionary = FarmState.get_save_state()
	for raw in bare["cells"]:
		if int(raw.get("x", -1)) == 5 and int(raw.get("y", -1)) == 1:
			raw["state"] = FarmState.UNTILLED
			raw["debris"] = ""
			raw["moisture"] = 0
			raw["crop"] = {
				"crop_id": "turnip",
				"stage": 0,
				"days_in_stage": 0,
				"total_days": 0,
				"watered": false,
				"quality": 0,
				"mature": false,
			}
		elif int(raw.get("x", -1)) == 6 and int(raw.get("y", -1)) == 1:
			raw["state"] = FarmState.UNTILLED
			raw["debris"] = ""
			raw["moisture"] = 0
			raw["crop"] = {}
	assert_true(FarmState.load_save_state(bare), "雨天夹具可以读")
	GameSession.weather.set_current_weather("rainy")
	GameSession.weather.apply_day_start_watering()
	var cropped := FarmState.get_cell(Vector2i(5, 1))
	var empty := FarmState.get_cell(Vector2i(6, 1))
	assert_true(int(cropped.get("state", -1)) == FarmState.WATERED and bool(Dictionary(cropped.get("crop", {})).get("watered", false)), "雨天把有作物的格子浇湿")
	assert_true(int(empty.get("state", -1)) == FarmState.UNTILLED, "雨天不浇空的未翻地")

	FarmState.reset()
	TimeManager.current_season = 0
	TimeManager.current_day = 10
	var plot := Vector2i(1, 1)
	var open_soil := Vector2i(2, 1)
	var untouched := Vector2i(3, 1)
	var guarded := Vector2i(4, 1)
	assert_true(Inventory.add_item("turnip_seed", 1), "雨天夹具有一包萝卜种子")
	assert_true(FarmState.till(plot) and FarmState.plant(plot, "turnip_seed"), "雨天夹具翻地并种下萝卜")
	assert_true(FarmState.till(open_soil), "雨天夹具有一块空耕地")
	GameSession.weather.set_current_weather("rainy")
	FarmState.advance_day()
	var dried := FarmState.get_cell(plot)
	var dried_crop: Dictionary = dried.get("crop", {})
	assert_true(int(dried.get("state", -1)) == FarmState.TILLED and not bool(dried_crop.get("watered", true)) and int(dried_crop.get("total_days", -1)) == 0, "过夜结算本身不因当前是雨天而浇水，未浇过的作物不生长")
	GameSession.weather.apply_day_start_watering()
	var soaked := FarmState.get_cell(plot)
	var soaked_crop: Dictionary = soaked.get("crop", {})
	assert_true(int(soaked.get("state", -1)) == FarmState.WATERED and bool(soaked_crop.get("watered", false)) and int(soaked_crop.get("total_days", -1)) == 0, "雨天开始后耕地被浇湿，但不再额外长一天")
	assert_true(int(FarmState.get_cell(open_soil).get("state", -1)) == FarmState.WATERED, "雨天浇湿没有作物的耕地")
	assert_true(int(FarmState.get_cell(untouched).get("state", -1)) == FarmState.UNTILLED, "雨天不改未翻的空地")
	FarmState.advance_day()
	var grown: Dictionary = FarmState.get_cell(plot).get("crop", {})
	assert_true(int(grown.get("total_days", -1)) == 1, "雨天浇过的下一夜作物生长")

	FarmState.advance_day()
	GameSession.weather.set_current_weather("sunny")
	GameSession.weather.apply_day_start_watering()
	assert_true(int(FarmState.get_cell(plot).get("state", -1)) == FarmState.TILLED, "晴天不会把耕地浇湿")

	assert_true(FarmState.till(guarded), "暴风雨夹具可以翻开一块新地")
	GameSession.weather.forced_weather = "stormy"
	TimeManager.current_time = 9.0
	GameSession.weather._on_day_changed(TimeManager.current_day)
	assert_true(GameSession.weather.get_current_weather() == "stormy", "可钉住暴风雨")
	assert_true(int(FarmState.get_cell(guarded).get("state", -1)) == FarmState.TILLED, "重置时刻的 day_changed 不浇地")
	TimeManager.current_time = 6.0
	GameSession.weather._on_day_changed(TimeManager.current_day)
	assert_true(int(FarmState.get_cell(guarded).get("state", -1)) == FarmState.WATERED, "过夜 6 点的暴风雨浇湿耕地")
	assert_true(int(FarmState.get_cell(untouched).get("state", -1)) == FarmState.UNTILLED, "暴风雨也不浇空的未翻地")
	GameSession.weather.forced_weather = ""

	DialogueManager._trigger_single_effect({"type": "open_tool_upgrade"})
	var from_dialogue := get_tree().root.find_child("ToolUpgradeUI", true, false)
	assert_true(from_dialogue != null and from_dialogue.visible, "水壶对话效果打开升级界面")
	if from_dialogue and from_dialogue.has_method("close"):
		from_dialogue.close()
		from_dialogue.free()

	TimeManager.current_time = 10.0
	var packed := load("res://src/entities/npc/NPC.tscn") as PackedScene
	assert_true(packed != null, "NPC 场景可以加载")
	if packed != null:
		var tom := packed.instantiate() as NPC
		tom.npc_id = "blacksmith_tom"
		add_child(tom)
		assert_true(tom.can_interact(), "上午的铁匠汤姆可以交互")
		tom.interact()
		var smith_ui := get_tree().root.find_child("ToolUpgradeUI", true, false)
		assert_true(smith_ui != null and smith_ui.visible, "铁匠汤姆打开工具升级界面")
		assert_true(not DialogueManager.is_in_dialogue(), "铁匠交互直接打开升级界面，不卡在对话里")
		if smith_ui and smith_ui.has_method("close"):
			smith_ui.close()
		tom.free()
		if smith_ui and is_instance_valid(smith_ui):
			smith_ui.free()

	GameSession.weather.forced_weather = ""
	GameSession.weather.set_current_weather(saved_weather)
	TimeManager.current_time = saved_time
	TimeManager.current_day = saved_day
	TimeManager.current_season = saved_season
	TimeManager.current_year = saved_year
	TimeManager._pause_count = saved_pause_count
	TimeManager.is_paused = saved_paused
	MoneySystem.set_money(money_before)
	Inventory.load_state(inv_snapshot)
	FarmState.load_save_state(farm_snapshot)
	GameManager.current_state = saved_state
	GameManager.is_game_active = saved_active
	get_tree().paused = tree_paused
	print("  Watering can upgrade and rain: All tests completed")


func run_debug_time_skip_tests() -> void:
	print("\n[Debug Time Skip Tests]")
	var key := InputEventKey.new()
	key.pressed = true
	key.echo = false
	key.keycode = KEY_F7
	key.physical_keycode = KEY_F7
	assert_true(not GameManager.wants_debug_time_skip(key, false), "发行版不响应 F7 跳时")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	assert_true(not GameManager.wants_debug_time_skip(mouse, false), "发行版对任意事件都不跳时")
	var target := GameManager.debug_time_skip_target()
	var minute := int((target - float(int(target))) * 60.0)
	assert_true(
		is_equal_approx(target, 25.0 + 55.0 / 60.0) and target < 26.0 and int(target) % 24 == 1 and minute == 55,
		"跳时目标是 1:55（25 + 55/60），且小于 2:00"
	)

	var saved_state = GameManager.current_state
	var saved_active = GameManager.is_game_active
	var saved_paused := get_tree().paused
	var saved_time := TimeManager.current_time
	var saved_accum := TimeManager._time_accumulator
	var saved_toasts := _debug_skip_toast_signature()

	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().paused = false
	assert_true(GameManager._debug_time_skip_allowed(), "PLAYING 且未暂停、无模态时可以跳时")

	get_tree().paused = true
	assert_true(not GameManager._debug_time_skip_allowed(), "场景树暂停时不能跳时")
	_assert_f7_does_not_skip(key, saved_time, saved_accum, saved_toasts, "暂停时 F7 不改时间也不弹 toast")
	get_tree().paused = false

	GameManager.current_state = GameManager.GameState.PAUSED
	assert_true(not GameManager._debug_time_skip_allowed(), "暂停菜单状态不能跳时")
	_assert_f7_does_not_skip(key, saved_time, saved_accum, saved_toasts, "暂停状态时 F7 不改时间也不弹 toast")
	GameManager.current_state = GameManager.GameState.PLAYING
	assert_true(GameManager._debug_time_skip_allowed(), "回到 PLAYING 且未暂停后可以跳时")

	var modal := Control.new()
	modal.name = "F7ModalProbe"
	add_child(modal)
	var stack_before := UIManager._stack.size()
	UIManager._stack.append({
		"id": "f7_probe",
		"node": modal,
		"focus": null,
		"pause": false,
	})
	assert_true(UIManager.has_open_modal() and not get_tree().paused, "模态夹具打开且场景树未暂停")
	assert_true(not GameManager._debug_time_skip_allowed(), "有中心模态时不能跳时")
	_assert_f7_does_not_skip(key, saved_time, saved_accum, saved_toasts, "有模态时 F7 不改时间也不弹 toast")
	while UIManager._stack.size() > stack_before:
		UIManager._stack.pop_back()
	modal.free()
	assert_true(not UIManager.has_open_modal(), "模态夹具已清掉")
	assert_true(GameManager._debug_time_skip_allowed(), "关掉模态后可以跳时")

	var upgrade := Control.new()
	upgrade.name = "ToolUpgradeUI"
	upgrade.visible = true
	add_child(upgrade)
	assert_true(
		upgrade.visible and not get_tree().paused and not UIManager.has_open_modal(),
		"升级界面可见且未进暂停或模态栈"
	)
	assert_true(not GameManager._debug_time_skip_allowed(), "可见工具升级界面时不能跳时")
	_assert_f7_does_not_skip(key, saved_time, saved_accum, saved_toasts, "升级界面开着时 F7 不改时间也不弹 toast")
	upgrade.visible = false
	assert_true(GameManager._debug_time_skip_allowed(), "隐藏的升级界面不拦截跳时")
	upgrade.free()

	var blocker := Control.new()
	blocker.name = "F7CenterBlocker"
	blocker.visible = true
	blocker.add_to_group(QuestTracker.BLOCKER_GROUP)
	add_child(blocker)
	assert_true(not GameManager._debug_time_skip_allowed(), "可见 quest_bar_blockers 时不能跳时")
	_assert_f7_does_not_skip(key, saved_time, saved_accum, saved_toasts, "中心遮挡开着时 F7 不改时间也不弹 toast")
	blocker.visible = false
	assert_true(GameManager._debug_time_skip_allowed(), "隐藏的中心遮挡不拦截跳时")
	blocker.free()

	assert_true(is_equal_approx(TimeManager.current_time, saved_time), "门闩测试没有改时间")
	assert_true(is_equal_approx(TimeManager._time_accumulator, saved_accum), "门闩测试没有改时间累计")
	GameManager.current_state = saved_state
	GameManager.is_game_active = saved_active
	get_tree().paused = saved_paused
	print("  Debug time skip: All tests completed")


func _debug_skip_toast_signature() -> String:
	if UIManager == null or UIManager._toast_root == null:
		return ""
	var parts: PackedStringArray = []
	for child in UIManager._toast_root.get_children():
		if child.is_queued_for_deletion():
			continue
		parts.append("%s#%s" % [str(child.get_meta("toast_text", "")), str(child.get_meta("toast_count", 1))])
	return "|".join(parts)


func _assert_f7_does_not_skip(event: InputEvent, time_before: float, accum_before: float, toast_before: String, message: String) -> void:
	if GameManager._debug_time_skip_allowed():
		assert_true(false, message)
		return
	GameManager._unhandled_input(event)
	var time_same := is_equal_approx(TimeManager.current_time, time_before)
	var accum_same := is_equal_approx(TimeManager._time_accumulator, accum_before)
	var toast_same := _debug_skip_toast_signature() == toast_before
	if not time_same:
		TimeManager.current_time = time_before
	if not accum_same:
		TimeManager._time_accumulator = accum_before
	assert_true(time_same and accum_same and toast_same, message)


func run_tool_upgrade_material_name_tests() -> void:
	print("\n[Tool Upgrade Material Names]")
	var ui := ToolUpgradeUI.new()
	assert_true(ui._material_display_name("iron_ingot") == "铁锭", "iron_ingot 显示为铁锭")
	assert_true(ui._material_display_name("gold_coins") == "金币", "gold_coins 显示为金币")
	assert_true(ui._material_display_name("gold_ingot") == "金锭", "gold_ingot 显示为金锭")
	assert_true(ui._material_display_name("diamond") == "钻石", "diamond 显示为钻石")
	assert_true(ui._material_display_name("missing_upgrade_material") == "missing_upgrade_material", "没有中文名时回退材料 id")
	ui.free()
	print("  Tool upgrade material names: All tests completed")


func run_tool_upgrade_focus_select_tests() -> void:
	print("\n[Tool Upgrade Focus Select]")
	var hoe_button := Button.new()
	hoe_button.set_meta("tool_type", ToolUpgrade.ToolType.HOE)
	var plain_button := Button.new()
	assert_true(ToolUpgradeUI.selection_for_focus_target(hoe_button) == ToolUpgrade.ToolType.HOE, "工具按钮焦点解析为该工具")
	assert_true(ToolUpgradeUI.selection_for_focus_target(plain_button) == -1, "没有工具标记的按钮不改变选中")
	hoe_button.free()
	plain_button.free()

	var saved_state = GameManager.current_state
	var saved_active = GameManager.is_game_active
	var saved_paused := get_tree().paused
	var inv_snapshot: Dictionary = Inventory.save_state()
	var money_before := MoneySystem.get_money()
	var packed := load("res://src/ui/menus/ToolUpgradeUI.tscn") as PackedScene
	assert_true(packed != null, "工具升级界面可以加载")
	var ui: ToolUpgradeUI = null
	if packed != null:
		ui = packed.instantiate() as ToolUpgradeUI
		add_child(ui)
		ui.open()
		assert_true(ui._tool_buttons.size() >= 2, "升级界面至少有两行工具")
		if ui._tool_buttons.size() >= 2:
			var first: Button = ui._tool_buttons[0]
			var second: Button = ui._tool_buttons[1]
			var first_type := int(first.get_meta("tool_type"))
			var second_type := int(second.get_meta("tool_type"))
			var first_name := str(ui.tool_upgrade_system.get_tool_data(first_type).get_type_name())
			var second_name := str(ui.tool_upgrade_system.get_tool_data(second_type).get_type_name())
			assert_true(ui.selected_tool_type == first_type, "打开界面时第一行已经被选中")
			assert_true(ui.tool_name_label.text == first_name, "打开界面时右侧名称是第一行工具")
			assert_true(str(ui.tool_tier_label.text).begins_with("当前等级:"), "打开界面时右侧有等级")
			assert_true(str(ui.upgrade_effects_label.text) != "", "打开界面时右侧有效果")
			assert_true(str(ui.upgrade_button.text) != "选择工具", "打开界面时升级按钮已按该工具刷新")
			var material_text := ""
			for child in ui.materials_list.get_children():
				if child.is_queued_for_deletion() or not (child is HBoxContainer):
					continue
				for sub in child.get_children():
					if sub is Label and not sub.is_queued_for_deletion():
						material_text += str(sub.text)
			assert_true("铁锭" in material_text and "金币" in material_text, "打开界面时右侧材料是第一行的需求")
			assert_true(ui._focus_owner() == first, "打开界面时绿框在第一行")

			ui._select_tool_type(second_type)
			assert_true(ui.selected_tool_type == second_type and ui.tool_name_label.text == second_name, "选中函数会刷新右侧名称")
			ui._select_tool_type(second_type)
			ui._select_tool_type(-1)
			assert_true(ui.selected_tool_type == second_type and ui.tool_name_label.text == second_name, "重复选中或空类型不会清空资料")

			ui._grab(first)
			assert_true(ui.selected_tool_type == first_type and ui.tool_name_label.text == first_name, "焦点落到工具行时立刻选中")
			var down := InputEventAction.new()
			down.action = "ui_down"
			down.pressed = true
			ui._input(down)
			assert_true(ui.selected_tool_type == second_type and ui.tool_name_label.text == second_name, "下键移到下一行时右侧资料跟着变")
			assert_true(ui._focus_owner() == second, "下键后绿框在下一行")
			var up := InputEventAction.new()
			up.action = "ui_up"
			up.pressed = true
			ui._input(up)
			assert_true(ui.selected_tool_type == first_type and ui._focus_owner() == first, "上键回到上一行时也选中该工具")

			var tab := InputEventAction.new()
			tab.action = "ui_focus_next"
			tab.pressed = true
			ui._input(tab)
			assert_true(ui.selected_tool_type == second_type and ui.tool_name_label.text == second_name, "Tab 链移到工具行时刷新资料")

			var last: Button = ui._tool_buttons[ui._tool_buttons.size() - 1]
			ui._grab(last)
			var last_type := ui.selected_tool_type
			var last_name := str(ui.tool_name_label.text)
			var last_tier := str(ui.tool_tier_label.text)
			var last_effect := str(ui.upgrade_effects_label.text)
			var last_button := str(ui.upgrade_button.text)
			var next_tab := InputEventAction.new()
			next_tab.action = "ui_focus_next"
			next_tab.pressed = true
			ui._input(next_tab)
			var parked := ui._focus_owner()
			assert_true(parked == ui.upgrade_button or parked == ui.close_button, "工具列表末尾再 Tab 会落到升级或关闭")
			assert_true(
				ui.selected_tool_type == last_type
				and ui.tool_name_label.text == last_name
				and ui.tool_tier_label.text == last_tier
				and ui.upgrade_effects_label.text == last_effect
				and ui.upgrade_button.text == last_button,
				"焦点移到升级或关闭时保留上次选中的工具资料"
			)

			ui._grab(second)
			var tier_before := int(ui.tool_upgrade_system.get_tool_data(second_type).current_tier)
			assert_true(ui._is_tool_button(ui._focus_owner()), "确定键测试前焦点在工具行")
			if ui._is_tool_button(ui._focus_owner()):
				var accept := InputEventAction.new()
				accept.action = "ui_accept"
				accept.pressed = true
				ui._input(accept)
				var tier_after := int(ui.tool_upgrade_system.get_tool_data(second_type).current_tier)
				assert_true(
					ui.selected_tool_type == second_type
					and ui.tool_name_label.text == second_name
					and tier_before == tier_after
					and ui.visible,
					"工具行上再按确定不升级、不关闭、资料不变"
				)
		if ui.has_method("close"):
			ui.close()
		ui.queue_free()
	GameManager.current_state = saved_state
	GameManager.is_game_active = saved_active
	get_tree().paused = saved_paused
	Inventory.load_state(inv_snapshot)
	MoneySystem.set_money(money_before)
	print("  Tool upgrade focus select: All tests completed")


func run_seed_sprite_tests() -> void:
	print("\n[Seed Sprite Tests]")
	var stage0 := "res://assets/sprites/crops/turnip_stage0.png"
	assert_true(ResourceLoader.exists(stage0), "turnip stage0 贴图在磁盘上")
	var turnip = GrowthSystem.get_crop_data("turnip")
	assert_true(turnip != null and turnip.stage_sprites.size() > 0, "turnip 作物数据有阶段贴图")
	assert_true(str(turnip.stage_sprites[0]) == stage0, "turnip 阶段表从 stage0 开始")
	assert_true(
		FarmState.crop_stage_sprite_path("turnip", 0, turnip.stage_sprites) == stage0,
		"stage 0 解析到 turnip_stage0.png"
	)
	assert_true(
		str(FarmState.crop_stage_sprite_path("turnip", 1, turnip.stage_sprites)).ends_with("turnip_stage1.png"),
		"stage 1 仍是 turnip_stage1.png"
	)
	var omitted: Array = [
		"res://assets/sprites/crops/turnip_stage1.png",
		"res://assets/sprites/crops/turnip_stage2.png",
		"res://assets/sprites/crops/turnip_stage3.png",
		"res://assets/sprites/crops/turnip_stage4.png",
	]
	assert_true(FarmState.crop_stage_sprite_path("turnip", 0, omitted) == stage0, "缺 stage0 的列表回退到 stage0 文件")
	assert_true(
		str(FarmState.crop_stage_sprite_path("turnip", 1, omitted)).ends_with("turnip_stage1.png"),
		"回退时 stage 1 不跳过下一张"
	)
	var kept := FarmState.crop_stage_sprite_path("missing_crop_zz", 0, ["res://assets/sprites/crops/turnip_stage1.png"])
	assert_true(kept == "res://assets/sprites/crops/turnip_stage1.png", "没有 stage0 也没有图标时保持原列表")
	var iconed := FarmState.crop_stage_sprite_path("wood", 0, [])
	assert_true(iconed.ends_with("wood.png") and ResourceLoader.exists(iconed), "没有 stage0 时用现有物品图标")

	var farm_snapshot: Dictionary = FarmState.get_save_state()
	var inv_snapshot: Dictionary = Inventory.save_state()
	var saved_season: int = TimeManager.current_season
	FarmState.reset()
	TimeManager.current_season = 0
	var open: Array[Vector2i] = []
	for y in range(FarmState.GRID_HEIGHT):
		for x in range(FarmState.GRID_WIDTH):
			var coord := Vector2i(x, y)
			if FarmState.get_debris(coord) != "":
				continue
			if int(FarmState.get_cell(coord).get("state", -1)) != FarmState.UNTILLED:
				continue
			open.append(coord)
			if open.size() >= 2:
				break
		if open.size() >= 2:
			break
	assert_true(open.size() >= 2, "有两格空地可以种和对照")
	if open.size() >= 2:
		var planted := open[0]
		var empty := open[1]
		assert_true(Inventory.add_item("turnip_seed", 1), "测试有一包防风草种子")
		assert_true(FarmState.till(planted) and FarmState.plant(planted, "turnip_seed"), "翻地后播下防风草")
		assert_true(int(Dictionary(FarmState.get_cell(planted).get("crop", {})).get("stage", -1)) == 0, "刚播下的阶段是 0")
		assert_true(FarmState.till(empty), "对照格只翻土不播种")
		var visual := FarmPlot.new()
		add_child(visual)
		visual.setup(planted)
		var shown := ""
		if visual._crop_sprite != null and visual._crop_sprite.texture != null:
			shown = str(visual._crop_sprite.texture.resource_path)
		assert_true(shown != "" and shown == stage0, "播种后格子拿到非空的 stage0 精灵")
		if visual._crop_sprite != null and visual._crop_sprite.texture != null:
			var tex_size: Vector2 = visual._crop_sprite.texture.get_size()
			var max_dim := maxf(tex_size.x, tex_size.y)
			assert_true(
				visual._crop_sprite.scale.x > 0.0 and is_equal_approx(visual._crop_sprite.scale.x, visual._crop_sprite.scale.y),
				"种子精灵等比缩放"
			)
			if max_dim > FarmPlot.SIZE:
				var base := (FarmPlot.SIZE * 0.85) / max_dim
				var cap := (FarmPlot.SIZE * FarmPlot.EARLY_SPRITE_CAP) / max_dim
				assert_true(
					visual._crop_sprite.scale.x > base and visual._crop_sprite.scale.x <= cap + 0.0001
						and is_equal_approx(visual._crop_sprite.position.y, FarmPlot.SIZE * 0.48),
					"大画布的 stage0 略放大并贴地，且不超出格子"
				)
		visual.free()
		var bare := FarmPlot.new()
		add_child(bare)
		bare.setup(empty)
		assert_true(bare._crop_sprite != null and bare._crop_sprite.texture == null, "空土没有作物精灵")
		bare.free()

	var crop_node := Crop.new()
	var crop_sprite := Sprite2D.new()
	crop_sprite.name = "Sprite2D"
	crop_node.add_child(crop_sprite)
	add_child(crop_node)
	crop_node.crop_id = "turnip"
	crop_node.crop_data = turnip
	crop_node.current_stage = 0
	crop_node.current_state = Crop.State.SEED
	crop_node._update_sprite()
	var crop_shown := ""
	if crop_node.sprite != null and crop_node.sprite.texture != null:
		crop_shown = str(crop_node.sprite.texture.resource_path)
	assert_true(crop_shown == stage0, "Crop.gd 的种子阶段也用 stage0")
	crop_node.free()

	TimeManager.current_season = saved_season
	Inventory.load_state(inv_snapshot)
	FarmState.load_save_state(farm_snapshot)
	print("  Seed sprites: All tests completed")

func run_quest_tracker_visibility_tests() -> void:
	print("\n[Quest Tracker Visibility]")
	assert_true(not QuestTracker.should_show(false, false), "没有活跃任务时任务条隐藏")
	assert_true(QuestTracker.should_show(true, false), "有任务且没有遮挡时任务条显示")
	assert_true(not QuestTracker.should_show(true, true), "被遮挡时任务条隐藏")
	assert_true(not QuestTracker.should_show(false, true), "没有任务时遮挡也不把任务条打开")
	assert_true(QuestTracker.blocks_bar(true, false, false, false), "场景树暂停遮挡任务条")
	assert_true(QuestTracker.blocks_bar(false, true, false, false), "游戏暂停遮挡任务条")
	assert_true(QuestTracker.blocks_bar(false, false, true, false), "模态打开遮挡任务条")
	assert_true(QuestTracker.blocks_bar(false, false, false, true), "中心界面打开遮挡任务条")
	assert_true(not QuestTracker.blocks_bar(false, false, false, false), "平时不遮挡任务条")

	var saved_state = GameManager.current_state
	var saved_active = GameManager.is_game_active
	var saved_paused := get_tree().paused
	var quest_snapshot: Dictionary = QuestSystem.save_state()
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	if get_tree().paused:
		get_tree().paused = false
	if QuestSystem.get_active_quests().is_empty() and QuestSystem.can_accept_quest("village_introduction"):
		QuestSystem.accept_quest("village_introduction")
	var has_quest := not QuestSystem.get_active_quests().is_empty()
	assert_true(has_quest, "任务条夹具有一条活跃任务")

	var tracker := load("res://src/ui/hud/QuestTracker.tscn").instantiate() as QuestTracker
	add_child(tracker)
	assert_true(tracker != null and tracker.visible == has_quest, "有活跃任务时任务条出现")

	var blocker := Control.new()
	blocker.visible = false
	blocker.add_to_group(QuestTracker.BLOCKER_GROUP)
	add_child(blocker)
	blocker.visible = true
	tracker.visible = true
	EventBus.ui_opened.emit("center_modal")
	assert_true(not tracker.visible, "中心界面打开的事件让任务条隐藏")
	blocker.visible = false
	EventBus.ui_closed.emit("center_modal")
	assert_true(tracker.visible == has_quest, "中心界面关掉后按活跃任务恢复")

	var packed := load("res://src/ui/menus/ToolUpgradeUI.tscn") as PackedScene
	assert_true(packed != null, "工具升级界面可以加载")
	if packed != null and tracker != null:
		var ui := packed.instantiate() as ToolUpgradeUI
		add_child(ui)
		ui.open()
		assert_true(ui.visible and not tracker.visible, "工具升级打开时任务条隐藏")
		ui.close()
		assert_true(not ui.visible and tracker.visible == has_quest, "工具升级关闭后任务条按活跃任务恢复")
		ui.queue_free()

	GameManager.current_state = GameManager.GameState.PLAYING
	if get_tree().paused:
		get_tree().paused = false
	GameManager.pause_game()
	assert_true(get_tree().paused and not tracker.visible, "暂停时任务条隐藏")
	GameManager.resume_game()
	assert_true(not get_tree().paused and tracker.visible == has_quest, "恢复游戏后任务条按活跃任务回来")

	blocker.queue_free()
	tracker.queue_free()
	QuestSystem.load_state(quest_snapshot)
	GameManager.current_state = saved_state
	GameManager.is_game_active = saved_active
	get_tree().paused = saved_paused
	print("  Quest tracker visibility: All tests completed")


func run_shipping_bin_interact_tests() -> void:
	print("\n[ShippingBin Interact]")
	var saved_state = GameManager.current_state
	var saved_active = GameManager.is_game_active
	var saved_paused := get_tree().paused
	var saved_bindings := InputManager.serialize_bindings()

	assert_true(
		InputManager.get_action_short_prompt(&"interact") == "Space",
		"键盘互动短提示偏好 Space，而不是更短的 E"
	)
	var only_e := InputEventKey.new()
	only_e.physical_keycode = KEY_E
	var remapped_e := InputManager.remap_action(&"interact", only_e)
	assert_true(
		remapped_e and InputManager.get_action_short_prompt(&"interact") == "E",
		"互动只绑 E 时短提示为 E"
	)
	InputManager.apply_serialized_bindings(saved_bindings)
	assert_true(
		InputManager.get_action_short_prompt(&"interact") == "Space",
		"恢复默认键位后短提示回到 Space"
	)

	var bin := (load("res://src/world/objects/ShippingBin.tscn") as PackedScene).instantiate() as ShippingBin
	add_child(bin)
	var player := Player.new()
	var prompt := bin.get_node_or_null("InteractPrompt") as InteractPrompt
	var label_text := bin.prompt_label.text if bin.prompt_label else ""
	assert_true(bin != null and player != null and prompt != null, "出货箱、玩家和气泡可以实例化")
	assert_true(
		not bin.interaction_prompt.contains("Press E") and not label_text.contains("Press E"),
		"出货文案不再写 Press E"
	)
	assert_true(
		prompt != null and prompt.key_label.text == "Space" and prompt.text_label.text == "出货",
		"出货气泡是 Space 出货"
	)

	var hits: Array[int] = [0]
	bin.bin_interacted.connect(func(_node): hits[0] += 1)
	bin.interact()
	assert_true(hits[0] == 0 and not UIManager.is_screen_open("shipping_bin"), "不在范围内 interact 不开箱")

	bin._on_body_entered(player)
	assert_true(
		player.building_in_range == bin and bin._player_in_range and bin.has_method("interact"),
		"进范围后 building_in_range 指向出货箱"
	)
	if player.building_in_range != null:
		player.building_in_range.interact()
	var screen := UIManager.get_screen("shipping_bin")
	assert_true(hits[0] == 1 and screen != null, "进范围后 interact 打开出货界面")
	if player.building_in_range != null:
		player.building_in_range.interact()
	assert_true(
		hits[0] == 2 and UIManager.get_screen("shipping_bin") == screen,
		"再 interact 不叠第二层出货界面"
	)
	UIManager.close_all()

	var other := Node.new()
	player.building_in_range = other
	bin._on_body_exited(player)
	assert_true(
		player.building_in_range == other and not bin._player_in_range,
		"离开时不清除别的建筑目标"
	)
	other.free()

	bin._on_body_entered(player)
	bin.set_interactable(false)
	assert_true(player.building_in_range == null, "关闭交互时放开 building_in_range")
	var hits_before := hits[0]
	bin.interact()
	assert_true(
		hits[0] == hits_before and not UIManager.is_screen_open("shipping_bin"),
		"不可交互时 interact 不开箱"
	)
	bin.set_interactable(true)
	assert_true(player.building_in_range == bin, "重新可交互且仍在范围内时占回 building_in_range")
	bin._on_body_exited(player)
	assert_true(player.building_in_range == null, "离开范围后清除 building_in_range")

	player.free()
	bin.queue_free()
	UIManager.close_all()
	InputManager.apply_serialized_bindings(saved_bindings)
	GameManager.current_state = saved_state
	GameManager.is_game_active = saved_active
	get_tree().paused = saved_paused
	print("  ShippingBin interact: All tests completed")


func run_debris_wrong_tool_tests() -> void:
	print("\n[Debris Wrong Tool]")
	var farm_snapshot := FarmState.get_save_state()
	var inv_snapshot := Inventory.save_state()
	var saved_stamina := StaminaManager.current_stamina
	StaminaManager.set_stamina(StaminaManager.max_stamina)
	var fixture := FarmState.get_save_state()
	var placed := {
		Vector2i(1, 1): FarmState.DEBRIS_WEED,
		Vector2i(2, 1): FarmState.DEBRIS_STONE,
		Vector2i(3, 1): FarmState.DEBRIS_TWIG,
		Vector2i(4, 1): FarmState.DEBRIS_STUMP,
	}
	for raw in fixture.get("cells", []):
		var coord := Vector2i(int(raw.get("x", -1)), int(raw.get("y", -1)))
		raw["debris"] = str(placed.get(coord, ""))
		raw["debris_hits"] = 0
		raw["debris_variant"] = 0
		raw["state"] = FarmState.UNTILLED
		raw["crop"] = {}
	assert_true(FarmState.load_save_state(fixture), "用错工具夹具可以载入")
	assert_true(FarmState.debris_wrong_tool_message(FarmState.DEBRIS_WEED) == "杂草要用镰刀清除", "杂草文案")
	assert_true(FarmState.debris_wrong_tool_message(FarmState.DEBRIS_STONE) == "石头要用镐子清除", "石头文案")
	assert_true(FarmState.debris_wrong_tool_message(FarmState.DEBRIS_TWIG) == "树枝要用斧头清除", "树枝文案")
	assert_true(FarmState.debris_wrong_tool_message(FarmState.DEBRIS_STUMP) == "树桩要用斧头清除", "树桩文案仍是要用斧头")
	var farm := Farm.new()
	var tools_by_kind := {
		FarmState.DEBRIS_WEED: [
			ToolManager.ToolType.HOE,
			ToolManager.ToolType.AXE,
			ToolManager.ToolType.PICKAXE,
			ToolManager.ToolType.WATERING_CAN,
		],
		FarmState.DEBRIS_STONE: [
			ToolManager.ToolType.HOE,
			ToolManager.ToolType.AXE,
			ToolManager.ToolType.SICKLE,
			ToolManager.ToolType.WATERING_CAN,
		],
		FarmState.DEBRIS_TWIG: [
			ToolManager.ToolType.HOE,
			ToolManager.ToolType.PICKAXE,
			ToolManager.ToolType.SICKLE,
			ToolManager.ToolType.WATERING_CAN,
		],
		FarmState.DEBRIS_STUMP: [
			ToolManager.ToolType.HOE,
			ToolManager.ToolType.PICKAXE,
			ToolManager.ToolType.SICKLE,
			ToolManager.ToolType.WATERING_CAN,
		],
	}
	var coords := {
		FarmState.DEBRIS_WEED: Vector2i(1, 1),
		FarmState.DEBRIS_STONE: Vector2i(2, 1),
		FarmState.DEBRIS_TWIG: Vector2i(3, 1),
		FarmState.DEBRIS_STUMP: Vector2i(4, 1),
	}
	for kind in [FarmState.DEBRIS_WEED, FarmState.DEBRIS_STONE, FarmState.DEBRIS_TWIG, FarmState.DEBRIS_STUMP]:
		var expect := FarmState.debris_wrong_tool_message(kind)
		var plot: Vector2i = coords[kind]
		for tool in tools_by_kind[kind]:
			var before_stam := StaminaManager.current_stamina
			var before_water := FarmState.get_watering_can_uses_left()
			var before_state := int(FarmState.get_cell(plot).get("state", -1))
			var result := farm.perform_farm_action(plot, tool)
			assert_true(
				bool(result.get("success", true)) == false
					and str(result.get("message", "")) == expect
					and FarmState.get_debris(plot) == kind
					and int(FarmState.get_cell(plot).get("state", -2)) == before_state
					and is_equal_approx(StaminaManager.current_stamina, before_stam)
					and FarmState.get_watering_can_uses_left() == before_water,
				"%s对%s：%s，success=false，不翻地不扣体力" % [
					_wrong_tool_label(tool),
					FarmState.debris_display_name(kind),
					expect,
				]
			)
	var fiber_before := Inventory.get_item_count("fiber")
	var clear_stam := StaminaManager.current_stamina
	var cleared := farm.perform_farm_action(Vector2i(1, 1), ToolManager.ToolType.SICKLE)
	assert_true(
		bool(cleared.get("success", false))
			and str(cleared.get("message", "")) == "清除了杂草，获得纤维"
			and FarmState.get_debris(Vector2i(1, 1)).is_empty()
			and Inventory.get_item_count("fiber") == fiber_before + 1
			and is_equal_approx(StaminaManager.current_stamina, clear_stam - 2.0)
			and int(FarmState.get_cell(Vector2i(1, 1)).get("state", -1)) == FarmState.UNTILLED,
		"镰刀清草仍然成功、掉纤维、扣 2 体力，不翻地"
	)
	farm.free()
	var toast_root := UIManager.get_node_or_null("UIOverlay/ToastRoot")
	if toast_root != null:
		for child in toast_root.get_children():
			child.free()
	FarmState.load_save_state(farm_snapshot)
	Inventory.load_state(inv_snapshot)
	StaminaManager.set_stamina(saved_stamina)
	print("  Debris wrong tool: All tests completed")


func _wrong_tool_label(tool: int) -> String:
	match tool:
		ToolManager.ToolType.HOE:
			return "锄头"
		ToolManager.ToolType.WATERING_CAN:
			return "水壶"
		ToolManager.ToolType.AXE:
			return "斧头"
		ToolManager.ToolType.PICKAXE:
			return "镐子"
		ToolManager.ToolType.SICKLE:
			return "镰刀"
		_:
			return str(tool)


func run_tool_number_hotkey_tests() -> void:
	print("\n[Tool Number Hotkeys]")
	var inv_snapshot: Dictionary = Inventory.save_state()
	var farm_snapshot: Dictionary = FarmState.get_save_state()
	var saved_stamina := StaminaManager.current_stamina
	var order: Array = ToolManager.TOOL_HOTKEY_ORDER
	assert_true(order.size() == 6, "工具直选有 6 个")
	assert_true(order[0] == ToolManager.ToolType.HOE, "1 是锄头")
	assert_true(order[1] == ToolManager.ToolType.WATERING_CAN, "2 是水壶")
	assert_true(order[2] == ToolManager.ToolType.AXE, "3 是斧头")
	assert_true(order[3] == ToolManager.ToolType.PICKAXE, "4 是镐子")
	assert_true(order[4] == ToolManager.ToolType.SICKLE, "5 是镰刀")
	assert_true(order[5] == ToolManager.ToolType.FISHING_ROD, "6 是鱼竿")
	assert_true(ToolDisplay.HINT_TOOL == "1–6 直选 · Q/R 切换", "工具提示写明 1–6 与 Q/R")
	assert_true(ToolDisplay.HINT_HAND == "1–6 直选 · Q/R 拿回", "收起时提示仍是 1–6 与 Q/R")

	var tm := ToolManager.new()
	add_child(tm)
	tm.equip_tool(ToolManager.ToolType.HOE)
	tm.equip_tool_by_hotkey(1)
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "下标 1 一键装备水壶")
	tm.equip_tool_by_hotkey(1)
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "已是水壶时下标 1 保持")
	tm.equip_tool_by_hotkey(-1)
	tm.equip_tool_by_hotkey(6)
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "越界下标不换工具")
	tm.next_tool()
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.AXE, "Q/R 的下一个仍是斧头")
	tm.previous_tool()
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "Q/R 的上一个仍回到水壶")
	tm.put_away_tool()
	assert_true(tm.is_using_hotbar_item(), "put_away 仍收起工具")
	tm.equip_tool_by_hotkey(1)
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "收起后数字键下标仍能直选水壶")

	var player := Player.new()
	player.tool_manager = tm
	tm.equip_tool(ToolManager.ToolType.HOE)
	assert_true(InputMap.has_action("tool_2"), "tool_2 动作已注册")
	var bound_2 := false
	if InputMap.has_action("tool_2"):
		for event in InputMap.action_get_events("tool_2"):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				if key_event.physical_keycode == KEY_2 or key_event.keycode == KEY_2:
					bound_2 = true
	assert_true(bound_2, "数字键 2 绑定到水壶")
	if InputMap.has_action("tool_2"):
		Input.action_press("tool_2")
		player._handle_tool_input()
		Input.action_release("tool_2")
	assert_true(tm.get_current_tool_type() == ToolManager.ToolType.WATERING_CAN, "模拟按下 2 切到水壶")

	var index_before := Inventory.get_selected_hotbar_index()
	var bar := HotkeyBar.new()
	add_child(bar)
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.physical_keycode = KEY_1
	key.pressed = true
	bar._input(key)
	assert_true(Inventory.get_selected_hotbar_index() == index_before, "快捷栏不再吃数字键 1")
	assert_true(bar.get_node("SelectHint").text == "点击或 Tab 选物品", "快捷栏提示改用点击或 Tab")
	var tab := InputEventAction.new()
	tab.action = "hotbar_next"
	tab.pressed = true
	bar._input(tab)
	assert_true(
		Inventory.get_selected_hotbar_index() == (index_before + 1) % HotkeyBar.HOTBAR_SIZE,
		"Tab 仍切换快捷栏"
	)
	bar.queue_free()
	tm.queue_free()
	player.free()

	StaminaManager.set_stamina(StaminaManager.max_stamina)
	FarmState.reset()
	FarmState.till(Vector2i(1, 1))
	var farm := Farm.new()
	var again: Dictionary = farm.perform_farm_action(Vector2i(1, 1), ToolManager.ToolType.HOE)
	assert_true(
		str(again.get("message", "")) == "这里已经翻过了（点快捷栏或按 Tab 选种子）",
		"翻过的地提示改用快捷栏或 Tab 选种子"
	)
	farm.free()
	var toast_root := UIManager.get_node_or_null("UIOverlay/ToastRoot")
	if toast_root != null:
		for child in toast_root.get_children():
			child.free()
	FarmState.load_save_state(farm_snapshot)
	Inventory.load_state(inv_snapshot)
	StaminaManager.set_stamina(saved_stamina)
	print("  Tool number hotkeys: All tests completed")

func run_house_camera_follow_tests() -> void:
	print("\n[House Camera Follow]")
	var screen := Vector2(1280, 720)
	var limits := Rect2(0, 0, 3200, 2240)
	var door := Vector2(841, 286)
	var visual := Vector2(850, 158)
	var display := Vector2(252, 256)
	var region := Farm.house_camera_follow_region(door, visual, display)
	assert_true(region.has_point(Vector2(260, 240)), "Follow region includes the northwest corner by the house")
	assert_true(region.has_point(door + Vector2(0, 72)), "Follow region includes the door apron")
	assert_true(not region.has_point(Vector2(2500, 1800)), "Follow region does not cover the far map edge")

	var corner := Vector2(260, 240)
	var corner_offset := Farm.house_camera_follow_offset(corner, region, limits, screen)
	assert_true(corner_offset == Vector2(-380, -120), "Northwest clamp is undone so the camera stays on the player")
	var door_offset := Farm.house_camera_follow_offset(door, region, limits, screen)
	assert_true(door_offset == Vector2(0, -74), "Door standing spot is pulled down off the top limit")
	var clear := Vector2(900, 450)
	assert_true(
		region.has_point(clear) and Farm.house_camera_follow_offset(clear, region, limits, screen) == Vector2.ZERO,
		"Inside the house area but clear of the edge, limits already centre the player"
	)
	assert_true(
		Farm.house_camera_follow_offset(Vector2(1600, 1100), region, limits, screen) == Vector2.ZERO,
		"Mid-map keeps a zero offset so the map limits still apply"
	)
	assert_true(
		Farm.house_camera_follow_offset(Vector2(3100, 1800), region, limits, screen) == Vector2.ZERO,
		"The far edge keeps a zero offset"
	)
	assert_true(Farm.actor_draws_in_front_of_house(360.0, 278.0), "South of the foundation the player draws in front")
	assert_true(not Farm.actor_draws_in_front_of_house(200.0, 278.0), "North of the foundation the wall draws in front")
	print("  House camera follow: All tests completed")



func run_shop_find_guide_tests() -> void:
	print("\n[Shop Find Guide]")
	assert_true(
		QuestSystem.get_objective_description("village_introduction", 0) == "去找店主莉莉买种子",
		"认识村民的第一目标是去找店主莉莉买种子"
	)
	assert_true(
		PlayerHouse.village_home_hint("village_house_entrance") == "这是住家，商店在外面找莉莉",
		"从村里进住家会提示商店在外面找莉莉"
	)
	assert_true(PlayerHouse.village_home_hint("house_entrance") == "", "从农场回家不把住家说成店")
	assert_true(PlayerHouse.village_home_hint("farm_start") == "", "其他出生点不提示住家")
	print("  Shop find guide: All tests completed")


func run_quest_tracker_feature_tests() -> void:
	print("\n[Quest Tracker Feature]")
	var tutorial = QuestSystem.get_quest("tutorial_farming")
	var village = QuestSystem.get_quest("village_introduction")
	var fisher = QuestSystem.get_quest("fisherman_catch")
	assert_true(tutorial != null and village != null and fisher != null, "任务条选择夹具能读到三张任务")
	var featured = QuestTracker.select_featured_quest([tutorial, village])
	assert_true(featured != null and str(featured.id) == "village_introduction", "先接农场入门再接村导时，任务条选认识村民")
	var reversed = QuestTracker.select_featured_quest([village, tutorial])
	assert_true(reversed != null and str(reversed.id) == "village_introduction", "村导进行中时不因农场入门排在后面而退回农场入门")
	var newest = QuestTracker.select_featured_quest([tutorial, fisher])
	assert_true(newest != null and str(newest.id) == "fisherman_catch", "没有村导时任务条显示最近接受的任务")
	var only = QuestTracker.select_featured_quest([tutorial])
	assert_true(only != null and str(only.id) == "tutorial_farming", "只有农场入门时任务条仍显示农场入门")
	assert_true(QuestTracker.select_featured_quest([]) == null, "没有活跃任务时没有要展示的任务")
	assert_true(QuestTracker.first_incomplete_objective([{"required": 1}, {"required": 1}], [0, 0]) == 0, "两项都未完成时当前目标是第一项")
	assert_true(QuestTracker.first_incomplete_objective([{"required": 1}, {"required": 1}], [1, 0]) == 1, "第一项完成后当前目标切到下一项")

	var snapshot: Dictionary = QuestSystem.save_state()
	QuestSystem.reset()
	var tracker: QuestTracker = null
	QuestSystem.unlock_quest("tutorial_farming")
	assert_true(QuestSystem.accept_quest("tutorial_farming"), "任务条夹具先接受农场入门")
	tracker = load("res://src/ui/hud/QuestTracker.tscn").instantiate() as QuestTracker
	add_child(tracker)
	assert_true(tracker._title != null and tracker._title.text == "农场入门", "只接农场入门时左上标题是农场入门")
	assert_true("收获1个防风草" in tracker._objective.text, "只接农场入门时当前目标是收获防风草")
	QuestSystem.unlock_quest("village_introduction")
	assert_true(QuestSystem.accept_quest("village_introduction"), "任务条夹具再接受认识村民")
	var active := QuestSystem.get_active_quests()
	var active_ids: Array[String] = []
	for quest in active:
		active_ids.append(str(quest.id))
	assert_true(active_ids == ["tutorial_farming", "village_introduction"], "农场入门仍在活跃列表里，手册还能看到")
	assert_true(tracker._title.text == "认识村民", "接了村导后任务条标题切到认识村民")
	assert_true("去找店主莉莉买种子" in tracker._objective.text, "接了村导后当前目标是去找店主莉莉买种子")
	assert_true("收获1个防风草" not in tracker._objective.text, "接了村导后任务条不再停在收获防风草")
	QuestSystem.set_objective_progress("village_introduction", 0, 1)
	assert_true(tracker._title.text == "认识村民", "买到种子前的第一步完成后标题仍是认识村民")
	assert_true("与农夫交谈" in tracker._objective.text, "当前目标改为未完成的第一项：与农夫交谈")
	assert_true("去找店主莉莉买种子" not in tracker._objective.text, "收起的任务条不再把已完成的买种子目标当成当前目标")
	if tracker != null:
		tracker.free()
	QuestSystem.load_state(snapshot)
	print("  Quest tracker feature: All tests completed")


func assert_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % message)
	else:
		failed_tests += 1
		print("  [FAIL] %s" % message)
