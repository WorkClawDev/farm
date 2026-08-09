extends Node

## Simple Test Runner - 简化测试运行器
## 直接创建所需系统进行测试

func _ready() -> void:
	print("==================================================")
	print("TEST: Pastoral Tales Unit Tests")
	print("==================================================")
	
	var results = {
		"total": 0,
		"passed": 0,
		"failed": 0
	}
	
	# 初始化 ItemDatabase (手动加载数据)
	var item_db = ItemDatabase.new()
	item_db.load_items()
	
	# 初始化 Inventory
	var inventory = Inventory.new()
	inventory._initialize_slots()
	
	# 运行 ItemDatabase 测试
	print("\n[DATABASE] Testing ItemDatabase...")
	results = _test_item_database(item_db, results)
	
	# 运行 Inventory 测试
	print("\n[INVENTORY] Testing Inventory...")
	results = _test_inventory(inventory, results)
	
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
	
	# 清理
	item_db.free()
	inventory.free()
	
	get_tree().quit()

func _test_item_database(db: ItemDatabase, results: Dictionary) -> Dictionary:
	var tests = [
		{"name": "test_item_count", "func": func(): return db.items.size() > 0},
		{"name": "test_get_item", "func": func(): var item = db.get_item("turnip"); return item != null and item.name == "芜菁"},
		{"name": "test_get_item_types", "func": func(): var item = db.get_item("turnip"); return item != null and item.type == ItemDatabase.ItemType.CROP},
		{"name": "test_get_icon_path", "func": func(): var path = db.get_icon_path("turnip"); return path != ""},
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

func _test_inventory(inv: Inventory, results: Dictionary) -> Dictionary:
	# 添加测试物品
	inv.add_item("turnip", 5)
	
	var tests = [
		{"name": "test_initial_empty_slots", "func": func(): return inv.get_empty_slot_count() == 35},
		{"name": "test_add_item", "func": func(): return inv.get_item_count("turnip") == 5},
		{"name": "test_has_item", "func": func(): return inv.has_item("turnip", 3)},
		{"name": "test_remove_item", "func": func(): inv.remove_item("turnip", 2); return inv.get_item_count("turnip") == 3},
		{"name": "test_has_not_enough", "func": func(): return not inv.has_item("turnip", 10)},
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
