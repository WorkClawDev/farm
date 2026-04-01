extends Control
class_name CraftingUI

## CraftingUI - 制作界面
## 显示配方列表、材料检查、执行制作

signal crafting_closed
signal item_crafted(recipe_id: String)

# 常量
const RECIPE_SLOT_SIZE := 64
const INGREDIENT_SLOT_SIZE := 48
const PADDING := 8

# 节点引用
var main_panel: Panel
var recipe_list_container: VBoxContainer
var recipe_detail_panel: PanelContainer
var ingredient_grid: GridContainer
var craft_button: Button
var close_button: Button
var category_tabs: HBoxContainer
var quantity_spinbox: SpinBox
var result_label: Label

# 数据
var _recipes: Array = []
var _filtered_recipes: Array = []
var _selected_recipe: CraftingSystem.Recipe = null
var _selected_category: int = -1  # -1 表示全部
var _workbench_type: String = ""
var _is_open: bool = false

# 配方槽位
var _recipe_slots: Array[Control] = []


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_refresh_recipes()


func _setup_ui() -> void:
	# 设置锚点
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 背景遮罩
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.5)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.gui_input.connect(_on_background_input)
	add_child(background)

	# 主面板
	main_panel = Panel.new()
	main_panel.name = "MainPanel"
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -400
	main_panel.offset_right = 400
	main_panel.offset_top = -300
	main_panel.offset_bottom = 300
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(main_panel)

	# 主容器
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.offset_left = 16
	main_vbox.offset_right = -16
	main_vbox.offset_top = 16
	main_vbox.offset_bottom = -16
	main_panel.add_child(main_vbox)

	# 顶部栏
	_setup_header(main_vbox)

	# 分类标签
	_setup_category_tabs(main_vbox)

	# 中间内容区域
	var content_hbox := HBoxContainer.new()
	content_hbox.name = "ContentHBox"
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# 左侧配方列表
	_setup_recipe_list(content_hbox)

	# 右侧详情面板
	_setup_detail_panel(content_hbox)


func _setup_header(parent: Container) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	parent.add_child(header)

	# 标题
	var title := Label.new()
	title.text = "制作"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# 工作台提示
	var workbench_label := Label.new()
	workbench_label.name = "WorkbenchLabel"
	workbench_label.text = ""
	workbench_label.add_theme_font_size_override("font_size", 14)
	workbench_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(workbench_label)

	# 关闭按钮
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(32, 32)
	header.add_child(close_button)


func _setup_category_tabs(parent: Container) -> void:
	category_tabs = HBoxContainer.new()
	category_tabs.name = "CategoryTabs"
	category_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(category_tabs)

	# 添加"全部"标签
	_add_category_button(-1, "全部")

	# 添加各分类标签
	var categories := [
		{"id": CraftingSystem.RecipeCategory.TOOL, "name": "工具"},
		{"id": CraftingSystem.RecipeCategory.EQUIPMENT, "name": "设备"},
		{"id": CraftingSystem.RecipeCategory.FOOD, "name": "食物"},
		{"id": CraftingSystem.RecipeCategory.RESOURCE, "name": "材料"},
		{"id": CraftingSystem.RecipeCategory.DECORATION, "name": "装饰"}
	]

	for category in categories:
		_add_category_button(category.id, category.name)


func _add_category_button(category_id: int, name: String) -> void:
	var button := Button.new()
	button.text = name
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(60, 32)
	button.set_meta("category_id", category_id)
	button.pressed.connect(_on_category_pressed.bind(category_id))
	category_tabs.add_child(button)


