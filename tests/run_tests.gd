extends SceneTree

## Test Runner - 测试运行器
## 运行所有单元测试

func _init() -> void:
	print("==================================================")
	print("TEST: Pastoral Tales Unit Tests")
	print("==================================================")
	
	var results = {
		"total": 0,
		"passed": 0,
		"failed": 0
	}
	
	# 运行时间管理器测试
	print("\n[TIME] Testing TimeManager...")
	results = _run_time_manager_tests(results)
	
	# 运行背包系统测试
	print("\n[INVENTORY] Testing Inventory...")
	results = _run_inventory_tests(results)
	
	# 运行物品数据库测试
	print("\n[DATABASE] Testing ItemDatabase...")
	results = _run_item_database_tests(results)
	
	# 输出结果
	print("\n==================================================")
	print("RESULTS")
	print("==================================================")
	print("Total: %d" % results.total)
	print("Passed: %d" % results.passed)
	print("Failed: %d" % results.failed)
	print("==================================================")
	
	if results.failed == 0:
		print("ALL TESTS PASSED!")
	else:
		print("SOME TESTS FAILED")
	
	quit()

func _run_time_manager_tests(results: Dictionary) -> Dictionary:
	var tests = [
		{"name": "test_time_initial", "func": _test_time_initial},
		{"name": "test_time_formatting", "func": _test_time_formatting},
		{"name": "test_season_names", "func": _test_season_names},
		{"name": "test_pause_resume", "func": _test_pause_resume}
	]
	
	for test in tests:
		results.total += 1
		var success = test.func.call()
		if success:
			results.passed += 1
			print("  [PASS] %s" % test.name)
		else:
			results.failed += 1
			print("  [FAIL] %s" % test.name)
	
	return results

func _run_inventory_tests(results: Dictionary) -> Dictionary:
	var tests = [
		{"name": "test_inventory_initial", "func": _test_inventory_initial},
		{"name": "test_inventory_add", "func": _test_inventory_add},
		{"name": "test_inventory_remove", "func": _test_inventory_remove},
		{"name": "test_inventory_has", "func": _test_inventory_has},
		{"name": "test_inventory_save_load", "func": _test_inventory_save_load}
	]
	
	for test in tests:
		results.total += 1
		var success = test.func.call()
		if success:
			results.passed += 1
			print("  [PASS] %s" % test.name)
		else:
			results.failed += 1
			print("  [FAIL] %s" % test.name)
	
	return results

func _run_item_database_tests(results: Dictionary) -> Dictionary:
	var tests = [
		{"name": "test_item_database_load", "func": _test_item_database_load},
		{"name": "test_get_item", "func": _test_get_item},
		{"name": "test_get_icon_path", "func": _test_get_icon_path}
	]
	
	for test in tests:
		results.total += 1
		var success = test.func.call()
		if success:
			results.passed += 1
			print("  [PASS] %s" % test.name)
		else:
			results.failed += 1
			print("  [FAIL] %s" % test.name)
	
	return results

# TimeManager Test Functions
func _test_time_initial() -> bool:
	var tm = TimeManager.new()
	var ok = tm.current_time == 6.0 and tm.current_day == 1
	tm.free()
	return ok

func _test_time_formatting() -> bool:
	var tm = TimeManager.new()
	var formatted = tm.get_formatted_time()
	var ok = formatted != ""
	tm.free()
	return ok

func _test_season_names() -> bool:
	var tm = TimeManager.new()
	var season = tm.get_season_name()
	var ok = season == "Spring" or season == "Summer" or season == "Fall" or season == "Winter"
	tm.free()
	return ok

func _test_pause_resume() -> bool:
	var tm = TimeManager.new()
	tm.pause_time()
	var is_paused = tm.is_paused
	tm.resume_time()
	var ok = is_paused and not tm.is_paused
	tm.free()
	return ok

# Inventory Test Functions
func _test_inventory_initial() -> bool:
	var inv = Inventory.new()
	inv._initialize_slots()
	var ok = inv.get_empty_slot_count() == 36
	inv.free()
	return ok

func _test_inventory_add() -> bool:
	var inv = Inventory.new()
	inv._initialize_slots()
	var result = inv.add_item("turnip", 5)
	var ok = result and inv.get_item_count("turnip") == 5
	inv.free()
	return ok

func _test_inventory_remove() -> bool:
	var inv = Inventory.new()
	inv._initialize_slots()
	inv.add_item("turnip", 10)
	var result = inv.remove_item("turnip", 3)
	var ok = result and inv.get_item_count("turnip") == 7
	inv.free()
	return ok

func _test_inventory_has() -> bool:
	var inv = Inventory.new()
	inv._initialize_slots()
	inv.add_item("turnip", 5)
	var ok = inv.has_item("turnip", 3) and not inv.has_item("turnip", 10)
	inv.free()
	return ok

func _test_inventory_save_load() -> bool:
	var inv = Inventory.new()
	inv._initialize_slots()
	inv.add_item("turnip", 5)
	inv.add_item("potato", 3)
	
	var save_data = inv.get_save_data()
	
	var inv2 = Inventory.new()
	inv2._initialize_slots()
	inv2.load_save_data(save_data)
	
	var ok = inv2.get_item_count("turnip") == 5 and inv2.get_item_count("potato") == 3
	inv.free()
	inv2.free()
	return ok

# ItemDatabase Test Functions
func _test_item_database_load() -> bool:
	var db = ItemDatabase.new()
	var ok = db.items.size() > 0
	db.free()
	return ok

func _test_get_item() -> bool:
	var db = ItemDatabase.new()
	var item = db.get_item("turnip")
	var ok = item != null and item.name == "芜菁"
	db.free()
	return ok

func _test_get_icon_path() -> bool:
	var db = ItemDatabase.new()
	var path = db.get_icon_path("turnip")
	var ok = path != ""
	db.free()
	return ok
