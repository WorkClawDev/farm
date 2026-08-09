extends Node2D
class_name IllustratedMapBackdrop

## A deterministic, code-native backdrop used by the secondary maps.
## Keeping it vector based avoids filtering seams and placeholder atlas artifacts.

@export_enum("village", "forest", "beach", "mine", "house") var map_style: String = "village"

const OUTER_RECT := Rect2(-1400, -900, 4200, 3000)


func setup(style: String) -> void:
	map_style = style
	name = "IllustratedMapBackdrop"
	z_index = -100
	queue_redraw()


func _draw() -> void:
	match map_style:
		"forest":
			_draw_forest()
		"beach":
			_draw_beach()
		"mine":
			_draw_mine()
		"house":
			_draw_house_interior()
		_:
			_draw_village()


func _draw_village() -> void:
	draw_rect(OUTER_RECT, Color("#9ac86e"))
	_draw_soft_patch(Vector2(420, 320), Vector2(1500, 1050), Color("#acd47b"))
	_draw_path([Vector2(-300, 310), Vector2(1180, 310)], 112.0)
	_draw_path([Vector2(420, -300), Vector2(420, 950)], 96.0)
	_draw_path([Vector2(120, 570), Vector2(980, 570)], 76.0)

	# Central village square and well.
	draw_circle(Vector2(420, 320), 112.0, Color("#dfc58f"))
	draw_circle(Vector2(420, 320), 48.0, Color("#72594b"))
	draw_circle(Vector2(420, 316), 39.0, Color("#78b8c2"))
	draw_arc(Vector2(420, 314), 49.0, PI, TAU, 24, Color("#f2dfb2"), 7.0)

	_draw_building(Vector2(70, 15), Vector2(250, 175), Color("#f3dca5"), Color("#b95f4a"))
	_draw_building(Vector2(520, 5), Vector2(270, 185), Color("#ead2ad"), Color("#6f8f63"))
	_draw_building(Vector2(760, 405), Vector2(250, 175), Color("#f1cf91"), Color("#a55342"))
	_draw_building(Vector2(35, 640), Vector2(275, 175), Color("#e9d2b0"), Color("#728fa0"))

	for pos in [
		Vector2(-40, 40), Vector2(-30, 245), Vector2(-20, 520), Vector2(-40, 800),
		Vector2(1080, 40), Vector2(1100, 245), Vector2(1090, 520), Vector2(1110, 800),
		Vector2(180, -80), Vector2(900, -70), Vector2(420, 850), Vector2(760, 850)
	]:
		_draw_tree(pos, 1.0)
	for pos in [Vector2(330, 215), Vector2(505, 215), Vector2(325, 430), Vector2(515, 430)]:
		_draw_flower_patch(pos)


func _draw_forest() -> void:
	draw_rect(OUTER_RECT, Color("#42683f"))
	_draw_soft_patch(Vector2(420, 360), Vector2(1350, 980), Color("#6fa45a"))
	_draw_path([Vector2(-250, 365), Vector2(1110, 365)], 86.0)
	_draw_path([Vector2(420, -180), Vector2(420, 950)], 76.0)
	_draw_path([Vector2(420, 610), Vector2(840, 740), Vector2(1100, 700)], 62.0)

	# A readable stream gives the forest a landmark.
	_draw_river([Vector2(750, -300), Vector2(720, 80), Vector2(820, 390), Vector2(770, 950)], 94.0)
	_draw_bridge(Vector2(800, 365))
	for x in range(-100, 1150, 115):
		_draw_tree(Vector2(x, 15 + (x % 3) * 25), 1.05)
		_draw_tree(Vector2(x + 45, 815 - (x % 4) * 22), 1.08)
	for y in range(120, 790, 125):
		_draw_tree(Vector2(5 + (y % 3) * 18, y), 1.0)
		_draw_tree(Vector2(1055 - (y % 4) * 16, y), 1.0)
	for pos in [Vector2(220, 240), Vector2(590, 235), Vector2(250, 555), Vector2(610, 610)]:
		_draw_flower_patch(pos)
	_draw_log(Vector2(600, 510))
	_draw_rock(Vector2(930, 610), 1.25, Color("#758277"))


