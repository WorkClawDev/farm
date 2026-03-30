extends Control
class_name MainMenu

const SAVE_FILE_PATH := "user://save_data.json"

var _game_started := false
var _button_style_normal: StyleBoxTexture
var _button_style_hover: StyleBoxTexture
var _button_style_pressed: StyleBoxTexture
var _fade_tween: Tween

@onready var background_rect: ColorRect = $BackgroundLayer/Background
@onready var background_layer: CanvasLayer = $BackgroundLayer
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
	print("[MainMenu] Ready")
	background_layer.layer = -10
	_setup_styles()
	_apply_styles()
	_setup_background_gradient()
	_populate_savefiles()
	_connect_buttons()
	_play_intro_animation()

	var save_exists := _has_save_file()
	load_game_btn.disabled = not save_exists
	load_game_btn.modulate.a = 1.0 if save_exists else 0.5
	version_label.text = "v1.0.0"
	new_game_btn.grab_focus()

func _connect_buttons() -> void:
	new_game_btn.pressed.connect(_on_new_game_pressed)
	load_game_btn.pressed.connect(_on_load_game_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _setup_styles() -> void:
	_button_style_normal = StyleBoxTexture.new()
	_button_style_normal.texture = load("res://assets/sprites/ui/button_normal.png")

	_button_style_hover = StyleBoxTexture.new()
	_button_style_hover.texture = load("res://assets/sprites/ui/button_hover.png")

	_button_style_pressed = StyleBoxTexture.new()
	_button_style_pressed.texture = load("res://assets/sprites/ui/button_pressed.png")

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
	background_rect.color = Color(0.08, 0.12, 0.20, 1.0)
	decoration_bar.color = Color(0.85, 0.70, 0.30, 0.8)

	for _i in range(40):
		var star := ColorRect.new()
		star.custom_minimum_size = Vector2(2, 2)
		star.color = Color(1.0, 1.0, 0.9, randf_range(0.2, 0.8))
		star.position = Vector2(randf() * 1280.0, randf() * 600.0)
		star.z_index = -5
		particle_container.add_child(star)

func _play_intro_animation() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	menu_container.modulate.a = 0.0

	var title_base_y := title_label.position.y
	title_label.position.y = title_base_y + 10.0

	var title_tween := create_tween()
	title_tween.set_parallel(true)
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(title_label, "position:y", title_base_y, 0.8).set_ease(Tween.EASE_OUT)
	await title_tween.finished
	await get_tree().create_timer(0.2).timeout

	var content_tween := create_tween()
	content_tween.set_parallel(true)
	content_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.6)
	content_tween.tween_property(menu_container, "modulate:a", 1.0, 0.6)

func _populate_savefiles() -> void:
	pass

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
	fade_rect.color.a = 0.0
	_fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await _fade_tween.finished
	get_tree().change_scene_to_file(scene_path)

func _on_new_game_pressed() -> void:
	if _game_started:
		return
	_game_started = true
	print("[MainMenu] New game")
	_fade_to_scene("res://src/world/maps/Farm.tscn")

func _on_load_game_pressed() -> void:
	if _game_started:
		return
	if not _has_save_file():
		_show_no_save_dialog()
		return

	print("[MainMenu] Load game")
	_game_started = _show_save_load_menu(false)

func _show_save_load_menu(is_save: bool) -> bool:
	var packed := load("res://src/ui/menus/SaveLoadMenu.tscn")
	if packed:
		var menu = packed.instantiate()
		if menu == null:
			return false
		menu.set_mode(menu.Mode.SAVE if is_save else menu.Mode.LOAD)
		menu.load_completed.connect(_on_save_load_completed)
		menu.save_completed.connect(_on_save_completed)
		menu.menu_closed.connect(_on_save_load_menu_closed)
		add_child(menu)
		return true
	return false

func _on_save_load_completed(slot: int) -> void:
	print("[MainMenu] Loaded slot %d" % slot)
	_fade_to_scene("res://src/world/maps/Farm.tscn")

func _on_save_completed(slot: int) -> void:
	print("[MainMenu] Saved to slot %d" % slot)

func _on_save_load_menu_closed() -> void:
	_game_started = false

func _on_settings_pressed() -> void:
	if _game_started:
		return
	print("[MainMenu] Settings")
	_game_started = _show_settings_menu()

func _show_settings_menu() -> bool:
	var packed := load("res://src/ui/menus/SettingsUI.tscn")
	if packed:
		var settings = packed.instantiate()
		if settings == null:
			return false
		settings.settings_closed.connect(_on_settings_closed)
		add_child(settings)
		settings.open()
		return true
	return false

func _on_settings_closed() -> void:
	_game_started = false

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit")
	get_tree().quit()

func _show_no_save_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "No save file was found."
	dialog.window_title = "Notice"
	dialog.ok_button_text = "OK"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	dialog.canceled.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()
	_game_started = false

func _show_coming_soon_dialog(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.window_title = "Notice"
	dialog.ok_button_text = "OK"
	dialog.confirmed.connect(_on_dialog_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _on_dialog_confirmed(dialog: AcceptDialog) -> void:
	dialog.queue_free()
	_game_started = false