func _setup_recipe_list(parent: Container) -> void:
	var list_panel := PanelContainer.new()
	list_panel.name = "ListPanel"
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 0.4
	parent.add_child(list_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "RecipeScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)

	recipe_list_container = VBoxContainer.new()
	recipe_list_container.name = "RecipeList"
	scroll.add_child(recipe_list_container)


func _setup_detail_panel(parent: Container) -> void:
	recipe_detail_panel = PanelContainer.new()
	recipe_detail_panel.name = "DetailPanel"
	recipe_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_detail_panel.size_flags_stretch_ratio = 0.6
	parent.add_child(recipe_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "DetailVBox"
	recipe_detail_panel.add_child(detail_vbox)

	# 配方名称
	var name_label := Label.new()
	name_label.name = "RecipeName"
	name_label.text = "选择一个配方"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_vbox.add_child(name_label)

	# 分隔
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	detail_vbox.add_child(spacer1)

	# 结果物品
	var result_hbox := HBoxContainer.new()
	result_hbox.name = "ResultHBox"
	result_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_vbox.add_child(result_hbox)

	var result_icon := ColorRect.new()
	result_icon.name = "ResultIcon"
	result_icon.color = Color(0.4, 0.8, 0.4)
	result_icon.custom_minimum_size = Vector2(INGREDIENT_SLOT_SIZE, INGREDIENT_SLOT_SIZE)
	result_hbox.add_child(result_icon)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 16)
	result_hbox.add_child(result_label)

	# 分隔
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	detail_vbox.add_child(spacer2)

	# 材料标题
	var ingredient_title := Label.new()
	ingredient_title.text = "所需材料:"
	ingredient_title.add_theme_font_size_override("font_size", 16)
	detail_vbox.add_child(ingredient_title)

	# 材料网格
	ingredient_grid = GridContainer.new()
	ingredient_grid.name = "IngredientGrid"
	ingredient_grid.columns = 4
	ingredient_grid.add_theme_constant_override("h_separation", PADDING)
	ingredient_grid.add_theme_constant_override("v_separation", PADDING)
	detail_vbox.add_child(ingredient_grid)

	# 弹性空间
	var spacer3 := Control.new()
	spacer3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(spacer3)

	# 制作数量
	var quantity_hbox := HBoxContainer.new()
	quantity_hbox.name = "QuantityHBox"
	quantity_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_vbox.add_child(quantity_hbox)

	var quantity_label := Label.new()
	quantity_label.text = "制作数量: "
	quantity_hbox.add_child(quantity_label)

	quantity_spinbox = SpinBox.new()
	quantity_spinbox.name = "QuantitySpinBox"
	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = 999
	quantity_spinbox.value = 1
	quantity_spinbox.step = 1
	quantity_hbox.add_child(quantity_spinbox)

	# 可制作数量提示
	var craftable_label := Label.new()
	craftable_label.name = "CraftableLabel"
	craftable_label.text = "(可制作: 0)"
	craftable_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	quantity_hbox.add_child(craftable_label)

	# 制作按钮
	craft_button = Button.new()
	craft_button.name = "CraftButton"
	craft_button.text = "制作"
	craft_button.custom_minimum_size = Vector2(120, 40)
	craft_button.disabled = true
	detail_vbox.add_child(craft_button)

	# 描述
	var desc_label := Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = ""
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail_vbox.add_child(desc_label)


func _connect_signals() -> void:
	close_button.pressed.connect(close)
	craft_button.pressed.connect(_on_craft_pressed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)

	if CraftingSystem:
		CraftingSystem.recipes_loaded.connect(_refresh_recipes)
		CraftingSystem.recipe_unlocked.connect(_on_recipe_unlocked)
		CraftingSystem.item_crafted.connect(_on_item_crafted)


func _refresh_recipes() -> void:
	if CraftingSystem == null:
		return

	# 根据工作台类型获取配方
	if _workbench_type == "":
		_recipes = CraftingSystem.get_unlocked_recipes()
	else:
		_recipes = CraftingSystem.get_recipes_by_workbench(_workbench_type)

	_apply_category_filter()
	_update_recipe_list()


func _apply_category_filter() -> void:
	_filtered_recipes.clear()

	if _selected_category == -1:
		_filtered_recipes = _recipes.duplicate()
	else:
		for recipe in _recipes:
			if recipe.category == _selected_category:
				_filtered_recipes.append(recipe)


func _update_recipe_list() -> void:
	# 清空现有槽位
	for child in recipe_list_container.get_children():
		child.queue_free()
	_recipe_slots.clear()

	# 创建配方槽位
	for recipe in _filtered_recipes:
		var slot := _create_recipe_slot(recipe)
		_recipe_slots.append(slot)
		recipe_list_container.add_child(slot)


func _create_recipe_slot(recipe: CraftingSystem.Recipe) -> Control:
	var slot := Button.new()
	slot.name = "RecipeSlot_%s" % recipe.id
	slot.custom_minimum_size = Vector2(RECIPE_SLOT_SIZE * 3, RECIPE_SLOT_SIZE)
	slot.toggle_mode = true
	slot.set_meta("recipe_id", recipe.id)

	# 检查是否可制作
	var can_craft := CraftingSystem.can_craft(recipe.id)
	if not can_craft.can_craft:
		slot.modulate = Color(0.6, 0.6, 0.6)

	# 创建内容
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(hbox)

	# 结果图标（用颜色方块代替）
	var icon := ColorRect.new()
	icon.color = _get_category_color(recipe.category)
	icon.custom_minimum_size = Vector2(RECIPE_SLOT_SIZE - 16, RECIPE_SLOT_SIZE - 16)
	hbox.add_child(icon)

	# 配方名称
	var name_label := Label.new()
	name_label.text = recipe.name
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	# 可制作数量
	var craftable := CraftingSystem.get_craftable_count(recipe.id)
	var count_label := Label.new()
	count_label.text = " x%d" % craftable
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(count_label)

	slot.pressed.connect(_on_recipe_selected.bind(recipe.id))

	return slot


func _get_category_color(category: int) -> Color:
	match category:
		CraftingSystem.RecipeCategory.TOOL: return Color(0.5, 0.5, 0.6)
		CraftingSystem.RecipeCategory.EQUIPMENT: return Color(0.4, 0.6, 0.8)
		CraftingSystem.RecipeCategory.FOOD: return Color(0.9, 0.6, 0.3)
		CraftingSystem.RecipeCategory.RESOURCE: return Color(0.6, 0.5, 0.4)
		CraftingSystem.RecipeCategory.DECORATION: return Color(0.9, 0.5, 0.8)
		CraftingSystem.RecipeCategory.ALCHEMY: return Color(0.7, 0.4, 0.9)
		_: return Color(0.5, 0.5, 0.5)


func _on_recipe_selected(recipe_id: String) -> void:
	_selected_recipe = CraftingSystem.get_recipe(recipe_id)
	_update_detail_panel()

	# 更新槽位选中状态
	for slot in _recipe_slots:
		if slot.get_meta("recipe_id") == recipe_id:
			slot.button_pressed = true


func _update_detail_panel() -> void:
	if _selected_recipe == null:
		return

	# 更新名称
	var name_label: Label = recipe_detail_panel.get_node_or_null("DetailVBox/RecipeName")
	if name_label:
		name_label.text = _selected_recipe.name

	# 更新结果
	if result_label:
		result_label.text = " x%d" % _selected_recipe.result_quantity

	# 更新描述
	var desc_label: Label = recipe_detail_panel.get_node_or_null("DetailVBox/DescriptionLabel")
	if desc_label:
		desc_label.text = _selected_recipe.description

	# 更新材料
	_update_ingredient_grid()

	# 更新可制作数量
	_update_craftable_count()

	# 更新制作按钮
	_update_craft_button()


func _update_ingredient_grid() -> void:
	if ingredient_grid == null:
		return

	# 清空现有格子
	for child in ingredient_grid.get_children():
		child.queue_free()

	if _selected_recipe == null:
		return

	var ingredients := CraftingSystem.get_ingredient_info(_selected_recipe.id)

	for ingredient in ingredients:
		var slot := _create_ingredient_slot(ingredient)
		ingredient_grid.add_child(slot)


func _create_ingredient_slot(ingredient: Dictionary) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(INGREDIENT_SLOT_SIZE, INGREDIENT_SLOT_SIZE)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vbox)

	# 图标（用颜色代替）
	var icon := ColorRect.new()
	icon.color = Color(0.4, 0.4, 0.4) if ingredient.sufficient else Color(0.8, 0.3, 0.3)
	icon.custom_minimum_size = Vector2(24, 24)
	vbox.add_child(icon)

	# 数量
	var count_label := Label.new()
	count_label.text = "%d/%d" % [ingredient.have, ingredient.required]
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE if ingredient.sufficient else Color(0.9, 0.3, 0.3))
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(count_label)

	# 添加工具提示
	slot.tooltip_text = "%s: %d/%d" % [ingredient.item_name, ingredient.have, ingredient.required]

	return slot


