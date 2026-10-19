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
	await _test_shipping_screen()
	await _test_cooking_screen()
	await _test_confirmation_pause()
	await _test_settings_validation()
	await _test_input_conflict()
	await _test_save_summaries()
	await _test_dialogue_long_text()
	await _test_toast_eviction_timers()
	await _test_pause_submenu_esc()
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
	_record("主模态打开后游戏暂停", GameManager.current_state == GameManager.GameState.PAUSED and get_tree().paused)
	_record("设置页存在可达焦点", get_viewport().gui_get_focus_owner() != null)
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("最后模态关闭后恢复游戏", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused)
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
	if journal:
		journal.close()
	await get_tree().process_frame
	_record("手册自行关闭会同步模态栈", not UIManager.is_screen_open("journal"))
	_record("手册关闭后恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused)

	var inventory_journal := await UIManager.open_screen("journal", {
		"pause_game": true,
		"tab": "inventory",
	}) as FarmJournal
	_record("背包快捷键语义固定打开背包页", inventory_journal != null and inventory_journal.get_active_tab_id() == "inventory")
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
	UserSettings.set_value("ui", "last_journal_tab", original_tab, false)
	GameManager.is_game_active = old_active
	GameManager.current_state = old_state


func _test_shipping_screen() -> void:
	var old_active := GameManager.is_game_active
	var old_state := GameManager.current_state
	GameManager.is_game_active = true
	GameManager.current_state = GameManager.GameState.PLAYING
	var screen := await UIManager.open_screen("shipping_bin", {"pause_game": true})
	_record("出货箱使用统一模态页面", screen != null and UIManager.is_screen_open("shipping_bin"))
	_record("出货箱页面具备可达焦点", get_viewport().gui_get_focus_owner() != null)
	if screen:
		screen.close()
	await get_tree().process_frame
	_record("关闭出货箱会恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused)
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
	_record("新档至少有三个基础食谱", screen != null and screen.get_recipe_count() >= 3)
	_record("烹饪页面具备可达焦点", get_viewport().gui_get_focus_owner() != null)
	if screen:
		screen.close()
	await get_tree().process_frame
	_record("关闭烹饪页面会恢复游戏时间", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused)
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
	_record("独立确认框会暂停游戏", GameManager.current_state == GameManager.GameState.PAUSED and get_tree().paused)
	UIManager.close_top_screen()
	await get_tree().process_frame
	_record("关闭独立确认框会恢复游戏", GameManager.current_state == GameManager.GameState.PLAYING and not get_tree().paused)
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


func _test_dialogue_long_text() -> void:
	var scene := load("res://src/ui/dialogs/DialogueBox.tscn") as PackedScene
	var dialogue := scene.instantiate() as DialogueBox
	add_child(dialogue)
	await get_tree().process_frame
	var long_text := "这是一段用于验证未来本地化扩展的长文本。".repeat(16)
	dialogue.show_dialogue("测试角色", [long_text])
	dialogue._finish_typewriter()
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


func _record(label: String, passed: bool) -> void:
	if passed:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
