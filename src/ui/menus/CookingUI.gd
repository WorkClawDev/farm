extends CanvasLayer
class_name CookingUI

## CookingUI - 烹饪界面
## 显示食谱列表、材料需求、烹饪操作

# 信号
signal cooking_ui_closed

# UI模式
enum UIMode {
	ALL,
	COOKING,
	BAKING,
	BREWING
}

# 常量
const SLOT_SIZE := 48
const RECIPE_BUTTON_HEIGHT := 50

# 节点引用
var main_panel: Panel
var recipe_list: VBoxContainer
var recipe_scroll: ScrollContainer
var info_panel: Panel
var ingredients_grid: GridContainer
var cook_button: Button
var close_button: Button
var category_tabs: HBoxContainer
var message_label: Label

# 数据
var _current_mode: UIMode = UIMode.ALL
var _selected_recipe_id: String = ""
var _is_open: bool = false
var _cooking_animation: Control = null

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	hide()

func _setup_ui() -> void:
	# 背景遮罩
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.5)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# 主面板
	main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -350
	main_panel.offset_right = 350
	main_panel.offset_top = -280
	main_panel.offset_bottom = 280
	add_child(main_panel)

	# 主容器
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	main_panel.add_child(vbox)

	# 头部
	_setup_header(vbox)

	# 分隔
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# 内容区域
	var content := HSplitContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# 左侧：食谱列表
	_setup_recipe_list(content)

	# 右侧：详情面板
	_setup_info_panel(content)

	# 分隔
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# 底部
	_setup_footer(vbox)

func _setup_header(parent: Container) -> void:
	var header := VBoxContainer.new()
	header.name = "Header"
	parent.add_child(header)

	# 标题行
	var title_row := HBoxContainer.new()
	header.add_child(title_row)

	var title := Label.new()
	title.text = "烹饪"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	title_row.add_child(close_button)

	# 分类标签
	category_tabs = HBoxContainer.new()
	category_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(category_tabs)

	var all_btn := Button.new()
	all_btn.text = "全部"
	all_btn.toggle_mode = true
	all_btn.button_pressed = true
	all_btn.pressed.connect(_on_category_pressed.bind(UIMode.ALL))
	category_tabs.add_child(all_btn)

	var cooking_btn := Button.new()
	cooking_btn.text = "烹饪"
	cooking_btn.toggle_mode = true
	cooking_btn.pressed.connect(_on_category_pressed.bind(UIMode.COOKING))
	category_tabs.add_child(cooking_btn)

	var baking_btn := Button.new()
	baking_btn.text = "烘焙"
	baking_btn.toggle_mode = true
	baking_btn.pressed.connect(_on_category_pressed.bind(UIMode.BAKING))
	category_tabs.add_child(baking_btn)

	var brewing_btn := Button.new()
	brewing_btn.text = "饮品"
	brewing_btn.toggle_mode = true
	brewing_btn.pressed.connect(_on_category_pressed.bind(UIMode.BREWING))
	category_tabs.add_child(brewing_btn)

func _setup_recipe_list(parent: Container) -> void:
	var list_panel := Panel.new()
	list_panel.name = "ListPanel"
	list_panel.custom_minimum_size = Vector2(280, 0)
	parent.add_child(list_panel)

	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.anchor_right = 1.0
	recipe_scroll.anchor_bottom = 1.0
	recipe_scroll.offset_left = 8
	recipe_scroll.offset_top = 8
	recipe_scroll.offset_right = -8
	recipe_scroll.offset_bottom = -8
	list_panel.add_child(recipe_scroll)

	recipe_list = VBoxContainer.new()
	recipe_list.name = "RecipeList"
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.add_child(recipe_list)

func _setup_info_panel(parent: Container) -> void:
	info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.anchor_right = 1.0
	info_vbox.anchor_bottom = 1.0
	info_vbox.offset_left = 16
	info_vbox.offset_top = 16
	info_vbox.offset_right = -16
	info_vbox.offset_bottom = -16
	info_panel.add_child(info_vbox)

	# 食谱名称
	var name_label := Label.new()
	name_label.name = "RecipeName"
	name_label.text = "选择一个食谱"
	name_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(name_label)

	# 描述
	var desc_label := Label.new()
	desc_label.name = "RecipeDesc"
	desc_label.text = ""
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# 分隔
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	info_vbox.add_child(spacer)

	# 材料标题
	var ingredients_title := Label.new()
	ingredients_title.text = "所需材料:"
	ingredients_title.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(ingredients_title)

	# 材料网格
	ingredients_grid = GridContainer.new()
	ingredients_grid.name = "IngredientsGrid"
	ingredients_grid.columns = 2
	info_vbox.add_child(ingredients_grid)

	# 效果信息
	var effects_label := Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.text = ""
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(effects_label)

	# 底部填充
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(filler)

	# 烹饪按钮
	cook_button = Button.new()
	cook_button.text = "烹饪"
	cook_button.custom_minimum_size = Vector2(0, 40)
	cook_button.disabled = true
	info_vbox.add_child(cook_button)

