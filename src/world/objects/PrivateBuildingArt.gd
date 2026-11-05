extends RefCounted

## Optional CraftPix building exteriors from the private submodule
## (assets/private/topdown_farm). Never preload these paths: the submodule may be
## absent, in which case every caller keeps its public fallback art.

const HOUSES_ATLAS := "res://assets/private/topdown_farm/buildings/x4/Houses_x4.png"
## One uniform scale for every CraftPix building (x4 atlas -> 2 screen px per
## source px). Keeps the farmhouse (B06) under the map's top edge with its door
## on the farm road, and never stretches width and height separately.
const DISPLAY_SCALE := 0.5


static func load_region(region: Rect2) -> Texture2D:
	if not ResourceLoader.exists(HOUSES_ATLAS):
		return null
	var atlas := load(HOUSES_ATLAS) as Texture2D
	if atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = region
	return texture


static func display_size(region: Rect2) -> Vector2:
	return region.size * DISPLAY_SCALE
