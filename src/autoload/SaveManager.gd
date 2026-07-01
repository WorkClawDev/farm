extends Node

## SaveManager - 存档管理器
## 负责游戏存档的保存和读取

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_error(error_message: String)
signal load_error(error_message: String)

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".sav"
const MAX_SAVE_SLOTS: int = 3

var _current_slot: int = 0
var _play_time: float = 0.0  # 累计游戏时间（秒）
var _session_start_time: float = 0.0

func _ready() -> void:
	print("[SaveManager] Initialized")
	_ensure_save_directory()
	_session_start_time = Time.get_unix_time_from_system()

func _process(delta: float) -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.is_game_active:
		_play_time += delta

func _ensure_save_directory() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("saves"):
			dir.make_dir("saves")
			print("[SaveManager] Created save directory")

func save_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	var save_data: Dictionary = _gather_save_data()
	var file_path: String = SAVE_DIR + "save" + str(slot) + SAVE_EXTENSION
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		game_saved.emit(slot)
		print("[SaveManager] Game saved to slot ", slot)
		return true
	else:
		var error: String = "Failed to save game: " + str(FileAccess.get_open_error())
		push_error(error)
		save_error.emit(error)
		return false

func load_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	var file_path: String = SAVE_DIR + "save" + str(slot) + SAVE_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		var error: String = "Save file not found: " + file_path
		push_error(error)
		load_error.emit(error)
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var save_data: Dictionary = file.get_var()
		file.close()
		_apply_save_data(save_data)
		_current_slot = slot
		game_loaded.emit(slot)
		print("[SaveManager] Game loaded from slot ", slot)
		return true
	else:
		var error: String = "Failed to load game: " + str(FileAccess.get_open_error())
		push_error(error)
		load_error.emit(error)
		return false

func has_save(slot: int) -> bool:
	var file_path: String = SAVE_DIR + "save" + str(slot) + SAVE_EXTENSION
	return FileAccess.file_exists(file_path)

func delete_save(slot: int) -> bool:
	var file_path: String = SAVE_DIR + "save" + str(slot) + SAVE_EXTENSION
	if FileAccess.file_exists(file_path):
		var dir: DirAccess = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove("save" + str(slot) + SAVE_EXTENSION)
			print("[SaveManager] Save slot ", slot, " deleted")
			return true
	return false

func get_save_info(slot: int) -> Dictionary:
	var file_path: String = SAVE_DIR + "save" + str(slot) + SAVE_EXTENSION
	if FileAccess.file_exists(file_path):
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var save_data: Dictionary = file.get_var()
			file.close()
			return {
				"exists": true,
				"timestamp": save_data.get("timestamp", 0),
				"play_time": save_data.get("play_time", 0),
				"date": save_data.get("date", "Unknown")
			}
	return {"exists": false}

func _gather_save_data() -> Dictionary:
	var save_data: Dictionary = {}
	var time_manager = get_node_or_null("/root/TimeManager")
	var money_system = get_node_or_null("/root/MoneySystem")
	var money_manager = get_node_or_null("/root/MoneyManager")
	var inventory = get_node_or_null("/root/Inventory")
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	var stamina_manager = get_node_or_null("/root/StaminaManager")
	var shipping_system = get_node_or_null("/root/ShippingSystem")
	var gift_system = get_node_or_null("/root/GiftSystem")
	var quest_system = get_node_or_null("/root/QuestSystem")
	var growth_system = get_node_or_null("/root/GrowthSystem")
	var friendship = get_node_or_null("/root/Friendship")
	var foraging_system = get_node_or_null("/root/ForagingSystem")
	var weather_system = get_node_or_null("/root/WeatherSystem")
	var festival_system = get_node_or_null("/root/FestivalSystem")
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	var fishing_system = get_node_or_null("/root/FishingSystem")
	var house_upgrade_system = get_node_or_null("/root/HouseUpgradeSystem")
	var npc_manager = get_node_or_null("/root/NPCManager")
	var crafting_system = get_node_or_null("/root/CraftingSystem")
	var cooking_system = get_node_or_null("/root/CookingSystem")

	# 保存时间数据
	if time_manager:
		save_data["time"] = time_manager.save_state()

	# 保存金钱数据
	if money_manager:
		save_data["money"] = money_manager.save_state()
	elif money_system:
		save_data["money"] = money_system.save_state()

	# 保存背包数据
	if inventory:
		save_data["inventory"] = inventory.get_save_data()
	elif inventory_manager:
		save_data["inventory"] = inventory_manager.save_state()

	# 保存体力数据
	if stamina_manager:
		save_data["stamina"] = stamina_manager.save_state()

	# 保存出货箱数据
	if shipping_system:
		save_data["shipping"] = shipping_system.save_state()

	# 保存送礼系统数据
	if gift_system:
		save_data["gift"] = gift_system.get_save_data()

	# 保存任务系统数据
	if quest_system:
		save_data["quest"] = quest_system.save_state()

	# 保存农场作物数据
	if growth_system and growth_system.has_method("save_state"):
		save_data["growth"] = growth_system.save_state()

	# 保存好感度数据
	if friendship and friendship.has_method("save_state"):
		save_data["friendship"] = friendship.save_state()

	# 保存采集点数据
	if foraging_system and foraging_system.has_method("save_state"):
		save_data["foraging"] = foraging_system.save_state()

	# 保存天气数据
	if weather_system and weather_system.has_method("save_state"):
		save_data["weather"] = weather_system.save_state()

	# 保存节日数据
	if festival_system and festival_system.has_method("save_state"):
		save_data["festival"] = festival_system.save_state()

	# 保存成就数据
	if achievement_system and achievement_system.has_method("save_state"):
		save_data["achievement"] = achievement_system.save_state()

	# 保存钓鱼数据
	if fishing_system and fishing_system.has_method("save_state"):
		save_data["fishing"] = fishing_system.save_state()

	# 保存房屋升级数据
	if house_upgrade_system and house_upgrade_system.has_method("save_state"):
		save_data["house_upgrade"] = house_upgrade_system.save_state()

	# 保存 NPC 管理器数据
	if npc_manager and npc_manager.has_method("save_state"):
		save_data["npc_manager"] = npc_manager.save_state()

	# 保存制作/烹饪数据
	if crafting_system and crafting_system.has_method("get_save_data"):
		save_data["crafting"] = crafting_system.get_save_data()
	if cooking_system and cooking_system.has_method("get_save_data"):
		save_data["cooking"] = cooking_system.get_save_data()

	# 保存动物建筑数据
	var animal_buildings_data := _gather_animal_buildings_data()
	if not animal_buildings_data.is_empty():
		save_data["animal_buildings"] = animal_buildings_data

	# 保存玩家数据
	var player_data: Dictionary = _gather_player_data()
	if not player_data.is_empty():
		save_data["player"] = player_data

	# 保存游戏管理器数据
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		save_data["game"] = {
			"state": game_manager.current_state
		}

	# 元数据
	save_data["timestamp"] = Time.get_unix_time_from_system()
	save_data["version"] = "1.0.0"
	save_data["date"] = Time.get_date_string_from_system()
	save_data["play_time"] = _play_time

	return save_data

