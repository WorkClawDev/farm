extends Node

const UI_SCENES := [
	"res://src/ui/menus/MainMenu.tscn",
	"res://src/ui/menus/SaveLoadMenu.tscn",
	"res://src/ui/menus/SettingsUI.tscn",
	"res://src/ui/menus/PauseMenu.tscn",
	"res://src/ui/menus/FarmJournal.tscn",
	"res://src/ui/menus/InventoryUI.tscn",
	"res://src/ui/menus/SeedShopUI.tscn",
	"res://src/ui/menus/ShopUI.tscn",
	"res://src/ui/menus/ShippingBinUI.tscn",
	"res://src/ui/menus/CookingUI.tscn",
	"res://src/ui/menus/AchievementUI.tscn",
	"res://src/ui/menus/FurnitureShopUI.tscn",
	"res://src/ui/menus/HouseUpgradeUI.tscn",
	"res://src/ui/menus/ToolUpgradeUI.tscn",
	"res://src/ui/dialogs/DialogueBox.tscn",
	"res://src/ui/hud/HUD.tscn",
	"res://src/ui/hud/HotkeyBar.tscn",
	"res://src/ui/hud/QuestTracker.tscn",
	"res://src/ui/hud/TimeDisplay.tscn",
	"res://src/ui/hud/ToolDisplay.tscn",
	"res://src/ui/hud/CombatHints.tscn",
	"res://src/ui/hud/HealthBar.tscn",
	"res://src/ui/minigames/FishingMinigame.tscn",
	"res://src/ui/effects/UpgradeAnimation.tscn",
	"res://src/ui/festival/FestivalNotificationPopup.tscn",
]

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("============================================================")
	print("田园物语 - UI 系统自动化测试")
	print("============================================================")
	await _test_theme()
	await _test_scene_coverage()
	await _test_modal_pause_and_focus()
	await _test_journal_lifecycle()
	await _test_open_close_same_frame()
	await _test_shipping_screen()
	await _test_shop_and_dialogue_pause_clock()
	await _test_cooking_screen()
	await _test_confirmation_pause()
	await _test_settings_validation()
	await _test_input_conflict()
	await _test_save_summaries()
	await _test_dialogue_long_text()
	await _test_toast_eviction_timers()
	await _test_pause_submenu_esc()
	await _test_pause_menu_first_direction()
	await _test_bug7_farm3_save_file()
	await _test_main_menu_down_does_not_activate()
	await _test_debug_launch_args()
	await _test_shop_keyboard_buy_and_scroll()
	print("============================================================")
	print("RESULTS: %d/%d passed" % [_passed, _passed + _failed])
	if _failed == 0:
		print("ALL UI TESTS PASSED")
	else:
		push_error("UI TESTS FAILED: %d" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)


func _test_theme() -> void:
	var theme := load("res://src/ui/theme/GameTheme.tres") as Theme
	_record("全局 GameTheme 可加载", theme != null)
	_record("主按钮主题变体存在", theme != null and theme.get_type_variation_base(&"PrimaryButton") == &"Button")
	_record("危险按钮主题变体存在", theme != null and theme.get_type_variation_base(&"DangerButton") == &"Button")
	_record("HUD 面板主题变体存在", theme != null and theme.get_type_variation_base(&"HUDPanel") == &"PanelContainer")


func _test_scene_coverage() -> void:
	var all_loaded := true
	for path in UI_SCENES:
		var scene := load(path) as PackedScene
		if scene == null:
			all_loaded = false
			print("  [DETAIL] 无法加载 ", path)
			continue
		var instance := scene.instantiate()
		if instance == null:
			all_loaded = false
		else:
			instance.free()
	_record("正式 UI 场景全部可加载实例化", all_loaded)

	var shop_scene := load("res://src/ui/menus/ShopUI.tscn") as PackedScene
	var shop_instance := shop_scene.instantiate() as Control
	UIThemeBridge.style_scene(shop_instance)
	_record("统一商店页面继承全局主题", shop_instance != null and shop_instance.theme != null)
	shop_instance.free()


