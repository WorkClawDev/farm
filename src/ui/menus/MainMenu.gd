extends Control
class_name MainMenu

const DebugLaunchScript = preload("res://src/core/debug/DebugLaunch.gd")

const SEASON_BACKGROUNDS := [
	preload("res://assets/ui/backgrounds/menu_spring.png"),
	preload("res://assets/ui/backgrounds/menu_summer.png"),
	preload("res://assets/ui/backgrounds/menu_autumn.png"),
	preload("res://assets/ui/backgrounds/menu_winter.png"),
]

const SEASON_LINES := [
	"春日的农场正等你回家",
	"盛夏的田野闪着金光",
	"丰收季里有新的故事",
	"冬雪覆盖着温暖的家",
]

@onready var background: TextureRect = $Background
@onready var brand_backdrop: PanelContainer = $SafeArea/Layout/BrandBackdrop
@onready var brand_column: VBoxContainer = $SafeArea/Layout/BrandColumn
@onready var title_label: Label = $SafeArea/Layout/BrandColumn/Title
@onready var subtitle_label: Label = $SafeArea/Layout/BrandColumn/Subtitle
@onready var menu_card: PanelContainer = $SafeArea/Layout/MenuCard
@onready var season_note: Label = $SafeArea/Layout/BrandColumn/SeasonNote
@onready var save_summary: Label = $SafeArea/Layout/MenuCard/Menu/SaveSummary
@onready var continue_button: Button = $SafeArea/Layout/MenuCard/Menu/ContinueBtn
@onready var new_game_button: Button = $SafeArea/Layout/MenuCard/Menu/NewGameBtn
@onready var load_button: Button = $SafeArea/Layout/MenuCard/Menu/LoadGameBtn
@onready var settings_button: Button = $SafeArea/Layout/MenuCard/Menu/SettingsBtn
@onready var credits_button: Button = $SafeArea/Layout/MenuCard/Menu/CreditsBtn
@onready var quit_button: Button = $SafeArea/Layout/MenuCard/Menu/QuitBtn
@onready var version_label: Label = $VersionLabel

var _latest_save: Dictionary = {}
var _transitioning := false


func _ready() -> void:
	print("[MainMenu] Ready")
	var launch := DebugLaunchScript.from_cmdline()
	if bool(launch.get("new_game", false)):
		_boot_debug_new_game()
		return
	if int(launch.get("slot", -1)) >= 0:
		_boot_debug_launch(launch)
		return
	_setup_menu()


func _boot_debug_new_game() -> void:
	DebugLaunchScript.apply_debug_new_game_save_dir()
	print("[DebugLaunch] --new-game save_dir=%s" % SaveManager.save_dir)
	await GameManager.start_new_game(0)


func _boot_debug_launch(launch: Dictionary) -> void:
	var slot := int(launch["slot"])
	var spawn := str(launch.get("spawn", ""))
	print("[DebugLaunch] --load-slot=%d (slot %d) spawn=%s" % [slot + 1, slot, spawn])
	var loaded: bool = await GameManager.load_game(slot, spawn)
	if not is_inside_tree():
		return
	if loaded:
		return
	_setup_menu()


func _setup_menu() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for art_directed_node in [brand_backdrop, title_label, subtitle_label, season_note]:
		art_directed_node.set_meta("preserve_theme_overrides", true)
	add_to_group("themed_ui_root")
	refresh_theme()
	_apply_localized_text()
	_refresh_save_state()
	_connect_buttons()
	if not $SafeArea/Layout.resized.is_connected(_apply_main_layout):
		$SafeArea/Layout.resized.connect(_apply_main_layout)
	_initialize_main_layout()


func _menu_buttons() -> Array[Button]:
	return [
		continue_button, new_game_button, load_button,
		settings_button, credits_button, quit_button,
	]


func _focusable_menu_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in _menu_buttons():
		if button.visible and not button.disabled:
			result.append(button)
	return result


## Disabled and hidden entries are FOCUS_NONE. A disabled "读取进度" used to stay
## FOCUS_ALL, so the first Down landed on it instead of the next real button.
func _wire_menu_focus() -> void:
	var buttons := _focusable_menu_buttons()
	for button in _menu_buttons():
		var enabled := button.visible and not button.disabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.focus_neighbor_left = NodePath()
		button.focus_neighbor_right = NodePath()
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
	for i in buttons.size():
		if i == 0:
			buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i])
		else:
			buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i - 1])
		if i == buttons.size() - 1:
			buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[i])
		else:
			buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[i + 1])


## Down is both ui_down and move_down. Handle it before Button.gui_input so a
## navigation key cannot activate the focused button. ui_accept is left alone.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or UIManager.has_open_modal():
		return
	if event is InputEventJoypadMotion:
		return
	if not (event.is_action("ui_down") or event.is_action("ui_up")):
		return
	if event.is_pressed():
		_move_menu_focus(1 if event.is_action("ui_down") else -1)
	get_viewport().set_input_as_handled()


func _move_menu_focus(delta: int) -> void:
	var buttons := _focusable_menu_buttons()
	if buttons.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := buttons.find(current)
	if index < 0:
		index = 0 if delta > 0 else buttons.size() - 1
	else:
		index = clampi(index + delta, 0, buttons.size() - 1)
	if buttons[index] != current:
		buttons[index].grab_focus()


func _initialize_main_layout() -> void:
	await get_tree().process_frame
	_apply_main_layout()
	_play_intro()