func _setup_footer(parent: Container) -> void:
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(footer)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)
	footer.add_child(message_label)

func _connect_signals() -> void:
	close_button.pressed.connect(close)
	cook_button.pressed.connect(_on_cook_pressed)

	# 连接烹饪系统信号
	if CookingSystem:
		CookingSystem.cooking_completed.connect(_on_cooking_completed)
		CookingSystem.cooking_failed.connect(_on_cooking_failed)
		CookingSystem.ingredients_missing.connect(_on_ingredients_missing)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()

## 打开界面
func open() -> void:
	visible = true
	_is_open = true
	_refresh_recipe_list()
	_clear_selection()

	if EventBus:
		get_node("/root/EventBus").ui_opened.emit("cooking")

## 关闭界面
func close() -> void:
	visible = false
	_is_open = false
	_selected_recipe_id = ""

	if EventBus:
		get_node("/root/EventBus").ui_closed.emit("cooking")

	cooking_ui_closed.emit()

## 切换显示
func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

## 刷新食谱列表
func _refresh_recipe_list() -> void:
	# 清空列表
	for child in recipe_list.get_children():
		child.queue_free()

	if CookingSystem == null:
		return

	var recipes := CookingSystem.get_learned_recipes()
	for recipe in recipes:
		# 过滤分类
		if _current_mode != UIMode.ALL:
			var category_map := {
				UIMode.COOKING: "cooking",
				UIMode.BAKING: "baking",
				UIMode.BREWING: "brewing"
			}
			if recipe.category != category_map.get(_current_mode, ""):
				continue

		_create_recipe_button(recipe)

