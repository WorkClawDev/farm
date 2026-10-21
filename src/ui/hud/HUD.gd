extends CanvasLayer

var _root: Control
var _info_panel: PanelContainer
var _date_label: Label
var _weather_label: Label
var _money_label: Label
var _stamina_panel: PanelContainer
var _stamina_bar: ProgressBar
var _stamina_label: Label
var _hint_panel: PanelContainer
var _hint_label: Label
var _hint_tween: Tween
var _stamina_hide_at := 0.0


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_signals()
	_update_time()
	_update_money(MoneySystem.get_money() if MoneySystem else 0, 0)
	_update_stamina(StaminaManager.current_stamina, StaminaManager.max_stamina)
	_update_input_hint(InputManager.get_current_device())
	_apply_hud_visibility()


func _process(_delta: float) -> void:
	if _stamina_panel and _stamina_panel.visible and Time.get_ticks_msec() / 1000.0 > _stamina_hide_at:
		var ratio: float = float(StaminaManager.get_stamina_percent()) if StaminaManager else 1.0
		if ratio > 0.3:
			_stamina_panel.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Only swap the theme on high-contrast toggles; the bridge's full restyle pass is for menus.
	UIStyles.follow_theme(_root)
	add_child(_root)

	_info_panel = UIFactory.hud_panel()
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.offset_left = -292
	_info_panel.offset_top = 20
	_info_panel.offset_right = -20
	_info_panel.offset_bottom = 20  # height hugs the two text rows (was a fixed, half-empty 112px)
	_info_panel.grow_vertical = Control.GROW_DIRECTION_END
	# Long dates widen the panel leftwards instead of past the screen edge.
	_info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	_info_panel.add_child(info)
	_date_label = _hud_label(&"HUDTitle")
	info.add_child(_date_label)
	var weather_money := HBoxContainer.new()
	info.add_child(weather_money)
	_weather_label = _hud_label(&"HUDText")
	_weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_money.add_child(_weather_label)
	_money_label = _hud_label(&"HUDAccent")
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weather_money.add_child(_money_label)

	_stamina_panel = UIFactory.hud_panel()
	_stamina_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina_panel.offset_left = 20
	_stamina_panel.offset_top = -124  # content is 60px tall; -116 grew 2px into the hint panel below
	_stamina_panel.offset_right = 292
	_stamina_panel.offset_bottom = -64
	_stamina_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_panel)
	var stamina_content := VBoxContainer.new()
	_stamina_panel.add_child(stamina_content)
	_stamina_label = _hud_label(&"HUDSmall")
	stamina_content.add_child(_stamina_label)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(236, 14)
	_stamina_bar.show_percentage = false
	stamina_content.add_child(_stamina_bar)

	_hint_panel = UIFactory.hud_panel()
	_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_panel.offset_left = 20
	_hint_panel.offset_top = -58
	_hint_panel.offset_right = 310
	_hint_panel.offset_bottom = -18
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint_panel)
	_hint_label = _hud_label(&"HUDSmall")
	_hint_panel.add_child(_hint_label)


## Sizes/colours come from GameTheme.tres: HUDTitle 18, HUDText 16, HUDSmall 14, HUDAccent = gold HUDTitle.
func _hud_label(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	return label


func _connect_signals() -> void:
	if TimeManager:
		TimeManager.time_changed.connect(_on_time_changed)
		TimeManager.day_changed.connect(_on_day_changed)
		TimeManager.season_changed.connect(_on_season_changed)
	var weather := GameSession.weather
	if weather and weather.has_signal("weather_changed"):
		weather.weather_changed.connect(_on_weather_changed)
	if MoneySystem:
		MoneySystem.money_changed.connect(_update_money)
	if StaminaManager:
		StaminaManager.stamina_changed.connect(_update_stamina)
	if InputManager:
		InputManager.input_device_changed.connect(_update_input_hint)
	if UserSettings:
		UserSettings.settings_changed.connect(_on_setting_changed)


func _update_time() -> void:
	if not TimeManager:
		return
	var season_index := clampi(int(TimeManager.current_season), 0, 3)
	var season: String = ["春", "夏", "秋", "冬"][season_index]
	_date_label.text = "第 %d 年 · %s季第 %d 天  %s" % [
		int(TimeManager.current_year),
		season,
		int(TimeManager.current_day),
		TimeManager.get_formatted_time(),
	]
	var weather := GameSession.weather
	_weather_label.text = weather.get_weather_name_cn() if weather and weather.has_method("get_weather_name_cn") else "晴朗"


func _update_money(amount: int, _delta: int) -> void:
	if _money_label:
		_money_label.text = "%d 金" % amount


func _update_stamina(current: float, maximum: float) -> void:
	if not _stamina_bar:
		return
	var ratio := clampf(current / maximum if maximum > 0 else 0.0, 0.0, 1.0)
	_stamina_bar.value = ratio * 100.0
	_stamina_label.text = "体力  %d / %d" % [int(current), int(maximum)]
	_stamina_panel.visible = ratio < 0.78
	_stamina_hide_at = Time.get_ticks_msec() / 1000.0 + 2.6
	if ratio <= 0.2:
		_stamina_bar.modulate = Color("#E5634F")
	elif ratio <= 0.45:
		_stamina_bar.modulate = Color("#E6B84B")
	else:
		_stamina_bar.modulate = Color.WHITE


func _update_input_hint(_device: int) -> void:
	if not _hint_label:
		return
	_hint_label.text = "%s 互动   ·   %s 手册   ·   %s 暂停" % [
		InputManager.get_action_prompt(&"interact"),
		InputManager.get_action_prompt(&"journal"),
		InputManager.get_action_prompt(&"pause"),
	]
	_hint_panel.visible = bool(UserSettings.get_value("accessibility", "show_hints", true))
	if _hint_panel.visible and not UserSettings.get_value("accessibility", "reduce_motion", false):
		if _hint_tween and _hint_tween.is_valid():
			_hint_tween.kill()
		_hint_panel.modulate.a = 1.0
		_hint_tween = create_tween()
		_hint_tween.tween_interval(4.0)
		_hint_tween.tween_property(_hint_panel, "modulate:a", 0.68, 0.35)


func _apply_hud_visibility() -> void:
	_root.visible = not bool(UserSettings.get_value("ui", "hud_hidden", false))


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "ui" and key == "hud_hidden":
		_apply_hud_visibility()
	elif section == "accessibility" and key in ["show_hints", "reduce_motion"]:
		_update_input_hint(InputManager.get_current_device())


func _on_time_changed(_value: float) -> void:
	_update_time()


func _on_day_changed(_value: int) -> void:
	_update_time()


func _on_season_changed(_season: int, _name: String) -> void:
	_update_time()


func _on_weather_changed(_weather: String, _type: int) -> void:
	_update_time()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		var hidden := not bool(UserSettings.get_value("ui", "hud_hidden", false))
		UserSettings.set_value("ui", "hud_hidden", hidden)
		UserSettings.save()
		get_viewport().set_input_as_handled()
