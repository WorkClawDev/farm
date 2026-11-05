extends RefCounted
class_name UIStyles

const BASE_THEME := preload("res://src/ui/theme/GameTheme.tres")
const HIGH_CONTRAST_THEME := preload("res://src/ui/theme/GameThemeHighContrast.tres")

const COLOR_INK := Color("#2C1F12")
const COLOR_CREAM := Color("#F4E9C8")
const COLOR_PAPER := Color("#F7EDCF")
const COLOR_GREEN := Color("#477A3C")
const COLOR_GOLD := Color("#D8A936")
const COLOR_DANGER := Color("#B24031")
const COLOR_SHADE := Color(0.035, 0.027, 0.02, 0.72)

const SPACE_XS := 6
const SPACE_SM := 10
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 36

static func active_theme() -> Theme:
	if Engine.has_singleton("UserSettings"):
		return HIGH_CONTRAST_THEME if UserSettings.get_value("accessibility", "high_contrast", false) else BASE_THEME
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var settings := tree.root.get_node_or_null("UserSettings")
		if settings and settings.get_value("accessibility", "high_contrast", false):
			return HIGH_CONTRAST_THEME
	return BASE_THEME

static func apply_root(control: Control) -> void:
	control.theme = active_theme()

## For HUD widgets that set their own theme: UIThemeBridge swaps it when high
## contrast is toggled (BUG-25: quest/hotbar/tool panels kept the old theme).
static func follow_theme(control: Control) -> void:
	control.theme = active_theme()
	control.add_to_group("theme_followers")

static func format_play_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 3600, (total % 3600) / 60]

const SYSTEM_UTC_OFFSET := -100000

## Saves store saved_at as UTC unix seconds; show it in the player's local time.
## utc_offset_minutes overrides the system zone (tests); the stored value never changes.
static func format_timestamp(timestamp: int, utc_offset_minutes: int = SYSTEM_UTC_OFFSET) -> String:
	if timestamp <= 0:
		return tr_key("ui.save.unknown_time", "时间未知")
	var offset := utc_offset_minutes
	if offset == SYSTEM_UTC_OFFSET:
		offset = int(Time.get_time_zone_from_system().get("bias", 0))
	var value := Time.get_datetime_dict_from_unix_time(timestamp + offset * 60)
	return "%04d-%02d-%02d  %02d:%02d" % [
		int(value.get("year", 0)),
		int(value.get("month", 0)),
		int(value.get("day", 0)),
		int(value.get("hour", 0)),
		int(value.get("minute", 0)),
	]

static func tr_key(key: String, fallback: String = "") -> String:
	var translated := TranslationServer.translate(key)
	return fallback if translated == key and not fallback.is_empty() else translated
