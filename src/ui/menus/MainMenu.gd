extends Control
class_name MainMenu

## 主菜单场景 - 田园物语风格重新设计
## 特色：星空粒子动画、渐变背景、像素风格按钮

const SAVE_FILE_PATH := "user://save_data.json"

var _game_started := false
var _button_style_normal: StyleBoxTexture
var _button_style_hover: StyleBoxTexture
var _button_style_pressed: StyleBoxTexture
var _fade_tween: Tween
var _title_tween: Tween
var _particle_timer: float = 0.0
var _particles: Array[Control] = []

@onready var background_rect: ColorRect = $BackgroundLayer/Background
@onready var title_label: Label = $TitleContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $TitleContainer/VBox/SubtitleLabel
@onready var menu_container: VBoxContainer = $MenuContainer/VBox
@onready var new_game_btn: Button = $MenuContainer/VBox/NewGameBtn
@onready var load_game_btn: Button = $MenuContainer/VBox/LoadGameBtn
@onready var settings_btn: Button = $MenuContainer/VBox/SettingsBtn
@onready var quit_btn: Button = $MenuContainer/VBox/QuitBtn
@onready var version_label: Label = $VersionLabel
@onready var particle_container: Node2D = $BackgroundLayer/ParticleLayer
@onready var decoration_bar: ColorRect = $BackgroundLayer/DecorationBar

func _ready() -> void:
	print("[DEBUG] MainMenu._ready starting")
	print("[DEBUG] MenuContainer: ", menu_container)
	print("[DEBUG] new_game_btn: ", new_game_btn, " rect: ", new_game_btn.get_global_rect() if new_game_btn else "null")
	print("[MainMenu] _ready() called")
	_setup_styles()
	_apply_styles()
	_setup_background_gradient()
	_populate_savefiles()
	_play_intro_animation()
	new_game_btn.grab_focus()
	print("[MainMenu] Setup complete, animation playing")

	# 验证是否已有存档
	var save_exists := _has_save_file()
	load_game_btn.disabled = not save_exists
	if not save_exists:
		load_game_btn.modulate.a = 0.5

	# 连接信号
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_game_btn.pressed.connect(_on_load_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# 版本信息
	version_label.text = "v1.0.0"

func _setup_styles() -> void:
	# 普通按钮样式
	_button_style_normal = StyleBoxTexture.new()
	_button_style_normal.texture = load("res://assets/sprites/ui/button_normal.png")
	_button_style_normal.expand_margin_left = 0
	_button_style_normal.expand_margin_right = 0
	_button_style_normal.expand_margin_top = 0
	_button_style_normal.expand_margin_bottom = 0

	_button_style_hover = StyleBoxTexture.new()
	_button_style_hover.texture = load("res://assets/sprites/ui/button_hover.png")
	_button_style_hover.expand_margin_left = 0
	_button_style_hover.expand_margin_right = 0
	_button_style_hover.expand_margin_top = 0
	_button_style_hover.expand_margin_bottom = 0

	_button_style_pressed = StyleBoxTexture.new()
	_button_style_pressed.texture = load("res://assets/sprites/ui/button_pressed.png")
	_button_style_pressed.expand_margin_left = 0
	_button_style_pressed.expand_margin_right = 0
	_button_style_pressed.expand_margin_top = 0
	_button_style_pressed.expand_margin_bottom = 0

func _apply_styles() -> void:
	var buttons := [new_game_btn, load_game_btn, settings_btn, quit_btn]
	for btn in buttons:
		if btn == null:
			continue
		btn.add_theme_stylebox_override("normal", _button_style_normal)
		btn.add_theme_stylebox_override("hover", _button_style_hover)
		btn.add_theme_stylebox_override("pressed", _button_style_pressed)
		btn.add_theme_color_override("font_hover_color", Color("#FFD700"))
		btn.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))
		btn.add_theme_font_size_override("font_size", 18)

