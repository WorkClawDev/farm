extends Node2D
class_name ForageIllustration

var item_id: String = ""
var type_index: int = 0


func setup(new_item_id: String, new_type_index: int) -> void:
	item_id = new_item_id.to_lower()
	type_index = new_type_index
	name = "ForageIllustration"
	z_index = 1
	queue_redraw()


func _draw() -> void:
	_draw_ellipse(Vector2(0, 14), Vector2(19, 7), Color(0.15, 0.2, 0.12, 0.25))
	if "mushroom" in item_id:
		_draw_mushroom()
	elif "berry" in item_id or "fruit" in item_id:
		_draw_berries()
	elif "flower" in item_id:
		_draw_flower()
	elif "herb" in item_id or "mint" in item_id:
		_draw_herb()
	elif "branch" in item_id or "wood" in item_id:
		_draw_branch()
	elif "stone" in item_id or "rock" in item_id:
		_draw_stone()
	elif "shell" in item_id:
		_draw_shell()
	else:
		match type_index:
			1:
				_draw_mushroom()
			2:
				_draw_flower()
			3:
				_draw_herb()
			4:
				_draw_branch()
			5:
				_draw_stone()
			6:
				_draw_shell()
			_:
				_draw_berries()


func _draw_mushroom() -> void:
	draw_rounded_rect(Rect2(-6, -1, 12, 19), Color("#ead5b5"), 5.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, 1), Vector2(-15, -16), Vector2(0, -24),
		Vector2(16, -16), Vector2(23, 2)
	]), Color("#b85e50"))
	draw_circle(Vector2(-8, -11), 3.0, Color("#f3d9b4"))
	draw_circle(Vector2(8, -14), 2.5, Color("#f3d9b4"))


func _draw_berries() -> void:
	draw_line(Vector2(0, -19), Vector2(-5, 4), Color("#477742"), 5.0)
	draw_line(Vector2(-2, -10), Vector2(-16, -18), Color("#477742"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -14), Vector2(12, -24), Vector2(10, -10)]), Color("#6aa052"))
	for pos in [Vector2(-13, 1), Vector2(0, 6), Vector2(13, 0), Vector2(6, -8)]:
		draw_circle(pos, 8.0, Color("#b84659"))
		draw_circle(pos + Vector2(-2, -2), 2.0, Color("#ef9b9f"))


func _draw_flower() -> void:
	draw_line(Vector2(0, 16), Vector2(0, -7), Color("#4b834b"), 5.0)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_circle(Vector2(cos(angle), sin(angle)) * 9.0 + Vector2(0, -10), 7.0, Color("#ee94ac"))
	draw_circle(Vector2(0, -10), 6.0, Color("#f4d36d"))


func _draw_herb() -> void:
	draw_line(Vector2(0, 17), Vector2(0, -17), Color("#3c713f"), 5.0)
	for pos in [Vector2(-10, 7), Vector2(10, 1), Vector2(-9, -7), Vector2(8, -13)]:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-8, 0), pos + Vector2(0, -7), pos + Vector2(9, 0), pos + Vector2(0, 7)
		]), Color("#66a653"))


func _draw_branch() -> void:
	draw_line(Vector2(-22, 12), Vector2(22, -12), Color("#76503a"), 9.0, true)
	draw_line(Vector2(-4, 2), Vector2(-14, -12), Color("#76503a"), 6.0, true)
	draw_line(Vector2(9, -5), Vector2(18, 7), Color("#76503a"), 6.0, true)
	draw_circle(Vector2(22, -12), 4.0, Color("#b37a4c"))


func _draw_stone() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, 11), Vector2(-16, -9), Vector2(-4, -21),
		Vector2(17, -15), Vector2(24, 8), Vector2(12, 17), Vector2(-12, 18)
	]), Color("#77827d"))
	draw_line(Vector2(-10, -10), Vector2(9, -15), Color("#a8b1a9"), 4.0)


func _draw_shell() -> void:
	draw_arc(Vector2.ZERO, 20.0, PI, TAU, 24, Color("#de8c78"), 9.0)
	for angle in [3.4, 3.9, 4.4, 4.9, 5.4, 5.9]:
		draw_line(Vector2(0, 3), Vector2(cos(angle), sin(angle)) * 18.0, Color("#f5ceb7"), 3.0)


func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	for center in [
		rect.position + Vector2(radius, radius),
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.position + Vector2(radius, rect.size.y - radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y - radius)
	]:
		draw_circle(center, radius, color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
