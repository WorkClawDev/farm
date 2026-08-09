extends GutTest

const SaveManagerScript := preload("res://src/autoload/SaveManager.gd")

func test_save_manager_rejects_invalid_slot() -> void:
	var save_manager = add_child_autofree(SaveManagerScript.new())

	assert_false(save_manager.save_game(-1), "Negative save slots should be rejected")
	assert_true(
		save_manager.load_snapshot(save_manager.MAX_SAVE_SLOTS).is_empty(),
		"Out-of-range load slots should be rejected"
	)
	assert_push_error_count(2, "Invalid slot checks should emit two push_error calls")


func test_save_manager_creates_and_deletes_save_file() -> void:
	var save_manager = add_child_autofree(SaveManagerScript.new())
	var slot: int = save_manager.MAX_SAVE_SLOTS - 1

	save_manager.delete_save(slot)
	assert_true(save_manager.save_game(slot), "SaveManager should save into a valid slot")
	assert_true(save_manager.has_save(slot), "Save file should exist after saving")

	var info = save_manager.get_save_info(slot)
	assert_true(info.get("exists", false), "Save info should report an existing save")
	assert_true(info.has("timestamp"), "Save info should include metadata")

	assert_true(save_manager.delete_save(slot), "SaveManager should delete an existing save")
	assert_false(save_manager.has_save(slot), "Save file should be removed after deletion")


func test_save_manager_formats_play_time() -> void:
	var save_manager = add_child_autofree(SaveManagerScript.new())
	save_manager._play_time = 3661.0

	assert_eq(save_manager.get_formatted_play_time(), "01:01:01", "Play time formatter should return HH:MM:SS")
