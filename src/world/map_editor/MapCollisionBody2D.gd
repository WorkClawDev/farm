@tool
extends StaticBody2D
class_name MapCollisionBody2D

enum BoundarySide {
	NONE,
	NORTH,
	SOUTH,
	WEST,
	EAST,
}

@export var preset: CollisionPreset:
	set(value):
		preset = value
		if preset != null:
			preset.apply_to(self)
@export var is_world_boundary: bool = false
@export var boundary_side: BoundarySide = BoundarySide.NONE


func apply_preset() -> void:
	if preset != null:
		preset.apply_to(self)