func _test_modal_pause_and_focus() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var screen := await UIManager.open_screen("settings", {"pause_game": true})
	await get_tree().process_frame
	_record("UIManager 可打开主模态", screen != null and UIManager.is_screen_open("settings"))
	_record("主模态打开后游戏暂停", GameManager.current_state == GameManager.GameState.PAUSED and get_tree().paused and TimeManager.is_paused)
	_record("设置页存在可达焦点", get_viewport().gui_get_focus_owner() != null)
	var done_buttons := screen.find_children("*", "Button", true, false).filter(func(b): return b.text == "完成")
	_record("设置页“完成”是绿色主按钮（BUG-28）", done_buttons.size() == 1 and done_buttons[0].theme_type_variation == &"PrimaryButton")
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("最后模态关闭后恢复游戏", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not TimeManager.is_paused)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_journal_lifecycle() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	var original_tab := str(UserSettings.get_value("ui", "last_journal_tab", "inventory"))
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	UserSettings.set_value("ui", "last_journal_tab", "quests", false)
	var journal := await UIManager.open_screen("journal", {"pause_game": true}) as FarmJournal
	_record("手册恢复上次打开页签", journal != null and journal.get_active_tab_id() == "quests")
	_record("手册打开时时间暂停", TimeManager.is_paused)
	if journal:
		journal.close()
	await get_tree().process_frame
	_record("手册自行关闭会同步模态栈", not UIManager.is_screen_open("journal"))
	_record("手册关闭后恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not TimeManager.is_paused)

	var inventory_journal := await UIManager.open_screen("journal", {
		"pause_game": true,
		"tab": "inventory",
	}) as FarmJournal
	_record("背包快捷键语义固定打开背包页", inventory_journal != null and inventory_journal.get_active_tab_id() == "inventory")
	_record("背包打开时时间暂停", TimeManager.is_paused)
	var same_journal := await UIManager.open_screen("journal", {
		"tab": "crafting",
		"workbench_type": "workbench",
	}) as FarmJournal
	_record(
		"工作台可把已打开手册切换到对应制作页",
		same_journal == inventory_journal
			and same_journal.get_active_tab_id() == "crafting"
			and same_journal.get_active_workbench_type() == "workbench"
	)
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("背包关闭后时间继续", not TimeManager.is_paused and GameManager.current_state == GameManager.GameState.PLAYING)
	UserSettings.set_value("ui", "last_journal_tab", original_tab, false)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


## open_screen awaits one frame before focusing; a close in that same frame used
## to hand a freed screen to UIFactory.focus_first (SCRIPT ERROR in check.sh).
func _test_open_close_same_frame() -> void:
	var opened := [0]
	var on_opened := func(_id: String, _node: Control): opened[0] += 1
	UIManager.screen_opened.connect(on_opened)
	UIManager.open_screen("journal", {"pause_game": true})
	UIManager.close_all()
	for i in 3:
		await get_tree().process_frame
	UIManager.screen_opened.disconnect(on_opened)
	_record(
		"同帧打开又关闭界面：不再抢焦点、不发 screen_opened、不报错",
		opened[0] == 0 and not UIManager.is_screen_open("journal") and not get_tree().paused and not TimeManager.is_paused
	)


func _test_shipping_screen() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var screen := await UIManager.open_screen("shipping_bin", {"pause_game": true})
	_record("出货箱使用统一模态页面", screen != null and UIManager.is_screen_open("shipping_bin"))
	_record("出货箱打开时时间暂停", TimeManager.is_paused)
	_record("出货箱页面具备可达焦点", get_viewport().gui_get_focus_owner() != null)
	if screen:
		screen.close()
	await get_tree().process_frame
	_record("关闭出货箱会恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not TimeManager.is_paused)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_shop_and_dialogue_pause_clock() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	var old_paused := TimeManager.is_paused
	var old_count := TimeManager._pause_count
	var old_flags: Dictionary = DialogueManager._player_flags.duplicate()
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	TimeManager.is_paused = false
	TimeManager._pause_count = 0
	var shop := await UIManager.open_screen("shop", {"pause_game": true, "shop_id": "general_store"})
	_record("商店打开时时间暂停", shop != null and UIManager.is_screen_open("shop") and TimeManager.is_paused)
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("商店关闭后时间继续", not UIManager.is_screen_open("shop") and not TimeManager.is_paused and not get_tree().paused)
	var started := DialogueManager.start_dialogue("mayor")
	_record("对话打开时时间暂停", started and DialogueManager.is_in_dialogue() and TimeManager.is_paused)
	DialogueManager.force_end_dialogue()
	_record("对话关闭后时间继续", not DialogueManager.is_in_dialogue() and not TimeManager.is_paused)
	DialogueManager._player_flags = old_flags
	TimeManager.is_paused = old_paused
	TimeManager._pause_count = old_count
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_cooking_screen() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var screen := await UIManager.open_screen("cooking", {"pause_game": true}) as CookingUI
	await get_tree().process_frame
	_record("厨房使用统一模态页面", screen != null and UIManager.is_screen_open("cooking"))
	_record("烹饪页面打开时时间暂停", TimeManager.is_paused)
	_record("新档至少有三个基础食谱", screen != null and screen.get_recipe_count() >= 3)
	_record("烹饪页面具备可达焦点", get_viewport().gui_get_focus_owner() != null)
	if screen:
		screen.close()
	await get_tree().process_frame
	_record("关闭烹饪页面会恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not TimeManager.is_paused)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_confirmation_pause() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	UIManager.show_confirmation({
		"title": "测试确认框",
		"message": "确认框应独立持有暂停状态。",
	})
	_record("独立确认框会暂停游戏", GameManager.current_state == GameManager.GameState.PAUSED and get_tree().paused and TimeManager.is_paused)
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("关闭独立确认框会恢复游戏", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused and not TimeManager.is_paused)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_settings_validation() -> void:
	var original := float(UserSettings.get_value("display", "ui_scale", 1.0))
	UserSettings.set_value("display", "ui_scale", 9.0)
	_record("UI 缩放越界值按字段回退", is_equal_approx(float(UserSettings.get_value("display", "ui_scale")), 1.3))
	UserSettings.set_value("display", "ui_scale", original)
	var exported := UserSettings.export_data()
	_record("设置 schema 带版本号", int(exported.get("schema_version", 0)) == UserSettings.SCHEMA_VERSION)


func _test_input_conflict() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	var conflict := InputManager.find_binding_conflict(&"interact", event)
	_record("键位冲突可被检测", not conflict.is_empty())
	_record("冲突键位会被拒绝", not InputManager.remap_action(&"interact", event))
	_record("设备提示可读", not InputManager.get_action_prompt(&"interact").is_empty())
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_XBUTTON1
	var serialized_mouse := InputManager._deserialize_event({
		"type": "mouse_button",
		"button_index": MOUSE_BUTTON_XBUTTON1,
	})
	_record("鼠标键位可安全持久化", serialized_mouse is InputEventMouseButton and serialized_mouse.button_index == mouse_event.button_index)


func _test_save_summaries() -> void:
	var summaries := SaveManager.get_all_save_summaries()
	_record("存档摘要保持三个槽位", summaries.size() == SaveManager.MAX_SAVE_SLOTS)
	var latest := SaveManager.get_latest_save_info()
	_record("最近存档查询安全", latest is Dictionary)
	# saved_at is UTC unix time; the card shows local time (03:52 UTC = 11:52 in UTC+8).
	_record("存档时间按 UTC+8 显示为本地时间", UIStyles.format_timestamp(1792381920, 480) == "2026-10-19  11:52")
	_record("存档时间按 UTC 显示不变", UIStyles.format_timestamp(1792381920, 0) == "2026-10-19  03:52")
	_record("存档时间跨日换算正确（UTC-5）", UIStyles.format_timestamp(1792381920, -300) == "2026-10-18  22:52")
	var now_local := Time.get_datetime_dict_from_system()
	var now_text := UIStyles.format_timestamp(int(Time.get_unix_time_from_system()))
	print("[UI] save time now=%s system_local=%02d:%02d tz=%s" % [now_text, int(now_local.hour), int(now_local.minute), Time.get_time_zone_from_system()])
	_record("存档时间用系统时区（与本机时钟一致）", now_text.ends_with("%02d:%02d" % [int(now_local.hour), int(now_local.minute)]) or now_text.ends_with("%02d:%02d" % [int(now_local.hour), (int(now_local.minute) + 1) % 60]))


func _test_dialogue_long_text() -> void:
	var scene := load("res://src/ui/dialogs/DialogueBox.tscn") as PackedScene
	var dialogue := scene.instantiate() as DialogueBox
	add_child(dialogue)
	await get_tree().process_frame
	var long_text := "这是一段用于验证未来本地化扩展的长文本。".repeat(16)
	dialogue.show_dialogue("测试角色", [long_text])
	var key := InputManager.get_action_prompt(&"interact")
	var typing_hint := dialogue.continue_indicator.text
	_record("打字中只提示一次“%s 显示全文”（BUG-34）" % key, dialogue.is_typing and dialogue.continue_indicator.visible and typing_hint == "%s 显示全文" % key)
	dialogue._finish_typewriter()
	_record("显示完后只提示“%s 继续”（BUG-34）" % key, dialogue.continue_indicator.visible and dialogue.continue_indicator.text == "%s 继续" % key)
	_record("长对话可完整显示", dialogue.text_label.text.length() == long_text.length())
	dialogue.queue_free()
	await get_tree().process_frame


func _test_toast_eviction_timers() -> void:
	# BUG-10 cap evicts old toasts; their dismiss timers must fire quietly (no
	# "Cannot convert argument 1 from Object to Object" — check.sh fails on ERROR lines).
	for i in range(UIManager.MAX_VISIBLE_TOASTS + 4):
		UIManager.show_toast("toast eviction %d" % i)
	await get_tree().process_frame
	_record("Toast 上限挤掉旧提示", UIManager.get_visible_toast_count() == UIManager.MAX_VISIBLE_TOASTS)
	await get_tree().create_timer(UIManager.TOAST_DURATION + 0.6, true, false, true).timeout
	await get_tree().process_frame
	_record("被挤掉的 Toast 计时器到点后全部消失", UIManager.get_visible_toast_count() == 0)


func _press_esc() -> void:
	# Real key events through the viewport (Esc maps to both "pause" and "ui_cancel").
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		get_viewport().push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_pause_submenu_esc() -> void:
	# BUG-18: a sub-screen opened from the pause menu owns Esc; the pause menu
	# (a scene node, so it sees _unhandled_input before the UIManager autoload)
	# must not close/unpause underneath it.
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var pm := (load("res://src/ui/menus/PauseMenu.tscn") as PackedScene).instantiate() as PauseMenu
	pm.visible = false
	layer.add_child(pm)
	pm.resume_requested.connect(func():
		pm.visible = false
		GameManager.resume_game())
	await get_tree().process_frame
	GameManager.pause_game()
	pm.visible = true
	await get_tree().process_frame
	for sub in [["save_load", pm._open_save], ["settings", pm._open_settings]]:
		var sid: String = sub[0]
		(sub[1] as Callable).call()
		for i in 3:
			await get_tree().process_frame
		_record("暂停菜单打开子界面 %s" % sid, UIManager.is_screen_open(sid))
		await _press_esc()
		_record("子界面 %s 按 Esc 只关子界面" % sid, not UIManager.is_screen_open(sid))
		_record("子界面 %s 关后暂停菜单仍在且保持暂停" % sid, pm.visible and get_tree().paused and GameManager.is_paused())
	# BUG-19: Esc on a confirm opened from a sub-screen closes only the confirm.
	var sub_confirms := [
		["save_load", "覆盖存档", pm._open_save, func(scr): scr._confirm_overwrite(2, false)],
		["save_load", "删除存档", pm._open_save, func(scr): scr._on_delete_pressed(2)],
		["settings", "恢复默认", pm._open_settings, func(scr): scr._confirm_reset()],
	]
	for sc in sub_confirms:
		var sid2: String = sc[0]
		var what: String = sc[1]
		(sc[2] as Callable).call()
		for i in 3:
			await get_tree().process_frame
		(sc[3] as Callable).call(UIManager.get_screen(sid2))
		await get_tree().process_frame
		_record("%s确认框已弹出" % what, UIManager.has_open_confirmation() and UIManager.is_screen_open(sid2))
		await _press_esc()
		_record("%s确认框按 Esc 只关确认框，%s 仍开且暂停" % [what, sid2], not UIManager.has_open_confirmation() and UIManager.is_screen_open(sid2) and get_tree().paused)
		await _press_esc()
		_record("%s后再按 Esc 关 %s，暂停菜单仍在且暂停" % [what, sid2], not UIManager.is_screen_open(sid2) and pm.visible and get_tree().paused and GameManager.is_paused())
	pm._confirm_quit()
	await get_tree().process_frame
	await _press_esc()
	_record("确认框按 Esc 取消且暂停菜单仍在", not UIManager.has_open_modal() and pm.visible and get_tree().paused)
	await _press_esc()
	_record("再按 Esc 关闭暂停菜单并恢复", not pm.visible and not get_tree().paused)
	UIManager.close_all()
	layer.queue_free()
	await get_tree().process_frame
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


## Opening used to grab 继续 only after process_frame. Direction keys flushed
## before that frame did nothing, and a hitch could swallow a whole burst.
func _test_pause_menu_first_direction() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	var old_paused := get_tree().paused
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().paused = false
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	var stray := Button.new()
	stray.text = "STRAY"
	stray.custom_minimum_size = Vector2(200, 48)
	stray.position = Vector2(16, 900)
	layer.add_child(stray)
	var pm := (load("res://src/ui/menus/PauseMenu.tscn") as PackedScene).instantiate() as PauseMenu
	pm.visible = false
	pm.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pm)
	pm.resume_requested.connect(func():
		pm.visible = false
		GameManager.resume_game())
	await get_tree().process_frame
	GameManager.pause_game()
	pm.visible = true
	var opened_on_resume := get_viewport().gui_get_focus_owner() == pm._resume_button
	_tap_ui_key(KEY_DOWN)
	var save_button: Button = pm._menu_buttons[1] if pm._menu_buttons.size() > 1 else null
	var moved := get_viewport().gui_get_focus_owner() == save_button and save_button != null and save_button.text == "保存"
	await get_tree().process_frame
	await get_tree().process_frame
	var stayed := get_viewport().gui_get_focus_owner() == save_button
	_tap_ui_key(KEY_UP)
	var back_to_resume := get_viewport().gui_get_focus_owner() == pm._resume_button
	_tap_ui_key(KEY_LEFT)
	var stayed_on_left := get_viewport().gui_get_focus_owner() == pm._resume_button
	_tap_ui_key(KEY_RIGHT)
	var stayed_on_right := get_viewport().gui_get_focus_owner() == pm._resume_button
	var focus_ok := opened_on_resume and pm._resume_button.text == "继续" and moved and stayed and back_to_resume and stayed_on_left and stayed_on_right
	if not focus_ok:
		var owner := get_viewport().gui_get_focus_owner()
		var owner_text := ""
		if owner is Button:
			owner_text = (owner as Button).text
		else:
			owner_text = str(owner)
		push_error("pause-focus detail open=%s down=%s stay=%s up=%s left=%s right=%s now=%s" % [opened_on_resume, moved, stayed, back_to_resume, stayed_on_left, stayed_on_right, owner_text])
	_record("暂停菜单打开后焦点立刻在继续", opened_on_resume and pm._resume_button.text == "继续")
	_record("暂停菜单第一次 ui_down 从继续移到保存", moved and stayed)
	_record("暂停菜单第一次 ui_up / 左右不离开菜单", back_to_resume and stayed_on_left and stayed_on_right)
	await _press_esc()
	_record("暂停菜单方向键后 Esc 仍一次关闭并恢复", not pm.visible and not get_tree().paused and not GameManager.is_paused())
	if get_tree().paused or GameManager.is_paused():
		pm.visible = false
		get_tree().paused = false
		GameManager.current_state = GameManager.GameState.PLAYING
	layer.queue_free()
	await get_tree().process_frame
	get_tree().paused = old_paused
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _tap_ui_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev)


