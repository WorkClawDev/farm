extends Node2D
class_name FarmLayoutEditor

const LAYOUT_PATH := "res://data/farm_layout.json"
const FARM_SCENE := preload("res://src/world/maps/Farm.tscn")
const SCENE_LIBRARY := {
	"shipping_bin": preload("res://src/world/objects/ShippingBin.tscn"),
	"workbench": preload("res://src/world/objects/Workbench.tscn"),
	"fishing_spot": preload("res://src/world/objects/FishingSpot.tscn"),
	"player_house_exterior": preload("res://src/world/objects/HouseExterior.tscn"),
	"coop": preload("res://src/world/objects/Coop.tscn"),
	"barn": preload("res://src/world/objects/Barn.tscn"),
	"ore": preload("res://src/world/objects/Ore.tscn")
}
const PALETTE := {
	"select": {"kind": "tool"},
	"shipping_bin": {"kind": "scene", "scene_key": "shipping_bin"},
	"workbench": {"kind": "scene", "scene_key": "workbench"},
	"fishing_spot": {"kind": "scene", "scene_key": "fishing_spot", "properties": {"location_type": "pond"}},
	"coop": {"kind": "scene", "scene_key": "coop"},
	"barn": {"kind": "scene", "scene_key": "barn"},
	"ore": {"kind": "scene", "scene_key": "ore"},
	"path_block": {"kind": "rect", "size": Vector2(64, 32), "color": Color(0.63, 0.52, 0.34, 0.9)},
	"water_block": {"kind": "rect", "size": Vector2(96, 96), "color": Color(0.24, 0.55, 0.8, 0.85)},
	"grass_tint": {"kind": "rect", "size": Vector2(128, 128), "color": Color(0.3, 0.55, 0.28, 0.35)},
	"fence_block": {"kind": "rect", "size": Vector2(64, 8), "color": Color(0.62, 0.43, 0.22, 1.0)},
	"house_block": {"kind": "scene", "scene_key": "player_house_exterior"}
}

@onready var farm_preview: Node2D = $FarmPreview
@onready var selection_box: ColorRect = $CanvasLayer/SelectionBox
@onready var info_label: Label = $CanvasLayer/Panel/InfoLabel
@onready var pos_x_edit: LineEdit = $CanvasLayer/Panel/PosXEdit
@onready var pos_y_edit: LineEdit = $CanvasLayer/Panel/PosYEdit
@onready var location_type_edit: LineEdit = $CanvasLayer/Panel/LocationTypeEdit
@onready var apply_button: Button = $CanvasLayer/Panel/ApplyButton
@onready var undo_button: Button = $CanvasLayer/Panel/UndoButton
@onready var redo_button: Button = $CanvasLayer/Panel/RedoButton

var layout_root: Node2D

var grid_size: int = 32
var selected_tool: String = "select"
var selected_node: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var undo_stack: Array[String] = []
var redo_stack: Array[String] = []
const MAX_HISTORY := 50

func _ready() -> void:
	_load_farm_preview()
	_bind_buttons()
	load_layout()
	_update_info()

func _load_farm_preview() -> void:
	var preview_scene := FARM_SCENE.instantiate()
	farm_preview.add_child(preview_scene)
	layout_root = preview_scene.get_node_or_null("LayoutRoot")
	var player := preview_scene.get_node_or_null("Player")
	if player:
		player.queue_free()
	var ui_canvas := preview_scene.get_node_or_null("CanvasLayer")
	if ui_canvas:
		ui_canvas.queue_free()
	if layout_root:
		for child in layout_root.get_children():
			child.queue_free()

func _bind_buttons() -> void:
	for button in $CanvasLayer/Panel/Buttons.get_children():
		if button is Button:
			button.pressed.connect(_on_palette_button_pressed.bind(button.name.to_lower()))
	$CanvasLayer/Panel/SaveButton.pressed.connect(save_layout)
	$CanvasLayer/Panel/LoadButton.pressed.connect(load_layout)
	$CanvasLayer/Panel/ClearButton.pressed.connect(clear_layout)
	apply_button.pressed.connect(_apply_selected_properties)
	undo_button.pressed.connect(undo)
	redo_button.pressed.connect(redo)

func _on_palette_button_pressed(tool_name: String) -> void:
	selected_tool = tool_name
	selected_node = null
	_update_selection_box()
	_update_property_fields()
	_update_info()

func _snapshot_current_layout() -> String:
	return JSON.stringify(_collect_layout_data())

func _push_undo_snapshot() -> void:
	undo_stack.append(_snapshot_current_layout())
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_history_buttons()

