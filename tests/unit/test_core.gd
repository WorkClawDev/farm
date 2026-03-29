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
	assert_true(item.name == "芜菁", "Turnip name should be 芜菁")
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

func assert_true(condition: bool, message: String):
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % message)
	else:
		failed_tests += 1
		print("  [FAIL] %s" % message)
