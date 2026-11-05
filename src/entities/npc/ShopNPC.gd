extends NPC
class_name ShopNPC

## ShopNPC - 商店NPC
## 与玩家交互时打开商店界面

# 商店类型
enum ShopType {
	SEED_SHOP,      # 种子店
	GENERAL_STORE,  # 杂货店
	BLACKSMITH,     # 铁匠铺
	FISHING_SHOP    # 渔具店
}

@export var shop_type: ShopType = ShopType.SEED_SHOP
@export var shop_ui_scene: PackedScene = null

# 商店UI实例
var shop_ui: Control = null

func _ready() -> void:
	super._ready()
	_add_shop_beacon()
	print("[ShopNPC] Shop NPC initialized: ", npc_name)

## 重写交互方法
func interact() -> void:
	if not can_interact():
		notify_unavailable()
		return
	
	# 先进行对话
	start_interaction()
	interacted.emit(self)
	
	# 触发对话
	_open_shop()

## 打开商店
func _open_shop() -> void:
	var shop_id := _get_shop_id()
	if UIManager == null:
		push_warning("[ShopNPC] UIManager unavailable")
		end_interaction()
		return
	UIManager.open_screen("shop", {
		"shop_id": shop_id,
		"pause_game": true,
	})
	shop_ui = UIManager.get_screen("shop")
	if shop_ui and shop_ui.has_signal("shop_closed"):
		var callback := Callable(self, "_on_shop_closed")
		if not shop_ui.is_connected("shop_closed", callback):
			shop_ui.connect("shop_closed", callback)
	print("[ShopNPC] Opened shop: ", npc_name)

func _add_shop_beacon() -> void:
	if get_node_or_null("ShopBeacon"):
		return
	var label := Label.new()
	label.name = "ShopBeacon"
	label.text = "商店"
	label.size = Vector2(72, 22)
	label.position = Vector2(-36, -64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_as_relative = false
	label.z_index = 100
	add_child(label)

func _get_shop_id() -> String:
	match shop_type:
		ShopType.SEED_SHOP:
			return "seed_shop"
		ShopType.GENERAL_STORE:
			return "general_store"
		ShopType.BLACKSMITH:
			return "blacksmith"
		ShopType.FISHING_SHOP:
			return "fish_shop"
		_:
			return "general_store"

## 商店关闭回调
func _on_shop_closed() -> void:
	end_interaction()
	_note_shop_visit()
	print("[ShopNPC] Shop closed: ", npc_name)


## Opening the counter counts as meeting the shopkeeper (village_introduction).
func _note_shop_visit() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.social:
		event_bus.social.dialogue_ended.emit(npc_id)

## 获取商店类型名称
func get_shop_type_name() -> String:
	match shop_type:
		ShopType.SEED_SHOP:
			return "种子店"
		ShopType.GENERAL_STORE:
			return "杂货店"
		ShopType.BLACKSMITH:
			return "铁匠铺"
		ShopType.FISHING_SHOP:
			return "渔具店"
		_:
			return "商店"
