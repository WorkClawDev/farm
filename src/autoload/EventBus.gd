extends Node

## EventBus - 统一事件总线
## 负责游戏内所有模块间的通信

# 单例
static var instance: EventBus

# 子领域 EventBus (使用 var 而非显式类型，避免解析时的循环依赖)
var game
var time
var player
var farm
var inventory
var social
var shop
var craft
var ui
var quest
var mine
var festival
var animal
var fishing
var combat
var shipping
var tool

func _ready() -> void:
	instance = self
	
	# 初始化所有子 EventBus
	game = EventBusGame.new()
	game.name = "EventBusGame"
	add_child(game)
	
	time = EventBusTime.new()
	time.name = "EventBusTime"
	add_child(time)
	
	player = EventBusPlayer.new()
	player.name = "EventBusPlayer"
	add_child(player)
	
	farm = EventBusFarm.new()
	farm.name = "EventBusFarm"
	add_child(farm)
	
	inventory = EventBusInventory.new()
	inventory.name = "EventBusInventory"
	add_child(inventory)
	
	social = EventBusSocial.new()
	social.name = "EventBusSocial"
	add_child(social)
	
	shop = EventBusShop.new()
	shop.name = "EventBusShop"
	add_child(shop)
	
	craft = EventBusCraft.new()
	craft.name = "EventBusCraft"
	add_child(craft)
	
	ui = EventBusUI.new()
	ui.name = "EventBusUI"
	add_child(ui)
	
	quest = EventBusQuest.new()
	quest.name = "EventBusQuest"
	add_child(quest)
	
	mine = EventBusMine.new()
	mine.name = "EventBusMine"
	add_child(mine)
	
	festival = EventBusFestival.new()
	festival.name = "EventBusFestival"
	add_child(festival)
	
	animal = EventBusAnimal.new()
	animal.name = "EventBusAnimal"
	add_child(animal)
	
	fishing = EventBusFishing.new()
	fishing.name = "EventBusFishing"
	add_child(fishing)
	
	combat = EventBusCombat.new()
	combat.name = "EventBusCombat"
	add_child(combat)
	
	shipping = EventBusShipping.new()
	shipping.name = "EventBusShipping"
	add_child(shipping)
	
	tool = EventBusTool.new()
	tool.name = "EventBusTool"
	add_child(tool)
	
	print("[EventBus] Initialized with 16 domain EventBus")

static func get_instance() -> EventBus:
	return instance

# ===== 兼容性别名信号 =====
# 这些信号在 sub-EventBus 中也有，这里做直接声明以保持兼容

# 背包/物品信号 (EventBusInventory)
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full

# 农场信号 (EventBusFarm)
signal crop_planted(crop_type: String, position: Vector2)
signal crop_grew(crop_type: String, stage: int)
signal crop_harvested(crop_type: String, quality: int, quantity: int)
signal soil_watered(position: Vector2)
signal soil_dried(position: Vector2)

# 场景切换信号
signal scene_transition_started(target_scene: String)
signal scene_transition_completed

# 社交信号 (EventBusSocial)
signal dialogue_ended(npc_id: String)

# 钓鱼信号 (EventBusFishing)
signal fish_caught(fish_id: String, fish_size: int, quality: int)

# 社交信号
signal gift_given(npc_id: String, item_id: String, reaction: int)
signal friendship_changed(npc_id: String, hearts: int)

# UI / Shop 兼容信号
signal player_moved(position: Vector2)
signal player_interacted(target: Node)
signal energy_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal combat_started
signal combat_ended
signal spawn_point_changed(spawn_point: String)
signal ui_opened(ui_name: String)
signal ui_closed(ui_name: String)
signal notification_shown(message: String, type: int)
signal shop_opened(shop_id: String)

# Festival 兼容信号
signal festival_started(festival_id: String, festival_data: Dictionary)
signal festival_ended(festival_id: String, festival_data: Dictionary)
signal festival_upcoming(festival_id: String, days_until: int)
signal festival_activity_completed(festival_id: String, activity_id: String, rewards: Dictionary)
signal festival_reward_claimed(festival_id: String, reward_id: String)
signal npc_activity_changed(npc_id: String, activity: Dictionary)