func _draw_beach() -> void:
	draw_rect(OUTER_RECT, Color("#f0d99f"))
	draw_rect(Rect2(-1400, -900, 4200, 920), Color("#d9b96f"))
	draw_rect(Rect2(-1400, 20, 4200, 135), Color("#ecd091"))
	draw_rect(Rect2(-1400, 155, 4200, 160), Color("#75c8c3"))
	draw_rect(Rect2(-1400, 315, 4200, 1800), Color("#429ead"))
	draw_rect(Rect2(-1400, 360, 4200, 1750), Color("#378d9e"))

	for y in [175.0, 235.0, 345.0, 455.0, 565.0, 675.0]:
		for x in range(-1300, 2700, 150):
			var offset := 42.0 if int(y) % 2 == 0 else 0.0
			draw_arc(Vector2(x + offset, y), 55.0, 0.15, PI - 0.15, 18, Color(0.86, 0.97, 0.93, 0.65), 4.0)

	_draw_path([Vector2(0, -750), Vector2(0, 35)], 92.0, Color("#d2aa63"), Color("#f5e4b1"))
	for pos in [Vector2(-420, -60), Vector2(-250, -130), Vector2(290, -90), Vector2(510, -35)]:
		_draw_dune_grass(pos)
	for pos in [Vector2(-245, 35), Vector2(410, 55), Vector2(600, 100)]:
		_draw_shell(pos)
	_draw_log(Vector2(-550, 80))


func _draw_mine() -> void:
	draw_rect(OUTER_RECT, Color("#211f24"))
	draw_rect(Rect2(-160, -30, 1120, 800), Color("#4e4846"))
	draw_rect(Rect2(-105, 20, 1010, 690), Color("#625955"))
	for y in range(55, 710, 84):
		for x in range(-70, 900, 96):
			var shade := Color("#6c625d") if int(x / 96 + y / 84) % 2 == 0 else Color("#5c5350")
			_draw_rock(Vector2(x, y), 0.72, shade)

	# Mine cart track and lamps.
	draw_line(Vector2(40, 520), Vector2(820, 520), Color("#332d2b"), 28.0)
	draw_line(Vector2(40, 505), Vector2(820, 505), Color("#9a7651"), 7.0)
	draw_line(Vector2(40, 535), Vector2(820, 535), Color("#9a7651"), 7.0)
	for x in range(65, 830, 55):
		draw_line(Vector2(x, 494), Vector2(x, 546), Color("#b38b5e"), 6.0)
	for pos in [Vector2(45, 70), Vector2(850, 70), Vector2(45, 650), Vector2(850, 650)]:
		_draw_mine_lamp(pos)
	_draw_ladder(Vector2(100, 300))
	_draw_ladder(Vector2(700, 300))


func _draw_house_interior() -> void:
	draw_rect(OUTER_RECT, Color("#382d2b"))
	draw_rect(Rect2(45, 50, 710, 440), Color("#f0dfbd"))
	draw_rect(Rect2(70, 88, 660, 370), Color("#c78d57"))
	for y in range(98, 458, 30):
		draw_line(Vector2(70, y), Vector2(730, y), Color("#ad7046"), 3.0)
	draw_rect(Rect2(290, 185, 225, 160), Color("#b95545"))
	draw_rect(Rect2(305, 200, 195, 130), Color("#d98162"))
	draw_rect(Rect2(325, 218, 155, 94), Color("#efb378"))

	_draw_bed(Vector2(125, 120))
	_draw_table(Vector2(355, 125))
	_draw_chest(Vector2(595, 120))
	_draw_stove(Vector2(145, 315))
	_draw_fireplace(Vector2(590, 300))
	draw_rect(Rect2(365, 432, 70, 26), Color("#4c332a"))
	draw_circle(Vector2(400, 445), 5.0, Color("#e8c771"))


func _draw_path(points: PackedVector2Array, width: float, edge := Color("#c79e61"), fill := Color("#e2c484")) -> void:
	draw_polyline(points, edge, width + 18.0, true)
	draw_polyline(points, fill, width, true)


func _draw_river(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, Color("#9fd5c3"), width + 20.0, true)
	draw_polyline(points, Color("#5aaeb5"), width, true)
	draw_polyline(points, Color(0.78, 0.94, 0.88, 0.7), 5.0, true)


