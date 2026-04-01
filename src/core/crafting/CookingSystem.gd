extends Node

## CookingSystem - 烹饪系统
## 管理食谱、烹饪制作、效果应用

# 信号
signal recipe_learned(recipe_id: String)
signal recipe_cooked(recipe_id: String, quantity: int)
signal cooking_started(recipe_id: String)
signal cooking_completed(recipe_id: String, result_item: String)
signal cooking_failed(recipe_id: String, reason: String)
signal ingredients_missing(recipe_id: String, missing: Array)

# 食谱数据结构
class RecipeData extends RefCounted:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var category: String = "cooking"  # cooking, baking, brewing
	var ingredients: Array = []  # [{item_id: "turnip", quantity: 2}, ...]
	var result_item: String = ""
	var result_quantity: int = 1
	var cooking_time: float = 2.0  # 游戏内小时
	var energy_cost: int = 5  # 烹饪消耗体力
	var effects: Dictionary = {}  # {energy: 50, buff: "speed", duration: 300}
	var unlock_condition: Dictionary = {}  # {type: "friendship", npc: "mayor", hearts: 3}
	var sell_price: int = 0
	var icon_path: String = ""

	func _to_string() -> String:
		return "[Recipe] %s (%s) -> %s x%d" % [id, name, result_item, result_quantity]

# 食谱数据库
var _recipes: Dictionary = {}
var _learned_recipes: Array[String] = []
var _is_loaded: bool = false

# 当前烹饪状态
var _is_cooking: bool = false
var _current_recipe: String = ""
var _cooking_progress: float = 0.0

# 引用
var _inventory: Inventory = null
var _item_database: ItemDatabase = null
var _stamina_manager: Node = null

func _ready() -> void:
	load_recipes()
	_connect_systems()

func _connect_systems() -> void:
	# 获取 Inventory 引用
	_inventory = get_node_or_null("/root/Inventory")
	if _inventory == null:
		_inventory = Inventory.new()
		add_child(_inventory)

	# 获取体力系统引用
	_stamina_manager = get_node_or_null("/root/StaminaManager")

	# 获取 ItemDatabase 引用
	_item_database = get_node_or_null("/root/ItemDatabase")
	if _item_database == null:
		_item_database = get_node_or_null("/root/ItemDatabase")
		

