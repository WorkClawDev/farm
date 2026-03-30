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
	if EventBus:
		get_node("/root/EventBus").dialogue_started.emit(npc_id)
	
	# 对话结束后打开商店
	# 这里简化处理，直接打开商店
	_open_shop()

## 打开商店
func _open_shop() -> void:
	if shop_ui_scene == null:
		# 根据商店类型加载默认UI
		match shop_type:
			ShopType.SEED_SHOP:
				shop_ui_scene = preload("res://src/ui/menus/SeedShopUI.tscn")
			_:
				print("[ShopNPC] No shop UI configured for type: ", shop_type)
				end_interaction()
				return
	
	if shop_ui == null:
		shop_ui = shop_ui_scene.instantiate()
		get_tree().current_scene.add_child(shop_ui)
		
		# 连接关闭信号
		if shop_ui.has_signal("shop_closed"):
			shop_ui.shop_closed.connect(_on_shop_closed)
	
	shop_ui.open_shop()
	print("[ShopNPC] Opened shop: ", npc_name)

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
