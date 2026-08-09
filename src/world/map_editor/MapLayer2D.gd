@tool
extends Node2D
class_name MapLayer2D

@export var layer_id: StringName
@export var layer_kind: MapLayerSpec.LayerKind = MapLayerSpec.LayerKind.OBJECT
@export var locked: bool = false


func configure_from_spec(spec: MapLayerSpec) -> void:
	if spec == null:
		return
	layer_id = spec.layer_id
	layer_kind = spec.kind
	name = spec.layer_id.to_pascal_case()
	z_index = spec.default_z_index
	y_sort_enabled = spec.y_sort
