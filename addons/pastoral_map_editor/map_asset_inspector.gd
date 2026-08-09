@tool
extends EditorInspectorPlugin

var map_plugin: EditorPlugin


func _init(editor_plugin: EditorPlugin) -> void:
	map_plugin = editor_plugin


func _can_handle(object: Object) -> bool:
	return object is Node and object.has_meta("map_asset_id")


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	usage_flags: int,
	_wide: bool
) -> bool:
	if not (usage_flags & PROPERTY_USAGE_SCRIPT_VARIABLE):
		return false
	var active_map: EditableMap2D = map_plugin.active_map
	if active_map == null or active_map.profile == null or active_map.profile.asset_library == null:
		return false
	var entry := active_map.profile.asset_library.get_entry(object.get_meta("map_asset_id"))
	if entry == null:
		return false
	return name not in entry.exposed_properties
