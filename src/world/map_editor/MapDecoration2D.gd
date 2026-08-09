@tool
extends Sprite2D
class_name MapDecoration2D

@export var asset_id: StringName


func configure(entry: MapAssetEntry) -> void:
	if entry == null or entry.kind != MapAssetEntry.AssetKind.DECORATION:
		return
	asset_id = entry.asset_id
	set_meta("map_asset_id", entry.asset_id)
	texture = entry.resource as Texture2D
