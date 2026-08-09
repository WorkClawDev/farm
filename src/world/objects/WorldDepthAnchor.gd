extends RefCounted
class_name WorldDepthAnchor

## Moves a sortable world object's root to its ground contact line without
## changing the visible or physical world positions of its direct children.
## Godot sorts Node2D children by their root Y position, so centered artwork
## needs this compensation to behave like a top-down object.
static func apply(root: Node2D, anchor_y: float, previous_anchor_y := 0.0) -> float:
	var delta := anchor_y - previous_anchor_y
	if is_zero_approx(delta):
		return anchor_y

	root.position.y += delta
	for child in root.get_children():
		if child is Node2D:
			var node_2d := child as Node2D
			node_2d.position -= Vector2(0, delta)
		elif child is Control:
			var control := child as Control
			control.position -= Vector2(0, delta)
	return anchor_y
