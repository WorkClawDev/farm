extends Control
class_name HouseUpgradeUI

## HouseUpgradeUI - 房屋升级界面
## 显示当前房屋状态和升级选项

@onready var current_level_label: Label = $Panel/CurrentLevelLabel
@onready var description_label: Label = $Panel/DescriptionLabel
@onready var upgrade_cost_label: Label = $Panel/UpgradeCostLabel
@onready var upgrade_button: Button = $Panel/UpgradeButton
@onready var close_button: Button = $Panel/CloseButton
@onready var money_label: Label = $Panel/MoneyLabel
@onready var benefits_label: Label = $Panel/BenefitsLabel

var _message_label: Label

func _ready() -> void:
	_setup_signals()
	_update_display()

func _setup_signals() -> void:
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _update_display() -> void:
	var house_system = get_node_or_null("/root/HouseUpgradeSystem")
	if not house_system:
		return
	
	# 显示当前房屋信息
	var config = house_system.get_current_config()
	var level_name = config.get("name", "未知")
	var description = config.get("description", "")
	
	if current_level_label:
		current_level_label.text = "当前房屋: " + level_name
	
	if description_label:
		description_label.text = description
	
	# 显示升级费用
	var can_upgrade = house_system.can_upgrade()
	if can_upgrade:
		var cost = house_system.get_upgrade_cost()
		if upgrade_cost_label:
			upgrade_cost_label.text = "升级费用: %dG" % cost
		if upgrade_button:
			upgrade_button.disabled = false
			upgrade_button.text = "升级房屋"
	else:
		if upgrade_cost_label:
			if house_system.get_current_level() == 3:
				upgrade_cost_label.text = "已达最高等级"
			else:
				var cost = house_system.get_upgrade_cost()
				upgrade_cost_label.text = "升级费用: %dG (金钱不足)" % cost
		if upgrade_button:
			upgrade_button.disabled = true
			upgrade_button.text = "无法升级"
	
	# 显示当前金钱
	var money_system = get_node_or_null("/root/MoneySystem")
	if money_label and money_system:
		money_label.text = "持有金钱: %dG" % money_system.get_money()
	
	# 显示房屋属性
	if benefits_label:
		var text = "房间数: %d\n" % config.get("room_count", 0)
		text += "家具槽位: %d\n" % config.get("furniture_slots", 0)
		text += "储物空间: %d\n" % config.get("storage_slots", 0)
		text += "厨房: %s\n" % ("有" if config.get("kitchen_available", false) else "无")
		text += "卧室: %d间" % config.get("bedroom_count", 0)
		benefits_label.text = text

func _on_upgrade_pressed() -> void:
	var house_system = get_node_or_null("/root/HouseUpgradeSystem")
	if house_system and house_system.upgrade_house():
		_update_display()
		_show_message("房屋升级成功！")
	else:
		_show_message("升级失败，请检查条件")

func _on_close_pressed() -> void:
	hide()

func _show_message(text: String) -> void:
	print("[HouseUpgradeUI] ", text)
	# 创建或复用消息标签
	if not _message_label:
		_message_label = Label.new()
		_message_label.name = "MessageLabel"
		_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message_label.add_theme_font_size_override("font_size", 16)
		_message_label.modulate = Color(1.0, 0.9, 0.2, 1.0)  # 金黄色
		_panel_add_message_label()
	
	_message_label.text = text
	_message_label.modulate.a = 1.0
	
	# 淡出动画
	var tween := create_tween()
	tween.tween_property(_message_label, "modulate:a", 0.0, 2.5)


func _panel_add_message_label() -> void:
	# 找到 Panel 并添加消息标签
	var panel := find_child("Panel", true, false)
	if panel and _message_label.get_parent() != panel:
		panel.add_child(_message_label)
		# 设置位置在面板底部
		_message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_message_label.offset_top = -60
		_message_label.offset_bottom = -35
		_message_label.offset_left = -150
		_message_label.offset_right = 150

func open() -> void:
	show()
	_update_display()