func _apply_main_layout() -> void:
	var available := ($SafeArea/Layout as Control).size
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var brand_size := Vector2(
		minf(available.x * 0.48, 560.0),
		minf(available.y * 0.58, 380.0)
	)
	var brand_position := Vector2(
		available.x * 0.05,
		(available.y - brand_size.y) * 0.5
	)
	brand_backdrop.position = brand_position
	brand_backdrop.size = brand_size
	brand_column.position = brand_position + Vector2(28, 20)
	brand_column.size = brand_size - Vector2(56, 40)
	menu_card.position = Vector2(available.x * 0.67, available.y * 0.02)
	menu_card.size = Vector2(available.x * 0.33, available.y * 0.96)


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func _apply_localized_text() -> void:
	$SafeArea/Layout/BrandColumn/Title.text = UIStyles.tr_key("ui.game.title", "田园物语")
	$SafeArea/Layout/BrandColumn/Subtitle.text = "P A S T O R A L   T A L E S"
	continue_button.text = UIStyles.tr_key("ui.main.continue", "继续游戏")
	new_game_button.text = UIStyles.tr_key("ui.main.new_game", "创建农场")
	load_button.text = UIStyles.tr_key("ui.main.load", "读取进度")
	settings_button.text = UIStyles.tr_key("ui.main.settings", "设置")
	credits_button.text = UIStyles.tr_key("ui.main.credits", "制作人员")
	quit_button.text = UIStyles.tr_key("ui.main.quit", "退出游戏")
	version_label.text = UIStyles.tr_key("ui.main.version", "版本 0.3 · 界面焕新")


func _refresh_save_state() -> void:
	_latest_save = SaveManager.get_latest_save_info()
	var has_save := not _latest_save.is_empty()
	continue_button.visible = has_save
	load_button.disabled = not SaveManager.has_any_save()
	var season := clampi(int(_latest_save.get("season", 0)), 0, 3)
	background.texture = SEASON_BACKGROUNDS[season]
	season_note.text = SEASON_LINES[season]
	if has_save:
		var season_names := ["春", "夏", "秋", "冬"]
		var date_text := "第 %d 年 · %s季第 %d 天" % [
			int(_latest_save.get("year", 1)),
			season_names[season],
			int(_latest_save.get("day", 1)),
		]
		save_summary.text = "%s · %s\n%s  ·  %s" % [
			UIStyles.tr_key("ui.main.latest_save", "最近的农场"),
			date_text,
			str(_latest_save.get("location", "农场")),
			UIStyles.format_play_time(float(_latest_save.get("play_time", 0.0))),
		]
	else:
		save_summary.text = UIStyles.tr_key("ui.main.no_save", "还没有农场记录")
	_wire_menu_focus()
	# UIThemeBridge queued style at node_added, before this _ready. Re-apply
	# after that deferred pass so a disabled "读取进度" stays FOCUS_NONE.
	call_deferred("_wire_menu_focus")
	await get_tree().process_frame
	var initial := continue_button if has_save else new_game_button
	if is_instance_valid(initial) and initial.focus_mode != Control.FOCUS_NONE:
		initial.grab_focus()


func _connect_buttons() -> void:
	continue_button.pressed.connect(_continue_latest)
	new_game_button.pressed.connect(_open_new_game)
	load_button.pressed.connect(_open_load)
	settings_button.pressed.connect(_open_settings)
	credits_button.pressed.connect(_show_credits)
	quit_button.pressed.connect(_confirm_quit)


func _continue_latest() -> void:
	if _transitioning:
		return
	var slot := SaveManager.get_latest_save_slot()
	if slot < 0:
		_refresh_save_state()
		return
	_transitioning = true
	GameManager.load_game(slot)


func _open_new_game() -> void:
	var screen := await UIManager.open_screen("save_load", {
		"pause_game": false,
		"mode": SaveLoadMenu.Mode.NEW_GAME,
	})
	if screen and screen.has_signal("menu_closed"):
		screen.menu_closed.connect(_refresh_save_state, CONNECT_ONE_SHOT)


func _open_load() -> void:
	await UIManager.open_screen("save_load", {
		"pause_game": false,
		"mode": SaveLoadMenu.Mode.LOAD,
	})


func _open_settings() -> void:
	await UIManager.open_screen("settings", {"pause_game": false})


func _show_credits() -> void:
	UIManager.show_confirmation({
		"title": "ui.credits.title",
		"message": "ui.credits.body",
		"confirm_key": "ui.common.close",
	})


func _confirm_quit() -> void:
	UIManager.show_confirmation({
		"title": "ui.main.quit",
		"message": "ui.pause.quit_confirm",
		"danger": true,
		"confirm_key": "ui.main.quit",
		"on_confirm": get_tree().quit,
	})


func _play_intro() -> void:
	if UserSettings.get_value("accessibility", "reduce_motion", false):
		return
	brand_column.modulate.a = 0.0
	brand_backdrop.modulate.a = 0.0
	menu_card.modulate.a = 0.0
	menu_card.position.x += 24.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(brand_column, "modulate:a", 1.0, 0.32)
	tween.tween_property(brand_backdrop, "modulate:a", 1.0, 0.32)
	tween.tween_property(menu_card, "modulate:a", 1.0, 0.32).set_delay(0.08)
	tween.tween_property(menu_card, "position:x", menu_card.position.x - 24.0, 0.32).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