func _draw_soft_patch(center: Vector2, size: Vector2, color: Color) -> void:
	draw_circle(center, minf(size.x, size.y) * 0.53, color)
	draw_rect(Rect2(center - size * 0.42, size * 0.84), color)


func _draw_building(pos: Vector2, size: Vector2, wall: Color, roof: Color) -> void:
	draw_rounded_rect(Rect2(pos + Vector2(8, 14), size), Color(0.18, 0.14, 0.12, 0.25), 18.0)
	draw_rounded_rect(Rect2(pos, size), wall, 16.0)
	var roof_points := PackedVector2Array([
		pos + Vector2(-22, 38),
		pos + Vector2(size.x * 0.5, -35),
		pos + Vector2(size.x + 22, 38),
		pos + Vector2(size.x - 4, 72),
		pos + Vector2(4, 72)
	])
	draw_colored_polygon(roof_points, roof)
	draw_rect(Rect2(pos + Vector2(size.x * 0.43, size.y - 66), Vector2(size.x * 0.18, 66)), Color("#75513e"))
	for window_x in [size.x * 0.16, size.x * 0.71]:
		draw_rect(Rect2(pos + Vector2(window_x, size.y - 76), Vector2(38, 38)), Color("#78b9bc"))
		draw_line(pos + Vector2(window_x + 19, size.y - 76), pos + Vector2(window_x + 19, size.y - 38), Color("#f4e5ba"), 3.0)


func _draw_tree(pos: Vector2, tree_scale: float) -> void:
	_draw_ellipse(pos + Vector2(3, 34) * tree_scale, Vector2(35, 14) * tree_scale, Color(0.16, 0.22, 0.13, 0.28))
	draw_rect(Rect2(pos + Vector2(-9, 4) * tree_scale, Vector2(18, 55) * tree_scale), Color("#76513b"))
	draw_circle(pos + Vector2(-20, 0) * tree_scale, 31.0 * tree_scale, Color("#477944"))
	draw_circle(pos + Vector2(22, -3) * tree_scale, 34.0 * tree_scale, Color("#4f894d"))
	draw_circle(pos + Vector2(0, -25) * tree_scale, 38.0 * tree_scale, Color("#609b55"))
	draw_circle(pos + Vector2(-7, -31) * tree_scale, 10.0 * tree_scale, Color(0.78, 0.9, 0.55, 0.35))


func _draw_flower_patch(pos: Vector2) -> void:
	for offset in [Vector2(-12, 2), Vector2(8, -8), Vector2(20, 10), Vector2(-24, -12)]:
		draw_line(pos + offset, pos + offset + Vector2(0, 13), Color("#4d7c3d"), 3.0)
		draw_circle(pos + offset, 5.0, Color("#f4d887"))
		draw_circle(pos + offset + Vector2(-4, 0), 3.0, Color("#ee96a4"))


func _draw_rock(pos: Vector2, rock_scale: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(-24, 10) * rock_scale,
		pos + Vector2(-13, -18) * rock_scale,
		pos + Vector2(15, -22) * rock_scale,
		pos + Vector2(29, 5) * rock_scale,
		pos + Vector2(14, 22) * rock_scale,
		pos + Vector2(-16, 21) * rock_scale
	])
	draw_colored_polygon(points, color)
	draw_line(pos + Vector2(-10, -12) * rock_scale, pos + Vector2(12, -16) * rock_scale, color.lightened(0.2), 4.0)


func _draw_log(pos: Vector2) -> void:
	draw_line(pos + Vector2(-35, -10), pos + Vector2(42, 15), Color("#684735"), 22.0)
	draw_circle(pos + Vector2(42, 15), 12.0, Color("#b48150"))
	draw_circle(pos + Vector2(42, 15), 6.0, Color("#7b5037"))


func _draw_dune_grass(pos: Vector2) -> void:
	for angle in [-1.1, -0.7, -0.25, 0.25, 0.7, 1.1]:
		draw_line(pos, pos + Vector2(cos(angle - PI / 2.0), sin(angle - PI / 2.0)) * 35.0, Color("#708b4a"), 5.0)