func _gather_player_data() -> Dictionary:
	var player_data: Dictionary = {}

	# 查找玩家节点
	var player: Node = _find_player()
	if player:
		player_data["position_x"] = player.global_position.x
		player_data["position_y"] = player.global_position.y

		# 保存玩家状态数据
		if "stamina" in player:
			player_data["stamina"] = player.stamina
		if "money" in player:
			player_data["money"] = player.money
		if "current_direction" in player:
			player_data["direction"] = player.current_direction

		# 保存当前场景
		player_data["current_scene"] = player.get_tree().current_scene.scene_file_path

	return player_data

func _find_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene.find_child("Player", true, false)
	return null

func _apply_save_data(data: Dictionary) -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	var money_system = get_node_or_null("/root/MoneySystem")
	var money_manager = get_node_or_null("/root/MoneyManager")
	var inventory = get_node_or_null("/root/Inventory")
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	var stamina_manager = get_node_or_null("/root/StaminaManager")
	var shipping_system = get_node_or_null("/root/ShippingSystem")
	var gift_system = get_node_or_null("/root/GiftSystem")
	var quest_system = get_node_or_null("/root/QuestSystem")
	var growth_system = get_node_or_null("/root/GrowthSystem")
	var friendship = get_node_or_null("/root/Friendship")
	var foraging_system = get_node_or_null("/root/ForagingSystem")
	var weather_system = get_node_or_null("/root/WeatherSystem")
	var festival_system = get_node_or_null("/root/FestivalSystem")
	var achievement_system = get_node_or_null("/root/AchievementSystem")
	var fishing_system = get_node_or_null("/root/FishingSystem")
	var house_upgrade_system = get_node_or_null("/root/HouseUpgradeSystem")
	var npc_manager = get_node_or_null("/root/NPCManager")
	var crafting_system = get_node_or_null("/root/CraftingSystem")
	var cooking_system = get_node_or_null("/root/CookingSystem")
	
	# 加载时间数据
	if data.has("time") and time_manager:
		time_manager.load_state(data["time"])

	# 加载金钱数据
	if data.has("money"):
		if money_manager:
			money_manager.load_state(data["money"])
		elif money_system:
			money_system.load_state(data["money"])

	# 加载背包数据
	if data.has("inventory"):
		if inventory:
			inventory.load_save_data(data["inventory"])
		elif inventory_manager:
			inventory_manager.load_state(data["inventory"])

	# 加载体力数据
	if data.has("stamina") and stamina_manager:
		stamina_manager.load_state(data["stamina"])

	# 加载出货箱数据
	if data.has("shipping") and shipping_system:
		shipping_system.load_state(data["shipping"])

	# 加载送礼系统数据
	if data.has("gift") and gift_system:
		gift_system.load_save_data(data["gift"])

	# 加载任务系统数据
	if data.has("quest") and quest_system:
		quest_system.load_state(data["quest"])

	# 加载农场作物数据
	if data.has("growth") and growth_system and growth_system.has_method("load_state"):
		growth_system.load_state(data["growth"])

	# 加载好感度数据
	if data.has("friendship") and friendship and friendship.has_method("load_state"):
		friendship.load_state(data["friendship"])
	elif data.has("gift") and friendship and friendship.has_method("load_state"):
		# 兼容旧存档：从 GiftSystem 迁移好感度
		var legacy_gift: Dictionary = data["gift"]
		if legacy_gift.has("friendship"):
			_migrate_legacy_friendship(friendship, legacy_gift["friendship"])

	# 加载采集点数据
	if data.has("foraging") and foraging_system and foraging_system.has_method("load_state"):
		foraging_system.load_state(data["foraging"])

	# 加载天气数据
	if data.has("weather") and weather_system and weather_system.has_method("load_state"):
		weather_system.load_state(data["weather"])

	# 加载节日数据
	if data.has("festival") and festival_system and festival_system.has_method("load_state"):
		festival_system.load_state(data["festival"])

	# 加载成就数据
	if data.has("achievement") and achievement_system and achievement_system.has_method("load_state"):
		achievement_system.load_state(data["achievement"])

	# 加载钓鱼数据
	if data.has("fishing") and fishing_system and fishing_system.has_method("load_state"):
		fishing_system.load_state(data["fishing"])

	# 加载房屋升级数据
	if data.has("house_upgrade") and house_upgrade_system and house_upgrade_system.has_method("load_state"):
		house_upgrade_system.load_state(data["house_upgrade"])

	# 加载 NPC 管理器数据
	if data.has("npc_manager") and npc_manager and npc_manager.has_method("load_state"):
		npc_manager.load_state(data["npc_manager"])

	# 加载制作/烹饪数据
	if data.has("crafting") and crafting_system and crafting_system.has_method("load_save_data"):
		crafting_system.load_save_data(data["crafting"])
	if data.has("cooking") and cooking_system and cooking_system.has_method("load_save_data"):
		cooking_system.load_save_data(data["cooking"])

	# 加载动物建筑数据
	if data.has("animal_buildings"):
		_apply_animal_buildings_data(data["animal_buildings"])

	# 加载游戏时间
	if data.has("play_time"):
		_play_time = data["play_time"]

	# 加载玩家数据
	if data.has("player"):
		_apply_player_data(data["player"])