func _update_craftable_count() -> void:
	var craftable_label: Label = recipe_detail_panel.get_node_or_null("DetailVBox/QuantityHBox/CraftableLabel")
	if craftable_label and _selected_recipe:
		var count := CraftingSystem.get_craftable_count(_selected_recipe.id)
		craftable_label.text = "(可制作: %d)" % count


func _update_craft_button() -> void:
	if craft_button == null or _selected_recipe == null:
		return

	var can_craft := CraftingSystem.can_craft(_selected_recipe.id)
	craft_button.disabled = not can_craft.can_craft

	if not can_craft.can_craft:
		craft_button.text = can_craft.reason
	else:
		craft_button.text = "制作"


func _on_category_pressed(category_id: int) -> void:
	_selected_category = category_id

	# 更新按钮状态
	for child in category_tabs.get_children():
		if child is Button:
			var child_id: int = child.get_meta("category_id", -1)
			child.button_pressed = (child_id == category_id)

	_apply_category_filter()
	_update_recipe_list()
	_selected_recipe = null


func _on_craft_pressed() -> void:
	if _selected_recipe == null:
		return

	var count := int(quantity_spinbox.value)
	var crafted := CraftingSystem.craft_batch(_selected_recipe.id, count, _workbench_type)

	if crafted > 0:
		item_crafted.emit(_selected_recipe.id)
		# 刷新界面
		_update_recipe_list()
		_update_detail_panel()


