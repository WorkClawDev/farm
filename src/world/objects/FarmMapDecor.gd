extends Node2D

## Sparse Stardew-like opening decor for the farm. Each entry is skipped when
## the private submodule is absent (ResourceLoader.exists inside PrivateDecor).

const PrivateDecorScript := preload("res://src/world/objects/PrivateDecor.gd")

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
	if placed > 0:
		print("[FarmMapDecor] placed %d / %d private decorations" % [placed, PLACEMENTS.size()])
	else:
		print("[FarmMapDecor] private decor missing; skipped all %d" % PLACEMENTS.size())