func _update_history_buttons() -> void:
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := _mouse_world_position()
		if event.pressed:
			if selected_tool == "select":
				selected_node = _find_node_at(world_pos)
				_update_property_fields()
				if selected_node:
					is_dragging = true
					drag_start_position = selected_node.position
					drag_offset = selected_node.position - _snap(world_pos)
			else:
				_place_item(world_pos)
		else:
			if is_dragging and selected_node and selected_node.position != drag_start_position:
				_push_undo_snapshot()
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging and selected_node:
		selected_node.position = _snap(_mouse_world_position()) + drag_offset
		_update_selection_box()
		_update_info()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var target := _find_node_at(_mouse_world_position())
		if target:
			_push_undo_snapshot()
			target.queue_free()
			if target == selected_node:
				selected_node = null
			_update_selection_box()
			_update_property_fields()
			_update_info()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE and selected_node:
			_push_undo_snapshot()
			selected_node.queue_free()
			selected_node = null
			_update_selection_box()
			_update_property_fields()
			_update_info()
		elif event.keycode == KEY_S and event.ctrl_pressed:
			save_layout()
		elif event.keycode == KEY_L and event.ctrl_pressed:
			load_layout()
		elif event.keycode == KEY_Z and event.ctrl_pressed:
			undo()
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			redo()

func _place_item(world_pos: Vector2) -> void:
	if not PALETTE.has(selected_tool):
		return
	_push_undo_snapshot()
	var definition: Dictionary = PALETTE[selected_tool]
	var node := _build_node_from_definition(definition, _snap(world_pos), selected_tool)
	if node:
		layout_root.add_child(node)
		selected_node = node
		_update_selection_box()
		_update_property_fields()
		_update_info()

func _build_node_from_definition(definition: Dictionary, position: Vector2, base_name: String) -> Node2D:
	var node: Node2D
	if definition.get("kind") == "scene":
		var packed: PackedScene = SCENE_LIBRARY.get(definition.get("scene_key", ""))
		if packed == null:
			return null
		node = packed.instantiate()
		var properties: Dictionary = definition.get("properties", {})
		for key in properties.keys():
			node.set(key, properties[key])
	else:
		var rect := ColorRect.new()
		rect.color = definition.get("color", Color.WHITE)
		rect.size = definition.get("size", Vector2(32, 32))
		rect.position = -rect.size / 2.0
		node = Node2D.new()
		node.add_child(rect)
	node.name = "%s_%s" % [base_name, Time.get_ticks_msec()]
	node.position = position
	return node

func _collect_layout_data() -> Dictionary:
	var data := {
		"grid_size": grid_size,
		"objects": []
	}
	for child in layout_root.get_children():
		data.objects.append(_serialize_node(child))
	return data

func save_layout() -> void:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_collect_layout_data(), "\t"))
		file.close()
		info_label.text = "已保存到 %s" % LAYOUT_PATH

func _apply_layout_data(data: Dictionary) -> void:
	clear_layout(false)
	grid_size = int(data.get("grid_size", 32))
	for obj in data.get("objects", []):
		var node := _deserialize_node(obj)
		if node:
			layout_root.add_child(node)
	selected_node = null
	_update_selection_box()
	_update_property_fields()
	_update_info()
	_update_history_buttons()

func load_layout() -> void:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		info_label.text = "未找到布局文件，已载入空布局"
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		info_label.text = "布局文件解析失败"
		return
	undo_stack.clear()
	redo_stack.clear()
	_apply_layout_data(json.data)

func clear_layout(update_label: bool = true) -> void:
	if update_label:
		_push_undo_snapshot()
	for child in layout_root.get_children():
		child.queue_free()
	selected_node = null
	_update_selection_box()
	_update_property_fields()
	_update_history_buttons()
	if update_label:
		info_label.text = "布局已清空"

func _serialize_node(node: Node2D) -> Dictionary:
	if node.get_child_count() > 0 and node.get_child(0) is ColorRect:
		var rect: ColorRect = node.get_child(0)
		return {
			"kind": "rect",
			"name": node.name,
			"position": {"x": node.position.x, "y": node.position.y},
			"size": {"x": rect.size.x, "y": rect.size.y},
			"color": {"r": rect.color.r, "g": rect.color.g, "b": rect.color.b, "a": rect.color.a}
		}
	var scene_key := _detect_scene_key(node)
	var props := {}
	if node.get_script() != null and node.get_script().resource_path.ends_with("FishingSpot.gd"):
		props["location_type"] = node.get("location_type")
	return {
		"kind": "scene",
		"name": node.name,
		"scene_key": scene_key,
		"position": {"x": node.position.x, "y": node.position.y},
		"properties": props
	}

