@tool
extends Resource
class_name MapProfile

@export var profile_id: StringName
@export var display_name: String
@export var default_size: Vector2i = Vector2i(50, 35)
@export var tile_size: Vector2i = Vector2i(64, 64)
@export var primary_tileset: TileSet
@export var layer_specs: Array[MapLayerSpec] = []
@export var asset_library: MapAssetLibrary
@export var collision_presets: Array[CollisionPreset] = []
@export var required_marker_ids: PackedStringArray = []


func get_layer_spec(layer_id: StringName) -> MapLayerSpec:
	for spec in layer_specs:
		if spec != null and spec.layer_id == layer_id:
			return spec
	return null


func get_collision_preset(preset_id: StringName) -> CollisionPreset:
	for preset in collision_presets:
		if preset != null and preset.preset_id == preset_id:
			return preset
	return null
