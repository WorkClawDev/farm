extends Node

## Grass v2b scatter. Synchronous so `godot --headless --quit --scene` can run it.

var total_tests := 0
var passed_tests := 0
var failed_tests := 0


func _ready() -> void:
	print("==================================================")
	print("GRASS SCATTER TESTS")
	print("==================================================")
	run_grass_tests()
	print("==================================================")
	print("RESULTS: %d/%d passed" % [passed_tests, total_tests])
	print("==================================================")
	if failed_tests == 0:
		print("ALL TESTS PASSED!")
		get_tree().quit(0)
	else:
		print("FAILED: %d tests" % failed_tests)
		get_tree().quit(1)


func run_grass_tests() -> void:
	print("\n[Grass Hash]")
	var twice_a := FarmTilesetBuilder.grass_variant_at(Vector2i(8, 8))
	var twice_b := FarmTilesetBuilder.grass_variant_at(Vector2i(8, 8))
	assert_true(twice_a == twice_b, "grass_variant_at(8, 8) is stable across calls")
	assert_true(FarmTilesetBuilder.grass_variant_at(Vector2i(0, 0)) == 0, "anchor (0, 0) variant is 0")
	assert_true(FarmTilesetBuilder.grass_atlas_at(Vector2i(0, 0)) == Vector2i(0, 0), "anchor (0, 0) atlas is (0, 0)")
	assert_true(FarmTilesetBuilder.grass_variant_at(Vector2i(8, 8)) == 3, "anchor (8, 8) variant is 3")
	assert_true(FarmTilesetBuilder.grass_atlas_at(Vector2i(8, 8)) == Vector2i(28, 0), "anchor (8, 8) atlas is (28, 0)")
	assert_true(FarmTilesetBuilder.grass_variant_at(Vector2i(11, 16)) == 1, "anchor (11, 16) variant is 1")
	assert_true(FarmTilesetBuilder.grass_atlas_at(Vector2i(11, 16)) == Vector2i(26, 0), "anchor (11, 16) atlas is (26, 0)")
	assert_true(FarmTilesetBuilder.grass_variant_at(Vector2i(5, 12)) == 8, "anchor (5, 12) variant is 8")
	assert_true(FarmTilesetBuilder.grass_atlas_at(Vector2i(5, 12)) == Vector2i(33, 0), "anchor (5, 12) atlas is (33, 0)")
	assert_true(FarmTilesetBuilder._raw_variant(3, 0) == 4, "avoid sample (3, 0) raw variant is 4")
	assert_true(FarmTilesetBuilder.grass_variant_at(Vector2i(3, 0)) == 2, "avoid sample (3, 0) final variant is 2")
	assert_true(FarmTilesetBuilder.grass_atlas_at(Vector2i(3, 0)) == Vector2i(27, 0), "avoid sample (3, 0) atlas is (27, 0)")
	var builder_src := FileAccess.get_file_as_string("res://src/world/maps/FarmTilesetBuilder.gd")
	var grass_src := builder_src.substr(builder_src.find("static func is_grass"))
	assert_true(not grass_src.contains("randi") and not grass_src.contains("randomize") and not grass_src.contains("RandomNumberGenerator"), "Grass scatter does not use RNG")

	print("\n[Grass TileSet]")
	var texture := load("res://assets/tiles/kenney/farm_ground_atlas_64.png") as Texture2D
	assert_true(texture != null and texture.get_width() == 2176 and texture.get_height() == 64, "Ground atlas is 2176x64 after import")
	assert_true(FarmTilesetBuilder.ATLAS_TILE_COUNT == 34 and FarmTilesetBuilder.COLUMNS == 34, "Atlas column count is 34")
	var tile_set := load("res://assets/tiles/farm_tileset.tres") as TileSet
	var source := tile_set.get_source(0) as TileSetAtlasSource if tile_set != null else null
	assert_true(source != null, "Farm TileSet source 0 is an atlas")
	if source != null:
		var missing := 0
		for x in range(1, 34):
			if not source.has_tile(Vector2i(x, 0)):
				missing += 1
		assert_true(missing == 0, "Atlas tiles (1, 0) through (33, 0) exist")
		var physics := 0
		for x in range(26, 34):
			var data := source.get_tile_data(Vector2i(x, 0), 0)
			if data == null or data.get_collision_polygons_count(0) != 0:
				physics += 1
		assert_true(physics == 0, "Grass variants 26-33 have no physics polygon")

	print("\n[Grass is_grass]")
	assert_true(FarmTilesetBuilder.is_grass(Vector2i(0, 0)), "(0, 0) is grass")
	assert_true(FarmTilesetBuilder.is_grass(Vector2i(1, 0)), "(1, 0) is grass")
	assert_true(FarmTilesetBuilder.is_grass(Vector2i(26, 0)), "(26, 0) is grass")
	assert_true(FarmTilesetBuilder.is_grass(Vector2i(33, 0)), "(33, 0) is grass")
	for x in range(3, 10):
		assert_true(not FarmTilesetBuilder.is_grass(Vector2i(x, 0)), "Path (%d, 0) is not grass" % x)
	for x in range(10, 19):
		assert_true(not FarmTilesetBuilder.is_grass(Vector2i(x, 0)), "Water (%d, 0) is not grass" % x)
	assert_true(not FarmTilesetBuilder.is_grass(Vector2i(23, 0)), "Soil (23, 0) is not grass")
	assert_true(not FarmTilesetBuilder.is_grass(Vector2i(24, 0)), "Stone (24, 0) is not grass")
	assert_true(not FarmTilesetBuilder.is_grass(Vector2i(2, 0)), "Decor (2, 0) is not grass")
	assert_true(not FarmTilesetBuilder.is_grass(Vector2i(25, 0)), "Hay (25, 0) is not grass")

	print("\n[Grass FarmMap scatter]")
	var packed_map := load("res://src/world/maps/content/FarmMap.tscn") as PackedScene
	assert_true(packed_map != null, "FarmMap scene loads")
	if packed_map == null:
		return
	var map := packed_map.instantiate() as EditableMap2D
	var ground := map.get_layer(&"ground") as TileMapLayer
	assert_true(ground != null, "FarmMap ground layer exists")
	if ground == null:
		map.free()
		return
	var before := _atlases(ground)
	var plain := 0
	var soil := 0
	var decor := 0
	for cell in before.keys():
		var atlas: Vector2i = before[cell]
		if atlas == Vector2i(0, 0):
			plain += 1
		elif atlas == Vector2i(23, 0):
			soil += 1
		elif atlas == Vector2i(2, 0):
			decor += 1
	assert_true(before.size() == 1750, "Farm ground still has 1750 cells before scatter")
	assert_true(plain == 1663, "Farm authored plain grass is 1663 cells (got %d)" % plain)
	assert_true(soil == 80, "Farm soil cells stay 80 (got %d)" % soil)
	assert_true(decor == 7, "Farm decor (2, 0) cells stay 7 (got %d)" % decor)
	FarmTilesetBuilder.scatter_grass(ground)
	var scattered := _atlases(ground)
	assert_true(scattered.size() == 1750, "Scatter keeps 1750 ground cells")
	var bad_grass := 0
	var changed_other := 0
	for cell in before.keys():
		var was: Vector2i = before[cell]
		var now: Vector2i = scattered[cell]
		if was == Vector2i(0, 0):
			var allowed_x := now.x == 0 or (now.x >= 26 and now.x <= 33)
			if now.y != 0 or not allowed_x or not FarmTilesetBuilder.is_grass(now):
				bad_grass += 1
		elif now != was:
			changed_other += 1
	assert_true(bad_grass == 0, "Former (0, 0) cells are grass variants 0 or 26-33")
	assert_true(changed_other == 0, "Soil, decor, and other ground cells are unchanged")
	FarmTilesetBuilder.scatter_grass(ground)
	var second := _atlases(ground)
	assert_true(_same_atlas(scattered, second), "A second scatter_grass leaves every ground cell unchanged")

	var sample := Vector2i(8, 20)
	var sample_atlas := FarmTilesetBuilder.grass_atlas_at(sample)
	assert_true(before.get(sample, Vector2i(-1, -1)) == Vector2i(0, 0), "Sample (8, 20) starts as plain grass")
	assert_true(ground.get_cell_atlas_coords(sample) == sample_atlas, "Sample (8, 20) scattered to grass_atlas_at")
	ground.set_cell(sample, 0, Vector2i(23, 0))
	ground.set_cell(sample, 0, FarmTilesetBuilder.grass_atlas_at(sample))
	assert_true(ground.get_cell_atlas_coords(sample) == sample_atlas, "Restoring grass uses grass_atlas_at")

	map.free()

	print("\n[Grass Save]")
	var farm_packed := load("res://src/world/maps/Farm.tscn") as PackedScene
	assert_true(farm_packed != null, "Farm scene loads")
	if farm_packed != null:
		var mounted := _mount_scene(farm_packed)
		var farm: Node = mounted["node"]
		var farm_ground: TileMapLayer = mounted["ground"]
		var farm_authored: Dictionary = mounted["authored"]
		assert_true(farm_ground != null, "Farm ground layer exists")
		if farm_ground != null:
			assert_true(_listens_for_farm_reset(farm), "Farm._ready connected farm_reset")
			_assert_scattered_ground(farm_ground, farm_authored, "Farm after _setup_map")
			var state := FarmState.get_save_state()
			var bad_key := false
			for key in state.keys():
				var key_name := str(key).to_lower()
				if key_name.contains("ground") or key_name.contains("atlas") or key_name.contains("tile_map"):
					bad_key = true
			assert_true(not bad_key, "Farm save has no ground, atlas, or tile_map keys")
			var paths = state.get("player_paths", null)
			assert_true(paths is Array, "player_paths is still a coordinate array")
			if paths is Array:
				for entry in paths:
					assert_true(entry is Array and entry.size() >= 2, "player_paths entries are [x, y]")
			var snap := FarmState.get_save_state()
			assert_true(snap.has("player_paths"), "Current save format includes player_paths")
			assert_true(FarmState.load_save_state(snap), "Current farm snapshot loads")
			_assert_scattered_ground(farm_ground, farm_authored, "Farm ground after current save farm_reset")
			var legacy: Dictionary = snap.duplicate(true)
			legacy.erase("player_paths")
			assert_true(not legacy.has("player_paths"), "Legacy save omits player_paths")
			assert_true(FarmState.load_save_state(legacy), "A save without player_paths still loads")
			_assert_scattered_ground(farm_ground, farm_authored, "Farm ground after legacy save farm_reset")
			FarmState.farm_reset.emit()
			_assert_scattered_ground(farm_ground, farm_authored, "Farm ground after farm_reset callback")

	print("\n[Grass Entrance]")
	if farm_packed != null:
		var entered := _mount_scene(farm_packed)
		var entrance_farm: Node = entered["node"]
		var entrance_ground: TileMapLayer = entered["ground"]
		var entrance_authored: Dictionary = entered["authored"]
		assert_true(entrance_ground != null, "Farm entrance ground layer exists")
		if entrance_ground != null:
			_assert_scattered_ground(entrance_ground, entrance_authored, "Farm entrance")
	var valley_packed := load("res://src/world/maps/content/PastoralValleyMap.tscn") as PackedScene
	assert_true(valley_packed != null, "PastoralValleyMap loads")
	if valley_packed != null:
		var valley_mount := _mount_scene(valley_packed)
		var valley: Node = valley_mount["node"]
		var valley_ground: TileMapLayer = valley_mount["ground"]
		var valley_before: Dictionary = valley_mount["authored"]
		assert_true(valley_ground != null, "Valley ground layer exists")
		if valley_ground != null:
			var valley_plain := 0
			var valley_grass2 := 0
			for cell in valley_before.keys():
				var atlas: Vector2i = valley_before[cell]
				if atlas == Vector2i(0, 0):
					valley_plain += 1
				elif atlas == Vector2i(1, 0):
					valley_grass2 += 1
			assert_true(valley_plain == 1252, "Valley authored plain grass is 1252 (got %d)" % valley_plain)
			assert_true(valley_grass2 == 195, "Valley (1, 0) cells are 195 (got %d)" % valley_grass2)
			_assert_scattered_ground(valley_ground, valley_before, "Valley entrance")
			var valley_grass2_moved := 0
			for cell in valley_before.keys():
				if valley_before[cell] != Vector2i(1, 0):
					continue
				if valley_ground.get_cell_atlas_coords(cell) != Vector2i(1, 0):
					valley_grass2_moved += 1
			assert_true(valley_grass2_moved == 0, "Valley entrance leaves (1, 0) cells unchanged")
	print("  Grass scatter: All tests completed")


