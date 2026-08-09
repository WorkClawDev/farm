@tool
extends RefCounted

const EXAMPLE_MAP := "res://src/world/maps/content/PastoralValleyMap.tscn"
const TEMP_MAP := "res://src/world/maps/content/MapEditorSmokeNew.tscn"

var _failures: Array[String] = []
var _editor
var _plugin: EditorPlugin


func run(editor_plugin: EditorPlugin) -> void:
	_plugin = editor_plugin
	_editor = editor_plugin.get_editor_interface()
	var editor = _editor
	print("[EDITOR TEST] Starting Pastoral Map editor workflow")
	_cleanup_temp()
	# Plugins enter the tree while Godot may still be restoring the previous
	# editor layout and open-scene tabs. Wait for that startup transaction so it
	# cannot overwrite the scene chosen by this workflow test.
	await _wait_for_editor_ready()
	print("[EDITOR TEST] Opening example map")
	editor.open_scene_from_path(EXAMPLE_MAP)
	var map: EditableMap2D = await _wait_for_map(EXAMPLE_MAP)
	# Give the plugin's deferred scene synchronization a chance to run. This
	# mirrors the frame boundary that occurs when a user opens a scene in the UI.
	await _wait_frames(3)
	_expect(map != null and map.map_id == &"pastoral_valley", "Editor opens the example EditableMap2D")
	var dock := editor.get_base_control().find_child("PastoralMapEditor", true, false) as PastoralMapEditorDock
	_expect(dock != null, "Pastoral Map dock is loaded in the real editor")
	if map == null or dock == null:
		await _finish()
		return
	var plugin = editor_plugin
	_expect(plugin.active_map == map, "Editor plugin tracks the active map")
	_expect(dock.tile_list.item_count >= 26, "Tile palette exposes the farm atlas")
	_expect(dock.terrain_option.item_count >= 3, "Terrain selector exposes Path, Water, and Fence")
	_expect(
		dock._can_drop_data(Vector2.ZERO, {"type": "files", "files": ["res://assets/tiles/farm_tileset.tres"]}),
		"Resource dock accepts Godot file drags"
	)

	print("[EDITOR TEST] Creating a new map")
	plugin._create_new_map_at(TEMP_MAP)
	var new_map: EditableMap2D = await _wait_for_map(TEMP_MAP)
	_expect(new_map != null, "New-map workflow creates an EditableMap2D scene")
	if new_map != null:
		_expect(new_map.get_layer(&"ground").get_used_cells().size() == 1750, "New map starts with a complete ground layer")
		_expect(new_map.get_layer(&"collision").get_child_count() == 4, "New map starts with four world boundaries")
		_expect(new_map.get_layer(&"markers").get_child_count() == 2, "New map starts with required spawn markers")
		var error_count := 0
		for issue in new_map.validate():
			if issue.severity == MapValidationIssue.Severity.ERROR:
				error_count += 1
		_expect(error_count == 0, "New map passes validation before its first manual edit")
		editor.open_scene_from_path(EXAMPLE_MAP)
		map = await _wait_for_map(EXAMPLE_MAP)
		await _wait_frames(3)
		var reopened := load(TEMP_MAP) as PackedScene
		_expect(reopened != null, "Saved map can be loaded again from disk")
		if reopened != null:
			var reopened_map := reopened.instantiate() as EditableMap2D
			_expect(reopened_map != null and reopened_map.validate().filter(func(issue): return issue.is_error()).is_empty(), "Reopened map retains valid layers, references, markers, and collision")
			reopened_map.free()
	_expect(map != null and plugin.active_map == map, "Editor returns to the example map after save/reopen verification")
	if map != null:
		_test_tile_edit_and_history(plugin, map)
		_test_custom_layer_and_history(plugin, dock, map)
		_test_resize_and_history(plugin, dock, map)
		_test_collision_and_history(plugin, map)

	_cleanup_temp()
	await _finish()


func _test_tile_edit_and_history(plugin, map: EditableMap2D) -> void:
	var ground := map.get_layer(&"ground") as MapTileLayer
	plugin.selected_layer = ground
	plugin.tool_mode = 1
	plugin.selected_source_id = 0
	plugin.selected_atlas_coords = Vector2i(24, 0)
	plugin.selected_alternative = 0
	var cell := Vector2i(49, 34)
	var before: Array = plugin._capture_cell(ground, cell)
	plugin.pending_before.clear()
	plugin.pending_after.clear()
	plugin._apply_drag_cell(cell)
	plugin._commit_cell_action("Editor smoke tile paint")
	_expect(ground.get_cell_atlas_coords(cell) == Vector2i(24, 0), "Pencil paints the selected tile")
	plugin.undo()
	_expect(plugin._capture_cell(ground, cell) == before, "Tile painting can be undone")
	plugin.redo()
	_expect(ground.get_cell_atlas_coords(cell) == Vector2i(24, 0), "Tile painting can be redone")
	plugin.undo()


