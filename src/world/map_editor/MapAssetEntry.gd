@tool
extends Resource
class_name MapAssetEntry

enum AssetKind {
	TILE_SET,
	DECORATION,
	SCENE,
}

@export var asset_id: StringName
@export var display_name: String
@export var kind: AssetKind = AssetKind.DECORATION
@export var resource: Resource
@export var thumbnail: Texture2D
@export var tags: PackedStringArray = []
@export var default_layer_id: StringName
@export var footprint: Vector2i = Vector2i.ONE
@export var exposed_properties: PackedStringArray = []


func is_valid_entry() -> bool:
	if asset_id.is_empty() or resource == null:
		return false
	match kind:
		AssetKind.TILE_SET:
			return resource is TileSet
		AssetKind.DECORATION:
			return resource is Texture2D
		AssetKind.SCENE:
			return resource is PackedScene
	return false
