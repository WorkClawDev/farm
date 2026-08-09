extends Node2D
class_name OreIllustration

var ore_color: Color = Color("#b9774d")


func setup(color: Color) -> void:
	ore_color = color
	name = "OreIllustration"
	queue_redraw()


func _draw() -> void:
	_draw_ellipse(Vector2(1, 17), Vector2(28, 9), Color(0.08, 0.07, 0.08, 0.35))
	var dark := ore_color.darkened(0.42)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, 13), Vector2(-23, -10), Vector2(-8, -26),
		Vector2(14, -23), Vector2(30, -4), Vector2(25, 17),
		Vector2(5, 27), Vector2(-16, 23)
	]), dark)
	for crystal in [
		PackedVector2Array([Vector2(-17, 8), Vector2(-11, -15), Vector2(-2, -22), Vector2(2, 5)]),
		PackedVector2Array([Vector2(-3, 10), Vector2(4, -22), Vector2(14, -16), Vector2(15, 12)]),
		PackedVector2Array([Vector2(11, 13), Vector2(18, -9), Vector2(27, -2), Vector2(24, 16)])
	]:
		draw_colored_polygon(crystal, ore_color)
		draw_polyline(crystal, ore_color.lightened(0.27), 2.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