func _setup_background_gradient() -> void:
	# 星空粒子 - 简单用几个随机点
	for i in range(40):
		var star := ColorRect.new()
		star.custom_minimum_size = Vector2(2, 2)
		star.color = Color(1, 1, 0.9, randf_range(0.2, 0.8))
		star.set_anchors_preset(Control.PRESET_FULL_RECT)
		star.position = Vector2(randf() * 1280, randf() * 600)
		star.z_index = -5
		particle_container.add_child(star)

func _play_intro_animation() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	menu_container.modulate.a = 0.0

# 标题上浮动画
	var title_base_y: float = title_label.position.y
	title_label.modulate.a = 0.0
	title_label.position.y = title_base_y + 10.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_label, "position:y", title_base_y - 20.0, 0.8).set_ease(Tween.EASE_OUT)
	await tw

	# 副标题和菜单渐入
	subtitle_label.modulate.a = 0.0
	menu_container.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(subtitle_label, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(0.2).timeout
	var tw3 := create_tween()
	tw3.tween_property(menu_container, "modulate:a", 1.0, 0.6)

	# 按钮依次弹出（每0.15秒一个）
	var btns := [new_game_btn, load_game_btn, settings_btn, quit_btn]
	for i in range(btns.size()):
		if btns[i]:
			var btn_base_y: float = btns[i].position.y
			btns[i].position.y = btn_base_y + 20.0
			btns[i].modulate.a = 0.0
			await get_tree().create_timer(0.5 + i * 0.15).timeout
			var btn_tw := create_tween()
			btn_tw.set_ease(Tween.EASE_OUT)
			btn_tw.tween_property(btns[i], "position:y", btn_base_y - 20.0, 0.3)
			var btn_tw2 := create_tween()
			btn_tw2.tween_property(btns[i], "modulate:a", 1.0, 0.3)

func _populate_savefiles() -> void:
	# 检查存档是否存在
	pass  # 已在 _ready 中处理

func _has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func _fade_to_scene(scene_path: String) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var fade_rect := ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.z_index = 100
	add_child(fade_rect)

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	fade_rect.color.a = 0.0
	_fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await _fade_tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_new_game_pressed() -> void:
	if _game_started:
		return
	_game_started = true
	print("[MainMenu] 新游戏")
	_fade_to_scene("res://src/world/maps/Farm.tscn")

func _on_load_game_pressed() -> void:
	if _game_started:
		return
	print("[MainMenu] 加载游戏")
	_show_save_load_menu(false)


func _show_save_load_menu(is_save: bool) -> void:
	var packed := load("res://src/ui/menus/SaveLoadMenu.tscn")
	if packed:
		var menu: SaveLoadMenu = packed.instantiate()
		menu.set_mode(SaveLoadMenu.Mode.SAVE if is_save else SaveLoadMenu.Mode.LOAD)
		menu.load_completed.connect(_on_save_load_completed)
		menu.save_completed.connect(_on_save_completed)
		menu.menu_closed.connect(_on_save_load_menu_closed)
		add_child(menu)


func _on_save_load_completed(slot: int) -> void:
	print("[MainMenu] 已加载存档槽位 %d" % slot)
	_fade_to_scene("res://src/world/maps/Farm.tscn")


func _on_save_completed(slot: int) -> void:
	print("[MainMenu] 已保存到存档槽位 %d" % slot)


func _on_save_load_menu_closed() -> void:
	_game_started = false

func _on_settings_pressed() -> void:
	print("[MainMenu] 设置")
	_show_settings_menu()


func _show_settings_menu() -> void:
	var packed := load("res://src/ui/menus/SettingsUI.tscn")
	if packed:
		var settings: SettingsUI = packed.instantiate()
		settings.settings_closed.connect(_on_settings_closed)
		add_child(settings)
		settings.open()


func _on_settings_closed() -> void:
	_game_started = false

func _on_quit_pressed() -> void:
	print("[MainMenu] 退出游戏")
	get_tree().quit()

func _show_no_save_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "没有找到存档"
	dialog.window_title = "提示"
	dialog.ok_button_text = "确定"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	dialog.canceled.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()
	_game_started = false

func _show_coming_soon_dialog(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.window_title = "提示"
	dialog.ok_button_text = "好的"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _on_dialog_confirmed(dialog: AcceptDialog) -> void:
	dialog.queue_free()
	_game_started = false
