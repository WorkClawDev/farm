extends Node

## ForagingSystem - 采集系统
## 管理野生资源的生成、刷新和采集

signal forage_item_spawned(item_id: String, position: Vector2)
signal forage_item_collected(item_id: String, position: Vector2, quantity: int)
signal forage_respawn_scheduled(position: Vector2, days: int)
signal forage_respawned(position: Vector2)

## 可采集物品类型
enum ForageType {
	WILD_FRUIT,    # 野果
	MUSHROOM,      # 蘑菇
	FLOWER,        # 花朵
	HERB,          # 草药
	BRANCH,        # 树枝
	STONE,         # 石头
	SEED,          # 野生种子
	SHELL          # 贝壳
}

## 可采集物品数据结构
class ForageData extends RefCounted:
	var id: String = ""
	var name: String = ""
	var type: int = ForageType.WILD_FRUIT
	var description: String = ""
	var icon_path: String = ""
	var item_id: String = ""          # 采集后获得的物品ID
	var min_quantity: int = 1
	var max_quantity: int = 3
	var seasons: Array[String] = []   # 可出现的季节
	var locations: Array[String] = [] # 可出现的地点 (farm, forest, village, beach)
	var respawn_days: int = 3         # 刷新天数
	var rarity: float = 1.0           # 稀有度 (0.0-1.0, 越低越稀有)
	var energy_cost: int = 2          # 采集消耗体力
	var exp_reward: int = 3           # 采集经验奖励

	func _to_string() -> String:
		return "[%s] %s" % [id, name]

## 可采集点数据结构
class ForagePoint extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var forage_id: String = ""
	var is_collected: bool = false
	var day_collected: int = 0
	var respawn_days: int = 3
	var location: String = "forest"

	func save_state() -> Dictionary:
		return {
			"pos_x": position.x,
			"pos_y": position.y,
			"forage_id": forage_id,
			"is_collected": is_collected,
			"day_collected": day_collected,
			"respawn_days": respawn_days,
			"location": location
		}

	func load_state(data: Dictionary) -> void:
		position = Vector2(data.get("pos_x", 0), data.get("pos_y", 0))
		forage_id = data.get("forage_id", "")
		is_collected = data.get("is_collected", false)
		day_collected = data.get("day_collected", 0)
		respawn_days = data.get("respawn_days", 3)
		location = data.get("location", "forest")

# 可采集物品数据库
var _forage_database: Dictionary = {}
# 当前场景的采集点
var _forage_points: Dictionary = {}  # key: "x_y" position string
# 场景采集点实例引用
var _forage_nodes: Dictionary = {}

var _is_initialized: bool = false

func _ready() -> void:
	_load_forage_database()
	_connect_signals()
	_is_initialized = true
	print("[ForagingSystem] Initialized with %d forage types" % _forage_database.size())

func _connect_signals() -> void:
	if TimeManager:
		get_node("/root/TimeManager").day_changed.connect(_on_day_changed)
	if EventBus:
		pass  # 可根据需要连接其他事件

## 加载可采集物品数据库
func _load_forage_database() -> void:
	# 默认可采集物品
	_create_default_database()

