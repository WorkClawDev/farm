extends GutTest


func test_inventory_manager_add_and_stack_items() -> void:
	var inventory_manager = add_child_autofree(InventoryManager.new())

	assert_true(inventory_manager.add_item("turnip", 2), "Should add a new item stack")
	assert_true(inventory_manager.add_item("turnip", 3), "Should stack identical items")
	assert_eq(inventory_manager.get_item_quantity("turnip"), 5, "Stacked quantity should be tracked")


func test_inventory_manager_remove_items_and_clear_stack() -> void:
	var inventory_manager = add_child_autofree(InventoryManager.new())
	inventory_manager.add_item("wood", 4)

	assert_true(inventory_manager.remove_item("wood", 1), "Should remove part of a stack")
	assert_eq(inventory_manager.get_item_quantity("wood"), 3, "Partial remove should leave remaining quantity")
	assert_true(inventory_manager.remove_item("wood", 3), "Should remove the rest of a stack")
	assert_false(inventory_manager.has_item("wood"), "Removing the full stack should clear the item")


func test_inventory_manager_save_and_load_round_trip() -> void:
	var inventory_manager = add_child_autofree(InventoryManager.new())
	inventory_manager.add_item("stone", 9)
	inventory_manager.add_item("fiber", 2)

	var saved = inventory_manager.save_state()

	var restored = add_child_autofree(InventoryManager.new())
	restored.load_state(saved)

	assert_eq(restored.get_item_quantity("stone"), 9, "Loaded inventory should contain saved stone quantity")
	assert_eq(restored.get_item_quantity("fiber"), 2, "Loaded inventory should contain saved fiber quantity")
