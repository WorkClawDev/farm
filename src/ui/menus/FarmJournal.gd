extends Control
class_name FarmJournal

signal inventory_closed
signal tab_changed(tab_id: String)

const TABS := [
	["inventory", "ui.journal.inventory", "背包"],
	["quests", "ui.journal.quests", "任务"],
	["map", "ui.journal.map", "地图"],
	["relationships", "ui.journal.relationships", "关系"],
	["skills", "ui.journal.skills", "技能"],
	["crafting", "ui.journal.crafting", "制作"],
	["collection", "ui.journal.collection", "收藏"],
	["achievements", "ui.journal.achievements", "成就"],
]

var _is_open := false
var _active_tab := 0
var _tab_buttons: Array[Button] = []
var _content: Control
var _money_label: Label
var _selected_slot := -1
var _selected_recipe := ""
var _workbench_type := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("themed_ui_root")
	refresh_theme()
	_build_ui()
	if Inventory:
		Inventory.inventory_changed.connect(_on_inventory_changed)
	if MoneySystem:
		MoneySystem.money_changed.connect(_on_money_changed)
	var saved_tab := str(UserSettings.get_value("ui", "last_journal_tab", "inventory"))
	open_tab(saved_tab)
	_is_open = visible


func configure(context: Dictionary) -> void:
	_workbench_type = str(context.get("workbench_type", ""))
	if context.has("tab"):
		open_tab(str(context["tab"]))
	elif context.has("initial_tab"):
		open_tab(str(context["initial_tab"]))


func refresh_theme() -> void:
	theme = UIStyles.active_theme()


func open() -> void:
	show()
	_is_open = true
	_refresh_page()
	await get_tree().process_frame
	UIFactory.focus_first(self)
	if EventBus:
		EventBus.ui.ui_opened.emit("journal")


func close() -> void:
	hide()
	_is_open = false
	_selected_slot = -1
	if EventBus:
		EventBus.ui.ui_closed.emit("journal")
	inventory_closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func get_active_tab_id() -> String:
	return str(TABS[_active_tab][0])


func get_active_workbench_type() -> String:
	return _workbench_type


func open_tab(tab_id: String) -> void:
	for index in range(TABS.size()):
		if TABS[index][0] == tab_id:
			_active_tab = index
			break
	if _content:
		_refresh_page()
	_update_tab_state()
	UserSettings.set_value("ui", "last_journal_tab", TABS[_active_tab][0], false)
	tab_changed.emit(TABS[_active_tab][0])


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.035, 0.027, 0.02, 0.88)
	add_child(shade)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 34)
	safe.add_theme_constant_override("margin_top", 28)
	safe.add_theme_constant_override("margin_right", 34)
	safe.add_theme_constant_override("margin_bottom", 28)
	add_child(safe)
	var panel := UIFactory.paper_panel()
	safe.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := UIFactory.title(UIStyles.tr_key("ui.journal.title", "农场手册"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_money_label)
	var close_button := UIFactory.button("×", &"", Vector2(48, 44))
	close_button.pressed.connect(close)
	header.add_child(close_button)
	_update_money()

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	layout.add_child(tabs)
	for index in range(TABS.size()):
		var tab := UIFactory.button(UIStyles.tr_key(TABS[index][1], TABS[index][2]), &"TabButton", Vector2(106, 44))
		# toggle_mode so button_pressed sticks and the active tab draws its "pressed" (selected) style.
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_tab.bind(index))
		tabs.add_child(tab)
		_tab_buttons.append(tab)

	layout.add_child(HSeparator.new())
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("margin_left", 6)
	_content.add_theme_constant_override("margin_top", 4)
	_content.add_theme_constant_override("margin_right", 6)
	_content.add_theme_constant_override("margin_bottom", 4)
	layout.add_child(_content)

	var hint := UIFactory.subtitle("Tab / LB·RB 切换分页  ·  Esc / B 返回")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(hint)


func _select_tab(index: int) -> void:
	_active_tab = clampi(index, 0, TABS.size() - 1)
	_selected_slot = -1
	_refresh_page()
	_update_tab_state()
	UserSettings.set_value("ui", "last_journal_tab", TABS[_active_tab][0], false)
	tab_changed.emit(TABS[_active_tab][0])


