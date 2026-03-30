extends Control
class_name ToolDisplay

## ToolDisplay - 工具显示UI
## 显示当前持有的工具

@onready var tool_icon: TextureRect = $ToolIcon
@onready var tool_name_label: Label = $ToolNameLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_tool_name: String = ""

func _ready() -> void:
	# 连接工具切换信号
	if get_tree().current_scene:
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player and player.tool_manager:
			player.tool_manager.tool_changed.connect(_on_tool_changed)
	
	# 初始隐藏
	modulate = Color(1, 1, 1, 0.7)

func _on_tool_changed(tool_type: int, tool_name: String) -> void:
	current_tool_name = tool_name
	tool_name_label.text = tool_name
	
	# 播放切换动画
	if animation_player:
		animation_player.play("tool_switch")
	
	# 更新图标（这里可以添加不同工具的图标）
	_update_tool_icon(tool_type)

func _update_tool_icon(tool_type: int) -> void:
	# 根据工具类型设置图标
	# 这里使用颜色区分不同工具
	match tool_type:
		0: # NONE
			tool_icon.modulate = Color(0.5, 0.5, 0.5)
		1: # HOE
			tool_icon.modulate = Color(0.8, 0.6, 0.4)
		2: # WATERING_CAN
			tool_icon.modulate = Color(0.2, 0.5, 0.9)
		3: # AXE
			tool_icon.modulate = Color(0.6, 0.3, 0.2)
		4: # PICKAXE
			tool_icon.modulate = Color(0.4, 0.4, 0.4)
		5: # SICKLE
			tool_icon.modulate = Color(0.3, 0.7, 0.3)
		6: # FISHING_ROD
			tool_icon.modulate = Color(0.9, 0.7, 0.2)
