extends Node
class_name MapLoader

## MapLoader - Autoload script for loading tile maps from JSON files.
## Place in Autoload as "MapLoader" (res://src/core/map/MapLoader.gd)

const TILE_SIZE := 16


## Load a tile map layout from a JSON file.
## Returns a 2D array of tile_ids, or an empty array if file not found/error.
static func load_layout(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[MapLoader] Could not open: " + path)
		return []

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[MapLoader] JSON parse error for: " + path)
		return []

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("[MapLoader] Invalid JSON format (expected dict): " + path)
		return []

	var tiles: Variant = data.get("tiles")
	if not tiles is Array:
		push_warning("[MapLoader] No 'tiles' array in: " + path)
		return []

	# Validate and normalize each row
	var result: Array = []
	for row in tiles:
		if not row is Array:
			continue
		var normalized_row: Array = []
		for tile_id in row:
			if tile_id is int:
				normalized_row.append(tile_id)
			elif tile_id is float:
				normalized_row.append(int(tile_id))
			else:
				normalized_row.append(0)
		result.append(normalized_row)

	print("[MapLoader] Loaded layout from: ", path, " (", result.size(), " rows)")
	return result


## Get map metadata from a JSON file (width, height, name, tile_size).
static func load_metadata(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}

	var data: Dictionary = json.data
	if not data is Dictionary:
		return {}

	return {
		"name": data.get("name", ""),
		"width": data.get("width", 0),
		"height": data.get("height", 0),
		"tile_size": data.get("tile_size", TILE_SIZE),
	}


## Check if a map file exists.
static func map_exists(path: String) -> bool:
	return FileAccess.file_exists(path)
