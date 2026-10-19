extends Control
class_name CookingUI

signal cooking_ui_closed

enum UIMode {
	ALL,
	COOKING,
	BAKING,
	BREWING,
}

var _current_mode := UIMode.ALL
var _selected_recipe_id := ""
var _is_open := false
var _category_buttons: Array[Button] = []
var _recipe_list: VBoxContainer
var _result_icon: TextureRect
var _recipe_name: Label
var _recipe_description: Label
var _ingredients: VBoxContainer
var _effects: Label
var _cook_button: Button
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	theme = UIStyles.active_theme()
	_build_ui()
	CookingManager.cooking_completed.connect(_on_cooking_completed)
	CookingManager.cooking_failed.connect(_on_cooking_failed)
	CookingManager.ingredients_missing.connect(_on_ingredients_missing)
	hide()


func configure(_context: Dictionary) -> void:
	open()


func open() -> void:
	show()
	_is_open = true
	_selected_recipe_id = ""
	_refresh_recipe_list()
	_clear_selection()
	await get_tree().process_frame
	UIFactory.focus_first(self)
	if EventBus:
		EventBus.ui.ui_opened.emit("cooking")


func close() -> void:
	if not _is_open:
		return
	hide()
	_is_open = false
	_selected_recipe_id = ""
	if EventBus:
		EventBus.ui.ui_closed.emit("cooking")
	cooking_ui_closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func get_recipe_count() -> int:
	return _recipe_list.get_child_count() if _recipe_list else 0


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = UIStyles.COLOR_SHADE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 48)
	safe.add_theme_constant_override("margin_top", 24)
	safe.add_theme_constant_override("margin_right", 48)
	safe.add_theme_constant_override("margin_bottom", 24)
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	var panel := UIFactory.paper_panel(Vector2(1060, 620))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UIFactory.title("厨房食谱")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var stamina := UIFactory.subtitle("烹饪会消耗少量体力")
	stamina.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A wrapping label in an HBox gets ~0 width and wraps one character per line,
	# which made the header (and the × button) hundreds of pixels tall (BUG-41).
	stamina.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(stamina)
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.tooltip_text = "关闭"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	for entry in [
		[UIMode.ALL, "全部"],
		[UIMode.COOKING, "料理"],
		[UIMode.BAKING, "烘焙"],
		[UIMode.BREWING, "饮品"],
	]:
		var button := UIFactory.button(str(entry[1]), &"TabButton", Vector2(132, 44))
		button.toggle_mode = true
		button.pressed.connect(_on_category_pressed.bind(int(entry[0])))
		tabs.add_child(button)
		_category_buttons.append(button)
	outer.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	outer.add_child(body)

	var list_panel := UIFactory.paper_panel(Vector2(390, 0))
	body.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_recipe_list)

	var details := UIFactory.paper_panel()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	details.add_child(content)
	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(96, 96)  # fits a 1280x720 window (BUG-41)
	_result_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_result_icon)
	_recipe_name = UIFactory.title("选择一个食谱", HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(_recipe_name)
	_recipe_description = Label.new()
	_recipe_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_recipe_description)
	content.add_child(HSeparator.new())
	content.add_child(UIFactory.subtitle("所需材料"))
	_ingredients = VBoxContainer.new()
	_ingredients.add_theme_constant_override("separation", 7)
	content.add_child(_ingredients)
	_effects = UIFactory.subtitle("")
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_effects)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(filler)
	_cook_button = UIFactory.button("开始烹饪", &"PrimaryButton", Vector2(0, 52))
	_cook_button.disabled = true
	_cook_button.pressed.connect(_on_cook_pressed)
	content.add_child(_cook_button)
	_status = UIFactory.subtitle("", HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)

	var footer := UIFactory.subtitle("方向键 / 摇杆选择  ·  Enter / A 烹饪  ·  Esc / B 返回")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(footer)
	_update_category_buttons()


