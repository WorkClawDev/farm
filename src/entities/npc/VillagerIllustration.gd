extends Node2D
class_name VillagerIllustration

var body_color := Color("#6d8f73")
var hair_color := Color("#6a493b")
var facing: int = 0

const PALETTES := [
	[Color("#789b73"), Color("#68483a")],
	[Color("#bd6f5b"), Color("#4d372f")],
	[Color("#6b89aa"), Color("#bd8a5d")],
	[Color("#a67ca3"), Color("#554039")],
	[Color("#d39a58"), Color("#5a3f30")],
]


func setup(identity: String, direction: int = 0) -> void:
	var palette: Array = PALETTES[absi(hash(identity)) % PALETTES.size()]
	body_color = palette[0]
	hair_color = palette[1]
	facing = direction
	name = "VillagerIllustration"
	queue_redraw()


func set_facing(direction: int) -> void:
	facing = direction
	queue_redraw()


func _draw() -> void:
	_draw_ellipse(Vector2(0, 25), Vector2(22, 8), Color(0.12, 0.15, 0.12, 0.28))
	draw_line(Vector2(-8, 13), Vector2(-10, 27), Color("#493b38"), 8.0)
	draw_line(Vector2(8, 13), Vector2(10, 27), Color("#493b38"), 8.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -10), Vector2(-15, 14), Vector2(0, 21),
		Vector2(15, 14), Vector2(20, -10), Vector2(0, -20)
	]), body_color)
	draw_line(Vector2(-15, -4), Vector2(-25, 9), body_color.darkened(0.18), 8.0)
	draw_line(Vector2(15, -4), Vector2(25, 9), body_color.darkened(0.18), 8.0)
	draw_circle(Vector2(0, -30), 16.0, Color("#e6b98b"))
	draw_arc(Vector2(0, -31), 16.0, PI, TAU, 18, hair_color, 9.0)
	if facing == 1:
		draw_circle(Vector2(0, -31), 13.0, hair_color)
	elif facing == 2:
		draw_circle(Vector2(-11, -31), 7.0, hair_color)
		draw_circle(Vector2(6, -35), 10.0, hair_color)
	elif facing == 3:
		draw_circle(Vector2(11, -31), 7.0, hair_color)
		draw_circle(Vector2(-6, -35), 10.0, hair_color)
	else:
		draw_circle(Vector2(-6, -29), 1.7, Color("#49332d"))
		draw_circle(Vector2(6, -29), 1.7, Color("#49332d"))
		draw_arc(Vector2(0, -25), 5.0, 0.25, PI - 0.25, 10, Color("#a35f58"), 1.5)
	draw_line(Vector2(-15, 5), Vector2(15, 5), body_color.lightened(0.2), 3.0)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