func _update_tab_state() -> void:
	for index in range(_tab_buttons.size()):
		_tab_buttons[index].set_pressed_no_signal(index == _active_tab)


func _refresh_page() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	match TABS[_active_tab][0]:
		"inventory":
			_content.add_child(_build_inventory_page())
		"quests":
			_content.add_child(_build_quest_page())
		"map":
			_content.add_child(_build_map_page())
		"relationships":
			_content.add_child(_build_relationship_page())
		"skills":
			_content.add_child(_build_skills_page())
		"crafting":
			_content.add_child(_build_crafting_page())
		"collection":
			_content.add_child(_build_collection_page())
		"achievements":
			_content.add_child(_build_achievement_page())


func _build_inventory_page() -> Control:
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	layout.add_child(left)
	var tools := HBoxContainer.new()
	left.add_child(tools)
	var section := UIFactory.title(UIStyles.tr_key("ui.journal.inventory", "背包"))
	section.add_theme_font_size_override("font_size", 25)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(section)
	var sort_button := UIFactory.button(UIStyles.tr_key("ui.journal.sort", "整理"), &"", Vector2(120, 42))
	sort_button.pressed.connect(_sort_inventory)
	tools.add_child(sort_button)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	left.add_child(grid)
	for index in range(Inventory.MAX_SLOTS):
		grid.add_child(_create_inventory_slot(index))

	var detail := UIFactory.paper_panel(Vector2(300, 0))
	layout.add_child(detail)
	var detail_content := VBoxContainer.new()
	detail_content.name = "DetailContent"
	detail_content.add_theme_constant_override("separation", 12)
	detail.add_child(detail_content)
	_populate_item_detail(detail_content, _selected_slot)
	return layout


