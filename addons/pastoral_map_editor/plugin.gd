@tool
extends EditorPlugin

const DEFAULT_PROFILE_PATH := "res://data/maps/farm/farm_profile.tres"
const MAP_CONTENT_ROOT := "res://src/world/maps/content"

enum ToolMode {
	SELECT,
	PENCIL,
	ERASER,
	PICKER,
	RECT,
	FILL,
	TERRAIN,
	ASSET,
	COLLISION_RECT,
	COLLISION_CIRCLE,
	COLLISION_POLYGON,
}

const TOOL_IDS := {
	"select": ToolMode.SELECT,
	"pencil": ToolMode.PENCIL,
	"eraser": ToolMode.ERASER,
	"picker": ToolMode.PICKER,
	"rect": ToolMode.RECT,
	"fill": ToolMode.FILL,
	"terrain": ToolMode.TERRAIN,
	"asset": ToolMode.ASSET,
	"collision_rect": ToolMode.COLLISION_RECT,
	"collision_circle": ToolMode.COLLISION_CIRCLE,
	"collision_polygon": ToolMode.COLLISION_POLYGON,
}

var dock: PastoralMapEditorDock
var active_map: EditableMap2D
var selected_layer: Node
var selected_asset: MapAssetEntry
var selected_collision_preset: CollisionPreset
var selected_source_id: int = -1
var selected_atlas_coords: Vector2i = Vector2i(-1, -1)
var selected_alternative: int = 0
var tool_mode: ToolMode = ToolMode.SELECT
var grid_visible := true
var snap_enabled := true
var drag_start_cell := Vector2i.ZERO
var drag_start_position := Vector2.ZERO
var painting := false
var pending_before := {}
var pending_after := {}
var polygon_points: PackedVector2Array = []

var open_dialog: EditorFileDialog
var save_dialog: EditorFileDialog
var resource_dialog: EditorFileDialog
var import_dialog: EditorFileDialog
var tileset_save_dialog: EditorFileDialog
var pending_save_mode := ""
var pending_tileset_texture: Texture2D
var tileset_options_dialog: ConfirmationDialog
var tile_width_spin: SpinBox
var tile_height_spin: SpinBox
var tile_margin_spin: SpinBox
var tile_separation_spin: SpinBox
var asset_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	asset_inspector = preload("res://addons/pastoral_map_editor/map_asset_inspector.gd").new(self)
	add_inspector_plugin(asset_inspector)
	dock = PastoralMapEditorDock.new()
	dock.name = "PastoralMapEditor"
	dock.setup(self)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)
	_build_dialogs()
	scene_changed.connect(_on_scene_changed)
	set_force_draw_over_forwarding_enabled()
	_refresh_active_map()
	if "--map-editor-smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_editor_smoke_test")


func _run_editor_smoke_test() -> void:
	await preload("res://tools/map_editor/editor_smoke_test.gd").new().run(self)


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	remove_control_from_docks(dock)
	remove_inspector_plugin(asset_inspector)
	asset_inspector = null
	dock.queue_free()
	dock = null


func _handles(object: Object) -> bool:
	return _find_map_for_object(object) != null


func _edit(object: Object) -> void:
	var edited_map := _find_map_for_object(object)
	if edited_map != null:
		active_map = edited_map
		if object is MapTileLayer or object is MapLayer2D:
			selected_layer = object
		elif selected_layer == null or selected_layer.get_parent() != active_map:
			selected_layer = active_map.get_layer(&"ground")
		_refresh_dock()


func _on_scene_changed(_scene_root: Node) -> void:
	# The editor can emit scene_changed before the freshly opened scene has
	# become the edited root. Refresh once immediately and once on the next
	# editor frame so programmatic opens and regular UI opens behave alike.
	_refresh_active_map()
	call_deferred("_refresh_active_map")


func _refresh_active_map() -> void:
	active_map = _find_map_in_tree(get_editor_interface().get_edited_scene_root())
	selected_layer = active_map.get_layer(&"ground") if active_map != null else null
	selected_asset = null
	selected_collision_preset = null
	selected_source_id = -1
	selected_atlas_coords = Vector2i(-1, -1)
	_refresh_dock()


func _refresh_dock() -> void:
	if dock == null:
		return
	if not is_instance_valid(selected_layer):
		selected_layer = active_map.get_layer(&"ground") if active_map != null else null
	dock.refresh(active_map, selected_layer)
	if selected_layer is MapTileLayer:
		dock.refresh_tiles(selected_layer.tile_set)
	elif active_map != null and active_map.profile != null:
		dock.refresh_tiles(active_map.profile.primary_tileset)


func _find_map_for_object(object: Object) -> EditableMap2D:
	if object is EditableMap2D:
		return object
	if object is Node:
		var current := object as Node
		while current != null:
			if current is EditableMap2D:
				return current
			current = current.get_parent()
	return _find_map_in_tree(get_editor_interface().get_edited_scene_root())


func _find_map_in_tree(root: Node) -> EditableMap2D:
	if root == null:
		return null
	if root is EditableMap2D:
		return root
	for child in root.get_children():
		var found := _find_map_in_tree(child)
		if found != null:
			return found
	return null


