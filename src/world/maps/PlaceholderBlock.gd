extends Node2D
class_name PlaceholderBlock

## 占位块 - 用于白模阶段的地图结构验证

@export var block_size: Vector2 = Vector2(64, 64)
@export var block_color: Color = Color.BROWN
@export var is_solid: bool = true  # 是否是障碍物

var rect: ColorRect

func _ready() -> void:
	rect = ColorRect.new()
	rect.size = block_size
	rect.color = block_color
	rect.position = -block_size / 2  # 居中
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	
	if not is_solid:
		rect.modulate.a = 0.5  # 半透明表示可通行

func set_size(new_size: Vector2) -> void:
	block_size = new_size
	if rect:
		rect.size = block_size
		rect.position = -block_size / 2

func set_color(new_color: Color) -> void:
	block_color = new_color
	if rect:
		rect.color = block_color