func _test_custom_layer_and_history(plugin, dock: PastoralMapEditorDock, map: EditableMap2D) -> void:
	dock.layer_name_edit.text = "smoke_decorations"
	dock.layer_kind_option.select(MapLayerSpec.LayerKind.DECORATION)
	plugin.add_layer_from_dock()
	var layer := map.get_layer(&"smoke_decorations")
	_expect(layer is MapLayer2D, "Layer panel creates a custom layer")
	var spec := map.get_layer_spec(&"smoke_decorations")
	_expect(spec != null and spec.accepts_asset_kind(MapAssetEntry.AssetKind.DECORATION), "Custom layer accepts its matching asset type")
	plugin.undo()
	_expect(map.get_layer(&"smoke_decorations") == null, "Layer creation can be undone")
	plugin.redo()
	_expect(map.get_layer(&"smoke_decorations") != null, "Layer creation can be redone")
	plugin.undo()


func _test_resize_and_history(plugin, dock: PastoralMapEditorDock, map: EditableMap2D) -> void:
	dock.map_width_spin.value = 51
	dock.map_height_spin.value = 36
	plugin.resize_map_from_dock()
	_expect(map.size_in_tiles == Vector2i(51, 36), "Map size panel expands the map")
	_expect(map.get_layer(&"ground").get_used_cells().size() == 51 * 36, "Map expansion fills new ground cells")
	var boundary_errors := map.validate().filter(func(issue): return issue.code in [&"world_boundary_geometry", &"world_boundary_missing"])
	_expect(boundary_errors.is_empty(), "Map expansion rebuilds all world boundaries")
	plugin.undo()
	_expect(map.size_in_tiles == Vector2i(50, 35), "Map resize can be undone")
	_expect(map.get_layer(&"ground").get_used_cells().size() == 50 * 35, "Resize undo restores tile data")


func _test_collision_and_history(plugin, map: EditableMap2D) -> void:
	var collision_layer := map.get_layer(&"collision") as MapLayer2D
	var before_count := collision_layer.get_child_count()
	plugin._create_collision_shape(Vector2(256, 256), Vector2(320, 320), 8)
	_expect(collision_layer.get_child_count() == before_count + 1, "Collision rectangle tool creates a collision body")
	plugin.undo()
	_expect(collision_layer.get_child_count() == before_count, "Collision creation can be undone")


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await _editor.get_base_control().get_tree().process_frame


func _wait_for_editor_ready(maximum_frames: int = 600) -> void:
	var filesystem: EditorFileSystem = _editor.get_resource_filesystem()
	for _index in range(maximum_frames):
		if not filesystem.is_scanning():
			break
		await _editor.get_base_control().get_tree().process_frame
	await _wait_frames(60)


func _wait_for_map(path: String, maximum_frames: int = 120) -> EditableMap2D:
	for _index in range(maximum_frames):
		var root: Node = _editor.get_edited_scene_root()
		if root is EditableMap2D and root.scene_file_path == path:
			return root
		await _editor.get_base_control().get_tree().process_frame
	var current_root: Node = _editor.get_edited_scene_root()
	print(
		"[EDITOR TEST] Timed out waiting for ", path,
		"; current=", current_root.scene_file_path if current_root != null else "<null>",
		"; open=", _editor.get_open_scenes()
	)
	return null


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[EDITOR PASS] ", description)
	else:
		_failures.append(description)
		push_error("[EDITOR FAIL] " + description)


func _cleanup_temp() -> void:
	var absolute := ProjectSettings.globalize_path(TEMP_MAP)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _finish() -> void:
	var root: Node = _editor.get_edited_scene_root()
	if root != null:
		var manager: EditorUndoRedoManager = _plugin.get_undo_redo()
		var history_id := manager.get_object_history_id(root)
		if history_id != EditorUndoRedoManager.INVALID_HISTORY:
			manager.clear_history(history_id, false)
	await _wait_frames(5)
	if _failures.is_empty():
		print("MAP EDITOR SMOKE TEST PASSED")
		_editor.get_base_control().get_tree().quit(0)
		return
	print("MAP EDITOR SMOKE TEST FAILED (%d)" % _failures.size())
	for failure in _failures:
		print("  - ", failure)
	_editor.get_base_control().get_tree().quit(1)