# BUG-7：选「农场 3」时日志是 Saved slot 2。槽从 0 计，农场 3 = 内部槽 2 = save_2.json。
# 农场 2 是 save_1.json。按下第三张卡必须只写第三槽，不能写到前一个农场。
# 只写临时目录，不读不写真实 user://saves/。
func _test_bug7_farm3_save_file() -> void:
	var prev_slot := SaveManager.get_current_slot()
	var prev_play := SaveManager.get_play_time()
	var prev_dir := SaveManager.save_dir
	var tmp_dir := "user://test_tmp_saves_%d_%d/" % [Time.get_ticks_usec(), randi()]
	SaveManager.save_dir = tmp_dir
	SaveManager._ensure_save_directory()
	var menu := (load("res://src/ui/menus/SaveLoadMenu.tscn") as PackedScene).instantiate() as SaveLoadMenu
	var empty_before := not SaveManager.has_save(0) and not SaveManager.has_save(1) and not SaveManager.has_save(2)
	var bound := -1
	var heading_ok := false
	if menu != null:
		menu.mode = SaveLoadMenu.Mode.SAVE
		add_child(menu)
		await get_tree().process_frame
		await get_tree().process_frame
		if menu._cards != null and menu._cards.get_child_count() >= 3 and menu._slot_buttons.size() >= 3:
			var heading := menu._cards.get_child(2).get_node("Content/Heading") as Label
			heading_ok = heading != null and heading.text == "农场 3"
			var action := menu._slot_buttons[2] as Button
			var conns: Array = action.pressed.get_connections()
			if not conns.is_empty():
				var cb: Callable = conns[0]["callable"]
				var args: Array = cb.get_bound_arguments()
				if not args.is_empty():
					bound = int(args[0])
			if heading_ok and empty_before:
				action.pressed.emit()
		menu.queue_free()
	var names := _list_file_names(tmp_dir)
	var wrote_third := names.size() == 1 and names[0] == "save_2.json" and FileAccess.file_exists(SaveManager.get_save_path(2))
	var wrote_other := FileAccess.file_exists(SaveManager.get_save_path(0)) or FileAccess.file_exists(SaveManager.get_save_path(1)) or FileAccess.file_exists(tmp_dir + "save_3.json")
	_remove_save_files(tmp_dir)
	_remove_empty_dir(tmp_dir.trim_suffix("/"))
	SaveManager.save_dir = prev_dir
	var tmp_abs := ProjectSettings.globalize_path(tmp_dir.trim_suffix("/"))
	var restored := SaveManager.save_dir == prev_dir and not DirAccess.dir_exists_absolute(tmp_abs)
	_record("农场 3 是第三张卡，按钮传入内部槽 2", heading_ok and bound == 2)
	_record(
		"选农场 3 只写入第三槽 save_2.json",
		empty_before and wrote_third and not wrote_other and SaveManager.get_current_slot() == 2
	)
	_record("BUG-7 测试删除了临时目录并还原存档根目录", restored)
	SaveManager.reset_session(prev_slot)
	SaveManager._play_time = prev_play


