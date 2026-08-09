extends GutTest

## TestInventory - 背包系统测试

var inventory: Inventory

func before_each() -> void:
	inventory = Inventory.new()
	add_child_autofree(inventory)
	inventory._initialize_slots()

func test_initial_state() -> void:
	assert_eq(inventory.get_empty_slot_count(), 36, "初始应该有36个空槽")
	
	var selected = inventory.get_selected_item_id()
	assert_eq(selected, "", "初始选中槽位应该为空")

func test_add_item() -> void:
	var result = inventory.add_item("turnip", 5)
	assert_true(result, "添加物品应该成功")
	assert_eq(inventory.get_item_count("turnip"), 5, "应该正确记录物品数量")

func test_add_multiple_items() -> void:
	inventory.add_item("turnip", 5)
	inventory.add_item("turnip", 3)
	assert_eq(inventory.get_item_count("turnip"), 8, "应该累加数量")

func test_remove_item() -> void:
	inventory.add_item("turnip", 10)
	var result = inventory.remove_item("turnip", 3)
	assert_true(result, "移除物品应该成功")
	assert_eq(inventory.get_item_count("turnip"), 7, "应该正确减少数量")

func test_has_item() -> void:
	inventory.add_item("turnip", 5)
	assert_true(inventory.has_item("turnip", 3), "应该有足够物品")
	assert_true(inventory.has_item("turnip", 5), "应该刚好足够")
	assert_false(inventory.has_item("turnip", 10), "应该不足")

func test_remove_more_than_have() -> void:
	inventory.add_item("turnip", 5)
	var result = inventory.remove_item("turnip", 10)
	assert_false(result, "移除超过拥有的数量应该失败")
	assert_eq(inventory.get_item_count("turnip"), 5, "数量应该不变")

func test_slot_operations() -> void:
	inventory.add_item("turnip", 5)
	
	var slot = inventory.get_slot(0)
	assert_not_null(slot, "应该能获取槽位")
	assert_eq(slot.item_id, "turnip", "槽位应该有物品")
	assert_eq(slot.quantity, 5, "槽位数量应该正确")

func test_clear_inventory() -> void:
	inventory.add_item("turnip", 5)
	inventory.add_item("potato", 3)
	
	inventory.clear_inventory()
	
	assert_eq(inventory.get_item_count("turnip"), 0, "清除后芜菁应该为0")
	assert_eq(inventory.get_item_count("potato"), 0, "清除后土豆应该为0")
	assert_eq(inventory.get_empty_slot_count(), 36, "应该有36个空槽")

func test_save_load() -> void:
	inventory.add_item("turnip", 5)
	inventory.add_item("potato", 3)
	
	var save_data = inventory.get_save_data()
	
	var new_inventory = Inventory.new()
	add_child_autofree(new_inventory)
	new_inventory.load_save_data(save_data)
	
	assert_eq(new_inventory.get_item_count("turnip"), 5, "加载后芜菁数量应该一致")
	assert_eq(new_inventory.get_item_count("potato"), 3, "加载后土豆数量应该一致")
