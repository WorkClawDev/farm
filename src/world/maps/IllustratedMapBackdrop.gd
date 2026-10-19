extends Node2D
class_name IllustratedMapBackdrop

## Outdoor backdrop for Village / Forest / Beach.
## Stage C: Kenney Tiny Town (+ Roguelike water on the farm atlas) stamped at 64px.
## Mine / house keep a light vector fill (interiors out of Stage C scope).

@export_enum("village", "forest", "beach", "mine", "house") var map_style: String = "village"

const OUTER_RECT := Rect2(-1400, -900, 4200, 3000)
const CELL := 64.0

const TEX_GRASS := preload("res://assets/tiles/kenney/decor/grass_64.png")
const TEX_GRASS2 := preload("res://assets/tiles/kenney/decor/grass2_64.png")
const TEX_DIRT := preload("res://assets/tiles/kenney/decor/dirt_64.png")
const TEX_STONE := preload("res://assets/tiles/kenney/decor/path_stone_64.png")
const TEX_TREE := preload("res://assets/tiles/kenney/decor/tree_64x192.png")
const TEX_TREE_ROUND := preload("res://assets/tiles/kenney/decor/tree_round_192.png")
const TEX_BUSH := preload("res://assets/tiles/kenney/decor/bush_64.png")
const TEX_WELL := preload("res://assets/tiles/kenney/decor/well_64.png")
const TEX_FENCE_H := preload("res://assets/tiles/kenney/decor/fence_h.png")
const TEX_FENCE_V := preload("res://assets/tiles/kenney/decor/fence_v.png")
const TEX_HOUSE_STONE := preload("res://assets/tiles/kenney/decor/house_stone_192.png")
const TEX_HOUSE_TAN := preload("res://assets/tiles/kenney/decor/house_tan_192.png")
const TEX_HOUSE_RED := preload("res://assets/tiles/kenney/decor/house_red_192.png")
const TEX_FLOWER := preload("res://assets/tiles/kenney/decor/flower_64.png")
const TEX_SAND := preload("res://assets/tiles/kenney/decor/sand_64.png")
const TEX_SAND2 := preload("res://assets/tiles/kenney/decor/sand2_64.png")
const TEX_WATER := preload("res://assets/tiles/kenney/decor/water_64.png")
const TEX_WATER2 := preload("res://assets/tiles/kenney/decor/water2_64.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keep the scene node name (IllustratedBackdrop); tests and maps look it up.
	z_index = -100
	queue_redraw()


func setup(style: String) -> void:
	map_style = style
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	match map_style:
		"forest":
			_draw_forest()
		"beach":
			_draw_beach()
		"mine":
			_draw_mine_fallback()
		"house":
			_draw_house_fallback()
		_:
			_draw_village()


func _stamp(tex: Texture2D, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	if tex == null:
		return
	var s := size if size != Vector2.ZERO else Vector2(tex.get_width(), tex.get_height())
	draw_texture_rect(tex, Rect2(pos, s), false)


func _fill_tiles(tex: Texture2D, rect: Rect2, alt: Texture2D = null) -> void:
	var x0 := int(floor(rect.position.x / CELL)) * int(CELL)
	var y0 := int(floor(rect.position.y / CELL)) * int(CELL)
	var x1 := int(ceil((rect.position.x + rect.size.x) / CELL)) * int(CELL)
	var y1 := int(ceil((rect.position.y + rect.size.y) / CELL)) * int(CELL)
	var gy := y0
	while gy < y1:
		var gx := x0
		while gx < x1:
			var use_alt := alt != null and ((gx + gy) / int(CELL)) % 5 == 0
			_stamp(alt if use_alt else tex, Vector2(gx, gy), Vector2(CELL, CELL))
			gx += int(CELL)
		gy += int(CELL)


func _path_h(y: float, x0: float, x1: float, tex: Texture2D = TEX_DIRT) -> void:
	var x := x0
	while x < x1:
		_stamp(tex, Vector2(x, y), Vector2(CELL, CELL))
		x += CELL


func _path_v(x: float, y0: float, y1: float, tex: Texture2D = TEX_DIRT) -> void:
	var y := y0
	while y < y1:
		_stamp(tex, Vector2(x, y), Vector2(CELL, CELL))
		y += CELL


func _draw_village() -> void:
	_fill_tiles(TEX_GRASS, OUTER_RECT, TEX_GRASS2)
	# Roads through the square.
	_path_h(256.0, -320.0, 1200.0)
	_path_h(512.0, 64.0, 1024.0)
	_path_v(384.0, -256.0, 960.0)
	# Plaza (centered on well at ~420,320)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_stamp(TEX_STONE, Vector2(388 + dx * CELL, 288 + dy * CELL), Vector2(CELL, CELL))
	# Center matches authored VillageWell global (420, 320).
	_stamp(TEX_WELL, Vector2(388, 288), Vector2(CELL, CELL))
	# Houses
	_stamp(TEX_HOUSE_STONE, Vector2(32, -32), Vector2(192, 192))
	_stamp(TEX_HOUSE_TAN, Vector2(520, -48), Vector2(192, 192))
	_stamp(TEX_HOUSE_RED, Vector2(760, 360), Vector2(192, 192))
	_stamp(TEX_HOUSE_STONE, Vector2(16, 600), Vector2(192, 192))
	# Short fence accents beside houses (not wrapping the well like benches).
	for i in range(3):
		_stamp(TEX_FENCE_H, Vector2(96 + i * CELL, 160), Vector2(CELL, CELL))
		_stamp(TEX_FENCE_H, Vector2(700 + i * CELL, 160), Vector2(CELL, CELL))
	# Trees around the edge
	for pos in [
		Vector2(-48, 0), Vector2(-32, 220), Vector2(-40, 500), Vector2(-48, 780),
		Vector2(1080, 20), Vector2(1100, 240), Vector2(1090, 500), Vector2(1110, 780),
		Vector2(160, -96), Vector2(880, -80), Vector2(608, 640), Vector2(740, 820)
	]:
		_stamp(TEX_TREE, pos)
	for pos in [Vector2(320, 200), Vector2(480, 200), Vector2(240, 560), Vector2(560, 560)]:
		_stamp(TEX_FLOWER, pos, Vector2(CELL, CELL))


func _draw_forest() -> void:
	_fill_tiles(TEX_GRASS2, OUTER_RECT, TEX_GRASS)
	_path_h(320.0, -256.0, 1120.0)
	_path_v(384.0, -160.0, 960.0)
	# Dense trees
	for x in range(-100, 1150, 120):
		_stamp(TEX_TREE, Vector2(x, 0))
		_stamp(TEX_TREE_ROUND, Vector2(x + 40, 720), Vector2(128, 128))
	for y in range(100, 780, 130):
		_stamp(TEX_TREE, Vector2(0, y))
		_stamp(TEX_TREE, Vector2(1040, y))
	for pos in [Vector2(220, 220), Vector2(600, 240), Vector2(280, 540), Vector2(640, 580)]:
		_stamp(TEX_BUSH, pos, Vector2(CELL, CELL))
		_stamp(TEX_FLOWER, pos + Vector2(48, 16), Vector2(CELL, CELL))


func _draw_beach() -> void:
	# Keep ocean collision (top ~155) but paint shore/water so the beach reads as sand+sea (BUG-51).
	const SHORE_Y := 80.0
	_fill_tiles(TEX_WATER, OUTER_RECT, TEX_WATER2)
	# Sand belt from inland down to the waterline (covers the playable shore).
	_fill_tiles(TEX_SAND, Rect2(-1400, -400, 4200, SHORE_Y + 400), TEX_SAND2)
	# Grass only farther inland (north), not the whole map.
	_fill_tiles(TEX_GRASS, Rect2(-1400, -900, 4200, 500), TEX_GRASS2)
	_path_v(0.0, -200.0, SHORE_Y + 20.0)
	for x in range(-200, 900, 96):
		_stamp(TEX_BUSH, Vector2(x, -80), Vector2(CELL, CELL))
	for x in range(-200, 1100, 64):
		_stamp(TEX_SAND2, Vector2(x, SHORE_Y - 64.0), Vector2(CELL, CELL))
		_stamp(TEX_STONE, Vector2(x, SHORE_Y - 32.0), Vector2(CELL, CELL))
		_stamp(TEX_WATER2, Vector2(x, SHORE_Y), Vector2(CELL, CELL))


func _draw_mine_fallback() -> void:
	draw_rect(OUTER_RECT, Color("#2b2f38"))
	draw_rect(Rect2(-200, -120, 1400, 900), Color("#3a414d"))


func _draw_house_fallback() -> void:
	draw_rect(OUTER_RECT, Color("#c4a882"))
	draw_rect(Rect2(80, 80, 960, 640), Color("#e6d2b0"))
