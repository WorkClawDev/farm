extends GutTest

## TestCookingSystem - 烹饪系统测试

var cooking_system: CookingSystem

func before_each() -> void:
	cooking_system = CookingSystem.new()
	add_child_autofree(cooking_system)
	cooking_system._create_default_recipes()

func test_load_recipes() -> void:
	var recipes = cooking_system.get_all_recipes()
	assert_gt(recipes.size(), 0, "应该加载至少一个配方")

func test_get_recipe() -> void:
	var recipe = cooking_system.get_recipe("fried_egg")
	assert_not_null(recipe, "应该能获取煎蛋配方")
	assert_eq(recipe.name, "煎蛋", "配方名称应该正确")

func test_learn_recipe() -> void:
	var result = cooking_system.learn_recipe("fried_egg")
	assert_true(result, "学习配方应该成功")
	assert_true(cooking_system.is_recipe_learned("fried_egg"), "配方应该已学习")

func test_learn_same_recipe_twice() -> void:
	cooking_system.learn_recipe("fried_egg")
	var result = cooking_system.learn_recipe("fried_egg")
	assert_false(result, "重复学习应该返回false")

func test_get_learned_recipes() -> void:
	cooking_system.learn_recipe("fried_egg")
	var learned = cooking_system.get_learned_recipes()
	assert_eq(learned.size(), 1, "应该有一个已学习配方")

func test_unlock_starting_recipes() -> void:
	cooking_system.unlock_starting_recipes()
	var learned = cooking_system.get_learned_recipes()
	assert_gt(learned.size(), 0, "应该解锁初始配方")

func test_save_load_learned_recipes() -> void:
	cooking_system.learn_recipe("fried_egg")
	
	var save_data = cooking_system.get_save_data()
	
	var new_system = CookingSystem.new()
	add_child_autofree(new_system)
	new_system._create_default_recipes()
	new_system.load_save_data(save_data)
	
	assert_true(new_system.is_recipe_learned("fried_egg"), "加载后配方应该已学习")