func _draw_shell(pos: Vector2) -> void:
	draw_arc(pos, 13.0, PI, TAU, 16, Color("#d68472"), 6.0)
	for angle in [3.5, 4.0, 4.5, 5.0, 5.5]:
		draw_line(pos, pos + Vector2(cos(angle), sin(angle)) * 12.0, Color("#f5c8ab"), 2.0)


func _draw_mine_lamp(pos: Vector2) -> void:
	draw_circle(pos, 50.0, Color(1.0, 0.75, 0.32, 0.09))
	draw_line(pos + Vector2(0, -34), pos + Vector2(0, -12), Color("#9b7655"), 5.0)
	draw_rect(Rect2(pos + Vector2(-10, -12), Vector2(20, 26)), Color("#d2a04f"))
	draw_circle(pos, 7.0, Color("#ffe49a"))


func _draw_ladder(pos: Vector2) -> void:
	draw_line(pos + Vector2(-20, -45), pos + Vector2(-20, 45), Color("#bd8b55"), 7.0)
	draw_line(pos + Vector2(20, -45), pos + Vector2(20, 45), Color("#bd8b55"), 7.0)
	for y in range(-36, 46, 18):
		draw_line(pos + Vector2(-20, y), pos + Vector2(20, y), Color("#d2a36d"), 5.0)


func _draw_bridge(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-70, -47), Vector2(140, 94)), Color("#6c4937"))
	for y in range(-40, 41, 16):
		draw_rounded_rect(
			Rect2(pos + Vector2(-66, y - 6), Vector2(132, 12)),
			Color("#bb8352") if y % 32 == 0 else Color("#a87249"),
			4.0
		)
	draw_line(pos + Vector2(-68, -44), pos + Vector2(68, -44), Color("#e0b875"), 5.0)
	draw_line(pos + Vector2(-68, 44), pos + Vector2(68, 44), Color("#e0b875"), 5.0)


func _draw_bed(pos: Vector2) -> void:
	draw_rounded_rect(Rect2(pos, Vector2(150, 92)), Color("#795747"), 12.0)
	draw_rounded_rect(Rect2(pos + Vector2(8, 8), Vector2(134, 76)), Color("#e7d3ad"), 10.0)
	draw_rounded_rect(Rect2(pos + Vector2(12, 12), Vector2(48, 25)), Color("#f5ebd7"), 8.0)
	draw_rect(Rect2(pos + Vector2(8, 43), Vector2(134, 41)), Color("#86a76c"))


func _draw_table(pos: Vector2) -> void:
	_draw_ellipse(pos + Vector2(70, 80), Vector2(82, 20), Color(0.2, 0.13, 0.1, 0.25))
	draw_rounded_rect(Rect2(pos, Vector2(140, 64)), Color("#9f6c43"), 16.0)
	draw_circle(pos + Vector2(70, 32), 20.0, Color("#e6c982"))
	draw_circle(pos + Vector2(70, 32), 13.0, Color("#8db05d"))


func _draw_chest(pos: Vector2) -> void:
	draw_rounded_rect(Rect2(pos, Vector2(105, 82)), Color("#875632"), 12.0)
	draw_rect(Rect2(pos + Vector2(5, 34), Vector2(95, 8)), Color("#c99554"))
	draw_rect(Rect2(pos + Vector2(47, 35), Vector2(12, 20)), Color("#edc66a"))


func _draw_stove(pos: Vector2) -> void:
	draw_rounded_rect(Rect2(pos, Vector2(105, 98)), Color("#59605d"), 10.0)
	draw_circle(pos + Vector2(29, 28), 17.0, Color("#262c2c"))
	draw_circle(pos + Vector2(76, 28), 17.0, Color("#262c2c"))
	draw_rect(Rect2(pos + Vector2(17, 57), Vector2(72, 28)), Color("#343b3a"))
	draw_circle(pos + Vector2(52, 71), 4.0, Color("#debd64"))


func _draw_fireplace(pos: Vector2) -> void:
	draw_rounded_rect(Rect2(pos, Vector2(115, 125)), Color("#a35e48"), 8.0)
	draw_rect(Rect2(pos + Vector2(20, 42), Vector2(75, 72)), Color("#3d2a28"))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(37, 104), pos + Vector2(54, 64), pos + Vector2(65, 87),
		pos + Vector2(78, 57), pos + Vector2(88, 104)
	]), Color("#ef9c45"))


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
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
