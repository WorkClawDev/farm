extends Node

const UI_SCENE_PREFIXES := [
	"res://src/ui/menus/",
	"res://src/ui/dialogs/",
	"res://src/ui/festival/",
	"res://src/ui/gift/",
	"res://src/ui/minigames/",
]

var _pending_roots: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	UserSettings.settings_changed.connect(_on_setting_changed)
	if get_tree().current_scene:
		_queue_style(get_tree().current_scene)


func style_scene(root: Node) -> void:
	if root == null:
		return
	root.add_to_group("themed_ui_root")
	var root_control := root as Control
	if root_control:
		root_control.theme = UIStyles.active_theme()
	else:
		_apply_theme_to_control_roots(root)
	_apply_recursive(root)


func _apply_theme_to_control_roots(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).theme = UIStyles.active_theme()
		else:
			_apply_theme_to_control_roots(child)


func _on_node_added(node: Node) -> void:
	var ui_root := _find_ui_root(node)
	if ui_root:
		_queue_style(ui_root)


func _find_ui_root(node: Node) -> Node:
	var current := node
	while current:
		var path := current.scene_file_path
		if not path.is_empty():
			for prefix in UI_SCENE_PREFIXES:
				if path.begins_with(prefix):
					return current
			return null
		current = current.get_parent()
	return null


func _queue_style(root: Node) -> void:
	if _pending_roots.has(root):
		return
	_pending_roots[root] = true
	call_deferred("_apply_pending", root)


func _apply_pending(root: Node) -> void:
	_pending_roots.erase(root)
	if is_instance_valid(root):
		style_scene(root)


func _apply_recursive(node: Node) -> void:
	# Formal brand marks and a small number of art-directed components need
	# explicit per-scene overrides on top of the global theme. They opt in with
	# metadata so the migration bridge does not erase those intentional values.
	if not bool(node.get_meta("preserve_theme_overrides", false)):
		if node is Button:
			_style_button(node)
		elif node is PanelContainer:
			_style_panel(node)
		elif node is Panel:
			_style_plain_panel(node)
		elif node is Label:
			_style_label(node)
		elif node is RichTextLabel:
			_style_rich_text(node)
		elif node is ProgressBar:
			_style_progress(node)
		elif node is LineEdit:
			_style_line_edit(node)
		elif node is ItemList:
			_style_item_list(node)
	for child in node.get_children():
		_apply_recursive(child)


func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.remove_theme_stylebox_override(style_name)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.remove_theme_color_override(color_name)
	button.remove_theme_font_size_override("font_size")
	var semantic := (button.name + " " + button.text).to_lower()
	if _contains_any(semantic, ["delete", "remove", "quit", "danger", "删除", "退出"]):
		button.theme_type_variation = &"DangerButton"
	elif _contains_any(semantic, ["confirm", "buy", "save", "upgrade", "cook", "craft", "购买", "保存", "升级", "制作", "烹饪", "确认"]):
		button.theme_type_variation = &"PrimaryButton"


func _style_panel(panel: PanelContainer) -> void:
	panel.remove_theme_stylebox_override("panel")
	if panel.theme_type_variation.is_empty():
		panel.theme_type_variation = &"PaperPanel"


func _style_plain_panel(panel: Panel) -> void:
	panel.remove_theme_stylebox_override("panel")


func _style_label(label: Label) -> void:
	var semantic := label.name.to_lower()
	if _contains_any(semantic, ["title", "heading", "shopname", "itemname"]):
		label.theme_type_variation = &"TitleLabel"
		label.remove_theme_font_size_override("font_size")
		label.remove_theme_color_override("font_color")


func _style_rich_text(label: RichTextLabel) -> void:
	label.remove_theme_color_override("default_color")
	label.remove_theme_stylebox_override("normal")


func _style_progress(progress: ProgressBar) -> void:
	progress.remove_theme_stylebox_override("background")
	progress.remove_theme_stylebox_override("fill")
	progress.remove_theme_color_override("font_color")


func _style_line_edit(edit: LineEdit) -> void:
	edit.remove_theme_stylebox_override("normal")
	edit.remove_theme_stylebox_override("focus")
	edit.remove_theme_color_override("font_color")


func _style_item_list(list: ItemList) -> void:
	list.remove_theme_stylebox_override("panel")
	list.remove_theme_stylebox_override("focus")
	list.focus_mode = Control.FOCUS_ALL


func _contains_any(text: String, needles: Array[String]) -> bool:
	for needle in needles:
		if needle in text:
			return true
	return false


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "accessibility" and key == "high_contrast":
		for root in get_tree().get_nodes_in_group("themed_ui_root"):
			if root is Node:
				style_scene(root)
