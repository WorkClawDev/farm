extends GutTest

## TestTimeManager - 时间管理器测试

var time_manager: TimeManager

func before_each() -> void:
	time_manager = TimeManager.new()
	add_child_autofree(time_manager)

func after_each() -> void:
	pass

func test_initial_time() -> void:
	assert_eq(time_manager.current_time, 9.0, "初始时间应该是早上9点")
	assert_eq(time_manager.current_day, 1, "初始日期应该是第1天")
	assert_eq(time_manager.current_season, 0, "初始季节应该是春季")
	assert_eq(time_manager.current_year, 1, "初始年份应该是第1年")

func test_time_formatting() -> void:
	var formatted = time_manager.get_formatted_time()
	assert_ne(formatted, "", "时间格式化应该返回非空字符串")
	
	var date_formatted = time_manager.get_formatted_date()
	assert_ne(date_formatted, "", "日期格式化应该返回非空字符串")
	assert_string_contains(date_formatted, "Year", "日期格式应该包含Year")

func test_season_names() -> void:
	assert_eq(time_manager.get_season_name(), "Spring", "季节0应该是Spring")
	
	# 测试其他季节
	time_manager.current_season = 1
	assert_eq(time_manager.get_season_name(), "Summer", "季节1应该是Summer")
	
	time_manager.current_season = 2
	assert_eq(time_manager.get_season_name(), "Fall", "季节2应该是Fall")
	
	time_manager.current_season = 3
	assert_eq(time_manager.get_season_name(), "Winter", "季节3应该是Winter")

func test_pause_resume() -> void:
	assert_false(time_manager.is_paused, "初始状态应该未暂停")
	
	time_manager.pause_time()
	assert_true(time_manager.is_paused, "暂停后应该为true")
	
	time_manager.resume_time()
	assert_false(time_manager.is_paused, "恢复后应该为false")

func test_save_load_state() -> void:
	# 设置一些状态
	time_manager.current_time = 12.5
	time_manager.current_day = 15
	time_manager.current_season = 2
	time_manager.current_year = 2
	
	# 保存状态
	var state = time_manager.save_state()
	
	# 创建新的管理器并加载
	var new_manager = TimeManager.new()
	add_child_autofree(new_manager)
	new_manager.load_state(state)
	
	# 验证状态
	assert_eq(new_manager.current_time, 12.5, "加载后时间应该一致")
	assert_eq(new_manager.current_day, 15, "加载后天数应该一致")
	assert_eq(new_manager.current_season, 2, "加载后季节应该一致")
	assert_eq(new_manager.current_year, 2, "加载后年份应该一致")