## 创建默认数据库
func _create_default_database() -> void:
	var default_forage: Array[Dictionary] = [
		# 野果类
		{
			"id": "wild_berry",
			"name": "野莓",
			"type": ForageType.WILD_FRUIT,
			"item_id": "wild_berry",
			"description": "野生的小浆果，酸甜可口。",
			"seasons": ["Spring", "Summer", "Fall"],
			"locations": ["forest", "farm"],
			"min_quantity": 1,
			"max_quantity": 3,
			"respawn_days": 3,
			"rarity": 0.8,
			"energy_cost": 1,
			"exp_reward": 2,
			"sell_price": 15
		},
		{
			"id": "wild_grape",
			"name": "野葡萄",
			"type": ForageType.WILD_FRUIT,
			"item_id": "wild_grape",
			"description": "藤蔓上结出的紫色葡萄。",
			"seasons": ["Summer", "Fall"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 4,
			"rarity": 0.5,
			"energy_cost": 1,
			"exp_reward": 3,
			"sell_price": 40
		},
		{
			"id": "blackberry",
			"name": "黑莓",
			"type": ForageType.WILD_FRUIT,
			"item_id": "blackberry",
			"description": "深紫色的黑莓，营养丰富。",
			"seasons": ["Fall"],
			"locations": ["forest", "farm"],
			"min_quantity": 1,
			"max_quantity": 3,
			"respawn_days": 3,
			"rarity": 0.7,
			"energy_cost": 1,
			"exp_reward": 2,
			"sell_price": 25
		},
		# 蘑菇类
		{
			"id": "common_mushroom",
			"name": "普通蘑菇",
			"type": ForageType.MUSHROOM,
			"item_id": "common_mushroom",
			"description": "常见的可食用蘑菇。",
			"seasons": ["Spring", "Summer", "Fall"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 2,
			"rarity": 0.9,
			"energy_cost": 1,
			"exp_reward": 2,
			"sell_price": 20
		},
		{
			"id": "chanterelle",
			"name": "鸡油菌",
			"type": ForageType.MUSHROOM,
			"item_id": "chanterelle",
			"description": "金黄色的鸡油菌，味道鲜美。",
			"seasons": ["Fall"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 4,
			"rarity": 0.4,
			"energy_cost": 1,
			"exp_reward": 5,
			"sell_price": 80
		},
		{
			"id": "morel",
			"name": "羊肚菌",
			"type": ForageType.MUSHROOM,
			"item_id": "morel",
			"description": "珍贵的羊肚菌，稀有食材。",
			"seasons": ["Spring"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 1,
			"respawn_days": 5,
			"rarity": 0.2,
			"energy_cost": 1,
			"exp_reward": 8,
			"sell_price": 150
		},
		# 花朵类
		{
			"id": "wild_flower",
			"name": "野花",
			"type": ForageType.FLOWER,
			"item_id": "wild_flower",
			"description": "路边盛开的野花。",
			"seasons": ["Spring", "Summer"],
			"locations": ["forest", "farm", "village"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 4,
			"rarity": 0.9,
			"energy_cost": 1,
			"exp_reward": 1,
			"sell_price": 10
		},
		{
			"id": "daffodil",
			"name": "水仙花",
			"type": ForageType.FLOWER,
			"item_id": "daffodil",
			"description": "春天盛开的水仙花。",
			"seasons": ["Spring"],
			"locations": ["forest", "village"],
			"min_quantity": 1,
			"max_quantity": 1,
			"respawn_days": 5,
			"rarity": 0.6,
			"energy_cost": 1,
			"exp_reward": 3,
			"sell_price": 30
		},
		{
			"id": "sunflower",
			"name": "向日葵",
			"type": ForageType.FLOWER,
			"item_id": "sunflower",
			"description": "追随阳光的向日葵。",
			"seasons": ["Summer"],
			"locations": ["farm", "village"],
			"min_quantity": 1,
			"max_quantity": 1,
			"respawn_days": 6,
			"rarity": 0.5,
			"energy_cost": 1,
			"exp_reward": 4,
			"sell_price": 50
		},
		# 草药类
		{
			"id": "wild_herb",
			"name": "野草药",
			"type": ForageType.HERB,
			"item_id": "wild_herb",
			"description": "有药用价值的野生草药。",
			"seasons": ["Spring", "Summer", "Fall"],
			"locations": ["forest", "farm"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 3,
			"rarity": 0.7,
			"energy_cost": 1,
			"exp_reward": 3,
			"sell_price": 25
		},
		{
			"id": "ginger_root",
			"name": "野姜",
			"type": ForageType.HERB,
			"item_id": "ginger_root",
			"description": "辛辣的生姜根茎。",
			"seasons": ["Summer", "Fall"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 4,
			"rarity": 0.5,
			"energy_cost": 2,
			"exp_reward": 4,
			"sell_price": 45
		},
		# 树枝/木材类
		{
			"id": "fallen_branch",
			"name": "枯枝",
			"type": ForageType.BRANCH,
			"item_id": "wood",
			"description": "掉落的树枝，可以收集木材。",
			"seasons": ["Spring", "Summer", "Fall", "Winter"],
			"locations": ["forest", "farm"],
			"min_quantity": 2,
			"max_quantity": 5,
			"respawn_days": 2,
			"rarity": 0.9,
			"energy_cost": 2,
			"exp_reward": 2,
			"sell_price": 2
		},
		{
			"id": "hardwood_branch",
			"name": "硬木枝",
			"type": ForageType.BRANCH,
			"item_id": "hardwood",
			"description": "坚硬的硬木树枝。",
			"seasons": ["Spring", "Summer", "Fall", "Winter"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 5,
			"rarity": 0.3,
			"energy_cost": 3,
			"exp_reward": 5,
			"sell_price": 15
		},
		# 石头类
		{
			"id": "loose_stone",
			"name": "散石",
			"type": ForageType.STONE,
			"item_id": "stone",
			"description": "散落在地上的石头。",
			"seasons": ["Spring", "Summer", "Fall", "Winter"],
			"locations": ["forest", "farm", "village"],
			"min_quantity": 1,
			"max_quantity": 3,
			"respawn_days": 3,
			"rarity": 0.8,
			"energy_cost": 1,
			"exp_reward": 1,
			"sell_price": 2
		},
		{
			"id": "river_stone",
			"name": "河石",
			"type": ForageType.STONE,
			"item_id": "river_stone",
			"description": "河边的光滑石头。",
			"seasons": ["Spring", "Summer", "Fall"],
			"locations": ["forest"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 4,
			"rarity": 0.5,
			"energy_cost": 1,
			"exp_reward": 2,
			"sell_price": 20
		},
		# 贝壳类
		{
			"id": "seashell",
			"name": "贝壳",
			"type": ForageType.SHELL,
			"item_id": "seashell",
			"description": "海边捡到的漂亮贝壳。",
			"seasons": ["Spring", "Summer", "Fall", "Winter"],
			"locations": ["beach"],
			"min_quantity": 1,
			"max_quantity": 2,
			"respawn_days": 2,
			"rarity": 0.7,
			"energy_cost": 1,
			"exp_reward": 2,
			"sell_price": 40
		},
		{
			"id": "coral",
			"name": "珊瑚",
			"type": ForageType.SHELL,
			"item_id": "coral",
			"description": "海洋中的珊瑚，美丽而脆弱。",
			"seasons": ["Summer"],
			"locations": ["beach"],
			"min_quantity": 1,
			"max_quantity": 1,
			"respawn_days": 6,
			"rarity": 0.3,
			"energy_cost": 1,
			"exp_reward": 5,
			"sell_price": 80
		}
	]

	for forage_data in default_forage:
		var data := _create_forage_data(forage_data)
		_forage_database[data.id] = data

## 从字典创建可采集物品数据
func _create_forage_data(data: Dictionary) -> ForageData:
	var forage := ForageData.new()
	forage.id = data.get("id", "")
	forage.name = data.get("name", forage.id)
	forage.type = data.get("type", ForageType.WILD_FRUIT)
	forage.item_id = data.get("item_id", forage.id)
	forage.description = data.get("description", "")
	forage.icon_path = data.get("icon_path", "")
	forage.min_quantity = data.get("min_quantity", 1)
	forage.max_quantity = data.get("max_quantity", 3)
	forage.respawn_days = data.get("respawn_days", 3)
	forage.rarity = data.get("rarity", 1.0)
	forage.energy_cost = data.get("energy_cost", 1)
	forage.exp_reward = data.get("exp_reward", 2)

	if data.has("seasons"):
		for season in data["seasons"]:
			forage.seasons.append(season)
	if data.has("locations"):
		for location in data["locations"]:
			forage.locations.append(location)

	return forage

## 获取可采集物品数据
func get_forage_data(forage_id: String) -> ForageData:
	return _forage_database.get(forage_id, null)

## 获取所有可采集物品ID
func get_all_forage_ids() -> Array:
	return _forage_database.keys()

## 按类型获取可采集物品
func get_forage_by_type(type: int) -> Array:
	var result := []
	for forage_id in _forage_database:
		var forage: ForageData = _forage_database[forage_id]
		if forage.type == type:
			result.append(forage)
	return result

## 获取当前季节可采集的物品
func get_seasonal_forage(season: String = "") -> Array:
	if season == "":
		season = get_node("/root/TimeManager").get_season_name() if TimeManager else "Spring"

	var result := []
	for forage_id in _forage_database:
		var forage: ForageData = _forage_database[forage_id]
		if forage.seasons.has(season):
			result.append(forage)
	return result

## 获取指定地点的可采集物品
func get_location_forage(location: String) -> Array:
	var result := []
	for forage_id in _forage_database:
		var forage: ForageData = _forage_database[forage_id]
		if forage.locations.has(location):
			result.append(forage)
	return result

## 为场景生成采集点
func generate_forage_points(location: String, count: int = 10) -> Array:
	var points := []
	var season: String = get_node("/root/TimeManager").get_season_name() if TimeManager else "Spring"

	# 获取该地点和季节可用的采集物品
	var available_forage := []
	for forage_id in _forage_database:
		var forage: ForageData = _forage_database[forage_id]
		if forage.locations.has(location) and forage.seasons.has(season):
			available_forage.append(forage)

	if available_forage.is_empty():
		print("[ForagingSystem] No forage available for location: ", location, " in ", season)
		return points

	# 根据稀有度随机选择
	for i in range(count):
		var selected: ForageData = _select_random_forage(available_forage)
		if selected:
			points.append(selected.id)

	return points

## 根据稀有度随机选择可采集物品
func _select_random_forage(available: Array) -> ForageData:
	if available.is_empty():
		return null

	# 加权随机选择（稀有度越低越难选中）
	var total_weight: float = 0.0
	for forage: ForageData in available:
		total_weight += forage.rarity

	var random_value: float = randf() * total_weight
	var current_weight: float = 0.0

	for forage: ForageData in available:
		current_weight += forage.rarity
		if random_value <= current_weight:
			return forage

	return available[0] as ForageData

## 注册采集点
func register_forage_point(pos: Vector2, forage_id: String, location: String = "forest") -> void:
	var key := _position_to_key(pos)
	var point := ForagePoint.new()
	point.position = pos
	point.forage_id = forage_id
	point.is_collected = false
	point.day_collected = 0
	point.respawn_days = get_forage_data(forage_id).respawn_days if get_forage_data(forage_id) else 3
	point.location = location

	_forage_points[key] = point
	forage_item_spawned.emit(forage_id, pos)
	print("[ForagingSystem] Registered forage point: ", forage_id, " at ", pos)

## 注销采集点
func unregister_forage_point(pos: Vector2) -> void:
	var key := _position_to_key(pos)
	if _forage_points.has(key):
		_forage_points.erase(key)

## 采集物品
func collect_forage(pos: Vector2) -> Dictionary:
	var key := _position_to_key(pos)

	if not _forage_points.has(key):
		return {"success": false, "message": "No forage at this location"}

	var point: ForagePoint = _forage_points[key]

	if point.is_collected:
		return {"success": false, "message": "Already collected"}

	var forage_data: ForageData = get_forage_data(point.forage_id)
	if forage_data == null:
		return {"success": false, "message": "Invalid forage data"}

	# 检查季节
	if TimeManager and not forage_data.seasons.has(get_node("/root/TimeManager").get_season_name()):
		return {"success": false, "message": "Not available this season"}

	# 标记为已采集
	point.is_collected = true
	point.day_collected = get_node("/root/TimeManager").current_day if TimeManager else 1

	# 计算采集数量
	var quantity: int = randi_range(forage_data.min_quantity, forage_data.max_quantity)

	# 添加到背包
	if Inventory:
		var added: bool = get_node("/root/Inventory").add_item(forage_data.item_id, quantity)
		if not added:
			# 背包满了，取消采集
			point.is_collected = false
			return {"success": false, "message": "Inventory full"}

	# 发射信号
	forage_item_collected.emit(forage_data.id, pos, quantity)

	# 发送通知
	if EventBus:
		get_node("/root/EventBus").inventory.item_added.emit(forage_data.item_id, quantity)
		get_node("/root/EventBus").ui.notification_shown.emit(
			"采集了 %d 个%s" % [quantity, forage_data.name],
			0
		)

	print("[ForagingSystem] Collected: ", forage_data.name, " x", quantity)

	return {
		"success": true,
		"forage_id": forage_data.id,
		"item_id": forage_data.item_id,
		"quantity": quantity,
		"exp": forage_data.exp_reward,
		"energy_cost": forage_data.energy_cost
	}

## 检查是否可以采集
func can_collect(pos: Vector2) -> bool:
	var key := _position_to_key(pos)
	if not _forage_points.has(key):
		return false

	var point: ForagePoint = _forage_points[key]
	return not point.is_collected

## 获取采集点信息
func get_forage_point_info(pos: Vector2) -> Dictionary:
	var key := _position_to_key(pos)
	if not _forage_points.has(key):
		return {}

	var point: ForagePoint = _forage_points[key]
	var forage_data: ForageData = get_forage_data(point.forage_id)

	if forage_data == null:
		return {}

	return {
		"forage_id": point.forage_id,
		"name": forage_data.name,
		"description": forage_data.description,
		"is_collected": point.is_collected,
		"days_until_respawn": _get_days_until_respawn(point)
	}

## 计算距离刷新的天数
func _get_days_until_respawn(point: ForagePoint) -> int:
	if not point.is_collected:
		return 0

	var current_day: int = get_node("/root/TimeManager").current_day if TimeManager else 1
	var days_since_collection: int = current_day - point.day_collected

	# 处理跨季/跨年的情况
	if days_since_collection < 0:
		days_since_collection += 28 if TimeManager else 28

	return max(0, point.respawn_days - days_since_collection)

## 每日更新处理刷新
func _on_day_changed(new_day: int) -> void:
	_process_respawns()

## 处理刷新
func _process_respawns() -> void:
	var current_day: int = get_node("/root/TimeManager").current_day if TimeManager else 1

	for key in _forage_points:
		var point: ForagePoint = _forage_points[key]

		if point.is_collected:
			var days_since_collection: int = current_day - point.day_collected
			if days_since_collection < 0:
				days_since_collection += 28 if TimeManager else 28

			if days_since_collection >= point.respawn_days:
				_respawn_forage_point(point)

## 刷新采集点
func _respawn_forage_point(point: ForagePoint) -> void:
	point.is_collected = false
	point.day_collected = 0

	# 更新场景中的节点
	var key := _position_to_key(point.position)
	if _forage_nodes.has(key):
		var node: Node2D = _forage_nodes[key]
		if node and is_instance_valid(node):
			if node.has_method("respawn"):
				node.respawn()
			else:
				node.visible = true

	forage_respawned.emit(point.position)
	print("[ForagingSystem] Respawned forage at: ", point.position)

## 注册场景节点引用
func register_forage_node(pos: Vector2, node: Node2D) -> void:
	var key := _position_to_key(pos)
	_forage_nodes[key] = node

## 注销场景节点引用
func unregister_forage_node(pos: Vector2) -> void:
	var key := _position_to_key(pos)
	_forage_nodes.erase(key)

## 位置转键值
func _position_to_key(pos: Vector2) -> String:
	return "%d_%d" % [int(pos.x), int(pos.y)]

## 保存状态
func save_state() -> Dictionary:
	var points_data := []
	for key in _forage_points:
		var point: ForagePoint = _forage_points[key]
		points_data.append(point.save_state())

	return {
		"forage_points": points_data
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	_forage_points.clear()

	var points_data: Array = data.get("forage_points", [])
	for point_data in points_data:
		var point := ForagePoint.new()
		point.load_state(point_data)
		var key := _position_to_key(point.position)
		_forage_points[key] = point

	print("[ForagingSystem] Loaded %d forage points" % _forage_points.size())

## 获取类型名称
func get_type_name(type: int) -> String:
	return ForageType.keys()[type]