## 创建食谱按钮
func _create_recipe_button(recipe) -> void:
	var button := Button.new()
	button.text = recipe.name
	button.custom_minimum_size = Vector2(0, RECIPE_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 检查是否可以烹饪
	var can_cook := CookingSystem.can_cook(recipe.id)
	if not can_cook.can_cook:
		button.modulate = Color(0.6, 0.6, 0.6, 1.0)
		button.tooltip_text = "材料不足"

	button.pressed.connect(_on_recipe_selected.bind(recipe.id))
	recipe_list.add_child(button)

## 选择食谱
func _on_recipe_selected(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	_update_info_panel()

## 更新信息面板
func _update_info_panel() -> void:
	if _selected_recipe_id == "":
		_clear_selection()
		return

	var recipe = CookingSystem.get_recipe(_selected_recipe_id)
	if recipe == null:
		_clear_selection()
		return

	# 更新名称
	var name_label: Label = info_panel.get_node("VBoxContainer/RecipeName")
	name_label.text = recipe.name

	# 更新描述
	var desc_label: Label = info_panel.get_node("VBoxContainer/RecipeDesc")
	desc_label.text = recipe.description

	# 更新材料
	_update_ingredients(recipe)

	# 更新效果
	_update_effects(recipe)

	# 更新烹饪按钮
	var can_cook := CookingSystem.can_cook(_selected_recipe_id)
	cook_button.disabled = not can_cook.can_cook

## 更新材料显示
func _update_ingredients(recipe) -> void:
	# 清空材料网格
	for child in ingredients_grid.get_children():
		child.queue_free()

	for ingredient in recipe.ingredients:
		var item_id: String = ingredient.get("item_id", "")
		var required: int = ingredient.get("quantity", 1)

		# 获取物品名称
		var item_name := item_id
		if ItemDatabase:
			var item = ItemDatabase.get_item(item_id)
			if item:
				item_name = item.name

		# 获取持有数量
		var have := 0
		if Inventory:
			have = Inventory.get_item_count(item_id)

		# 材料名称
		var name_label := Label.new()
		name_label.text = item_name
		ingredients_grid.add_child(name_label)

		# 数量
		var qty_label := Label.new()
		qty_label.text = "%d / %d" % [have, required]
		if have < required:
			qty_label.add_theme_color_override("font_color", Color.RED)
		else:
			qty_label.add_theme_color_override("font_color", Color.GREEN)
		ingredients_grid.add_child(qty_label)

## 更新效果显示
func _update_effects(recipe) -> void:
	var effects_label: Label = info_panel.get_node("VBoxContainer/EffectsLabel")
	var effects_text := ""

	if recipe.effects.has("energy"):
		effects_text += "恢复体力: %d  " % recipe.effects.energy
	if recipe.effects.has("health"):
		effects_text += "恢复生命: %d  " % recipe.effects.health
	if recipe.effects.has("buff"):
		var buff_name := _get_buff_name(recipe.effects.buff)
		var duration: int = recipe.effects.get("duration", 0)
		effects_text += "\n增益: %s (%d秒)" % [buff_name, duration]

	effects_label.text = effects_text

## 获取增益名称
func _get_buff_name(buff_type: String) -> String:
	var names := {
		"speed": "速度提升",
		"farming": "农作业加速",
		"mining": "采矿加速",
		"fishing": "钓鱼运气",
		"luck": "幸运加成",
		"max_energy": "体力上限提升"
	}
	return names.get(buff_type, buff_type)

## 清除选择
func _clear_selection() -> void:
	_selected_recipe_id = ""

	var name_label: Label = info_panel.get_node("VBoxContainer/RecipeName")
	name_label.text = "选择一个食谱"

	var desc_label: Label = info_panel.get_node("VBoxContainer/RecipeDesc")
	desc_label.text = ""

	var effects_label: Label = info_panel.get_node("VBoxContainer/EffectsLabel")
	effects_label.text = ""

	for child in ingredients_grid.get_children():
		child.queue_free()

	cook_button.disabled = true
	message_label.text = ""

## 分类按钮按下
func _on_category_pressed(mode: UIMode) -> void:
	_current_mode = mode
	_update_category_buttons()
	_refresh_recipe_list()
	_clear_selection()

func _update_category_buttons() -> void:
	var buttons := category_tabs.get_children()
	var modes := [UIMode.ALL, UIMode.COOKING, UIMode.BAKING, UIMode.BREWING]
	for i in buttons.size():
		buttons[i].button_pressed = (modes[i] == _current_mode)

## 烹饪按钮按下
func _on_cook_pressed() -> void:
	if _selected_recipe_id == "":
		return

	_show_cooking_animation()
	var success := CookingSystem.cook(_selected_recipe_id)

	if not success:
		_hide_cooking_animation()

## 显示烹饪动画
func _show_cooking_animation() -> void:
	if _cooking_animation:
		return

	_cooking_animation = Control.new()
	_cooking_animation.name = "CookingAnimation"
	_cooking_animation.anchor_right = 1.0
	_cooking_animation.anchor_bottom = 1.0
	_cooking_animation.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cooking_animation)

	# 半透明背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_cooking_animation.add_child(bg)

	# 烹饪中文字
	var label := Label.new()
	label.text = "烹饪中..."
	label.add_theme_font_size_override("font_size", 32)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.offset_left = -80
	label.offset_top = -20
	_cooking_animation.add_child(label)

	cook_button.disabled = true

## 隐藏烹饪动画
func _hide_cooking_animation() -> void:
	if _cooking_animation:
		_cooking_animation.queue_free()
		_cooking_animation = null

## 烹饪完成
func _on_cooking_completed(recipe_id: String, _result_item: String) -> void:
	_hide_cooking_animation()

	var recipe = CookingSystem.get_recipe(recipe_id)
	if recipe:
		_show_message("成功制作了 %s!" % recipe.name, false)

	# 刷新界面
	_refresh_recipe_list()
	_update_info_panel()

## 烹饪失败
func _on_cooking_failed(_recipe_id: String, reason: String) -> void:
	_hide_cooking_animation()

	var message := "烹饪失败: "
	match reason:
		"recipe_not_found":
			message += "食谱不存在"
		"recipe_not_learned":
			message += "尚未学会此食谱"
		"missing_ingredients":
			message += "材料不足"
		_:
			message += reason

	_show_message(message, true)

## 材料不足
func _on_ingredients_missing(_recipe_id: String, missing: Array) -> void:
	var missing_items := []
	for item in missing:
		if item.has("item_id"):
			var item_name := item.item_id
			if ItemDatabase:
				var item_data = ItemDatabase.get_item(item.item_id)
				if item_data:
					item_name = item_data.name
			missing_items.append(item_name)

	_show_message("缺少材料: %s" % ", ".join(missing_items), true)

## 显示消息
func _show_message(message: String, is_error: bool = false) -> void:
	message_label.text = message
	if is_error:
		message_label.modulate = Color.RED
	else:
		message_label.modulate = Color.GREEN

	# 3秒后清除
	await get_tree().create_timer(3.0).timeout
	message_label.text = ""

func is_open() -> bool:
	return _is_open