func _refresh_recipe_list() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()
	var recipes: Array = CookingManager.get_learned_recipes()
	var visible_count := 0
	for recipe in recipes:
		if not _recipe_matches_filter(str(recipe.category)):
			continue
		var check: Dictionary = CookingManager.can_cook(str(recipe.id))
		var button := UIFactory.button(
			"%s\n%s" % [
				recipe.name,
				"材料齐全" if bool(check.can_cook) else "材料不足",
			],
			&"",
			Vector2(0, 68)
		)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = ItemDatabase.load_icon_texture(str(recipe.result_item))
		button.expand_icon = true
		button.modulate = Color.WHITE if bool(check.can_cook) else Color(0.72, 0.68, 0.62)
		button.pressed.connect(_on_recipe_selected.bind(str(recipe.id)))
		_recipe_list.add_child(button)
		visible_count += 1
	if visible_count == 0:
		var empty := UIFactory.subtitle("这个分类还没有学会的食谱", HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size.y = 100
		_recipe_list.add_child(empty)


func _recipe_matches_filter(category: String) -> bool:
	return (
		_current_mode == UIMode.ALL
		or (_current_mode == UIMode.COOKING and category == "cooking")
		or (_current_mode == UIMode.BAKING and category == "baking")
		or (_current_mode == UIMode.BREWING and category == "brewing")
	)


func _on_recipe_selected(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	_update_details()


func _update_details() -> void:
	var recipe: Variant = CookingManager.get_recipe(_selected_recipe_id)
	if recipe == null:
		_clear_selection()
		return
	_result_icon.texture = ItemDatabase.load_icon_texture(str(recipe.result_item))
	_recipe_name.text = str(recipe.name)
	_recipe_description.text = str(recipe.description)
	for child in _ingredients.get_children():
		child.queue_free()
	for ingredient in recipe.ingredients:
		var item_id := str(ingredient.get("item_id", ""))
		var required := int(ingredient.get("quantity", 1))
		var have := Inventory.get_item_count(item_id)
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.texture = ItemDatabase.load_icon_texture(item_id)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_label := Label.new()
		name_label.text = Inventory.get_item_name(item_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var count := Label.new()
		count.text = "%d / %d" % [have, required]
		count.modulate = UIStyles.COLOR_GREEN if have >= required else UIStyles.COLOR_DANGER
		row.add_child(count)
		_ingredients.add_child(row)
	var effect_parts: Array[String] = []
	if recipe.effects.has("energy"):
		effect_parts.append("恢复体力 %d" % int(recipe.effects.energy))
	if recipe.effects.has("health"):
		effect_parts.append("恢复生命 %d" % int(recipe.effects.health))
	_effects.text = "效果：%s  ·  烹饪消耗 %d 体力" % [
		"、".join(effect_parts) if not effect_parts.is_empty() else "美味料理",
		int(recipe.energy_cost),
	]
	var check: Dictionary = CookingManager.can_cook(_selected_recipe_id)
	_cook_button.disabled = not bool(check.can_cook)
	_status.text = "材料或体力不足" if _cook_button.disabled else ""
	_status.modulate = UIStyles.COLOR_DANGER if _cook_button.disabled else Color.WHITE


func _clear_selection() -> void:
	_selected_recipe_id = ""
	_result_icon.texture = null
	_recipe_name.text = "选择一个食谱"
	_recipe_description.text = "先从左侧选择已经学会的料理。"
	for child in _ingredients.get_children():
		child.queue_free()
	_effects.text = ""
	_cook_button.disabled = true
	_status.text = ""


func _on_category_pressed(mode: int) -> void:
	_current_mode = mode as UIMode
	_update_category_buttons()
	_refresh_recipe_list()
	_clear_selection()


func _update_category_buttons() -> void:
	for index in range(_category_buttons.size()):
		_category_buttons[index].button_pressed = index == int(_current_mode)


func _on_cook_pressed() -> void:
	if _selected_recipe_id.is_empty():
		return
	_cook_button.disabled = true
	if not CookingManager.cook(_selected_recipe_id):
		_update_details()


func _on_cooking_completed(recipe_id: String, result_item: String) -> void:
	if not _is_open:
		return
	var recipe: Variant = CookingManager.get_recipe(recipe_id)
	UIManager.show_toast("ui.toast.item_received", {
		"item": Inventory.get_item_name(result_item),
		"count": int(recipe.result_quantity) if recipe else 1,
	}, "success")
	_refresh_recipe_list()
	_update_details()


func _on_cooking_failed(_recipe_id: String, reason: String) -> void:
	if not _is_open:
		return
	_status.text = {
		"missing_ingredients": "材料不足",
		"recipe_not_learned": "尚未学会这个食谱",
	}.get(reason, "烹饪失败：" + reason)
	_status.modulate = UIStyles.COLOR_DANGER


func _on_ingredients_missing(_recipe_id: String, _missing: Array) -> void:
	if _is_open:
		_status.text = "材料不足，请检查右侧清单"
		_status.modulate = UIStyles.COLOR_DANGER


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