func _apply_player_data(player_data: Dictionary) -> void:
	var player: Node = _find_player()
	if not player:
		push_warning("[SaveManager] Player not found, cannot apply player data")
		return

	# 恢复玩家位置
	if player_data.has("position_x") and player_data.has("position_y"):
		player.global_position = Vector2(
			player_data["position_x"],
			player_data["position_y"]
		)

	# 恢复玩家状态
	if player_data.has("stamina") and "stamina" in player:
		player.stamina = player_data["stamina"]
	if player_data.has("money") and "money" in player:
		player.money = player_data["money"]
	if player_data.has("direction") and "current_direction" in player:
		player.current_direction = player_data["direction"]

	print("[SaveManager] Player data applied")

func get_current_slot() -> int:
	return _current_slot

func get_play_time() -> float:
	return _play_time

func get_formatted_play_time() -> String:
	var total_seconds: int = int(_play_time)
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func get_all_save_slots_info() -> Array:
	var slots: Array = []
	for i in range(MAX_SAVE_SLOTS):
		slots.append(get_save_info(i))
	return slots

## 收集动物建筑数据
func _gather_animal_buildings_data() -> Array:
	var buildings_data: Array = []
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return buildings_data

	# 查找所有动物建筑
	var buildings := tree.current_scene.find_children("", "AnimalBuilding", true, false)
	for building in buildings:
		buildings_data.append(building.save_state())

	return buildings_data

## 应用动物建筑数据
func _apply_animal_buildings_data(data: Array) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return

	var buildings := tree.current_scene.find_children("", "AnimalBuilding", true, false)
	for building_data: Dictionary in data:
		var building_type: String = building_data.get("building_type", "")
		var pos_x: float = building_data.get("position", {}).get("x", 0)
		var pos_y: float = building_data.get("position", {}).get("y", 0)

		# 查找匹配的建筑
		for building in buildings:
			if building.building_type == building_type:
				building.load_state(building_data)
				break

	print("[SaveManager] Animal buildings data applied")

## 将旧版 GiftSystem 好感度（0-100）迁移到 Friendship 点数系统
func _migrate_legacy_friendship(friendship: Node, legacy_data: Dictionary) -> void:
	if not friendship.has_method("add_friendship_points"):
		return
	for npc_id in legacy_data.keys():
		var legacy_hearts: int = int(legacy_data[npc_id]) / 10
		if legacy_hearts <= 0:
			continue
		var target_points: int = legacy_hearts * 250
		var current_points: int = friendship.get_points(npc_id) if friendship.has_method("get_points") else 0
		var delta: int = target_points - current_points
		if delta > 0:
			friendship.add_friendship_points(npc_id, delta, Friendship.FriendshipSource.EVENT)
	print("[SaveManager] Migrated legacy friendship data for %d NPCs" % legacy_data.size())