func _on_quantity_changed(_value: float) -> void:
	# 更新可制作检查
	_update_craft_button()


func _on_recipe_unlocked(recipe_id: String) -> void:
	_refresh_recipes()


func _on_item_crafted(_recipe_id: String, _result_item: String, _quantity: int) -> void:
	# 刷新材料显示
	_update_ingredient_grid()
	_update_craftable_count()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if _is_open:
				close()
				get_viewport().set_input_as_handled()


func open(workbench_type: String = "") -> void:
	_workbench_type = workbench_type
	visible = true
	_is_open = true

	# 更新工作台标签
	var workbench_label: Label = main_panel.get_node_or_null("MainVBox/Header/WorkbenchLabel")
	if workbench_label:
		if workbench_type != "":
			workbench_label.text = "[%s]" % workbench_type
		else:
			workbench_label.text = ""

	_refresh_recipes()

	if EventBus:
		get_node("/root/EventBus").ui.ui_opened.emit("crafting")


func close() -> void:
	visible = false
	_is_open = false
	_selected_recipe = null

	if EventBus:
		get_node("/root/EventBus").ui.ui_closed.emit("crafting")

	crafting_closed.emit()


func toggle(workbench_type: String = "") -> void:
	if _is_open:
		close()
	else:
		open(workbench_type)


func is_open() -> bool:
	return _is_open