func _create_inventory_slot(index: int) -> Button:
	# Same look as the HUD hotbar (SlotButton etc. in GameTheme.tres): big centred
	# icon, quantity in the bottom-right corner, hotbar key in the top-left, and the
	# picked-up slot uses the theme's pressed/selected style instead of a gold tint.
	var slot := UIFactory.button("", &"SlotButton", Vector2(72, 72))
	slot.name = "Slot_%d" % index
	slot.focus_mode = Control.FOCUS_ALL
	slot.toggle_mode = true
	slot.set_pressed_no_signal(index == _selected_slot)
	var data = Inventory.get_slot(index)
	if data and not data.is_empty():
		# Icon as a child rect (like the HUD hotbar) so it leaves the bottom strip free
		# for "×15" instead of filling the whole slot under it.
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = ItemDatabase.load_icon_texture(data.item_id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 12
		icon.offset_top = 6
		icon.offset_right = -12
		icon.offset_bottom = -21
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		slot.tooltip_text = UIFactory.slot_tooltip(Inventory.get_item_name(data.item_id), data.quantity)
		if data.quantity > 1:
			slot.add_child(_slot_corner_label("Quantity", "×%d" % data.quantity, &"SlotQuantityLabel", HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM))
	else:
		slot.tooltip_text = UIFactory.slot_tooltip("", 0)
	if index < Inventory.HOTBAR_SIZE:
		var key := _slot_corner_label("Key", str(index + 1), &"SlotKeyLabel", HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
		key.modulate.a = 0.72
		slot.add_child(key)
	slot.pressed.connect(_on_inventory_slot_pressed.bind(index))
	return slot


func _slot_corner_label(label_name: String, text: String, variation: StringName, h: HorizontalAlignment, v: VerticalAlignment) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = h
	label.vertical_alignment = v
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 5
	label.offset_top = 1
	label.offset_right = -5
	label.offset_bottom = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _populate_item_detail(container: VBoxContainer, index: int) -> void:
	if index < 0:
		container.add_child(UIFactory.title("物品详情"))
		container.add_child(UIFactory.subtitle(UIStyles.tr_key("ui.journal.item_detail", "选择物品查看详情")))
		return
	var data = Inventory.get_slot(index)
	if data == null or data.is_empty():
		container.add_child(UIFactory.title("空槽位"))
		container.add_child(UIFactory.subtitle("选择另一个物品，或将物品移动到这里。"))
		return
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(110, 110)
	icon.texture = ItemDatabase.load_icon_texture(data.item_id)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.add_child(icon)
	container.add_child(UIFactory.title(Inventory.get_item_name(data.item_id), HORIZONTAL_ALIGNMENT_CENTER))
	var count := Label.new()
	count.text = "持有 %d" % Inventory.get_item_count(data.item_id)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(count)
	var description := Label.new()
	description.text = Inventory.get_item_description(data.item_id)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(description)
	container.add_child(UIFactory.subtitle("再次选择一个槽位可交换或合并物品。"))


func _on_inventory_slot_pressed(index: int) -> void:
	if _selected_slot < 0:
		_selected_slot = index
	elif _selected_slot == index:
		_selected_slot = -1
	else:
		var from = Inventory.get_slot(_selected_slot)
		var to = Inventory.get_slot(index)
		if from and to and not from.is_empty() and not to.is_empty() and from.item_id == to.item_id:
			Inventory.merge_slots(_selected_slot, index)
		else:
			Inventory.swap_slots(_selected_slot, index)
		_selected_slot = index
	_refresh_page()


func _sort_inventory() -> void:
	var entries: Array[Dictionary] = []
	for index in range(Inventory.MAX_SLOTS):
		var slot = Inventory.get_slot(index)
		if slot and not slot.is_empty():
			entries.append({"item_id": slot.item_id, "quantity": slot.quantity})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Inventory.get_item_name(a.item_id) < Inventory.get_item_name(b.item_id)
	)
	for index in range(Inventory.MAX_SLOTS):
		if index < entries.size():
			Inventory.set_slot(index, entries[index].item_id, entries[index].quantity)
		else:
			Inventory.set_slot(index, "", 0)
	_selected_slot = -1
	UIManager.show_toast("ui.journal.sort", {}, "success")


func _build_quest_page() -> Control:
	var active = QuestSystem.get_active_quests() if QuestSystem else []
	if active.is_empty():
		return _empty_page("ui.journal.quests", "ui.journal.quest_empty")
	var scroll := _scrolling_list()
	var list := scroll.get_child(0) as VBoxContainer
	list.add_child(UIFactory.title(UIStyles.tr_key("ui.journal.quests", "任务")))
	for quest in active:
		var card := UIFactory.paper_panel()
		var content := VBoxContainer.new()
		card.add_child(content)
		content.add_child(UIFactory.title(str(quest.title)))
		content.add_child(UIFactory.subtitle(str(quest.description)))
		for objective_index in range(quest.objectives.size()):
			var progress := QuestSystem.get_objective_progress(quest.id, objective_index)
			var required := int(quest.objectives[objective_index].required)
			var row := Label.new()
			row.text = "%s  %s  %d/%d" % [
				"✓" if progress >= required else "○",
				QuestSystem.get_objective_description(quest.id, objective_index),
				progress,
				required,
			]
			content.add_child(row)
		list.add_child(card)
	return scroll


func _build_map_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.journal.map", "地图"), HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(UIFactory.subtitle(UIStyles.tr_key("ui.journal.map_hint", "绘制中的山谷地图会标记你去过的地点"), HORIZONTAL_ALIGNMENT_CENTER))
	var map_panel := UIFactory.paper_panel()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(map_panel)
	var locations := GridContainer.new()
	locations.columns = 3
	locations.add_theme_constant_override("h_separation", UIStyles.SPACE_MD)
	locations.add_theme_constant_override("v_separation", UIStyles.SPACE_MD)
	map_panel.add_child(locations)
	for location in [["农场", "⌂", "你的土地与家"], ["村庄", "♜", "商店和村民"], ["森林", "♣", "采集与秘密"], ["海滩", "≈", "钓鱼与贝壳"], ["矿洞", "◆", "矿石与冒险"], ["家", "⌂", "休息与烹饪"]]:
		var card := UIFactory.button("%s\n%s\n%s" % [location[1], location[0], location[2]], &"", Vector2(220, 112))
		locations.add_child(card)
	return page


func _build_relationship_page() -> Control:
	var entries := Friendship.get_npcs_by_friendship() if Friendship else []
	if entries.is_empty():
		return _empty_page("ui.journal.relationships", "ui.journal.relationship_hint")
	var scroll := _scrolling_list()
	var list := scroll.get_child(0) as VBoxContainer
	list.add_child(UIFactory.title(UIStyles.tr_key("ui.journal.relationships", "关系")))
	for entry in entries:
		var card := UIFactory.paper_panel()
		var row := HBoxContainer.new()
		card.add_child(row)
		var name := UIFactory.title(str(entry.npc_id).capitalize())
		name.add_theme_font_size_override("font_size", 23)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var hearts := Label.new()
		hearts.text = "♥".repeat(int(entry.hearts)) + "♡".repeat(maxi(0, 10 - int(entry.hearts)))
		hearts.modulate = Color("#C95C55")
		row.add_child(hearts)
		list.add_child(card)
	return scroll


func _build_skills_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	page.add_child(UIFactory.title(UIStyles.tr_key("ui.journal.skills", "技能")))
	page.add_child(UIFactory.subtitle(UIStyles.tr_key("ui.journal.skills_hint", "在农场生活中积累经验，提升各项技能")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIStyles.SPACE_MD)
	grid.add_theme_constant_override("v_separation", UIStyles.SPACE_MD)
	page.add_child(grid)
	var player_level := QuestSystem.get_current_level() if QuestSystem and QuestSystem.has_method("get_current_level") else 1
	for skill in [["农耕", "照料作物与土地", player_level], ["采集", "探索森林和海滩", 1], ["钓鱼", "在不同水域垂钓", 1], ["采矿", "深入矿洞开采矿石", 1]]:
		var card := UIFactory.paper_panel(Vector2(340, 112))
		var content := VBoxContainer.new()
		card.add_child(content)
		content.add_child(UIFactory.title("%s · 等级 %d" % [skill[0], skill[2]]))
		content.add_child(UIFactory.subtitle(skill[1]))
		grid.add_child(card)
	return page


func _build_crafting_page() -> Control:
	var recipes: Array = []
	if CraftingSystem:
		if _workbench_type.is_empty():
			recipes = CraftingSystem.get_unlocked_recipes()
		else:
			recipes = CraftingSystem.get_recipes_by_workbench(_workbench_type)
	if recipes.is_empty():
		return _empty_page("ui.journal.crafting", "ui.journal.crafting_hint")
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", UIStyles.SPACE_LG)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 430
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if not _workbench_type.is_empty():
		var station_name: String = str({
			"workbench": "工作台",
			"furnace": "熔炉",
			"kitchen": "厨房",
			"anvil": "铁砧",
		}.get(_workbench_type, _workbench_type))
		list.add_child(UIFactory.title(station_name))
		list.add_child(UIFactory.subtitle("仅显示可在这里制作的配方"))
	if _selected_recipe.is_empty() and not recipes.is_empty():
		_selected_recipe = recipes[0].id
	for recipe in recipes:
		var craftable := CraftingSystem.get_craftable_count(recipe.id)
		# BUG-22/23: list rows, not green action buttons (UIThemeBridge used to turn every
		# "可制作" row into a PrimaryButton). Selected row = pressed style; 0 craftable = muted.
		var variation := &"ListItemButton" if craftable > 0 else &"ListItemButtonMuted"
		var button := UIFactory.button("%s\n可制作 %d" % [recipe.name, craftable], variation, Vector2(390, 58))
		button.name = "Recipe_%s" % recipe.id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.set_pressed_no_signal(recipe.id == _selected_recipe)
		button.pressed.connect(_select_recipe.bind(recipe.id))
		list.add_child(button)
	var detail := UIFactory.paper_panel()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(detail)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	detail.add_child(content)
	var selected = CraftingSystem.get_recipe(_selected_recipe)
	if selected:
		content.add_child(UIFactory.title(selected.name))
		content.add_child(UIFactory.subtitle(selected.description))
		content.add_child(HSeparator.new())
		for ingredient in CraftingSystem.get_ingredient_info(selected.id):
			var label := Label.new()
			label.text = "%s  %d / %d" % [ingredient.item_name, ingredient.have, ingredient.required]
			label.modulate = UIStyles.COLOR_GREEN if ingredient.sufficient else UIStyles.COLOR_DANGER
			content.add_child(label)
		var craft := UIFactory.button("制作  ×1", &"PrimaryButton", Vector2(0, 50))
		var required_station := str(selected.workbench_required)
		var station_matches := required_station.is_empty() or required_station == _workbench_type
		craft.disabled = not bool(CraftingSystem.can_craft(selected.id).can_craft) or not station_matches
		craft.tooltip_text = "需要在对应工作台制作" if not station_matches else ""
		craft.pressed.connect(_craft_selected)
		content.add_child(craft)
	return layout


func _select_recipe(recipe_id: String) -> void:
	_selected_recipe = recipe_id
	_refresh_page()


func _craft_selected() -> void:
	if CraftingSystem.craft(_selected_recipe, _workbench_type):
		var recipe = CraftingSystem.get_recipe(_selected_recipe)
		UIManager.show_toast("ui.toast.item_received", {
			"item": Inventory.get_item_name(recipe.result_item),
			"count": recipe.result_quantity,
		}, "success")
	_refresh_page()


func _build_collection_page() -> Control:
	var ids := Inventory.get_all_item_ids() if Inventory else []
	if ids.is_empty():
		return _empty_page("ui.journal.collection", "ui.journal.collection_hint")
	var scroll := _scrolling_list()
	var list := scroll.get_child(0) as VBoxContainer
	list.add_child(UIFactory.title("收藏 · 已发现 %d 种" % ids.size()))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for item_id in ids:
		var item := UIFactory.button(Inventory.get_item_name(item_id), &"", Vector2(142, 74))
		item.icon = ItemDatabase.load_icon_texture(item_id)
		item.expand_icon = true
		item.tooltip_text = Inventory.get_item_description(item_id)
		grid.add_child(item)
	return scroll


func _build_achievement_page() -> Control:
	var achievements := AchievementSystem.get_all_achievements() if AchievementSystem else {}
	if achievements.is_empty():
		return _empty_page("ui.journal.achievements", "ui.journal.achievement_hint")
	var scroll := _scrolling_list()
	var list := scroll.get_child(0) as VBoxContainer
	list.add_child(UIFactory.title("成就 · %d / %d" % [AchievementSystem.get_unlocked_count(), AchievementSystem.get_total_count()]))
	for achievement_id in achievements:
		var achievement = achievements[achievement_id]
		var unlocked := AchievementSystem.is_achievement_unlocked(achievement_id)
		var progress := AchievementSystem.get_achievement_progress(achievement_id)
		var card := UIFactory.paper_panel()
		card.modulate.a = 1.0 if unlocked else 0.72
		var row := HBoxContainer.new()
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UIFactory.title(("%s " % ("✓" if unlocked else "○")) + str(achievement.name)))
		text.add_child(UIFactory.subtitle(str(achievement.description)))
		var status := Label.new()
		status.text = "已完成" if unlocked else "%d / %d" % [int(progress.get("current", 0)), int(progress.get("required", 1))]
		row.add_child(status)
		list.add_child(card)
	return scroll


func _empty_page(title_key: String, body_key: String) -> Control:
	var center := CenterContainer.new()
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 520
	content.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	center.add_child(content)
	content.add_child(UIFactory.title(UIStyles.tr_key(title_key), HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(UIFactory.subtitle(UIStyles.tr_key(body_key), HORIZONTAL_ALIGNMENT_CENTER))
	return center


func _scrolling_list() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", UIStyles.SPACE_MD)
	scroll.add_child(list)
	return scroll


func _update_money() -> void:
	if _money_label:
		_money_label.text = "%d 金币  " % (MoneySystem.get_money() if MoneySystem else 0)


func _on_money_changed(_amount: int, _delta: int) -> void:
	_update_money()


func _on_inventory_changed() -> void:
	if _is_open and TABS[_active_tab][0] in ["inventory", "collection", "crafting"]:
		_refresh_page()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("journal") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_left"):
		_select_tab(wrapi(_active_tab - 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_right"):
		_select_tab(wrapi(_active_tab + 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()
