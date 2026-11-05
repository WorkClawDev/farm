extends GutTest

const TimeManagerScript := preload("res://src/autoload/TimeManager.gd")

func test_time_manager_starts_at_expected_defaults() -> void:
	var time_manager = add_child_autofree(TimeManagerScript.new())

	assert_eq(time_manager.current_time, 9.0, "TimeManager should start at 9:00")
	assert_eq(time_manager.current_day, 1, "TimeManager should start on day 1")
	assert_eq(time_manager.get_season_name(), "Spring", "TimeManager should start in Spring")


func test_time_manager_can_advance_day_and_season() -> void:
	var time_manager = add_child_autofree(TimeManagerScript.new())

	time_manager.current_time = 26.0
	time_manager._advance_day()
	assert_eq(time_manager.current_time, 6.0, "Advancing day should reset time to 6:00")
	assert_eq(time_manager.current_day, 2, "Advancing day should increment the day")

	time_manager.current_day = time_manager.DAYS_PER_SEASON
	time_manager.current_season = 0
	time_manager.current_time = 26.0
	time_manager._advance_day()
	assert_eq(time_manager.current_day, 1, "Season rollover should reset day to 1")
	assert_eq(time_manager.current_season, 1, "Season rollover should advance the season")
	assert_eq(time_manager.get_season_name(), "Summer", "Season rollover should move to Summer")


func test_time_manager_save_and_load_round_trip() -> void:
	var time_manager = add_child_autofree(TimeManagerScript.new())
	time_manager.current_time = 14.5
	time_manager.current_day = 7
	time_manager.current_season = 2
	time_manager.current_year = 3

	var saved = time_manager.save_state()

	var restored = add_child_autofree(TimeManagerScript.new())
	restored.load_state(saved)

	assert_eq(restored.current_time, 14.5, "Loaded time should match saved time")
	assert_eq(restored.current_day, 7, "Loaded day should match saved day")
	assert_eq(restored.current_season, 2, "Loaded season should match saved season")
	assert_eq(restored.current_year, 3, "Loaded year should match saved year")
