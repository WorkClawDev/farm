extends Control
class_name ToolDisplay

## ToolDisplay - 工具显示UI
## 显示当前持有的工具

const TOOL_ICON_IDS := {
	ToolManager.ToolType.HOE: "hoe",
	ToolManager.ToolType.WATERING_CAN: "watering_can",
	ToolManager.ToolType.AXE: "axe",
	ToolManager.ToolType.PICKAXE: "pickaxe",
	ToolManager.ToolType.SICKLE: "sickle",
	ToolManager.ToolType.FISHING_ROD: "fishing_rod",
}

var tool_icon: TextureRect
var tool_name_label: Label
var _hint_label: Label
var _icon_card: PanelContainer
var _switch_tween: Tween

var current_tool_name: String = ""

func _ready() -> void:
	_build_ui()
	# 连接工具切换信号
	if get_tree().current_scene:
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player and player.tool_manager:
			player.tool_manager.tool_changed.connect(_on_tool_changed)
			var tool_type: int = player.tool_manager.get_current_tool_type()
			_on_tool_changed(tool_type, player.tool_manager._get_tool_name(tool_type))


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -248
	offset_top = -94
	offset_right = -20
	offset_bottom = -18
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIStyles.active_theme()

	var panel := UIFactory.hud_panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	_icon_card = PanelContainer.new()
	_icon_card.custom_minimum_size = Vector2(54, 54)
	_icon_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.97, 0.91, 0.73, 0.96)
	card_style.border_color = UIStyles.COLOR_GOLD
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	_icon_card.add_theme_stylebox_override("panel", card_style)
	content.add_child(_icon_card)

	tool_icon = TextureRect.new()
	tool_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tool_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tool_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tool_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_card.add_child(tool_icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 0)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(labels)

	tool_name_label = Label.new()
	tool_name_label.theme_type_variation = &"HUDText"
	tool_name_label.add_theme_font_size_override("font_size", 18)
	labels.add_child(tool_name_label)

	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"HUDText"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.modulate.a = 0.82
	_hint_label.text = "Q / R  切换工具"
	labels.add_child(_hint_label)

func _on_tool_changed(tool_type: int, tool_name: String) -> void:
	current_tool_name = tool_name
	tool_name_label.text = tool_name
	_update_tool_icon(tool_type)
	if not UserSettings.get_value("accessibility", "reduce_motion", false):
		if _switch_tween and _switch_tween.is_valid():
			_switch_tween.kill()
		_icon_card.scale = Vector2(0.9, 0.9)
		_icon_card.pivot_offset = _icon_card.size * 0.5
		_switch_tween = create_tween()
		_switch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_switch_tween.tween_property(_icon_card, "scale", Vector2.ONE, 0.16)

func _update_tool_icon(tool_type: int) -> void:
	var item_id := str(TOOL_ICON_IDS.get(tool_type, ""))
	tool_icon.texture = ItemDatabase.load_icon_texture(item_id) if not item_id.is_empty() else null
	tool_icon.modulate = Color.WHITE if tool_icon.texture else Color(0.65, 0.62, 0.55)