func _list_file_names(dir_path: String) -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return names
	for entry in dir.get_files():
		names.append(str(entry))
	return names


func _remove_save_files(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for name in names:
		dir.remove(name)


func _remove_empty_dir(dir_path: String) -> void:
	var parent := DirAccess.open("user://")
	if parent != null:
		parent.remove(dir_path.get_file())


const DebugLaunchScript = preload("res://src/core/debug/DebugLaunch.gd")


func _test_main_menu_down_does_not_activate() -> void:
	var prev_slot := SaveManager.get_current_slot()
	var prev_play := SaveManager.get_play_time()
	var prev_dir := SaveManager.save_dir
	var tmp_dir := "user://test_tmp_menu_nav_%d_%d/" % [Time.get_ticks_usec(), randi()]
	SaveManager.save_dir = tmp_dir
	SaveManager._ensure_save_directory()
	var no_save := await _exercise_menu_down(false)
	var with_save := await _exercise_menu_down(true)
	_remove_save_files(tmp_dir)
	_remove_empty_dir(tmp_dir.trim_suffix("/"))
	SaveManager.save_dir = prev_dir
	SaveManager.reset_session(prev_slot)
	SaveManager._play_time = prev_play
	UIManager.close_all()
	_record("主菜单按 ui_down 不触发任何按钮（无存档，跳过禁用项）", no_save)
	_record("主菜单按 ui_down 两次不进入游戏（有存档）", with_save)
	_record("主菜单方向键测试还原了存档目录", SaveManager.save_dir == prev_dir)


func _note_menu_press(hits: Array, button_name: String) -> void:
	hits.append(button_name)


func _exercise_menu_down(with_save: bool) -> bool:
	if with_save:
		SaveManager.reset_session(0)
		if not SaveManager.save_game(0):
			return false
	var state_before := GameManager.current_state
	var active_before := GameManager.is_game_active
	var menu := (load("res://src/ui/menus/MainMenu.tscn") as PackedScene).instantiate() as MainMenu
	var hits: Array = []
	add_child(menu)
	for button in menu.find_children("*", "Button", true, false):
		var btn := button as Button
		btn.pressed.connect(_note_menu_press.bind(hits, str(btn.name)))
	for i in 4:
		await get_tree().process_frame
	var focus_ok := true
	if with_save:
		focus_ok = _focus_name() == "ContinueBtn"
		await _press_ui_key(KEY_DOWN)
		focus_ok = focus_ok and _focus_name() == "NewGameBtn"
		await _press_ui_key(KEY_DOWN)
		focus_ok = focus_ok and _focus_name() == "LoadGameBtn"
		focus_ok = focus_ok and hits.is_empty()
	else:
		focus_ok = _focus_name() == "NewGameBtn"
		focus_ok = focus_ok and menu.load_button.focus_mode == Control.FOCUS_NONE
		await _press_ui_key(KEY_DOWN)
		focus_ok = focus_ok and _focus_name() == "SettingsBtn" and hits.is_empty()
		await _press_ui_key(KEY_DOWN)
		focus_ok = focus_ok and _focus_name() == "CreditsBtn" and hits.is_empty()
		await _press_ui_key(KEY_ENTER)
		await get_tree().process_frame
		focus_ok = focus_ok and hits.size() == 1 and str(hits[0]) == "CreditsBtn" and UIManager.has_open_confirmation()
		UIManager.close_all()
		await get_tree().process_frame
	var unchanged := GameManager.current_state == state_before and GameManager.is_game_active == active_before
	if not focus_ok or not unchanged:
		print("  [DETAIL] menu down with_save=", with_save, " focus=", _focus_name(), " hits=", hits, " state=", GameManager.current_state)
	menu.queue_free()
	await get_tree().process_frame
	return focus_ok and unchanged and not UIManager.has_open_modal()


func _press_ui_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _focus_name() -> String:
	var owner := get_viewport().gui_get_focus_owner()
	return owner.name if owner else ""


func _test_debug_launch_args() -> void:
	var parsed := DebugLaunchScript.parse(PackedStringArray(["--load-slot=3", "--spawn=village_west"]), true)
	var rejected := DebugLaunchScript.parse(PackedStringArray(["--load-slot=0", "--load-slot=4", "--load-slot=abc", "--spawn=nowhere"]), true)
	var release := DebugLaunchScript.parse(PackedStringArray(["--load-slot=3", "--spawn=village_west"]), false)
	var slot_one := DebugLaunchScript.parse(PackedStringArray(["--load-slot=1"]), true)
	var spec: Dictionary = DebugLaunchScript.spawn_spec("village_west")
	_record("命令行 --load-slot=3 是内部槽 2，spawn=village_west", int(parsed.get("slot", -2)) == 2 and str(parsed.get("spawn", "")) == "village_west")
	_record("--load-slot=1 是内部槽 0", int(slot_one.get("slot", -2)) == 0)
	_record("非法槽和未知 spawn 被忽略", int(rejected.get("slot", 0)) == -1 and str(rejected.get("spawn", "x")) == "")
	_record("非 debug 构建忽略 --load-slot 和 --spawn", int(release.get("slot", 0)) == -1 and str(release.get("spawn", "x")) == "")
	_record(
		"village_west 在村子西路、西出口东侧",
		str(spec.get("scene", "")) == "res://src/world/maps/Village.tscn"
			and str(spec.get("spawn_point", "")) == "village_west"
			and spec.get("position", Vector2.ZERO) == Vector2(150, 300)
	)
	_record("本测试进程没有 --load-slot，不会自动读档", int(DebugLaunchScript.from_cmdline().get("slot", 0)) == -1)

	var real_before := _list_file_names("user://saves/")
	var prev_slot := SaveManager.get_current_slot()
	var prev_play := SaveManager.get_play_time()
	var prev_dir := SaveManager.save_dir
	var prev_state := GameManager.current_state
	var prev_active := GameManager.is_game_active
	var tmp_dir := "user://test_tmp_dbgargs_%d_%d/" % [Time.get_ticks_usec(), randi()]
	SaveManager.save_dir = tmp_dir
	SaveManager._ensure_save_directory()
	SaveManager.reset_session(2)
	var wrote := SaveManager.save_game(2)
	var only_third := wrote and FileAccess.file_exists(SaveManager.get_save_path(2)) and not FileAccess.file_exists(SaveManager.get_save_path(0)) and not FileAccess.file_exists(SaveManager.get_save_path(1))
	# change_scene_to_file frees the current scene. Stay on root so this runner survives.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	var loaded: bool = await GameManager.load_game(int(parsed["slot"]), str(parsed["spawn"]))
	for i in 3:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var scene := get_tree().current_scene
	var placed := (
		loaded
		and scene != null
		and scene.name == "Village"
		and scene.scene_file_path == "res://src/world/maps/Village.tscn"
		and SaveManager.get_current_slot() == 2
		and GameManager.current_spawn_point == "village_west"
		and player != null
		and player.global_position.distance_to(Vector2(150, 300)) < 1.0
		and scene.name == "Village"
	)
	_remove_save_files(tmp_dir)
	_remove_empty_dir(tmp_dir.trim_suffix("/"))
	SaveManager.save_dir = prev_dir
	var real_after := _list_file_names("user://saves/")
	var tmp_abs := ProjectSettings.globalize_path(tmp_dir.trim_suffix("/"))
	_record("临时目录写入第三槽后 --load-slot=3 --spawn=village_west 把玩家放到村西", only_third and placed)
	_record(
		"调试读档只用了临时 save_dir，真实 user://saves/ 未改动",
		SaveManager.save_dir == prev_dir and real_before == real_after and not DirAccess.dir_exists_absolute(tmp_abs)
	)
	SaveManager.reset_session(prev_slot)
	SaveManager._play_time = prev_play
	GameManager.is_game_active = prev_active
	GameManager.current_state = prev_state


## BUG-S1: Tab/方向键要能走到商品、数量、购买、关闭。
## BUG-S2: 焦点移到视口外的一行时，列表要滚到那一行。
func _test_shop_keyboard_buy_and_scroll() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	var saved_time := TimeManager.current_time
	var saved_day := TimeManager.current_day
	var saved_season := TimeManager.current_season
	var money_before := MoneySystem.get_money()
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	TimeManager.current_time = 10.0
	TimeManager.current_day = 10
	TimeManager.current_season = 0
	var paused_before := TimeManager.is_paused
	var shop := await UIManager.open_screen("shop", {"pause_game": true, "shop_id": "seed_shop"}) as ShopUI
	for _i in 4:
		await get_tree().process_frame
	var items: Array[Button] = []
	if shop != null:
		for button in shop._item_buttons:
			items.append(button)
	var listed_fiber := false
	for button in items:
		if str(button.get_meta("shop_item_id", "")) == "fiber_seeds":
			listed_fiber = true
	_record("种子店键盘列表里没有纤维种子", shop != null and items.size() >= 2 and not listed_fiber)
	var scroll: ScrollContainer = shop._list_scroll if shop != null else null
	_record("商品列表会跟随焦点滚动", scroll != null and scroll.follow_focus)
	var scrolled := false
	var row_visible := false
	if scroll != null and items.size() >= 2:
		var box := scroll.get_child(0) as VBoxContainer
		var probe := Control.new()
		probe.name = "ScrollProbe"
		probe.custom_minimum_size = Vector2(10, 2400)
		probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(probe)
		box.move_child(probe, 0)
		for _i in 3:
			await get_tree().process_frame
		scroll.scroll_vertical = 0
		items[items.size() - 1].grab_focus()
		for _i in 3:
			await get_tree().process_frame
		scrolled = int(scroll.scroll_vertical) > 0
		row_visible = _row_inside_scroll(scroll, items[items.size() - 1])
		if not scrolled or not row_visible:
			print("  [DETAIL] scroll_v=", scroll.scroll_vertical, " scroll_size=", scroll.size, " row=", _row_rect(items[items.size() - 1]))
		probe.queue_free()
		scroll.scroll_vertical = 0
		await get_tree().process_frame
	_record("焦点移到列表下方时滚动条跟着走，选中行仍在视口里", scrolled and row_visible)

	var bought_id := ""
	var bought_before := 0
	var path_ok := false
	if shop != null and items.size() >= 2 and scroll != null:
		var close_button: Button = shop._close_button
		close_button.grab_focus()
		await get_tree().process_frame
		var on_item := false
		for _step in 6:
			await _press_ui_key(KEY_TAB)
			if _focus_name().begins_with("ShopItem_"):
				on_item = true
				break
		var first_name := str(items[0].name)
		on_item = on_item and _focus_name() == first_name
		await _press_ui_key(KEY_DOWN)
		var moved_down := _focus_name() == str(items[1].name)
		await _press_ui_key(KEY_UP)
		var moved_up := _focus_name() == first_name
		await _press_ui_key(KEY_ENTER)
		await get_tree().process_frame
		var selected := shop.selected_item_id == str(items[0].get_meta("shop_item_id", "")) and not shop._confirm.disabled
		await _press_ui_key(KEY_RIGHT)
		await get_tree().process_frame
		var on_qty := shop._is_quantity_focus(get_viewport().gui_get_focus_owner())
		await _press_ui_key(KEY_UP)
		await get_tree().process_frame
		var qty_ok := int(shop._quantity.value) == 2 and shop.selected_quantity == 2
		await _press_ui_key(KEY_TAB)
		await get_tree().process_frame
		var on_buy := _focus_name() == "ShopConfirm" and shop._confirm.text == "购买"
		bought_id = shop.selected_item_id
		bought_before = Inventory.get_item_count(bought_id)
		await _press_ui_key(KEY_ENTER)
		for _i in 3:
			await get_tree().process_frame
		var bought := Inventory.get_item_count(bought_id) == bought_before + 2 and MoneySystem.get_money() < money_before
		await _press_ui_key(KEY_TAB)
		await get_tree().process_frame
		var on_close := _focus_name() == "ShopClose"
		await _press_ui_key(KEY_ENTER)
		for _i in 3:
			await get_tree().process_frame
		var closed := not UIManager.is_screen_open("shop") and TimeManager.is_paused == paused_before
		path_ok = on_item and moved_down and moved_up and selected and on_qty and qty_ok and on_buy and bought and on_close and closed
		if not path_ok:
			print("  [DETAIL] shop keys item=", on_item, " down=", moved_down, " up=", moved_up, " selected=", selected, " qty=", on_qty, " qty2=", qty_ok, " buy=", on_buy, " bought=", bought, " close=", on_close, " closed=", closed, " focus=", _focus_name(), " id=", bought_id)
	_record("键盘可以选商品、改数量、购买并关闭种子店", path_ok)

	if UIManager.is_screen_open("shop"):
		UIManager.close_all()
		await get_tree().process_frame
	if bought_id != "":
		var extra := Inventory.get_item_count(bought_id) - bought_before
		if extra > 0:
			Inventory.remove_item(bought_id, extra)
	var money_delta := MoneySystem.get_money() - money_before
	if money_delta > 0:
		MoneySystem.spend_money(money_delta, MoneySystem.ExpenseType.OTHER, "shop_key_test_restore")
	elif money_delta < 0:
		MoneySystem.add_money(-money_delta, MoneySystem.IncomeSource.OTHER, "shop_key_test_restore")
	TimeManager.current_time = saved_time
	TimeManager.current_day = saved_day
	TimeManager.current_season = saved_season
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state
	_record("商店键盘测试还原金币", MoneySystem.get_money() == money_before)


func _row_inside_scroll(scroll: ScrollContainer, button: Control) -> bool:
	var row := button.get_parent() as Control
	var target := row if row != null else button
	if scroll.size.y <= 1.0 or target.size.y <= 1.0:
		return false
	var view := Rect2(scroll.global_position, scroll.size)
	var rect := Rect2(target.global_position, target.size)
	return view.encloses(rect)


func _row_rect(button: Control) -> Rect2:
	var row := button.get_parent() as Control
	var target := row if row != null else button
	return Rect2(target.global_position, target.size)


func _record(label: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
