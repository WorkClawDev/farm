extends Area2D
class_name CarpenterNPC

## CarpenterNPC - 木匠NPC
## 处理房屋升级和家具购买

@export var npc_name: String = "木匠"

var is_player_in_range: bool = false
var current_player: Player = null

# UI引用
var house_upgrade_ui: Control = null
var furniture_shop_ui: Control = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[CarpenterNPC] Carpenter initialized")

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = true
		current_player = body
		print("[CarpenterNPC] 按 E 键与木匠对话")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_in_range = false
		current_player = null

func _input(event: InputEvent) -> void:
	if not is_player_in_range:
		return
	
	if event.is_action_pressed("interact"):
		_open_carpenter_menu()

func _open_carpenter_menu() -> void:
	print("[CarpenterNPC] 打开木匠菜单")
	_show_carpenter_dialog()

func _show_carpenter_dialog() -> void:
	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = Vector2(300, 200)
	dialog.name = "CarpenterDialog"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var title := Label.new()
	title.text = "木匠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	var house_btn := Button.new()
	house_btn.text = "房屋升级"
	house_btn.pressed.connect(_on_carpenter_house_upgrade)
	vbox.add_child(house_btn)

	var furniture_btn := Button.new()
	furniture_btn.text = "购买家具"
	furniture_btn.pressed.connect(_on_carpenter_furniture)
	vbox.add_child(furniture_btn)

	var close_btn := Button.new()
	close_btn.text = "离开"
	close_btn.pressed.connect(_on_carpenter_close.bind(dialog))
	vbox.add_child(close_btn)

	dialog.hide()
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()

func _on_carpenter_house_upgrade() -> void:
	print("[CarpenterNPC] 选择: 房屋升级")
	open_house_upgrade()

func _on_carpenter_furniture() -> void:
	print("[CarpenterNPC] 选择: 购买家具")
	open_furniture_shop()

func _on_carpenter_close(dialog: Control) -> void:
	dialog.queue_free()

func _show_dialog() -> void:
	# 简单的对话显示
	print("[CarpenterNPC] 木匠: \"你好！需要我帮你升级房屋或购买家具吗？\"")
	print("[CarpenterNPC] 选项: 1. 房屋升级  2. 购买家具  3. 离开")

## 打开房屋升级界面
func open_house_upgrade() -> void:
	if house_upgrade_ui == null:
		var ui_scene = load("res://src/ui/menus/HouseUpgradeUI.tscn")
		if ui_scene:
			house_upgrade_ui = ui_scene.instantiate()
			get_tree().current_scene.add_child(house_upgrade_ui)
	
	if house_upgrade_ui:
		house_upgrade_ui.open()

## 打开家具商店界面
func open_furniture_shop() -> void:
	if furniture_shop_ui == null:
		var ui_scene = load("res://src/ui/menus/FurnitureShopUI.tscn")
		if ui_scene:
			furniture_shop_ui = ui_scene.instantiate()
			get_tree().current_scene.add_child(furniture_shop_ui)
	
	if furniture_shop_ui:
		furniture_shop_ui.open()