@tool
extends VBoxContainer
class_name PastoralMapEditorDock

var plugin: EditorPlugin
var map_label: Label
var status_label: Label
var layer_tree: Tree
var layer_name_edit: LineEdit
var layer_kind_option: OptionButton
var asset_search: LineEdit
var asset_list: ItemList
var tile_list: ItemList
var terrain_option: OptionButton
var collision_preset_option: OptionButton
var issue_list: ItemList
var map_width_spin: SpinBox
var map_height_spin: SpinBox
var opacity_slider: HSlider
var y_sort_toggle: CheckButton
var cursor_label: Label
var tool_buttons: Dictionary = {}


func setup(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin
	custom_minimum_size = Vector2(330, 520)
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Pastoral 地图编辑器"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	map_label = Label.new()
	map_label.text = "未打开 EditableMap2D"
	add_child(map_label)

	var size_row := HBoxContainer.new()
	add_child(size_row)
	var size_label := Label.new()
	size_label.text = "地图尺寸"
	size_row.add_child(size_label)
	map_width_spin = SpinBox.new()
	map_width_spin.min_value = 1
	map_width_spin.max_value = 512
	map_width_spin.suffix = " 格宽"
	size_row.add_child(map_width_spin)
	map_height_spin = SpinBox.new()
	map_height_spin.min_value = 1
	map_height_spin.max_value = 512
	map_height_spin.suffix = " 格高"
	size_row.add_child(map_height_spin)
	_add_button(size_row, "应用", plugin.resize_map_from_dock)

	var file_bar := HBoxContainer.new()
	add_child(file_bar)
	_add_button(file_bar, "新建", plugin.create_new_map)
	_add_button(file_bar, "打开", plugin.open_map)
	_add_button(file_bar, "保存", plugin.save_map)
	_add_button(file_bar, "另存", plugin.save_map_as)
	_add_button(file_bar, "运行", plugin.run_map)

	var history_bar := HBoxContainer.new()
	add_child(history_bar)
	_add_button(history_bar, "撤销", plugin.undo)
	_add_button(history_bar, "重做", plugin.redo)
	_add_button(history_bar, "校验", plugin.validate_active_map)

	add_child(_section_label("绘制工具"))
	var tools := GridContainer.new()
	tools.columns = 4
	add_child(tools)
	for definition in [
		["select", "选择"], ["pencil", "画笔"], ["eraser", "橡皮"], ["picker", "取色"],
		["rect", "矩形"], ["fill", "填充"], ["terrain", "Terrain"], ["asset", "放资源"],
		["collision_rect", "碰撞矩形"], ["collision_circle", "碰撞圆"], ["collision_polygon", "碰撞多边形"],
	]:
		var button := Button.new()
		button.text = definition[1]
		button.toggle_mode = true
		button.pressed.connect(plugin.set_active_tool.bind(definition[0]))
		tools.add_child(button)
		tool_buttons[definition[0]] = button

	var grid_row := HBoxContainer.new()
	add_child(grid_row)
	var grid_toggle := CheckButton.new()
	grid_toggle.text = "网格"
	grid_toggle.button_pressed = true
	grid_toggle.toggled.connect(plugin.set_grid_visible)
	grid_row.add_child(grid_toggle)
	var snap_toggle := CheckButton.new()
	snap_toggle.text = "吸附"
	snap_toggle.button_pressed = true
	snap_toggle.toggled.connect(plugin.set_snap_enabled)
	grid_row.add_child(snap_toggle)

	add_child(_section_label("图层"))
	layer_tree = Tree.new()
	layer_tree.custom_minimum_size.y = 150
	layer_tree.columns = 3
	layer_tree.set_column_title(0, "名称")
	layer_tree.set_column_title(1, "类型")
	layer_tree.set_column_title(2, "状态")
	layer_tree.column_titles_visible = true
	layer_tree.item_selected.connect(plugin.select_layer_from_dock)
	add_child(layer_tree)

	var layer_edit_row := HBoxContainer.new()
	add_child(layer_edit_row)
	layer_name_edit = LineEdit.new()
	layer_name_edit.placeholder_text = "layer_id"
	layer_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_edit_row.add_child(layer_name_edit)
	layer_kind_option = OptionButton.new()
	for kind_name in MapLayerSpec.LayerKind.keys():
		layer_kind_option.add_item(kind_name.capitalize())
	layer_edit_row.add_child(layer_kind_option)
	_add_button(layer_edit_row, "+", plugin.add_layer_from_dock)

	var layer_actions := HBoxContainer.new()
	add_child(layer_actions)
	_add_button(layer_actions, "重命名", plugin.rename_layer_from_dock)
	_add_button(layer_actions, "复制", plugin.duplicate_layer)
	_add_button(layer_actions, "删除", plugin.delete_layer)
	_add_button(layer_actions, "↑", plugin.move_layer.bind(-1))
	_add_button(layer_actions, "↓", plugin.move_layer.bind(1))
	_add_button(layer_actions, "显示", plugin.toggle_layer_visibility)
	_add_button(layer_actions, "锁定", plugin.toggle_layer_lock)

	var opacity_row := HBoxContainer.new()
	add_child(opacity_row)
	var opacity_label := Label.new()
	opacity_label.text = "透明度"
	opacity_row.add_child(opacity_label)
	opacity_slider = HSlider.new()
	opacity_slider.min_value = 0.05
	opacity_slider.max_value = 1.0
	opacity_slider.step = 0.05
	opacity_slider.value = 1.0
	opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opacity_slider.value_changed.connect(plugin.set_layer_opacity)
	opacity_row.add_child(opacity_slider)
	y_sort_toggle = CheckButton.new()
	y_sort_toggle.text = "Y Sort"
	y_sort_toggle.toggled.connect(plugin.set_layer_y_sort)
	opacity_row.add_child(y_sort_toggle)

	add_child(_section_label("地图资源"))
	asset_search = LineEdit.new()
	asset_search.placeholder_text = "搜索 ID、名称或标签"
	asset_search.text_changed.connect(plugin.refresh_assets)
	add_child(asset_search)
	asset_list = ItemList.new()
	asset_list.custom_minimum_size.y = 120
	asset_list.select_mode = ItemList.SELECT_SINGLE
	asset_list.item_selected.connect(plugin.select_asset)
	asset_list.item_activated.connect(plugin.open_asset)
	add_child(asset_list)

	var asset_actions := HBoxContainer.new()
	add_child(asset_actions)
	_add_button(asset_actions, "登记", plugin.register_resource)
	_add_button(asset_actions, "导入图片", plugin.import_external_texture)
	_add_button(asset_actions, "创建 TileSet", plugin.create_tileset_from_selected)
	_add_button(asset_actions, "取消登记", plugin.unregister_selected_asset)

	add_child(_section_label("瓦片调色板"))
	tile_list = ItemList.new()
	tile_list.fixed_icon_size = Vector2i(40, 40)
	tile_list.icon_mode = ItemList.ICON_MODE_TOP
	tile_list.max_columns = 6
	tile_list.custom_minimum_size.y = 150
	tile_list.item_selected.connect(plugin.select_tile)
	add_child(tile_list)

	var terrain_row := HBoxContainer.new()
	add_child(terrain_row)
	var terrain_label := Label.new()
	terrain_label.text = "Terrain 类型"
	terrain_row.add_child(terrain_label)
	terrain_option = OptionButton.new()
	terrain_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_option.item_selected.connect(plugin.select_terrain)
	terrain_row.add_child(terrain_option)

	var collision_row := HBoxContainer.new()
	add_child(collision_row)
	var preset_label := Label.new()
	preset_label.text = "碰撞预设"
	collision_row.add_child(preset_label)
	collision_preset_option = OptionButton.new()
	collision_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collision_preset_option.item_selected.connect(plugin.select_collision_preset)
	collision_row.add_child(collision_preset_option)

	add_child(_section_label("问题"))
	issue_list = ItemList.new()
	issue_list.custom_minimum_size.y = 110
	issue_list.item_activated.connect(plugin.focus_issue)
	add_child(issue_list)

	status_label = Label.new()
	status_label.text = "打开 FarmMap.tscn 开始编辑"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	cursor_label = Label.new()
	cursor_label.text = "格坐标：-"
	add_child(cursor_label)
	set_tool("select")


func refresh(active_map: EditableMap2D, selected_layer: Node) -> void:
	if active_map == null:
		map_label.text = "未打开 EditableMap2D"
		layer_tree.clear()
		asset_list.clear()
		tile_list.clear()
		collision_preset_option.clear()
		return
	map_label.text = "%s · %dx%d · %dx%dpx" % [
		active_map.display_name,
		active_map.size_in_tiles.x,
		active_map.size_in_tiles.y,
		active_map.tile_size.x,
		active_map.tile_size.y,
	]
	map_width_spin.value = active_map.size_in_tiles.x
	map_height_spin.value = active_map.size_in_tiles.y
	refresh_layers(active_map, selected_layer)
	refresh_assets(active_map)
	refresh_collision_presets(active_map)
	if selected_layer != null:
		opacity_slider.set_block_signals(true)
		y_sort_toggle.set_block_signals(true)
		opacity_slider.value = selected_layer.modulate.a
		y_sort_toggle.button_pressed = selected_layer.y_sort_enabled
		opacity_slider.set_block_signals(false)
		y_sort_toggle.set_block_signals(false)


func refresh_layers(active_map: EditableMap2D, selected_layer: Node) -> void:
	layer_tree.set_block_signals(true)
	layer_tree.clear()
	var root := layer_tree.create_item()
	for child in active_map.get_children():
		var layer_id: StringName
		var kind_name := ""
		var locked := false
		if child is MapTileLayer:
			layer_id = child.layer_id
			kind_name = "Tile"
			locked = child.locked
		elif child is MapLayer2D:
			layer_id = child.layer_id
			kind_name = MapLayerSpec.LayerKind.keys()[child.layer_kind].capitalize()
			locked = child.locked
		else:
			continue
		var item := layer_tree.create_item(root)
		item.set_text(0, str(layer_id))
		item.set_text(1, kind_name)
		item.set_text(2, "%s%s" % ["隐藏 " if not child.visible else "", "锁定" if locked else ""])
		item.set_metadata(0, layer_id)
		if child == selected_layer:
			item.select(0)
	layer_tree.set_block_signals(false)


func refresh_assets(active_map: EditableMap2D) -> void:
	asset_list.clear()
	if active_map == null or active_map.profile == null or active_map.profile.asset_library == null:
		return
	var query := asset_search.text if asset_search != null else ""
	for entry in active_map.profile.asset_library.find_entries(query):
		var icon := entry.thumbnail
		if icon == null and entry.resource is Texture2D:
			icon = entry.resource
		asset_list.add_item(entry.display_name, icon)
		asset_list.set_item_metadata(asset_list.item_count - 1, entry.asset_id)


func refresh_collision_presets(active_map: EditableMap2D) -> void:
	collision_preset_option.clear()
	if active_map == null or active_map.profile == null:
		return
	for preset in active_map.profile.collision_presets:
		if preset == null:
			continue
		collision_preset_option.add_item(preset.display_name)
		collision_preset_option.set_item_metadata(collision_preset_option.item_count - 1, preset.preset_id)


func refresh_tiles(tile_set: TileSet) -> void:
	tile_list.clear()
	terrain_option.clear()
	if tile_set == null:
		return
	for source_index in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(source_index)
		var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas == null:
			continue
		for tile_index in range(atlas.get_tiles_count()):
			var coords := atlas.get_tile_id(tile_index)
			var icon := AtlasTexture.new()
			icon.atlas = atlas.texture
			icon.region = atlas.get_tile_texture_region(coords)
			tile_list.add_item("%d:%d,%d" % [source_id, coords.x, coords.y], icon)
			tile_list.set_item_metadata(tile_list.item_count - 1, [source_id, coords])
	for terrain_set in range(tile_set.get_terrain_sets_count()):
		for terrain in range(tile_set.get_terrains_count(terrain_set)):
			var terrain_name := tile_set.get_terrain_name(terrain_set, terrain)
			terrain_option.add_item("%d · %s" % [terrain_set + 1, terrain_name])
			terrain_option.set_item_metadata(terrain_option.item_count - 1, [terrain_set, terrain])


func show_issues(issues: Array[MapValidationIssue]) -> void:
	issue_list.clear()
	var error_count := 0
	var warning_count := 0
	for issue in issues:
		var prefix := "[信息]"
		if issue.severity == MapValidationIssue.Severity.ERROR:
			prefix = "[错误]"
			error_count += 1
		elif issue.severity == MapValidationIssue.Severity.WARNING:
			prefix = "[警告]"
			warning_count += 1
		issue_list.add_item("%s %s" % [prefix, issue.message])
		issue_list.set_item_metadata(issue_list.item_count - 1, issue.node_path)
	status_label.text = "校验完成：%d 个错误，%d 个警告" % [error_count, warning_count]


func set_tool(tool_id: String) -> void:
	for id in tool_buttons:
		tool_buttons[id].button_pressed = id == tool_id


func selected_layer_id() -> StringName:
	var item := layer_tree.get_selected()
	return item.get_metadata(0) if item != null else StringName()


func selected_asset_id() -> StringName:
	var selected := asset_list.get_selected_items()
	return asset_list.get_item_metadata(selected[0]) if not selected.is_empty() else StringName()


func selected_collision_preset_id() -> StringName:
	var index := collision_preset_option.selected
	return collision_preset_option.get_item_metadata(index) if index >= 0 else StringName()


func selected_terrain() -> Array:
	var index := terrain_option.selected
	return terrain_option.get_item_metadata(index) if index >= 0 else []


func set_cursor_cell(cell: Vector2i, world_position: Vector2) -> void:
	cursor_label.text = "格坐标：%d, %d    世界：%.0f, %.0f" % [cell.x, cell.y, world_position.x, world_position.y]


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "files" and not data.get("files", []).is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	plugin.register_dropped_resources(data.get("files", []))


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