func _build_dialogs() -> void:
	open_dialog = _new_editor_file_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, EditorFileDialog.ACCESS_RESOURCES)
	open_dialog.filters = PackedStringArray(["*.tscn ; 地图场景"])
	open_dialog.file_selected.connect(_open_map_path)
	dock.add_child(open_dialog)

	save_dialog = _new_editor_file_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE, EditorFileDialog.ACCESS_RESOURCES)
	save_dialog.filters = PackedStringArray(["*.tscn ; 地图场景"])
	save_dialog.file_selected.connect(_save_dialog_selected)
	dock.add_child(save_dialog)

	resource_dialog = _new_editor_file_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, EditorFileDialog.ACCESS_RESOURCES)
	resource_dialog.filters = PackedStringArray([
		"*.tres,*.res ; Godot 资源",
		"*.tscn,*.scn ; PackedScene",
		"*.png,*.jpg,*.jpeg,*.svg,*.webp ; Texture2D",
	])
	resource_dialog.file_selected.connect(_register_resource_path)
	dock.add_child(resource_dialog)

	import_dialog = _new_editor_file_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, EditorFileDialog.ACCESS_FILESYSTEM)
	import_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.svg,*.webp ; 图片"])
	import_dialog.file_selected.connect(_import_texture_path)
	dock.add_child(import_dialog)

	tileset_save_dialog = _new_editor_file_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE, EditorFileDialog.ACCESS_RESOURCES)
	tileset_save_dialog.filters = PackedStringArray(["*.tres ; TileSet 资源"])
	tileset_save_dialog.file_selected.connect(_save_new_tileset)
	dock.add_child(tileset_save_dialog)

	tileset_options_dialog = ConfirmationDialog.new()
	tileset_options_dialog.title = "由贴图创建 TileSet"
	var options := GridContainer.new()
	options.columns = 2
	tileset_options_dialog.add_child(options)
	tile_width_spin = _add_spin_option(options, "瓦片宽度", 1, 1024, 64)
	tile_height_spin = _add_spin_option(options, "瓦片高度", 1, 1024, 64)
	tile_margin_spin = _add_spin_option(options, "边距", 0, 256, 0)
	tile_separation_spin = _add_spin_option(options, "间距", 0, 256, 0)
	tileset_options_dialog.confirmed.connect(_choose_tileset_save_path)
	dock.add_child(tileset_options_dialog)


func _new_editor_file_dialog(mode: EditorFileDialog.FileMode, access: EditorFileDialog.Access) -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = mode
	dialog.access = access
	dialog.size = Vector2i(900, 620)
	return dialog


