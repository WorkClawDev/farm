@tool
extends Resource
class_name MapAssetLibrary

@export var entries: Array[MapAssetEntry] = []


func get_entry(asset_id: StringName) -> MapAssetEntry:
	for entry in entries:
		if entry != null and entry.asset_id == asset_id:
			return entry
	return null


func find_entries(query: String = "", required_tags: PackedStringArray = []) -> Array[MapAssetEntry]:
	var result: Array[MapAssetEntry] = []
	var normalized_query := query.strip_edges().to_lower()
	for entry in entries:
		if entry == null:
			continue
		if not normalized_query.is_empty():
			var haystack := (str(entry.asset_id) + " " + entry.display_name + " " + " ".join(entry.tags)).to_lower()
			if not normalized_query in haystack:
				continue
		var matches_tags := true
		for tag in required_tags:
			if tag not in entry.tags:
				matches_tags = false
				break
		if matches_tags:
			result.append(entry)
	return result


func register(entry: MapAssetEntry) -> bool:
	if entry == null or not entry.is_valid_entry() or get_entry(entry.asset_id) != null:
		return false
	entries.append(entry)
	emit_changed()
	return true


func unregister(asset_id: StringName) -> bool:
	for index in range(entries.size()):
		if entries[index] != null and entries[index].asset_id == asset_id:
			entries.remove_at(index)
			emit_changed()
			return true
	return false