## 加载食谱数据库
func load_recipes() -> bool:
	var path := "res://data/recipes.json"

	if not FileAccess.file_exists(path):
		push_warning("[CookingSystem] recipes.json not found at: " + path)
		_create_default_recipes()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("[CookingSystem] Failed to open recipes.json: " + str(error))
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("[CookingSystem] JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return false

	var data: Dictionary = json.get_data()
	_parse_recipes(data)

	_is_loaded = true
	print("[CookingSystem] Loaded %d recipes" % _recipes.size())
	return true

## 解析食谱数据
func _parse_recipes(data: Dictionary) -> void:
	if not data.has("recipes"):
		push_warning("[CookingSystem] No 'recipes' array in recipes.json")
		return

	var recipes_array: Array = data["recipes"]
	for recipe_data in recipes_array:
		var recipe := _create_recipe_from_dict(recipe_data)
		if recipe.id != "":
			_recipes[recipe.id] = recipe

## 从字典创建食谱
func _create_recipe_from_dict(data: Dictionary) -> RecipeData:
	var recipe := RecipeData.new()

	recipe.id = data.get("id", "")
	if recipe.id == "":
		push_warning("[CookingSystem] Recipe missing 'id' field")
		return recipe

	recipe.name = data.get("name", recipe.id)
	recipe.description = data.get("description", "")
	recipe.category = data.get("category", "cooking")
	recipe.result_item = data.get("result_item", "")
	recipe.result_quantity = data.get("result_quantity", 1)
	recipe.cooking_time = data.get("cooking_time", 2.0)
	recipe.energy_cost = data.get("energy_cost", 5)
	recipe.effects = data.get("effects", {})
	recipe.unlock_condition = data.get("unlock_condition", {})
	recipe.sell_price = data.get("sell_price", 0)
	recipe.icon_path = data.get("icon", "")

	# 解析材料
	var ingredients_data: Array = data.get("ingredients", [])
	for ingredient in ingredients_data:
		recipe.ingredients.append({
			"item_id": ingredient.get("item_id", ""),
			"quantity": ingredient.get("quantity", 1)
		})

	return recipe

## 创建默认食谱
func _create_default_recipes() -> void:
	var default_recipes := [
		{
			"id": "fried_egg",
			"name": "煎蛋",
			"description": "简单美味的煎蛋，恢复少量体力。",
			"category": "cooking",
			"ingredients": [{"item_id": "egg", "quantity": 1}],
			"result_item": "fried_egg",
			"result_quantity": 1,
			"cooking_time": 0.5,
			"energy_cost": 3,
			"effects": {"energy": 35},
			"sell_price": 50
		},
		{
			"id": "vegetable_soup",
			"name": "蔬菜汤",
			"description": "营养丰富的蔬菜汤，恢复中量体力。",
			"category": "cooking",
			"ingredients": [
				{"item_id": "turnip", "quantity": 1},
				{"item_id": "potato", "quantity": 1},
				{"item_id": "tomato", "quantity": 1}
			],
			"result_item": "vegetable_soup",
			"result_quantity": 1,
			"cooking_time": 1.0,
			"energy_cost": 5,
			"effects": {"energy": 80},
			"sell_price": 150
		}
	]

	for recipe_data in default_recipes:
		var recipe := _create_recipe_from_dict(recipe_data)
		_recipes[recipe.id] = recipe

	_is_loaded = true
	print("[CookingSystem] Created default recipes with %d entries" % _recipes.size())

## 获取食谱
func get_recipe(recipe_id: String) -> RecipeData:
	return _recipes.get(recipe_id, null)

## 获取所有食谱
func get_all_recipes() -> Array:
	return _recipes.values()

## 获取已学习的食谱
func get_learned_recipes() -> Array:
	var result := []
	for recipe_id in _learned_recipes:
		if _recipes.has(recipe_id):
			result.append(_recipes[recipe_id])
	return result

## 检查食谱是否已学习
func is_recipe_learned(recipe_id: String) -> bool:
	return recipe_id in _learned_recipes

## 学习食谱
func learn_recipe(recipe_id: String) -> bool:
	if not _recipes.has(recipe_id):
		push_warning("[CookingSystem] Recipe not found: " + recipe_id)
		return false

	if recipe_id in _learned_recipes:
		return false  # 已经学会了

	_learned_recipes.append(recipe_id)
	recipe_learned.emit(recipe_id)
	print("[CookingSystem] Learned recipe: %s" % recipe_id)
	return true

## 检查是否有足够的材料
func can_cook(recipe_id: String) -> Dictionary:
	var result := {
		"can_cook": false,
		"missing": [],
		"has_energy": true
	}

	var recipe := get_recipe(recipe_id)
	if recipe == null:
		result.missing.append({"error": "recipe_not_found"})
		return result

	# 检查材料
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var required: int = ingredient.get("quantity", 1)

		if _inventory == null:
			result.missing.append({"item_id": item_id, "required": required, "have": 0})
			continue

		var have := _inventory.get_item_count(item_id)
		if have < required:
			result.missing.append({
				"item_id": item_id,
				"required": required,
				"have": have
			})

	# 检查体力
	var stamina_ok := true
	if _stamina_manager:
		var cost: float = recipe.energy_cost
		var current_stamina = _stamina_manager.get("current_stamina")
		if current_stamina is float or current_stamina is int:
			stamina_ok = float(current_stamina) >= cost
		else:
			stamina_ok = false
	result.has_energy = stamina_ok

	result.can_cook = result.missing.is_empty() and result.has_energy
	return result

## 获取可用食谱列表（材料齐全）
func get_available_recipes() -> Array:
	var result := []
	for recipe_id in _learned_recipes:
		if _recipes.has(recipe_id):
			var check := can_cook(recipe_id)
			if check.can_cook:
				result.append(_recipes[recipe_id])
	return result

## 烹饪
func cook(recipe_id: String) -> bool:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		cooking_failed.emit(recipe_id, "recipe_not_found")
		return false

	# 检查是否已学习
	if not is_recipe_learned(recipe_id):
		cooking_failed.emit(recipe_id, "recipe_not_learned")
		return false

	# 检查材料
	var check := can_cook(recipe_id)
	if not check.can_cook:
		if not check.missing.is_empty():
			ingredients_missing.emit(recipe_id, check.missing)
		cooking_failed.emit(recipe_id, "missing_ingredients")
		return false

	# 消耗材料
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var quantity: int = ingredient.get("quantity", 1)
		if _inventory:
			_inventory.remove_item(item_id, quantity)

	# 消耗体力
	if _stamina_manager:
		var cost: float = recipe.energy_cost
		if _stamina_manager.has_method("use_stamina"):
			_stamina_manager.use_stamina(cost)

	# 添加成品
	if _inventory:
		_inventory.add_item(recipe.result_item, recipe.result_quantity)

	# 发射信号
	cooking_started.emit(recipe_id)
	cooking_completed.emit(recipe_id, recipe.result_item)
	recipe_cooked.emit(recipe_id, recipe.result_quantity)

	print("[CookingSystem] Cooked: %s -> %s x%d" % [recipe_id, recipe.result_item, recipe.result_quantity])
	return true

## 按类型获取食谱
func get_recipes_by_category(category: String) -> Array:
	var result := []
	for recipe_id in _recipes:
		var recipe: RecipeData = _recipes[recipe_id]
		if recipe.category == category:
			result.append(recipe)
	return result

## 获取使用指定食材的食谱
func get_recipes_using_ingredient(item_id: String) -> Array:
	var result := []
	for recipe_id in _recipes:
		var recipe: RecipeData = _recipes[recipe_id]
		for ingredient in recipe.ingredients:
			if ingredient.get("item_id", "") == item_id:
				result.append(recipe)
				break
	return result

## 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"learned_recipes": _learned_recipes
	}

## 加载存档数据
func load_save_data(data: Dictionary) -> void:
	_learned_recipes.clear()
	var recipes: Array = data.get("learned_recipes", [])
	for recipe_id in recipes:
		if recipe_id is String and _recipes.has(recipe_id):
			_learned_recipes.append(recipe_id)
	print("[CookingSystem] Loaded %d learned recipes" % _learned_recipes.size())

## 解锁初始食谱
func unlock_starting_recipes() -> void:
	# 游戏开始时解锁基础食谱
	var starting_recipes := ["fried_egg", "boiled_egg", "toast"]
	for recipe_id in starting_recipes:
		if _recipes.has(recipe_id):
			learn_recipe(recipe_id)
