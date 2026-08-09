@tool
extends Resource
class_name MapLayerSpec

enum LayerKind {
	TILE,
	DECORATION,
	OBJECT,
	COLLISION,
	MARKER,
}

@export var layer_id: StringName
@export var display_name: String
@export var kind: LayerKind = LayerKind.TILE
@export var required: bool = false
@export var default_z_index: int = 0
@export var y_sort: bool = false
@export var allowed_asset_tags: PackedStringArray = []


func accepts_asset_kind(asset_kind: int) -> bool:
	match kind:
		LayerKind.TILE:
			return asset_kind == MapAssetEntry.AssetKind.TILE_SET
		LayerKind.DECORATION:
			return asset_kind == MapAssetEntry.AssetKind.DECORATION
		LayerKind.OBJECT:
			return asset_kind == MapAssetEntry.AssetKind.SCENE
		_:
			return false
