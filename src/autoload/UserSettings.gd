extends Node

signal settings_changed(section: String, key: String, value: Variant)
signal settings_applied

const SCHEMA_VERSION := 1
const SETTINGS_PATH := "user://ui_settings.json"
const UI_SCALES := [0.85, 1.0, 1.15, 1.3]

const DEFAULTS := {
	"schema_version": SCHEMA_VERSION,
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
	},
	"display": {
		"window_mode": "windowed",
		"resolution": "1280x720",
		"vsync": true,
		"ui_scale": 1.0,
	},
	"accessibility": {
		"high_contrast": false,
		"reduce_motion": false,
		"text_speed": 1.0,
		"show_hints": true,
	},
	"input": {
		"gamepad_icons": "auto",
		"bindings": {},
	},
	"ui": {
		"last_journal_tab": "inventory",
		"hud_hidden": false,
	},
}

var _data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale("zh_CN")
	load_settings()
	apply_all()


func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var section_data = _data.get(section, {})
	if section_data is Dictionary and section_data.has(key):
		return section_data[key]
	if fallback != null:
		return fallback
	var defaults_section = DEFAULTS.get(section, {})
	return defaults_section.get(key) if defaults_section is Dictionary else null


func set_value(section: String, key: String, value: Variant, apply_now := true) -> void:
	if not _data.has(section) or not _data[section] is Dictionary:
		_data[section] = {}
	_data[section][key] = _sanitize_field(section, key, value)
	if apply_now:
		_apply_field(section, key, _data[section][key])
	settings_changed.emit(section, key, _data[section][key])


func load_settings() -> void:
	_data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_warning("[UserSettings] Settings file is corrupt; using defaults")
		return
	var loaded: Dictionary = json.data
	for section in DEFAULTS:
		if section == "schema_version":
			continue
		var loaded_section = loaded.get(section, {})
		if not loaded_section is Dictionary:
			continue
		for key in DEFAULTS[section]:
			if loaded_section.has(key):
				_data[section][key] = _sanitize_field(section, key, loaded_section[key])
	_data.schema_version = SCHEMA_VERSION


func save() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[UserSettings] Unable to write settings")
		return false
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	return true


func reset_defaults() -> void:
	_data = DEFAULTS.duplicate(true)
	apply_all()
	save()


func apply_all() -> void:
	for section in _data:
		if section == "schema_version" or not _data[section] is Dictionary:
			continue
		for key in _data[section]:
			_apply_field(section, key, _data[section][key])
	settings_applied.emit()


func export_data() -> Dictionary:
	return _data.duplicate(true)


func _sanitize_field(section: String, key: String, value: Variant) -> Variant:
	match "%s.%s" % [section, key]:
		"audio.master_volume", "audio.music_volume", "audio.sfx_volume":
			return clampf(float(value), 0.0, 1.0)
		"display.ui_scale":
			var requested := clampf(float(value), 0.85, 1.3)
			var nearest := 1.0
			var nearest_distance := INF
			for candidate in UI_SCALES:
				var distance := absf(float(candidate) - requested)
				if distance < nearest_distance:
					nearest = float(candidate)
					nearest_distance = distance
			return nearest
		"accessibility.text_speed":
			return clampf(float(value), 0.0, 2.0)
		"display.window_mode":
			return str(value) if str(value) in ["windowed", "fullscreen", "borderless"] else "windowed"
		"display.resolution":
			return str(value) if str(value) in ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"] else "1280x720"
		"input.gamepad_icons":
			return str(value) if str(value) in ["auto", "xbox", "playstation", "nintendo"] else "auto"
		"display.vsync", "accessibility.high_contrast", "accessibility.reduce_motion", "accessibility.show_hints", "ui.hud_hidden":
			return bool(value)
		"input.bindings":
			return value if value is Dictionary else {}
	return value


func _apply_field(section: String, key: String, value: Variant) -> void:
	match "%s.%s" % [section, key]:
		"audio.master_volume":
			if AudioManager.has_method("set_master_volume"):
				AudioManager.set_master_volume(float(value))
		"audio.music_volume":
			if AudioManager.has_method("set_music_volume"):
				AudioManager.set_music_volume(float(value))
		"audio.sfx_volume":
			if AudioManager.has_method("set_sfx_volume"):
				AudioManager.set_sfx_volume(float(value))
		"display.vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED
			)
		"display.window_mode":
			_apply_window_mode(str(value))
		"display.resolution":
			_apply_resolution(str(value))
		"display.ui_scale":
			get_tree().root.content_scale_factor = float(value)
		"input.bindings":
			if InputManager.has_method("apply_serialized_bindings"):
				InputManager.apply_serialized_bindings(value)
		"accessibility.high_contrast":
			get_tree().call_group("themed_ui_root", "refresh_theme")


func _apply_window_mode(mode: String) -> void:
	match mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_resolution(value: String) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var parts := value.split("x")
	if parts.size() == 2:
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
