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

	return ImageTexture.create_from_image(image)
