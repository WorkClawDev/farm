extends Control
class_name SaveLoadMenu

signal save_completed(slot: int)
signal load_completed(slot: int)
signal menu_closed

enum Mode { SAVE, LOAD, NEW_GAME }

const SLOT_COUNT := 3
const SEASON_NAMES := ["春", "夏", "秋", "冬"]
const SEASON_COLORS := [
	Color("#9CCB82"),
	Color("#E7BE52"),
	Color("#D98245"),
	Color("#8EB5CA"),
]

@export var mode: Mode = Mode.SAVE

var _title: Label
var _cards: HBoxContainer
var _slot_buttons: Array[Button] = []
var _delete_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	_build_ui()
	_refresh_slots()
	await get_tree().process_frame
	UIFactory.focus_first(self)


func configure(context: Dictionary) -> void:
	if context.has("mode"):
		mode = int(context.mode) as Mode
	if _title:
		_update_title()
		_refresh_slots()


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if _title:
		_update_title()
		_refresh_slots()


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func close() -> void:
	menu_closed.emit()
	queue_free()


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 36)
	add_child(safe)

	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1060, 520))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = UIFactory.title("", HORIZONTAL_ALIGNMENT_LEFT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.tooltip_text = UIStyles.tr_key("ui.common.close", "关闭")
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_update_title()

	var description := UIFactory.subtitle("旧存档始终保留到新存档完整写入后，读取失败不会自动删除文件。")
	layout.add_child(description)
	layout.add_child(HSeparator.new())

	_cards = HBoxContainer.new()
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	layout.add_child(_cards)
	for slot in range(SLOT_COUNT):
		_cards.add_child(_create_card(slot))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	var back := UIFactory.button(UIStyles.tr_key("ui.common.back", "返回"), &"", Vector2(140, 46))
	back.pressed.connect(close)
	footer.add_child(back)


func _create_card(slot: int) -> PanelContainer:
	var panel := UIFactory.paper_panel(Vector2(320, 360))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)

	var season_band := ColorRect.new()
	season_band.name = "SeasonBand"
	season_band.custom_minimum_size.y = 8
	season_band.color = SEASON_COLORS[0]
	season_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(season_band)

	var heading := Label.new()
	heading.name = "Heading"
	heading.theme_type_variation = &"TitleLabel"
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)

	var date := Label.new()
	date.name = "Date"
	date.add_theme_font_size_override("font_size", 17)
	content.add_child(date)

	var details := Label.new()
	details.name = "Details"
	details.theme_type_variation = &"SubtitleLabel"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(details)

	var action := UIFactory.button("", &"PrimaryButton", Vector2(0, 52))
	action.name = "Action"
	action.pressed.connect(_on_slot_pressed.bind(slot))
	content.add_child(action)
	_slot_buttons.append(action)

	var remove := UIFactory.button(UIStyles.tr_key("ui.save.delete", "删除"), &"DangerButton", Vector2(0, 44))
	remove.name = "Delete"
	remove.pressed.connect(_on_delete_pressed.bind(slot))
	content.add_child(remove)
	_delete_buttons.append(remove)
	return panel


func _update_title() -> void:
	_title.text = UIStyles.tr_key({
		Mode.SAVE: "ui.save.title.save",
		Mode.LOAD: "ui.save.title.load",
		Mode.NEW_GAME: "ui.save.title.new",
	}[mode], "保存农场")


func _refresh_slots() -> void:
	if _cards == null:
		return
	var summaries := SaveManager.get_all_save_summaries()
	for slot in range(SLOT_COUNT):
		var info: Dictionary = summaries[slot]
		var content := _cards.get_child(slot).get_node("Content") as VBoxContainer
		var heading := content.get_node("Heading") as Label
		var date := content.get_node("Date") as Label
		var details := content.get_node("Details") as Label
		var band := content.get_node("SeasonBand") as ColorRect
		var action := _slot_buttons[slot]
		var remove := _delete_buttons[slot]
		heading.text = "农场 %d" % (slot + 1)

		if info.get("corrupt", false):
			date.text = UIStyles.tr_key("ui.save.corrupt", "这个存档暂时无法读取")
			details.text = "文件仍保留在原位置，可在修复后再次尝试。"
			band.color = UIStyles.COLOR_DANGER
			action.text = UIStyles.tr_key("ui.save.load", "读取进度")
			action.disabled = true
			remove.visible = true
			continue
		if not info.get("exists", false):
			date.text = UIStyles.tr_key("ui.save.empty", "创建新农场")
			details.text = "空白田地\n从第一年春季第 1 天开始"
			band.color = Color("#B7B09A")
			action.text = UIStyles.tr_key("ui.save.empty", "创建新农场")
			action.disabled = mode == Mode.LOAD
			remove.visible = false
			continue

		var season := clampi(int(info.get("season", 0)), 0, 3)
		band.color = SEASON_COLORS[season]
		date.text = "第 %d 年 · %s季第 %d 天" % [
			int(info.get("year", 1)),
			SEASON_NAMES[season],
			int(info.get("day", 1)),
		]
		details.text = "%s\n%d 金币\n游玩 %s\n%s" % [
			str(info.get("location", "农场")),
			int(info.get("money", 0)),
			UIStyles.format_play_time(float(info.get("play_time", 0.0))),
			UIStyles.format_timestamp(int(info.get("timestamp", 0))),
		]
		action.text = {
			Mode.SAVE: "保存到这里",
			Mode.LOAD: "读取这个农场",
			Mode.NEW_GAME: "重新开始",
		}[mode]
		action.disabled = false
		remove.visible = true


func _on_slot_pressed(slot: int) -> void:
	match mode:
		Mode.SAVE:
			if SaveManager.has_save(slot):
				_confirm_overwrite(slot, false)
			else:
				_save_game(slot)
		Mode.LOAD:
			_load_game(slot)
		Mode.NEW_GAME:
			if SaveManager.has_save(slot):
				_confirm_overwrite(slot, true)
			else:
				_start_new_game(slot)


func _confirm_overwrite(slot: int, start_new: bool) -> void:
	UIManager.show_confirmation({
		"title": "ui.save.overwrite_title",
		"message": "ui.save.overwrite_message",
		"args": {"slot": slot + 1},
		"danger": true,
		"on_confirm": _start_new_game.bind(slot) if start_new else _save_game.bind(slot),
	})


func _save_game(slot: int) -> void:
	if SaveManager.save_game(slot):
		save_completed.emit(slot)
		UIManager.show_toast("ui.save.success", {}, "success")
		_refresh_slots()
	else:
		UIManager.show_toast("ui.save.failed", {}, "error")


func _load_game(slot: int) -> void:
	var info := SaveManager.get_save_info(slot)
	if not info.get("exists", false):
		UIManager.show_toast("ui.save.load_failed", {}, "error")
		return
	load_completed.emit(slot)
	UIManager.close_all()
	GameManager.load_game(slot)


func _start_new_game(slot: int) -> void:
	load_completed.emit(slot)
	UIManager.close_all()
	GameManager.start_new_game(slot)


func _on_delete_pressed(slot: int) -> void:
	UIManager.show_confirmation({
		"title": "ui.save.delete_title",
		"message": "ui.save.delete_message",
		"args": {"slot": slot + 1},
		"danger": true,
		"confirm_key": "ui.save.delete",
		"on_confirm": _delete_save.bind(slot),
	})


func _delete_save(slot: int) -> void:
	if SaveManager.delete_save(slot):
		UIManager.show_toast("ui.save.deleted", {}, "success")
	_refresh_slots()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
