extends RefCounted

## Small floating label so a map exit can be found (BUG-32/35/36).
## Same look as the village exit signs.
static func attach(area: Area2D, text: String, offset := Vector2.ZERO) -> Label:
	if text.is_empty() or area.get_node_or_null("ExitSign"):
		return null
	var label := Label.new()
	label.name = "ExitSign"
	label.text = text
	label.size = Vector2(120, 26)
	label.position = Vector2(-60, -13) + offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(label)
	return label
