extends Node

## CraftingSystem - 制作系统
## 管理配方数据、检查材料、执行制作

signal recipe_unlocked(recipe_id: String)
signal item_crafted(recipe_id: String, result_item: String, quantity: int)
signal crafting_failed(recipe_id: String, reason: String)
signal recipes_loaded

# 配方类型
enum RecipeCategory {
	TOOL,       # 工具制作
	EQUIPMENT,  # 装备制作
	FOOD,       # 食物烹饪
	RESOURCE,   # 资源加工
	DECORATION, # 装饰制作
	ALCHEMY     # 炼金合成
}

# 配方数据结构
class Recipe extends RefCounted:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var category: int = RecipeCategory.TOOL
	var result_item: String = ""
	var result_quantity: int = 1
	var ingredients: Array[Dictionary] = []  # [{"item_id": "wood", "quantity": 5}, ...]
	var craft_time: float = 0.0  # 制作时间（秒），0表示即时制作
	var workbench_required: String = ""  # 需要的工作台类型，空表示不需要
	var unlocked_by_default: bool = true
	var unlock_condition: Dictionary = {}  # 解锁条件

	func _to_string() -> String:
		return "[Recipe: %s -> %s x%d]" % [id, result_item, result_quantity]

# 配方数据库
var _recipes: Dictionary = {}
var _unlocked_recipes: Array[String] = []
var _is_loaded: bool = false

# 数据库引用
var _item_database: ItemDatabase = null
var _inventory: Inventory = null

func _ready() -> void:
	_connect_databases()
	load_recipes()

func _connect_databases() -> void:
	_item_database = get_node_or_null("/root/ItemDatabase")
	if _item_database == null:
		_item_database = get_node_or_null("/root/ItemDatabase")
		

	_inventory = get_node_or_null("/root/Inventory")
	if _inventory == null:
		_inventory = Inventory.new()
		add_child(_inventory)

