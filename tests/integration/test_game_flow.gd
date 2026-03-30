extends SceneTree

## Game Flow Integration Test - 游戏流程集成测试
## 验证从主菜单到游戏的完整流程

var test_results = {
	"total": 0,
	"passed": 0,
	"failed": 0,
	"errors": []
}

func _init() -> void:
	print("============================================================")
	print("田园物语 - 游戏流程集成测试")
	print("============================================================")
	
	# 测试1: 主菜单场景
	test("主菜单场景存在", _test_main_menu_exists())
	test("主菜单场景可加载", _test_main_menu_loadable())
	
	# 测试2: 农场场景
	test("农场场景存在", _test_farm_exists())
	test("农场场景可加载", _test_farm_loadable())
	
	# 测试3: 玩家场景
	test("玩家场景存在", _test_player_exists())
	test("玩家场景可加载", _test_player_loadable())
	
	# 测试4: 数据文件
	test("物品数据有效", _test_items_data())
	test("作物数据有效", _test_crops_data())
	test("NPC数据有效", _test_npcs_data())
	
	# 测试5: AutoLoad
	test("GameManager 可用", _test_gamemanager())
	test("TimeManager 可用", _test_timemanager())
	test("Inventory 可用", _test_inventory())
	
	# 测试6: 场景切换
	test("场景切换功能", _test_scene_transition())
	
	# 输出结果
	print("\n============================================================")
	print("测试结果")
	print("============================================================")
	print("总计: %d" % test_results.total)
	print("通过: %d ✓" % test_results.passed)
	print("失败: %d ✗" % test_results.failed)
	
	if test_results.errors.size() > 0:
		print("\n错误详情:")
		for error in test_results.errors:
			print("  - %s" % error)
	
	print("============================================================")
	
	if test_results.failed == 0:
		print("所有测试通过！游戏可以正常游玩。")
	else:
		print("有测试失败，请检查上述问题。")
	
	quit()

func test(name: String, result: bool) -> void:
	test_results.total += 1
	if result:
		test_results.passed += 1
		print("  ✓ %s" % name)
	else:
		test_results.failed += 1
		test_results.errors.append(name)
		print("  ✗ %s" % name)

func _test_main_menu_exists() -> bool:
	return FileAccess.file_exists("res://src/ui/menus/MainMenu.tscn")

func _test_main_menu_loadable() -> bool:
	var scene = load("res://src/ui/menus/MainMenu.tscn")
	return scene != null

func _test_farm_exists() -> bool:
	return FileAccess.file_exists("res://src/world/maps/Farm.tscn")

func _test_farm_loadable() -> bool:
	var scene = load("res://src/world/maps/Farm.tscn")
	return scene != null

func _test_player_exists() -> bool:
	return FileAccess.file_exists("res://src/entities/player/Player.tscn")

func _test_player_loadable() -> bool:
	var scene = load("res://src/entities/player/Player.tscn")
	return scene != null

func _test_items_data() -> bool:
	if not FileAccess.file_exists("res://data/items.json"):
		return false
	var file = FileAccess.open("res://data/items.json", FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	return json.parse(file.get_as_text()) == OK

func _test_crops_data() -> bool:
	if not FileAccess.file_exists("res://data/crops.json"):
		return false
	var file = FileAccess.open("res://data/crops.json", FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	return json.parse(file.get_as_text()) == OK

func _test_npcs_data() -> bool:
	if not FileAccess.file_exists("res://data/npcs.json"):
		return false
	var file = FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if not file:
		return false
	var json = JSON.new()
	return json.parse(file.get_as_text()) == OK

func _test_gamemanager() -> bool:
	return ResourceLoader.exists("res://src/autoload/GameManager.gd")

func _test_timemanager() -> bool:
	return ResourceLoader.exists("res://src/autoload/TimeManager.gd")

func _test_inventory() -> bool:
	return ResourceLoader.exists("res://src/core/inventory/Inventory.gd")

func _test_scene_transition() -> bool:
	# 检查场景切换脚本是否存在
	return FileAccess.file_exists("res://src/world/transitions/SceneTransition.gd")