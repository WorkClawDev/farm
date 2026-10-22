extends Node2D

## Sparse Stardew-like opening decor for the farm. Each private entry is skipped
## when the submodule is absent (ResourceLoader.exists inside PrivateDecor).
## Field-edge pieces are main-repo Kenney / item art only, at the same 0.5 scale.

const PrivateDecorScript := preload("res://src/world/objects/PrivateDecor.gd")
const EDGE_SCALE := 0.5
const TEX_EDGE_TREE := preload("res://assets/tiles/kenney/decor/tree_64x192.png")
const TEX_EDGE_BUSH := preload("res://assets/tiles/kenney/decor/bush_64.png")
const TEX_EDGE_ROCK := preload("res://assets/sprites/items/ninja_adventure/stone.png")

## path relative to assets/private/topdown_farm/, feet position, kind
const PLACEMENTS: Array[Dictionary] = [
	# West / north edge trees (6)
	{"path": "trees/x4/separately/Trees/Tree1_x4.png", "pos": Vector2(96, 160), "kind": "tree"},
	{"path": "trees/x4/separately/Trees/Tree2_x4.png", "pos": Vector2(200, 96), "kind": "tree"},
	{"path": "trees/x4/separately/Trees/Tree1_x4.png", "pos": Vector2(72, 300), "kind": "tree"},
	{"path": "trees/x4/separately/Trees/Tree3_x4.png", "pos": Vector2(280, 80), "kind": "tree"},
	{"path": "trees/x4/separately/Trees/Tree2_x4.png", "pos": Vector2(1280, 120), "kind": "tree"},
	{"path": "trees/x4/separately/Trees/Tree1_x4.png", "pos": Vector2(1420, 220), "kind": "tree"},
	# Bush clumps near farmhouse (3)
	{"path": "bushes/x4/separately/Assets/Bush_simple1_1_x4.png", "pos": Vector2(700, 200), "kind": "bush"},
	{"path": "bushes/x4/separately/Assets/Bush_simple2_1_x4.png", "pos": Vector2(1080, 200), "kind": "bush"},
	{"path": "bushes/x4/separately/Assets/Bush_simple1_2_x4.png", "pos": Vector2(680, 240), "kind": "bush"},
	# Roadside rocks (2)
	{"path": "rocks/x4/separately/Rock1_3_x4.png", "pos": Vector2(560, 580), "kind": "rock"},
	{"path": "rocks/x4/separately/Rock1_4_x4.png", "pos": Vector2(1080, 600), "kind": "rock"},
	{"path": "rocks/x4/separately/Rock2_3_x4.png", "pos": Vector2(420, 540), "kind": "rock"},
]

## Feet on open grass beside the field. Off the dirt road, the house steps,
## the village exit, and the tilled plot centres (x 640..1216, y 400..848).
const EDGE_PLACEMENTS: Array[Dictionary] = [
	{"tex": TEX_EDGE_BUSH, "pos": Vector2(520, 500), "kind": "bush"},
	{"tex": TEX_EDGE_TREE, "pos": Vector2(470, 660), "kind": "tree"},
	{"tex": TEX_EDGE_BUSH, "pos": Vector2(540, 700), "kind": "bush"},
	{"tex": TEX_EDGE_ROCK, "pos": Vector2(1200, 248), "kind": "rock"},
]


func _ready() -> void:
	y_sort_enabled = true
	var placed := 0
	for entry in PLACEMENTS:
		var node := PrivateDecorScript.spawn(
			self,
			str(entry["path"]),
			entry["pos"] as Vector2,
			str(entry.get("kind", "decor"))
		)
		if node != null:
			placed += 1
	var edge := _place_edge_decor()
	print("[FarmMapDecor] opening decor %d (private %d/%d, edge %d)" % [placed + edge, placed, PLACEMENTS.size(), edge])


func _place_edge_decor() -> int:
	var placed := 0
	for entry in EDGE_PLACEMENTS:
		var texture: Texture2D = entry["tex"]
		if texture == null:
			continue
		var feet: Vector2 = entry["pos"]
		var kind := str(entry.get("kind", "decor"))
		var body := StaticBody2D.new()
		body.name = "edge_%s_%d_%d" % [kind, int(feet.x), int(feet.y)]
		body.position = feet
		body.collision_layer = 1
		body.collision_mask = 0
		body.y_sort_enabled = true
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(EDGE_SCALE, EDGE_SCALE)
		var display_h := texture.get_height() * EDGE_SCALE
		sprite.position = Vector2(0, -display_h * 0.5)
		body.add_child(sprite)
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 10.0 if kind == "tree" else 8.0
		collision.shape = shape
		collision.position = Vector2(0, -4)
		body.add_child(collision)
		add_child(body)
		placed += 1
	return placed
