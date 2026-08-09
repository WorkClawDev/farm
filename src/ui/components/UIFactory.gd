extends RefCounted
class_name UIFactory

static func button(text: String, variation: StringName = &"", minimum := Vector2(180, 48)) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = minimum
	result.focus_mode = Control.FOCUS_ALL
	if not variation.is_empty():
		result.theme_type_variation = variation
	return result

static func title(text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"TitleLabel"
	result.horizontal_alignment = alignment
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func subtitle(text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"SubtitleLabel"
	result.horizontal_alignment = alignment
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func paper_panel(minimum := Vector2.ZERO) -> PanelContainer:
	var result := PanelContainer.new()
	result.theme_type_variation = &"PaperPanel"
	result.custom_minimum_size = minimum
	return result

static func hud_panel() -> PanelContainer:
	var result := PanelContainer.new()
	result.theme_type_variation = &"HUDPanel"
	return result

static func margin(content: Control, amount := 24) -> MarginContainer:
	var result := MarginContainer.new()
	result.add_theme_constant_override("margin_left", amount)
	result.add_theme_constant_override("margin_top", amount)
	result.add_theme_constant_override("margin_right", amount)
	result.add_theme_constant_override("margin_bottom", amount)
	result.add_child(content)
	return result

static func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

static func focus_first(root: Node) -> void:
	var focusables := root.find_children("*", "Button", true, false)
	if not focusables.is_empty():
		(focusables[0] as Button).grab_focus()
