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

	_connect_compatibility_aliases()
	
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
signal npc_interacted(npc: Node)
signal dialogue_started(npc_id: String)
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
signal shop_closed
signal item_bought(item_id: String, price: int)
signal item_sold(item_id: String, price: int)
signal season_changed(season: int, season_name: String)
signal enemy_spawned(enemy: Node)
signal enemy_damaged(enemy: Node, damage: int)
signal enemy_died(enemy: Node, loot: Dictionary)
signal player_attacked(weapon: String, damage: int)
signal player_damaged(damage: int, source: Node)

# Festival 兼容信号
signal festival_started(festival_id: String, festival_data: Dictionary)
signal festival_ended(festival_id: String, festival_data: Dictionary)
signal festival_upcoming(festival_id: String, days_until: int)
signal festival_activity_completed(festival_id: String, activity_id: String, rewards: Dictionary)
signal festival_reward_claimed(festival_id: String, reward_id: String)
signal npc_activity_changed(npc_id: String, activity: Dictionary)

func _connect_compatibility_aliases() -> void:
	inventory.item_added.connect(func(item_id: String, quantity: int): item_added.emit(item_id, quantity))
	inventory.item_removed.connect(func(item_id: String, quantity: int): item_removed.emit(item_id, quantity))
	inventory.inventory_full.connect(func(): inventory_full.emit())

	farm.crop_planted.connect(func(crop_type: String, position: Vector2): crop_planted.emit(crop_type, position))
	farm.crop_grew.connect(func(crop_type: String, stage: int): crop_grew.emit(crop_type, stage))
	farm.crop_harvested.connect(func(crop_type: String, quality: int, quantity: int): crop_harvested.emit(crop_type, quality, quantity))
	farm.soil_watered.connect(func(position: Vector2): soil_watered.emit(position))
	farm.soil_dried.connect(func(position: Vector2): soil_dried.emit(position))

	time.season_changed.connect(func(season: int, season_name: String): season_changed.emit(season, season_name))

	player.player_moved.connect(func(position: Vector2): player_moved.emit(position))
	player.player_interacted.connect(func(target: Node): player_interacted.emit(target))
	player.energy_changed.connect(func(current: int, maximum: int): energy_changed.emit(current, maximum))
	player.health_changed.connect(func(current: int, maximum: int): health_changed.emit(current, maximum))
	player.combat_started.connect(func(): combat_started.emit())
	player.combat_ended.connect(func(): combat_ended.emit())
	player.spawn_point_changed.connect(func(spawn_point: String): spawn_point_changed.emit(spawn_point))

	shop.shop_opened.connect(func(shop_id: String): shop_opened.emit(shop_id))
	shop.shop_closed.connect(func(): shop_closed.emit())
	shop.item_bought.connect(func(item_id: String, price: int): item_bought.emit(item_id, price))
	shop.item_sold.connect(func(item_id: String, price: int): item_sold.emit(item_id, price))

	ui.ui_opened.connect(func(ui_name: String): ui_opened.emit(ui_name))
	ui.ui_closed.connect(func(ui_name: String): ui_closed.emit(ui_name))
	ui.notification_shown.connect(func(message: String, type: int): notification_shown.emit(message, type))

	social.npc_interacted.connect(func(npc: Node): npc_interacted.emit(npc))
	social.dialogue_started.connect(func(npc_id: String): dialogue_started.emit(npc_id))
	social.dialogue_ended.connect(func(npc_id: String): dialogue_ended.emit(npc_id))
	social.friendship_changed.connect(func(npc_id: String, hearts: int): friendship_changed.emit(npc_id, hearts))
	social.gift_given.connect(func(npc_id: String, item_id: String, reaction: int): gift_given.emit(npc_id, item_id, reaction))
	social.npc_activity_changed.connect(func(npc_id: String, activity: Dictionary): npc_activity_changed.emit(npc_id, activity))

	combat.enemy_spawned.connect(func(enemy: Node): enemy_spawned.emit(enemy))
	combat.enemy_damaged.connect(func(enemy: Node, damage: int): enemy_damaged.emit(enemy, damage))
	combat.enemy_died.connect(func(enemy: Node, loot: Dictionary): enemy_died.emit(enemy, loot))
	combat.player_attacked.connect(func(weapon: String, damage: int): player_attacked.emit(weapon, damage))
	combat.player_damaged.connect(func(damage: int, source: Node): player_damaged.emit(damage, source))
	combat.combat_started.connect(func(): combat_started.emit())
	combat.combat_ended.connect(func(): combat_ended.emit())

	game.scene_transition_started.connect(func(target_scene: String): scene_transition_started.emit(target_scene))
	game.scene_transition_completed.connect(func(): scene_transition_completed.emit())

	festival.festival_started.connect(func(festival_id: String, festival_data: Dictionary): festival_started.emit(festival_id, festival_data))
	festival.festival_ended.connect(func(festival_id: String, festival_data: Dictionary): festival_ended.emit(festival_id, festival_data))
	festival.festival_upcoming.connect(func(festival_id: String, days_until: int): festival_upcoming.emit(festival_id, days_until))
	festival.festival_activity_completed.connect(func(festival_id: String, activity_id: String, rewards: Dictionary): festival_activity_completed.emit(festival_id, activity_id, rewards))
	festival.festival_reward_claimed.connect(func(festival_id: String, reward_id: String): festival_reward_claimed.emit(festival_id, reward_id))
