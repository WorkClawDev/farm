extends RefCounted
class_name RuntimeTextureLoader


static func load_texture(texture_path: String) -> Texture2D:
	var source_path := ProjectSettings.globalize_path(texture_path)
	if not FileAccess.file_exists(source_path):
		if ResourceLoader.exists(texture_path, "Texture2D"):
			return load(texture_path) as Texture2D
		return null

	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		if ResourceLoader.exists(texture_path, "Texture2D"):
			return load(texture_path) as Texture2D
		return null

	# Runtime-loaded source art bypasses Godot's import settings. Generate
	# mipmaps here so scaled watercolor buildings and UI/world props keep clean
	# antialiased edges instead of shimmering or stair-stepping.
	if image.get_width() > 32 or image.get_height() > 32:
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
