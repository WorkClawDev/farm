extends Control
class_name PauseMenu

## PauseMenu - 暂停菜单
## 提供游戏暂停时的菜单选项

signal resume_requested
signal save_requested
signal load_requested
signal quit_to_menu_requested
signal quit_game_requested

# 节点引用
var main_vbox: VBoxContainer
var title_label: Label
var resume_button: Button
var save_button: Button
var load_button: Button
var settings_button: Button
var quit_button: Button

# 存档菜单引用
var save_load_menu: SaveLoadMenu = null
var settings_ui: SettingsUI = null

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	settings_ui = preload("res://src/ui/menus/SettingsUI.tscn").instantiate()
	settings_ui.settings_closed.connect(_on_settings_ui_closed)
	add_child(settings_ui)

func _setup_ui() -> void:
	# 设置背景
	# 使用面板容器作为背景
	var panel := Panel.new()
	panel.name = "BackgroundPanel"
	panel.anchor_right = 1.0
	panel.bottom = 1.0
	panel.modulate = Color(0, 0, 0, 0.5)
	add_child(panel)

	# 主容器
	main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(main_vbox)

	# 标题
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "游戏暂停"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	main_vbox.add_child(title_label)

	# 分隔
	_add_spacer(30)

	# 继续游戏按钮
	resume_button = _create_button("继续游戏", "_on_resume_pressed")
	main_vbox.add_child(resume_button)

	# 保存游戏按钮
	save_button = _create_button("保存游戏", "_on_save_pressed")
	main_vbox.add_child(save_button)

	# 加载游戏按钮
	load_button = _create_button("加载游戏", "_on_load_pressed")
	main_vbox.add_child(load_button)

	# 设置按钮
	settings_button = _create_button("设置", "_on_settings_pressed")
	main_vbox.add_child(settings_button)

	# 分隔
	_add_spacer(20)

	# 退出按钮
	quit_button = _create_button("退出游戏", "_on_quit_pressed")
	main_vbox.add_child(quit_button)

	# 返回主菜单按钮
	var quit_to_menu_button := _create_button("返回主菜单", "_on_quit_to_menu_pressed")
	main_vbox.add_child(quit_to_menu_button)

	# 设置锚点居中
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -150
	offset_right = 150
	offset_top = -200
	offset_bottom = 200

func _create_button(text: String, callback: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 45)
	button.pressed.connect(Callable(self, callback))
	return button

func _add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	main_vbox.add_child(spacer)

func _connect_signals() -> void:
	# 连接 SaveManager 信号
	if SaveManager:
		SaveManager.game_saved.connect(_on_game_saved)
		SaveManager.game_loaded.connect(_on_game_loaded)

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_save_pressed() -> void:
	_open_save_load_menu(SaveLoadMenu.Mode.SAVE)

func _on_load_pressed() -> void:
	_open_save_load_menu(SaveLoadMenu.Mode.LOAD)

func _on_settings_pressed() -> void:
	if settings_ui:
		settings_ui.open()

func _on_settings_ui_closed() -> void:
	print("[PauseMenu] Settings closed")

func _on_quit_pressed() -> void:
	quit_game_requested.emit()

func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_requested.emit()

func _open_save_load_menu(mode: SaveLoadMenu.Mode) -> void:
	if save_load_menu:
		save_load_menu.queue_free()

	save_load_menu = SaveLoadMenu.new()
	save_load_menu.mode = mode
	save_load_menu.menu_closed.connect(_on_save_load_menu_closed)
	add_child(save_load_menu)

func _on_save_load_menu_closed() -> void:
	save_load_menu = null

func _on_game_saved(slot: int) -> void:
	print("[PauseMenu] Game saved to slot ", slot)

func _on_game_loaded(slot: int) -> void:
	print("[PauseMenu] Game loaded from slot ", slot)
	resume_requested.emit()