func _add_spin_option(parent: GridContainer, label_text: String, minimum: float, maximum: float, value: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = value
	parent.add_child(spin)
	return spin


func create_new_map() -> void:
	pending_save_mode = "new"
	save_dialog.current_path = MAP_CONTENT_ROOT + "/NewMap.tscn"
	save_dialog.popup_centered_ratio(0.8)


func open_map() -> void:
	open_dialog.current_dir = MAP_CONTENT_ROOT
	open_dialog.popup_centered_ratio(0.8)


func save_map() -> void:
	if active_map == null:
		_set_status("没有可保存的地图")
		return
	get_editor_interface().save_scene()
	_set_status("地图已保存")


func save_map_as() -> void:
	if active_map == null:
		_set_status("没有可另存的地图")
		return
	pending_save_mode = "save_as"
	var root := get_editor_interface().get_edited_scene_root()
	var current_path := root.scene_file_path if root != null else ""
	save_dialog.current_path = current_path if not current_path.is_empty() else MAP_CONTENT_ROOT + "/Map.tscn"
	save_dialog.popup_centered_ratio(0.8)


func resize_map_from_dock() -> void:
	if active_map == null:
		_set_status("请先打开地图")
		return
	var new_size := Vector2i(int(dock.map_width_spin.value), int(dock.map_height_spin.value))
	var old_size := active_map.size_in_tiles
	if new_size == old_size:
		_set_status("地图尺寸没有变化")
		return
	var new_world_rect := Rect2(Vector2.ZERO, Vector2(new_size * active_map.tile_size))
	for layer_node in active_map.get_children():
		if not layer_node is MapLayer2D:
			continue
		for child in layer_node.get_children():
			if child is MapCollisionBody2D and child.is_world_boundary:
				continue
			if child is Node2D and not new_world_rect.has_point(child.position):
				_set_status("无法缩放：%s 将位于地图外" % active_map.get_path_to(child))
				dock.map_width_spin.value = old_size.x
				dock.map_height_spin.value = old_size.y
				return
	var before := _capture_tile_layer_states(active_map)
	var after := _resized_tile_layer_states(active_map, before, old_size, new_size)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("调整地图尺寸", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_apply_map_resize", active_map, new_size, after)
	undo_redo.add_undo_method(self, "_apply_map_resize", active_map, old_size, before)
	undo_redo.commit_action()
	_set_status("地图尺寸已调整为 %dx%d，边界已同步重建" % [new_size.x, new_size.y])


func _capture_tile_layer_states(map: EditableMap2D) -> Dictionary:
	var result := {}
	for child in map.get_children():
		if not child is MapTileLayer:
			continue
		var states := {}
		for cell in child.get_used_cells():
			states[cell] = _capture_cell(child, cell)
		result[str(child.layer_id)] = states
	return result


func _resized_tile_layer_states(
	map: EditableMap2D,
	before: Dictionary,
	old_size: Vector2i,
	new_size: Vector2i
) -> Dictionary:
	var result := {}
	for layer_id in before:
		var states := {}
		for cell in before[layer_id]:
			if cell.x >= 0 and cell.y >= 0 and cell.x < new_size.x and cell.y < new_size.y:
				states[cell] = before[layer_id][cell]
		result[layer_id] = states
	var ground := map.get_layer(&"ground") as MapTileLayer
	if ground != null and (new_size.x > old_size.x or new_size.y > old_size.y):
		var ground_states: Dictionary = result.get("ground", {})
		var fill_state := _default_ground_tile_state(ground)
		if not fill_state.is_empty():
			for y in range(new_size.y):
				for x in range(new_size.x):
					if x >= old_size.x or y >= old_size.y:
						ground_states[Vector2i(x, y)] = fill_state
		result["ground"] = ground_states
	return result


func _default_ground_tile_state(layer: MapTileLayer) -> Array:
	if layer.tile_set == null or layer.tile_set.get_source_count() == 0:
		return []
	var source_id := layer.tile_set.get_source_id(0)
	var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.get_tiles_count() == 0:
		return []
	return [source_id, atlas.get_tile_id(0), 0]


func _apply_map_resize(map: EditableMap2D, size: Vector2i, layer_states: Dictionary) -> void:
	map.size_in_tiles = size
	for child in map.get_children():
		if not child is MapTileLayer:
			continue
		child.clear()
		var states: Dictionary = layer_states.get(str(child.layer_id), {})
		_apply_cell_states(child, states)
	map.rebuild_world_boundaries()
	if map == active_map:
		_refresh_dock()


func run_map() -> void:
	if active_map == null:
		_set_status("没有可运行的地图")
		return
	get_editor_interface().save_scene()
	get_editor_interface().play_current_scene()


func undo() -> void:
	var history := _get_active_map_history()
	if history != null and history.has_undo():
		history.undo()
	_refresh_dock()


func redo() -> void:
	var history := _get_active_map_history()
	if history != null and history.has_redo():
		history.redo()
	_refresh_dock()


func _get_active_map_history() -> UndoRedo:
	if active_map == null:
		return null
	var manager := get_undo_redo()
	var history_id := manager.get_object_history_id(active_map)
	if history_id == EditorUndoRedoManager.INVALID_HISTORY:
		return null
	return manager.get_history_undo_redo(history_id)


func _open_map_path(path: String) -> void:
	get_editor_interface().open_scene_from_path(path)


func _save_dialog_selected(path: String) -> void:
	if pending_save_mode == "new":
		_create_new_map_at(path)
	elif pending_save_mode == "save_as":
		get_editor_interface().save_scene_as(path)
	pending_save_mode = ""


func _create_new_map_at(path: String) -> void:
	var profile := load(DEFAULT_PROFILE_PATH) as MapProfile
	if profile == null:
		_set_status("无法加载默认 Profile: %s" % DEFAULT_PROFILE_PATH)
		return
	var root := EditableMap2D.new()
	root.name = path.get_file().get_basename().to_pascal_case()
	root.map_id = StringName(path.get_file().get_basename().to_snake_case())
	root.display_name = root.name
	root.size_in_tiles = profile.default_size
	root.tile_size = profile.tile_size
	root.profile = profile
	for spec in profile.layer_specs:
		var layer := _create_layer_for_spec(spec, profile)
		root.add_child(layer)
		layer.owner = root
	var ground := root.get_layer(&"ground") as MapTileLayer
	if ground != null:
		var fill_state := _default_ground_tile_state(ground)
		if not fill_state.is_empty():
			for y in range(root.size_in_tiles.y):
				for x in range(root.size_in_tiles.x):
					ground.set_cell(Vector2i(x, y), fill_state[0], fill_state[1], fill_state[2])
	root.rebuild_world_boundaries()
	var marker_layer := root.get_layer(&"markers") as MapLayer2D
	if marker_layer != null:
		var center := Vector2(root.size_in_tiles * root.tile_size) / 2.0
		for marker_index in range(profile.required_marker_ids.size()):
			var marker := MapMarker2D.new()
			marker.marker_id = StringName(profile.required_marker_ids[marker_index])
			marker.name = str(marker.marker_id).to_pascal_case()
			marker.marker_kind = MapMarker2D.MarkerKind.SPAWN
			marker.position = center + Vector2(marker_index * root.tile_size.x, 0)
			marker_layer.add_child(marker)
			marker.owner = root
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.free()
		_set_status("新地图打包失败: %s" % error_string(pack_error))
		return
	var save_error := ResourceSaver.save(packed, path)
	root.free()
	if save_error != OK:
		_set_status("新地图保存失败: %s" % error_string(save_error))
		return
	get_editor_interface().get_resource_filesystem().update_file(path)
	# Opening a scene from a file-dialog/plugin callback must be deferred until
	# the editor finishes the current UI transaction.
	get_editor_interface().call_deferred("open_scene_from_path", path)
	_set_status("已创建地图: %s" % path)


func _create_layer_for_spec(spec: MapLayerSpec, profile: MapProfile) -> Node2D:
	if spec.kind == MapLayerSpec.LayerKind.TILE:
		var tile_layer := MapTileLayer.new()
		tile_layer.configure_from_spec(spec)
		tile_layer.tile_set = profile.primary_tileset
		return tile_layer
	var layer := MapLayer2D.new()
	layer.configure_from_spec(spec)
	return layer


func validate_active_map() -> void:
	if active_map == null:
		_set_status("没有可校验的地图")
		return
	var issues := active_map.validate()
	dock.show_issues(issues)


func focus_issue(index: int) -> void:
	if active_map == null:
		return
	var path: NodePath = dock.issue_list.get_item_metadata(index)
	var node := active_map.get_node_or_null(path)
	if node != null:
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(node)


func set_active_tool(tool_id: String) -> void:
	tool_mode = TOOL_IDS.get(tool_id, ToolMode.SELECT)
	painting = false
	pending_before.clear()
	pending_after.clear()
	if tool_mode != ToolMode.COLLISION_POLYGON:
		polygon_points.clear()
	dock.set_tool(tool_id)
	update_overlays()


func set_grid_visible(value: bool) -> void:
	grid_visible = value
	update_overlays()


func set_snap_enabled(value: bool) -> void:
	snap_enabled = value


func select_layer_from_dock() -> void:
	if active_map == null:
		return
	selected_layer = active_map.get_layer(dock.selected_layer_id())
	if selected_layer != null:
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(selected_layer)
	if selected_layer is MapTileLayer:
		dock.refresh_tiles(selected_layer.tile_set)
	dock.refresh_layers(active_map, selected_layer)


func add_layer_from_dock() -> void:
	if active_map == null:
		return
	var requested_id := StringName(dock.layer_name_edit.text.strip_edges().to_snake_case())
	if requested_id.is_empty() or active_map.get_layer(requested_id) != null:
		_set_status("图层 ID 为空或已存在")
		return
	var spec := MapLayerSpec.new()
	spec.layer_id = requested_id
	spec.display_name = requested_id.to_pascal_case()
	spec.kind = dock.layer_kind_option.selected as MapLayerSpec.LayerKind
	var layer := _create_layer_for_spec(spec, active_map.profile)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("添加地图图层", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_add_owned_node", active_map, layer, active_map)
	undo_redo.add_undo_method(active_map, "remove_child", layer)
	undo_redo.add_do_reference(layer)
	undo_redo.commit_action()
	selected_layer = layer
	_refresh_dock()


func rename_layer_from_dock() -> void:
	if active_map == null or selected_layer == null:
		return
	var new_id := StringName(dock.layer_name_edit.text.strip_edges().to_snake_case())
	if new_id.is_empty() or (active_map.get_layer(new_id) != null and active_map.get_layer(new_id) != selected_layer):
		_set_status("新的图层 ID 为空或已存在")
		return
	var old_id: StringName = selected_layer.layer_id
	var undo_redo := get_undo_redo()
	undo_redo.create_action("重命名地图图层", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_property(selected_layer, "layer_id", new_id)
	undo_redo.add_do_property(selected_layer, "name", new_id.to_pascal_case())
	undo_redo.add_undo_property(selected_layer, "layer_id", old_id)
	undo_redo.add_undo_property(selected_layer, "name", selected_layer.name)
	undo_redo.commit_action()
	_refresh_dock()


func duplicate_layer() -> void:
	if active_map == null or selected_layer == null:
		return
	var copy := selected_layer.duplicate()
	var base_id := str(selected_layer.layer_id) + "_copy"
	var unique_id := base_id
	var suffix := 2
	while active_map.get_layer(unique_id) != null:
		unique_id = base_id + str(suffix)
		suffix += 1
	copy.layer_id = StringName(unique_id)
	copy.name = unique_id.to_pascal_case()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("复制地图图层", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_add_owned_node", active_map, copy, active_map)
	undo_redo.add_undo_method(active_map, "remove_child", copy)
	undo_redo.add_do_reference(copy)
	undo_redo.commit_action()
	selected_layer = copy
	_refresh_dock()


func delete_layer() -> void:
	if active_map == null or selected_layer == null:
		return
	var spec := active_map.profile.get_layer_spec(selected_layer.layer_id) if active_map.profile != null else null
	if spec != null and spec.required:
		_set_status("必需图层不能删除")
		return
	var old_index := selected_layer.get_index()
	var layer := selected_layer
	var undo_redo := get_undo_redo()
	undo_redo.create_action("删除地图图层", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(active_map, "remove_child", layer)
	undo_redo.add_undo_method(self, "_restore_owned_node", active_map, layer, active_map, old_index)
	undo_redo.add_undo_reference(layer)
	undo_redo.commit_action()
	selected_layer = null
	_refresh_dock()


func move_layer(direction: int) -> void:
	if active_map == null or selected_layer == null:
		return
	var old_index := selected_layer.get_index()
	var new_index := clampi(old_index + direction, 0, active_map.get_child_count() - 1)
	if new_index == old_index:
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action("调整地图图层顺序", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(active_map, "move_child", selected_layer, new_index)
	undo_redo.add_undo_method(active_map, "move_child", selected_layer, old_index)
	undo_redo.commit_action()
	_refresh_dock()


func toggle_layer_visibility() -> void:
	if selected_layer == null:
		return
	_set_undoable_property(selected_layer, "visible", not selected_layer.visible, "切换图层显示")


func toggle_layer_lock() -> void:
	if selected_layer == null or not (selected_layer is MapTileLayer or selected_layer is MapLayer2D):
		return
	_set_undoable_property(selected_layer, "locked", not selected_layer.locked, "切换图层锁定")


func set_layer_opacity(value: float) -> void:
	if selected_layer == null:
		return
	var color: Color = selected_layer.modulate
	color.a = value
	_set_undoable_property(selected_layer, "modulate", color, "调整图层透明度")


func set_layer_y_sort(value: bool) -> void:
	if selected_layer == null:
		return
	_set_undoable_property(selected_layer, "y_sort_enabled", value, "切换图层 Y Sort")


func _set_undoable_property(object: Object, property: StringName, value: Variant, action_name: String) -> void:
	var old_value: Variant = object.get(property)
	if old_value == value:
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_property(object, property, value)
	undo_redo.add_undo_property(object, property, old_value)
	undo_redo.commit_action()
	_refresh_dock()


func refresh_assets(_query: String = "") -> void:
	if dock != null:
		dock.refresh_assets(active_map)


func select_asset(index: int) -> void:
	if active_map == null or active_map.profile == null or active_map.profile.asset_library == null:
		return
	var asset_id: StringName = dock.asset_list.get_item_metadata(index)
	selected_asset = active_map.profile.asset_library.get_entry(asset_id)
	if selected_asset != null and selected_asset.kind == MapAssetEntry.AssetKind.TILE_SET:
		var tile_set := selected_asset.resource as TileSet
		dock.refresh_tiles(tile_set)
		if selected_layer is MapTileLayer and selected_layer.tile_set != tile_set:
			_set_undoable_property(selected_layer, "tile_set", tile_set, "设置图层 TileSet")


func open_asset(index: int) -> void:
	select_asset(index)
	if selected_asset != null:
		get_editor_interface().edit_resource(selected_asset.resource)


func register_resource() -> void:
	if active_map == null:
		_set_status("请先打开地图")
		return
	resource_dialog.popup_centered_ratio(0.8)


func register_dropped_resources(paths: Variant) -> void:
	if active_map == null or active_map.profile == null:
		_set_status("请先打开地图")
		return
	var registered := 0
	for path_value in paths:
		var path := str(path_value)
		var resource := load(path)
		if resource is TileSet or resource is Texture2D or resource is PackedScene:
			_register_loaded_resource(resource, path)
			registered += 1
	if registered == 0:
		_set_status("拖放内容中没有可登记的 TileSet、贴图或场景")
	else:
		_set_status("已通过拖放登记 %d 个资源" % registered)


func _register_resource_path(path: String) -> void:
	var resource := load(path)
	if resource == null:
		_set_status("无法加载资源: %s" % path)
		return
	_register_loaded_resource(resource, path)


func _register_loaded_resource(resource: Resource, path: String) -> void:
	var library := active_map.profile.asset_library
	if library == null:
		library = MapAssetLibrary.new()
		active_map.profile.asset_library = library
	var entry := MapAssetEntry.new()
	entry.asset_id = _unique_asset_id(path.get_file().get_basename().to_snake_case())
	entry.display_name = path.get_file().get_basename().capitalize()
	entry.resource = resource
	if resource is TileSet:
		entry.kind = MapAssetEntry.AssetKind.TILE_SET
		entry.default_layer_id = &"ground"
	elif resource is Texture2D:
		entry.kind = MapAssetEntry.AssetKind.DECORATION
		entry.default_layer_id = &"decoration"
		entry.thumbnail = resource
	elif resource is PackedScene:
		entry.kind = MapAssetEntry.AssetKind.SCENE
		entry.default_layer_id = &"objects"
	else:
		_set_status("只支持 TileSet、Texture2D 和 PackedScene")
		return
	if not library.register(entry):
		_set_status("资源登记失败")
		return
	_save_profile_resources()
	dock.refresh_assets(active_map)
	_set_status("已登记资源: %s" % entry.display_name)


func _unique_asset_id(base: String) -> StringName:
	var candidate := base
	var suffix := 2
	while active_map.profile.asset_library != null and active_map.profile.asset_library.get_entry(candidate) != null:
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return StringName(candidate)


func unregister_selected_asset() -> void:
	if active_map == null or selected_asset == null or active_map.profile.asset_library == null:
		return
	var removed_id := selected_asset.asset_id
	if active_map.profile.asset_library.unregister(removed_id):
		_save_profile_resources()
		selected_asset = null
		dock.refresh_assets(active_map)
		_set_status("已取消登记；源文件未删除: %s" % removed_id)


func import_external_texture() -> void:
	if active_map == null or active_map.profile == null:
		_set_status("请先打开地图")
		return
	import_dialog.popup_centered_ratio(0.8)


func _import_texture_path(source_path: String) -> void:
	var profile_id := str(active_map.profile.profile_id)
	var destination_dir := "res://assets/maps/%s" % profile_id
	var absolute_dir := ProjectSettings.globalize_path(destination_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_set_status("无法创建资源目录: %s" % error_string(mkdir_error))
		return
	var filename := source_path.get_file()
	var stem := filename.get_basename()
	var extension := filename.get_extension()
	var destination := destination_dir.path_join(filename)
	var suffix := 2
	while FileAccess.file_exists(destination):
		destination = destination_dir.path_join("%s_%d.%s" % [stem, suffix, extension])
		suffix += 1
	var copy_error := DirAccess.copy_absolute(source_path, ProjectSettings.globalize_path(destination))
	if copy_error != OK:
		_set_status("图片导入失败: %s" % error_string(copy_error))
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().get_resource_filesystem().reimport_files(PackedStringArray([destination]))
	var imported := load(destination)
	if imported is Texture2D:
		_register_loaded_resource(imported, destination)
	else:
		_set_status("图片已复制，等待 Godot 完成导入: %s" % destination)


func create_tileset_from_selected() -> void:
	if selected_asset == null or selected_asset.kind != MapAssetEntry.AssetKind.DECORATION:
		_set_status("请先选择一个贴图资源")
		return
	pending_tileset_texture = selected_asset.resource as Texture2D
	if active_map != null:
		tile_width_spin.value = active_map.tile_size.x
		tile_height_spin.value = active_map.tile_size.y
	tileset_options_dialog.popup_centered()


func _choose_tileset_save_path() -> void:
	if pending_tileset_texture == null:
		return
	tileset_save_dialog.current_path = "res://assets/maps/%s/%s_tileset.tres" % [
		active_map.profile.profile_id,
		str(selected_asset.asset_id),
	]
	tileset_save_dialog.popup_centered_ratio(0.8)


func _save_new_tileset(path: String) -> void:
	if pending_tileset_texture == null:
		return
	var region_size := Vector2i(int(tile_width_spin.value), int(tile_height_spin.value))
	var margin := int(tile_margin_spin.value)
	var separation := int(tile_separation_spin.value)
	var tile_set := TileSet.new()
	tile_set.tile_size = region_size
	var atlas := TileSetAtlasSource.new()
	atlas.texture = pending_tileset_texture
	atlas.texture_region_size = region_size
	atlas.margins = Vector2i(margin, margin)
	atlas.separation = Vector2i(separation, separation)
	var available := Vector2i(pending_tileset_texture.get_size()) - atlas.margins * 2
	var step := region_size + atlas.separation
	var columns := maxi(0, (available.x + separation) / step.x)
	var rows := maxi(0, (available.y + separation) / step.y)
	for y in range(rows):
		for x in range(columns):
			atlas.create_tile(Vector2i(x, y))
	tile_set.add_source(atlas)
	var error := ResourceSaver.save(tile_set, path)
	if error != OK:
		_set_status("TileSet 保存失败: %s" % error_string(error))
		return
	get_editor_interface().get_resource_filesystem().scan()
	_register_loaded_resource(tile_set, path)
	pending_tileset_texture = null


func _save_profile_resources() -> void:
	if active_map == null or active_map.profile == null:
		return
	var library := active_map.profile.asset_library
	if library != null and not library.resource_path.is_empty():
		ResourceSaver.save(library)
	if not active_map.profile.resource_path.is_empty():
		ResourceSaver.save(active_map.profile)


func select_tile(index: int) -> void:
	var data: Array = dock.tile_list.get_item_metadata(index)
	if data.size() < 2:
		return
	selected_source_id = data[0]
	selected_atlas_coords = data[1]
	selected_alternative = 0
	if tool_mode == ToolMode.SELECT:
		set_active_tool("pencil")


func select_collision_preset(index: int) -> void:
	if active_map == null or active_map.profile == null:
		return
	var preset_id: StringName = dock.collision_preset_option.get_item_metadata(index)
	selected_collision_preset = active_map.profile.get_collision_preset(preset_id)


func select_terrain(index: int) -> void:
	var terrain_data: Array = dock.terrain_option.get_item_metadata(index)
	if terrain_data.size() >= 2:
		_set_status("Terrain：Set %d / %d" % [int(terrain_data[0]) + 1, int(terrain_data[1]) + 1])


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if active_map == null:
		return false
	if event is InputEventMouseMotion:
		var world := _event_to_world(event.position)
		var cell := Vector2i(
			floori(world.x / active_map.tile_size.x),
			floori(world.y / active_map.tile_size.y)
		)
		dock.set_cursor_cell(cell, world)
	if tool_mode == ToolMode.SELECT:
		return false
	if event is InputEventKey and event.pressed:
		if tool_mode == ToolMode.COLLISION_POLYGON and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_commit_collision_polygon()
			return true
		if event.keycode == KEY_ESCAPE:
			polygon_points.clear()
			painting = false
			update_overlays()
			return true
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if event.pressed:
			return _begin_canvas_action(event.position)
		return _end_canvas_action(event.position)
	if event is InputEventMouseMotion and painting:
		if tool_mode in [ToolMode.PENCIL, ToolMode.ERASER]:
			_apply_drag_cell(_event_to_cell(event.position))
			update_overlays()
			return true
		update_overlays()
		return true
	return false


func _begin_canvas_action(viewport_position: Vector2) -> bool:
	if tool_mode in [ToolMode.COLLISION_RECT, ToolMode.COLLISION_CIRCLE, ToolMode.COLLISION_POLYGON]:
		return _begin_collision_action(viewport_position)
	if tool_mode == ToolMode.ASSET:
		_place_selected_asset(viewport_position)
		return true
	var layer := selected_layer as MapTileLayer
	if layer == null or layer.locked or not layer.visible:
		_set_status("请选择一个可见且未锁定的瓦片图层")
		return false
	var cell := _event_to_cell(viewport_position)
	match tool_mode:
		ToolMode.PICKER:
			_pick_cell(layer, cell)
			return true
		ToolMode.FILL:
			_fill_cells(layer, cell)
			return true
		ToolMode.TERRAIN:
			_paint_terrain(layer, cell)
			return true
		ToolMode.PENCIL, ToolMode.ERASER:
			if tool_mode == ToolMode.PENCIL and selected_source_id < 0:
				_set_status("请先选择瓦片")
				return true
			painting = true
			pending_before.clear()
			pending_after.clear()
			drag_start_cell = cell
			_apply_drag_cell(cell)
			return true
		ToolMode.RECT:
			if selected_source_id < 0:
				_set_status("请先选择瓦片")
				return true
			painting = true
			drag_start_cell = cell
			return true
	return false


func _end_canvas_action(viewport_position: Vector2) -> bool:
	if not painting:
		return false
	if tool_mode in [ToolMode.COLLISION_RECT, ToolMode.COLLISION_CIRCLE]:
		_create_collision_shape(drag_start_position, _event_to_world(viewport_position), tool_mode)
		painting = false
		update_overlays()
		return true
	if tool_mode == ToolMode.RECT:
		_paint_rectangle(drag_start_cell, _event_to_cell(viewport_position))
		painting = false
		update_overlays()
		return true
	if tool_mode in [ToolMode.PENCIL, ToolMode.ERASER]:
		painting = false
		_commit_cell_action("绘制瓦片" if tool_mode == ToolMode.PENCIL else "擦除瓦片")
		update_overlays()
		return true
	painting = false
	return false


func _event_to_world(viewport_position: Vector2) -> Vector2:
	var viewport := active_map.get_viewport()
	if viewport == null:
		return viewport_position
	return viewport.get_canvas_transform().affine_inverse() * viewport_position


func _event_to_cell(viewport_position: Vector2) -> Vector2i:
	var layer := selected_layer as MapTileLayer
	if layer == null:
		return Vector2i.ZERO
	return layer.local_to_map(layer.to_local(_event_to_world(viewport_position)))


func _snap_world(world_position: Vector2) -> Vector2:
	if not snap_enabled or active_map == null:
		return world_position
	return Vector2(
		round(world_position.x / active_map.tile_size.x) * active_map.tile_size.x,
		round(world_position.y / active_map.tile_size.y) * active_map.tile_size.y
	)


func _capture_cell(layer: MapTileLayer, cell: Vector2i) -> Array:
	return [
		layer.get_cell_source_id(cell),
		layer.get_cell_atlas_coords(cell),
		layer.get_cell_alternative_tile(cell),
	]


func _apply_drag_cell(cell: Vector2i) -> void:
	var layer := selected_layer as MapTileLayer
	if layer == null or not _cell_in_bounds(cell):
		return
	if pending_before.has(cell):
		return
	pending_before[cell] = _capture_cell(layer, cell)
	if tool_mode == ToolMode.ERASER:
		layer.erase_cell(cell)
	else:
		layer.set_cell(cell, selected_source_id, selected_atlas_coords, selected_alternative)
	pending_after[cell] = _capture_cell(layer, cell)


func _commit_cell_action(action_name: String) -> void:
	var layer := selected_layer as MapTileLayer
	if layer == null or pending_before.is_empty():
		pending_before.clear()
		pending_after.clear()
		return
	_apply_cell_states(layer, pending_before)
	var before := pending_before.duplicate(true)
	var after := pending_after.duplicate(true)
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_apply_cell_states", layer, after)
	undo_redo.add_undo_method(self, "_apply_cell_states", layer, before)
	undo_redo.commit_action()
	pending_before.clear()
	pending_after.clear()


func _apply_cell_states(layer: MapTileLayer, states: Dictionary) -> void:
	for cell in states:
		var state: Array = states[cell]
		if int(state[0]) < 0:
			layer.erase_cell(cell)
		else:
			layer.set_cell(cell, int(state[0]), state[1], int(state[2]))


func _paint_rectangle(from: Vector2i, to: Vector2i) -> void:
	pending_before.clear()
	pending_after.clear()
	var minimum := Vector2i(mini(from.x, to.x), mini(from.y, to.y))
	var maximum := Vector2i(maxi(from.x, to.x), maxi(from.y, to.y))
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_apply_drag_cell(Vector2i(x, y))
	_commit_cell_action("矩形绘制瓦片")


func _fill_cells(layer: MapTileLayer, start: Vector2i) -> void:
	if selected_source_id < 0 or not _cell_in_bounds(start):
		return
	var target := _capture_cell(layer, start)
	var replacement := [selected_source_id, selected_atlas_coords, selected_alternative]
	if target == replacement:
		return
	var queue: Array[Vector2i] = [start]
	var visited := {}
	pending_before.clear()
	pending_after.clear()
	while not queue.is_empty():
		var cell := queue.pop_front()
		if visited.has(cell) or not _cell_in_bounds(cell):
			continue
		visited[cell] = true
		if _capture_cell(layer, cell) != target:
			continue
		_apply_drag_cell(cell)
		queue.append(cell + Vector2i.LEFT)
		queue.append(cell + Vector2i.RIGHT)
		queue.append(cell + Vector2i.UP)
		queue.append(cell + Vector2i.DOWN)
	_commit_cell_action("填充瓦片区域")


func _pick_cell(layer: MapTileLayer, cell: Vector2i) -> void:
	var state := _capture_cell(layer, cell)
	if int(state[0]) < 0:
		_set_status("该格为空")
		return
	selected_source_id = state[0]
	selected_atlas_coords = state[1]
	selected_alternative = state[2]
	for index in range(dock.tile_list.item_count):
		var data: Array = dock.tile_list.get_item_metadata(index)
		if data[0] == selected_source_id and data[1] == selected_atlas_coords:
			dock.tile_list.select(index)
			break
	set_active_tool("pencil")


func _paint_terrain(layer: MapTileLayer, cell: Vector2i) -> void:
	if layer.tile_set == null or layer.tile_set.get_terrain_sets_count() == 0:
		_set_status("当前 TileSet 未配置 Terrain Set")
		return
	var selected_terrain := dock.selected_terrain()
	if selected_terrain.size() < 2:
		_set_status("请先选择 Terrain 类型")
		return
	var terrain_set := int(selected_terrain[0])
	var terrain := int(selected_terrain[1])
	var before := _capture_all_cells(layer)
	layer.set_cells_terrain_connect([cell], terrain_set, terrain)
	var after := _capture_all_cells(layer)
	_apply_cell_states(layer, before)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Terrain 自动连接", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_apply_cell_states", layer, after)
	undo_redo.add_undo_method(self, "_apply_cell_states", layer, before)
	undo_redo.commit_action()


func _capture_all_cells(layer: MapTileLayer) -> Dictionary:
	var result := {}
	for y in range(active_map.size_in_tiles.y):
		for x in range(active_map.size_in_tiles.x):
			var cell := Vector2i(x, y)
			result[cell] = _capture_cell(layer, cell)
	return result


func _cell_in_bounds(cell: Vector2i) -> bool:
	return active_map != null and cell.x >= 0 and cell.y >= 0 and cell.x < active_map.size_in_tiles.x and cell.y < active_map.size_in_tiles.y


func _place_selected_asset(viewport_position: Vector2) -> void:
	if active_map == null or selected_asset == null:
		_set_status("请先选择地图资源")
		return
	var target_layer := selected_layer
	var spec := active_map.get_layer_spec(target_layer.layer_id) if target_layer != null else null
	if spec == null or not spec.accepts_asset_kind(selected_asset.kind):
		target_layer = active_map.get_layer(selected_asset.default_layer_id)
		spec = active_map.get_layer_spec(selected_asset.default_layer_id)
	if target_layer == null or spec == null or not spec.accepts_asset_kind(selected_asset.kind):
		_set_status("资源与当前图层不匹配")
		return
	if target_layer.locked or not target_layer.visible:
		_set_status("目标图层已锁定或隐藏")
		return
	var node: Node2D
	if selected_asset.kind == MapAssetEntry.AssetKind.DECORATION:
		node = MapDecoration2D.new()
		node.configure(selected_asset)
	elif selected_asset.kind == MapAssetEntry.AssetKind.SCENE:
		node = (selected_asset.resource as PackedScene).instantiate() as Node2D
		if node != null:
			node.set_meta("map_asset_id", selected_asset.asset_id)
	else:
		_set_status("TileSet 资源需要应用到瓦片图层")
		return
	if node == null:
		_set_status("资源不是 Node2D 场景")
		return
	node.name = _unique_child_name(target_layer, selected_asset.asset_id.to_pascal_case())
	node.position = target_layer.to_local(_snap_world(_event_to_world(viewport_position)))
	var undo_redo := get_undo_redo()
	undo_redo.create_action("放置地图资源", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_add_owned_node", target_layer, node, active_map)
	undo_redo.add_undo_method(target_layer, "remove_child", node)
	undo_redo.add_do_reference(node)
	undo_redo.commit_action()
	call_deferred("_select_node_in_editor", node.get_instance_id())


func _begin_collision_action(viewport_position: Vector2) -> bool:
	var collision_layer := active_map.get_layer(&"collision") as MapLayer2D
	if collision_layer == null or collision_layer.locked or not collision_layer.visible:
		_set_status("碰撞图层不存在、已锁定或隐藏")
		return false
	selected_layer = collision_layer
	var local_position := collision_layer.to_local(_snap_world(_event_to_world(viewport_position)))
	if tool_mode == ToolMode.COLLISION_POLYGON:
		polygon_points.append(local_position)
		update_overlays()
		return true
	drag_start_position = local_position
	painting = true
	return true


func _create_collision_shape(from: Vector2, to: Vector2, mode: ToolMode) -> void:
	var collision_layer := active_map.get_layer(&"collision") as MapLayer2D
	if collision_layer == null:
		return
	var center := (from + to) / 2.0
	var dimensions := (to - from).abs()
	if dimensions.x < 4.0 or dimensions.y < 4.0:
		return
	var body := MapCollisionBody2D.new()
	body.name = _unique_child_name(collision_layer, "Collision")
	body.position = center
	body.preset = _current_collision_preset()
	body.apply_preset()
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	if mode == ToolMode.COLLISION_CIRCLE:
		var circle := CircleShape2D.new()
		circle.radius = maxf(dimensions.x, dimensions.y) / 2.0
		shape_node.shape = circle
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = dimensions
		shape_node.shape = rectangle
	body.add_child(shape_node)
	body.apply_preset()
	_add_collision_with_undo(collision_layer, body)


func _commit_collision_polygon() -> void:
	if active_map == null or polygon_points.size() < 3:
		_set_status("碰撞多边形至少需要 3 个点")
		return
	var collision_layer := active_map.get_layer(&"collision") as MapLayer2D
	if collision_layer == null:
		return
	var center := Vector2.ZERO
	for point in polygon_points:
		center += point
	center /= polygon_points.size()
	var body := MapCollisionBody2D.new()
	body.name = _unique_child_name(collision_layer, "CollisionPolygon")
	body.position = center
	body.preset = _current_collision_preset()
	body.apply_preset()
	var polygon := CollisionPolygon2D.new()
	polygon.name = "CollisionPolygon2D"
	var local_points := PackedVector2Array()
	for point in polygon_points:
		local_points.append(point - center)
	polygon.polygon = local_points
	body.add_child(polygon)
	body.apply_preset()
	_add_collision_with_undo(collision_layer, body)
	polygon_points.clear()
	update_overlays()


func _add_collision_with_undo(collision_layer: MapLayer2D, body: MapCollisionBody2D) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action("添加地图碰撞", UndoRedo.MERGE_DISABLE, active_map)
	undo_redo.add_do_method(self, "_add_owned_node", collision_layer, body, active_map)
	undo_redo.add_undo_method(collision_layer, "remove_child", body)
	undo_redo.add_do_reference(body)
	undo_redo.commit_action()
	var editable_shape := body.get_child(0) if body.get_child_count() > 0 else body
	call_deferred("_select_node_in_editor", editable_shape.get_instance_id())


func _current_collision_preset() -> CollisionPreset:
	if selected_collision_preset != null:
		return selected_collision_preset
	if active_map != null and active_map.profile != null:
		return active_map.profile.get_collision_preset(&"world_solid")
	return null


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if active_map == null:
		return
	if grid_visible:
		_draw_grid(overlay)
	if painting and tool_mode in [ToolMode.RECT, ToolMode.COLLISION_RECT, ToolMode.COLLISION_CIRCLE]:
		var start_world := Vector2.ZERO
		if tool_mode == ToolMode.RECT and selected_layer is MapTileLayer:
			start_world = selected_layer.to_global(selected_layer.map_to_local(drag_start_cell) - Vector2(active_map.tile_size) / 2.0)
		else:
			start_world = (active_map.get_layer(&"collision") as Node2D).to_global(drag_start_position)
		var start_screen := active_map.get_viewport().get_canvas_transform() * start_world
		var end_screen := overlay.get_local_mouse_position()
		var rect := Rect2(start_screen, end_screen - start_screen).abs()
		if tool_mode == ToolMode.COLLISION_CIRCLE:
			overlay.draw_circle(rect.get_center(), maxf(rect.size.x, rect.size.y) / 2.0, Color(1, 0.25, 0.2, 0.2))
		else:
			overlay.draw_rect(rect, Color(1, 0.8, 0.15, 0.2), true)
			overlay.draw_rect(rect, Color(1, 0.8, 0.15, 0.9), false, 2.0)
	if polygon_points.size() > 0:
		var collision_layer := active_map.get_layer(&"collision") as Node2D
		var screen_points := PackedVector2Array()
		for point in polygon_points:
			var world := collision_layer.to_global(point)
			screen_points.append(active_map.get_viewport().get_canvas_transform() * world)
		if screen_points.size() >= 2:
			overlay.draw_polyline(screen_points, Color(1, 0.35, 0.2), 2.0)
		for point in screen_points:
			overlay.draw_circle(point, 4.0, Color(1, 0.85, 0.2))


func _draw_grid(overlay: Control) -> void:
	var transform := active_map.get_viewport().get_canvas_transform() * active_map.global_transform
	var map_pixels := Vector2(active_map.size_in_tiles * active_map.tile_size)
	var color := Color(1, 1, 1, 0.12)
	for x in range(active_map.size_in_tiles.x + 1):
		var local_x := float(x * active_map.tile_size.x)
		overlay.draw_line(transform * Vector2(local_x, 0), transform * Vector2(local_x, map_pixels.y), color)
	for y in range(active_map.size_in_tiles.y + 1):
		var local_y := float(y * active_map.tile_size.y)
		overlay.draw_line(transform * Vector2(0, local_y), transform * Vector2(map_pixels.x, local_y), color)


func _add_owned_node(parent: Node, node: Node, owner: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_clear_owner_recursive(node)
	parent.add_child(node)
	_set_owner_recursive(node, owner)


func _restore_owned_node(parent: Node, node: Node, owner: Node, index: int) -> void:
	_add_owned_node(parent, node, owner)
	parent.move_child(node, clampi(index, 0, parent.get_child_count() - 1))


func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		if child.owner == null or child.owner == node:
			_set_owner_recursive(child, owner)


func _clear_owner_recursive(node: Node) -> void:
	for child in node.get_children():
		_clear_owner_recursive(child)
	node.owner = null


func _select_node_in_editor(instance_id: int) -> void:
	var object := instance_from_id(instance_id)
	if not object is Node:
		return
	var node := object as Node
	if not node.is_inside_tree():
		return
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)


func _unique_child_name(parent: Node, base: String) -> String:
	var candidate := base
	var suffix := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base, suffix]
		suffix += 1
	return candidate


func _set_status(message: String) -> void:
	if dock != null and dock.status_label != null:
		dock.status_label.text = message