func _mount_scene(packed: PackedScene) -> Dictionary:
	# Read authored cells before add_child so _ready can scatter.
	var node := packed.instantiate()
	var ground := _find_ground(node)
	var authored := {}
	if ground != null:
		authored = _atlases(ground)
		add_child(node)
	return {"node": node, "ground": ground, "authored": authored}


func _find_ground(node: Node) -> TileMapLayer:
	var map: EditableMap2D = null
	if node is EditableMap2D:
		map = node as EditableMap2D
	else:
		map = node.get_node_or_null("FarmMap") as EditableMap2D
	if map == null:
		return null
	return map.get_layer(&"ground") as TileMapLayer


func _listens_for_farm_reset(farm: Node) -> bool:
	for conn in FarmState.farm_reset.get_connections():
		var bound := conn["callable"] as Callable
		if bound.get_object() == farm:
			return true
	return false


func _assert_scattered_ground(layer: TileMapLayer, authored: Dictionary, label: String) -> void:
	var now_map := _atlases(layer)
	var plain := 0
	var plain_bad := 0
	var other_bad := 0
	var varied := 0
	var example := ""
	for cell in authored.keys():
		var coord: Vector2i = cell
		var was: Vector2i = authored[cell]
		var has_cell := now_map.has(coord)
		var now: Vector2i = now_map.get(coord, Vector2i(-999, -999))
		if was == Vector2i(0, 0):
			plain += 1
			var expected := FarmTilesetBuilder.grass_atlas_at(coord)
			if expected != Vector2i(0, 0):
				varied += 1
			if not has_cell or now != expected:
				plain_bad += 1
				if example.is_empty():
					example = "%s expected %s got %s" % [coord, expected, now]
		elif not has_cell or now != was:
			other_bad += 1
			if example.is_empty():
				example = "%s expected %s got %s" % [coord, was, now]
	var extra := 0
	for cell in now_map.keys():
		if not authored.has(cell):
			extra += 1
	assert_true(plain > 0, "%s checked %d former (0, 0) cells" % [label, plain])
	assert_true(varied > 0, "%s grass_atlas_at changes some former (0, 0) cells (%d)" % [label, varied])
	assert_true(plain_bad == 0, "%s former (0, 0) cells equal grass_atlas_at (%s)" % [label, example])
	assert_true(other_bad == 0 and extra == 0, "%s other ground cells unchanged (%d checked, %s)" % [label, authored.size() - plain, example])


func _atlases(layer: TileMapLayer) -> Dictionary:
	var out := {}
	for cell in layer.get_used_cells():
		out[cell] = layer.get_cell_atlas_coords(cell)
	return out


func _same_atlas(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for cell in left.keys():
		if left[cell] != right.get(cell, Vector2i(-999, -999)):
			return false
	return true


func assert_true(condition: bool, message: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % message)
	else:
		failed_tests += 1
		print("  [FAIL] %s" % message)
