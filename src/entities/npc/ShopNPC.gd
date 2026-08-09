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
	print("[ShopNPC] Shop NPC initialized: ", npc_name)

## 重写交互方法
func interact() -> void:
	if not can_interact():
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
	print("[ShopNPC] Shop closed: ", npc_name)

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
