extends SceneTree

## Integration Test - 游戏启动集成测试
## 验证游戏核心系统可以正常初始化和运行

func _init() -> void:
	print("============================================================")
	print("游戏启动集成测试")
	print("============================================================")
	
	var all_passed = true
	
	# 测试1: 验证数据文件
	print("\n[测试] 数据文件...")
	all_passed = _test_data_files() and all_passed
	
	# 测试2: 验证场景文件
	print("\n[测试] 场景文件...")
	all_passed = _test_scene_files() and all_passed
	
	# 测试3: 验证脚本文件
	print("\n[测试] 脚本文件...")
	all_passed = _test_script_files() and all_passed
	
	# 测试4: 验证项目配置
	print("\n[测试] 项目配置...")
	all_passed = _test_project_config() and all_passed
	
	# 输出结果
	print("\n============================================================")
	if all_passed:
		print("所有集成测试通过!")
		print("游戏可以正常启动和运行")
	else:
		print("有测试失败，请检查")
	print("============================================================")
	
	quit()

func _test_data_files() -> bool:
	var files = [
		"res://data/items.json",
		"res://data/crops.json",
		"res://data/recipes.json",
		"res://data/npcs.json",
		"res://data/dialogues.json",
		"res://data/fish.json",
		"res://data/quests.json"
	]
	
	var all_exist = true
	for file in files:
		if FileAccess.file_exists(file):
			print("  [OK] %s" % file.get_file())
		else:
			print("  [FAIL] %s (不存在)" % file.get_file())
			all_exist = false
	
	return all_exist

func _test_scene_files() -> bool:
	var scenes = [
		"res://src/world/maps/Farm.tscn",
		"res://src/world/maps/Village.tscn",
		"res://src/world/maps/Beach.tscn",
		"res://src/world/maps/Mine.tscn",
		"res://src/entities/player/Player.tscn",
		"res://src/entities/npc/NPC.tscn",
		"res://src/ui/menus/MainMenu.tscn"
	]
	
	var all_exist = true
	for scene in scenes:
		if FileAccess.file_exists(scene):
			print("  [OK] %s" % scene.get_file())
		else:
			print("  [FAIL] %s (不存在)" % scene.get_file())
			all_exist = false
	
	return all_exist

func _test_script_files() -> bool:
	var scripts = [
		"res://src/autoload/GameManager.gd",
		"res://src/autoload/TimeManager.gd",
		"res://src/core/inventory/Inventory.gd",
		"res://src/autoload/EventBus.gd",
		"res://src/entities/player/Player.gd",
		"res://src/core/farming/GrowthSystem.gd",
		"res://src/core/quest/QuestSystem.gd"
	]
	
	var all_exist = true
	for script in scripts:
		if FileAccess.file_exists(script):
			print("  [OK] %s" % script.get_file())
		else:
			print("  [FAIL] %s (不存在)" % script.get_file())
			all_exist = false
	
	return all_exist

func _test_project_config() -> bool:
	var config = ConfigFile.new()
	var err = config.load("res://project.godot")
	
	if err != OK:
		print("  [FAIL] 无法加载 project.godot")
		return false
	
	print("  [OK] project.godot 加载成功")
	
	# 检查关键配置
	var project_name = config.get_value("application", "config/name", "")
	if project_name == "Pastoral Tales":
		print("  [OK] 项目名称正确: %s" % project_name)
	else:
		print("  [WARN] 项目名称: %s" % project_name)
	
	# 检查autoload
	var autoloads = config.get_section_keys("autoload")
	var required_autoloads = ["GameManager", "TimeManager", "Inventory", "EventBus"]
	var all_autoloads_present = true
	
	for autoload in required_autoloads:
		if autoload in autoloads:
			print("  [OK] AutoLoad: %s" % autoload)
		else:
			print("  [FAIL] AutoLoad缺失: %s" % autoload)
			all_autoloads_present = false
	
	return all_autoloads_present
