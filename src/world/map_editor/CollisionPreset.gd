@tool
extends Resource
class_name CollisionPreset

@export var preset_id: StringName
@export var display_name: String
@export_flags_2d_physics var collision_layer: int = 1
@export_flags_2d_physics var collision_mask: int = 0
@export var one_way: bool = false
@export var editor_color: Color = Color(0.95, 0.25, 0.2, 0.35)


func apply_to(body: CollisionObject2D) -> void:
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	for child in body.get_children():
		if child is CollisionShape2D:
			child.one_way_collision = one_way
		elif child is CollisionPolygon2D:
			child.one_way_collision = one_way