## 加载配方数据
func load_recipes() -> bool:
	var path := "res://data/recipes.json"

	if not FileAccess.file_exists(path):
		push_warning("[CraftingSystem] recipes.json not found at: " + path)
		_create_default_recipes()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("[CraftingSystem] Failed to open recipes.json: " + str(error))
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("[CraftingSystem] JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return false

	var data: Dictionary = json.get_data()
	_parse_recipes(data)

	_is_loaded = true
	recipes_loaded.emit()
	print("[CraftingSystem] Loaded %d recipes" % _recipes.size())
	return true

## 解析配方数据
func _parse_recipes(data: Dictionary) -> void:
	if not data.has("recipes"):
		push_warning("[CraftingSystem] No 'recipes' array in recipes.json")
		return

	var recipes_array: Array = data["recipes"]
	for recipe_data in recipes_array:
		var recipe := _create_recipe_from_dict(recipe_data)
		if recipe.id != "":
			_recipes[recipe.id] = recipe
			if recipe.unlocked_by_default:
				_unlocked_recipes.append(recipe.id)

## 从字典创建配方
func _create_recipe_from_dict(data: Dictionary) -> Recipe:
	var recipe := Recipe.new()

	recipe.id = data.get("id", "")
	if recipe.id == "":
		push_warning("[CraftingSystem] Recipe missing 'id' field")
		return recipe

	recipe.name = data.get("name", recipe.id)
	recipe.description = data.get("description", "")

	# 解析类型
	var category_str: String = data.get("category", "tool")
	recipe.category = _parse_category(category_str)

	recipe.result_item = data.get("result_item", "")
	recipe.result_quantity = data.get("result_quantity", 1)
	recipe.craft_time = data.get("craft_time", 0.0)
	recipe.workbench_required = data.get("workbench_required", "")
	recipe.unlocked_by_default = data.get("unlocked_by_default", true)
	recipe.unlock_condition = data.get("unlock_condition", {})

	# 解析材料
	if data.has("ingredients"):
		var ingredients_array: Array = data["ingredients"]
		for ingredient_data in ingredients_array:
			if ingredient_data is Dictionary:
				recipe.ingredients.append({
					"item_id": ingredient_data.get("item_id", ""),
					"quantity": ingredient_data.get("quantity", 1)
				})

	return recipe

## 解析配方类型字符串
func _parse_category(category_str: String) -> int:
	match category_str.to_lower():
		"tool": return RecipeCategory.TOOL
		"equipment": return RecipeCategory.EQUIPMENT
		"food": return RecipeCategory.FOOD
		"resource": return RecipeCategory.RESOURCE
		"decoration": return RecipeCategory.DECORATION
		"alchemy": return RecipeCategory.ALCHEMY
		_: return RecipeCategory.TOOL

## 创建默认配方
func _create_default_recipes() -> void:
	var default_recipes := [
		{
			"id": "wooden_fence",
			"name": "木栅栏",
			"description": "用木材制作的简单栅栏。",
			"category": "decoration",
			"result_item": "wooden_fence",
			"result_quantity": 2,
			"ingredients": [{"item_id": "wood", "quantity": 3}],
			"unlocked_by_default": true
		},
		{
			"id": "chest",
			"name": "木箱",
			"description": "用于存储物品的木箱。",
			"category": "decoration",
			"result_item": "chest",
			"result_quantity": 1,
			"ingredients": [{"item_id": "wood", "quantity": 10}],
			"unlocked_by_default": true
		},
		{
			"id": "stone_brick",
			"name": "石砖",
			"description": "加工过的石材，用于建筑。",
			"category": "resource",
			"result_item": "stone_brick",
			"result_quantity": 1,
			"ingredients": [{"item_id": "stone", "quantity": 2}],
			"workbench_required": "workbench",
			"unlocked_by_default": true
		}
	]

	for recipe_data in default_recipes:
		var recipe := _create_recipe_from_dict(recipe_data)
		_recipes[recipe.id] = recipe
		if recipe.unlocked_by_default:
			_unlocked_recipes.append(recipe.id)

	_is_loaded = true
	print("[CraftingSystem] Created default recipes with %d entries" % _recipes.size())

## 获取配方
func get_recipe(recipe_id: String) -> Recipe:
	return _recipes.get(recipe_id, null)

## 检查配方是否存在
func has_recipe(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)

## 获取所有配方
func get_all_recipes() -> Array:
	return _recipes.values()

## 获取已解锁的配方
func get_unlocked_recipes() -> Array:
	var result := []
	for recipe_id in _unlocked_recipes:
		if _recipes.has(recipe_id):
			result.append(_recipes[recipe_id])
	return result

## 按类型获取配方
func get_recipes_by_category(category: int) -> Array:
	var result := []
	for recipe_id in _recipes:
		var recipe: Recipe = _recipes[recipe_id]
		if recipe.category == category:
			result.append(recipe)
	return result

## 按工作台类型获取配方
func get_recipes_by_workbench(workbench_type: String) -> Array:
	var result := []
	for recipe_id in _recipes:
		var recipe: Recipe = _recipes[recipe_id]
		if recipe.workbench_required == workbench_type:
			result.append(recipe)
	return result

## 获取无需工作台的配方
func get_portable_recipes() -> Array:
	var result := []
	for recipe_id in _recipes:
		var recipe: Recipe = _recipes[recipe_id]
		if recipe.workbench_required == "" and recipe.unlocked_by_default:
			result.append(recipe)
	return result

## 检查是否可以制作
func can_craft(recipe_id: String, check_inventory: bool = true) -> Dictionary:
	var result := {
		"can_craft": false,
		"missing_ingredients": [],
		"reason": ""
	}

	var recipe := get_recipe(recipe_id)
	if recipe == null:
		result.reason = "配方不存在"
		return result

	# 检查是否解锁
	if not is_recipe_unlocked(recipe_id):
		result.reason = "配方未解锁"
		return result

	# 检查材料
	if check_inventory:
		for ingredient in recipe.ingredients:
			var item_id: String = ingredient.get("item_id", "")
			var required: int = ingredient.get("quantity", 1)

			if _inventory == null:
				result.reason = "背包系统不可用"
				return result

			var have := _inventory.get_item_count(item_id)
			if have < required:
				result.missing_ingredients.append({
					"item_id": item_id,
					"required": required,
					"have": have
				})

		if result.missing_ingredients.size() > 0:
			result.reason = "材料不足"
			return result

	result.can_craft = true
	return result

## 检查配方是否解锁
func is_recipe_unlocked(recipe_id: String) -> bool:
	return _unlocked_recipes.has(recipe_id)

## 解锁配方
func unlock_recipe(recipe_id: String) -> bool:
	if not has_recipe(recipe_id):
		push_warning("[CraftingSystem] Cannot unlock unknown recipe: " + recipe_id)
		return false

	if is_recipe_unlocked(recipe_id):
		return true  # 已经解锁

	_unlocked_recipes.append(recipe_id)
	recipe_unlocked.emit(recipe_id)
	print("[CraftingSystem] Recipe unlocked: " + recipe_id)
	return true

## 制作物品
func craft(recipe_id: String, workbench_type: String = "") -> bool:
	var check_result := can_craft(recipe_id)
	if not check_result.can_craft:
		crafting_failed.emit(recipe_id, check_result.reason)
		push_warning("[CraftingSystem] Cannot craft %s: %s" % [recipe_id, check_result.reason])
		return false

	var recipe := get_recipe(recipe_id)

	# 检查工作台要求
	if recipe.workbench_required != "" and recipe.workbench_required != workbench_type:
		crafting_failed.emit(recipe_id, "需要工作台: " + recipe.workbench_required)
		return false

	# 消耗材料
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var quantity: int = ingredient.get("quantity", 1)
		_inventory.remove_item(item_id, quantity)

	# 添加结果物品
	var success := _inventory.add_item(recipe.result_item, recipe.result_quantity)

	if success:
		item_crafted.emit(recipe_id, recipe.result_item, recipe.result_quantity)
		print("[CraftingSystem] Crafted: %s x%d" % [recipe.result_item, recipe.result_quantity])
	else:
		# 如果添加失败，返还材料
		push_warning("[CraftingSystem] Failed to add result item, returning materials")
		for ingredient in recipe.ingredients:
			var item_id: String = ingredient.get("item_id", "")
			var quantity: int = ingredient.get("quantity", 1)
			_inventory.add_item(item_id, quantity)
		crafting_failed.emit(recipe_id, "背包空间不足")
		return false

	return true

## 批量制作
func craft_batch(recipe_id: String, count: int, workbench_type: String = "") -> int:
	var crafted := 0
	for i in count:
		if craft(recipe_id, workbench_type):
			crafted += 1
		else:
			break
	return crafted

## 获取可制作数量
func get_craftable_count(recipe_id: String) -> int:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		return 0

	if not is_recipe_unlocked(recipe_id):
		return 0

	var min_count := 999999
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var required: int = ingredient.get("quantity", 1)
		var have := _inventory.get_item_count(item_id)

		var craftable := have / required if required > 0 else 0
		min_count = mini(min_count, craftable)

	return min_count

## 获取配方材料信息（用于UI显示）
func get_ingredient_info(recipe_id: String) -> Array:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		return []

	var result := []
	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var required: int = ingredient.get("quantity", 1)
		var have := _inventory.get_item_count(item_id) if _inventory else 0

		var item_name := item_id
		if _item_database:
			var item := _item_database.get_item(item_id)
			if item:
				item_name = item.name

		result.append({
			"item_id": item_id,
			"item_name": item_name,
			"required": required,
			"have": have,
			"sufficient": have >= required
		})

	return result

## 获取存档数据
func get_save_data() -> Dictionary:
	return {
		"unlocked_recipes": _unlocked_recipes.duplicate()
	}

## 加载存档数据
func load_save_data(data: Dictionary) -> void:
	_unlocked_recipes.clear()
	var saved_recipes: Array = data.get("unlocked_recipes", [])
	for recipe_id in saved_recipes:
		if has_recipe(recipe_id):
			_unlocked_recipes.append(recipe_id)


func reset() -> void:
	_unlocked_recipes.clear()
	for recipe_id in _recipes:
		var recipe: Recipe = _recipes[recipe_id]
		if recipe.unlocked_by_default:
			_unlocked_recipes.append(recipe_id)

## 获取类型名称
func get_category_name(category: int) -> String:
	return RecipeCategory.keys()[category]
