extends RefCounted
class_name PrivateDecor

## Optional CraftPix trees / bushes / rocks from the private submodule.
## Paths are never preloaded or referenced from .tscn so a missing submodule
## just skips the decoration.

const PRIVATE_ROOT := "res://assets/private/topdown_farm/"
## Same uniform scale as PrivateBuildingArt (x4 atlas -> half screen size).
const DISPLAY_SCALE := 0.5


static func load_texture(relative_path: String) -> Texture2D:
	var path := PRIVATE_ROOT + relative_path
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Spawns a y-sorted StaticBody2D whose origin sits at the feet (bottom-centre
## of the sprite). Returns null when the private texture is missing.
static func spawn(parent: Node2D, relative_path: String, feet: Vector2, kind: String = "decor") -> StaticBody2D:
	var texture := load_texture(relative_path)
	if texture == null:
		return null

	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [kind, int(feet.x), int(feet.y)]
	body.position = feet
	body.collision_layer = 1
	body.collision_mask = 0
	body.y_sort_enabled = true

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
	var display_h := texture.get_size().y * DISPLAY_SCALE
	# Root is at the feet; shift artwork up so the canvas bottom sits on the origin.
	sprite.position = Vector2(0, -display_h * 0.5)
	body.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	match kind:
		"tree":
			shape.radius = 14.0
		"bush":
			shape.radius = 10.0
		_:
			shape.radius = 12.0
	collision.shape = shape
	collision.position = Vector2(0, -4)
	body.add_child(collision)

	parent.add_child(body)
	return body