func _deserialize_node(data: Dictionary) -> Node2D:
	var pos := Vector2(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	if data.get("kind") == "rect":
		var def := {
			"kind": "rect",
			"size": Vector2(data.get("size", {}).get("x", 32), data.get("size", {}).get("y", 32)),
			"color": Color(data.get("color", {}).get("r", 1.0), data.get("color", {}).get("g", 1.0), data.get("color", {}).get("b", 1.0), data.get("color", {}).get("a", 1.0))
		}
		var rect_node := _build_node_from_definition(def, pos, data.get("name", "rect"))
		rect_node.name = data.get("name", rect_node.name)
		return rect_node
	var def_scene := {
		"kind": "scene",
		"scene_key": data.get("scene_key", "shipping_bin"),
		"properties": data.get("properties", {})
	}
	var scene_node := _build_node_from_definition(def_scene, pos, data.get("name", "scene"))
	if scene_node:
		scene_node.name = data.get("name", scene_node.name)
	return scene_node

func _detect_scene_key(node: Node2D) -> String:
	var script_path := ""
	if node.get_script() != null:
		script_path = node.get_script().resource_path
	if script_path.ends_with("ShippingBin.gd"):
		return "shipping_bin"
	if script_path.ends_with("Workbench.gd"):
		return "workbench"
	if script_path.ends_with("FishingSpot.gd"):
		return "fishing_spot"
	if script_path.ends_with("HouseExterior.gd"):
		return "player_house_exterior"
	if script_path.ends_with("Coop.gd"):
		return "coop"
	if script_path.ends_with("Barn.gd"):
		return "barn"
	if script_path.ends_with("Ore.gd"):
		return "ore"
	return "shipping_bin"

func _find_node_at(world_pos: Vector2) -> Node2D:
	var children = layout_root.get_children()
	children.reverse()
	for child in children:
		if _node_contains_point(child, world_pos):
			return child
	return null

func _node_contains_point(node: Node2D, world_pos: Vector2) -> bool:
	if node.get_child_count() > 0 and node.get_child(0) is ColorRect:
		var rect: ColorRect = node.get_child(0)
		var rect_global = Rect2(node.position - rect.size / 2.0, rect.size)
		return rect_global.has_point(world_pos)
	return _get_node_rect(node).has_point(world_pos)

func _snap(pos: Vector2) -> Vector2:
	return Vector2(round(pos.x / grid_size) * grid_size, round(pos.y / grid_size) * grid_size)

func _mouse_world_position() -> Vector2:
	return get_global_mouse_position()

func _update_selection_box() -> void:
	if selected_node == null:
		selection_box.visible = false
		return

	selection_box.visible = true
	var rect := _get_node_rect(selected_node)
	selection_box.position = rect.position
	selection_box.size = rect.size

func _get_node_rect(node: Node2D) -> Rect2:
	if node.get_child_count() > 0 and node.get_child(0) is ColorRect:
		var color_rect: ColorRect = node.get_child(0)
		return Rect2(node.position - color_rect.size / 2.0, color_rect.size)
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var texture_size := Vector2(sprite.texture.get_size()) * sprite.scale.abs()
		var sprite_pos := node.position + sprite.position
		if sprite.centered:
			return Rect2(sprite_pos - texture_size / 2.0, texture_size)
		return Rect2(sprite_pos, texture_size)
	return Rect2(node.position - Vector2(24, 24), Vector2(48, 48))

func _update_property_fields() -> void:
	if selected_node == null:
		pos_x_edit.text = ""
		pos_y_edit.text = ""
		location_type_edit.text = ""
		location_type_edit.editable = false
		return
	pos_x_edit.text = str(int(selected_node.position.x))
	pos_y_edit.text = str(int(selected_node.position.y))
	if selected_node.get_script() != null and selected_node.get_script().resource_path.ends_with("FishingSpot.gd"):
		location_type_edit.editable = true
		location_type_edit.text = str(selected_node.get("location_type"))
	else:
		location_type_edit.editable = false
		location_type_edit.text = ""

func _apply_selected_properties() -> void:
	if selected_node == null:
		return
	var old_position := selected_node.position
	var old_location_type: Variant = selected_node.get("location_type") if location_type_edit.editable else null
	var x := int(pos_x_edit.text) if pos_x_edit.text != "" else int(selected_node.position.x)
	var y := int(pos_y_edit.text) if pos_y_edit.text != "" else int(selected_node.position.y)
	var new_position := _snap(Vector2(x, y))
	var new_location_type := location_type_edit.text
	var changed := new_position != old_position
	if location_type_edit.editable and new_location_type != "" and new_location_type != str(old_location_type):
		changed = true
	if changed:
		_push_undo_snapshot()
	selected_node.position = new_position
	if location_type_edit.editable and new_location_type != "":
		selected_node.set("location_type", new_location_type)
	_update_selection_box()
	_update_property_fields()
	_update_info()

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot_current_layout())
	var snapshot: String = undo_stack.pop_back()
	_restore_snapshot(snapshot)
	info_label.text = "已撤销"

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot_current_layout())
	var snapshot: String = redo_stack.pop_back()
	_restore_snapshot(snapshot)
	info_label.text = "已重做"

func _restore_snapshot(snapshot: String) -> void:
	var json := JSON.new()
	if json.parse(snapshot) != OK:
		return
	_apply_layout_data(json.data)

func _update_info() -> void:
	var selected_text := "当前工具: %s" % selected_tool
	if selected_node:
		selected_text = "选中: %s | 位置: (%d, %d)" % [selected_node.name, int(selected_node.position.x), int(selected_node.position.y)]
	info_label.text = "左键放置/选择，右键删除，Delete 删除，Ctrl+S 保存，Ctrl+L 载入，Ctrl+Z 撤销，Ctrl+Y 重做\n%s" % selected_text
