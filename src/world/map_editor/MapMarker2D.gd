@tool
extends Marker2D
class_name MapMarker2D

enum MarkerKind {
	SPAWN,
	TRANSITION,
	ANCHOR,
}

@export var marker_id: StringName
@export var marker_kind: MarkerKind = MarkerKind.ANCHOR
@export_file("*.tscn") var target_scene: String = ""
@export var target_marker: StringName
