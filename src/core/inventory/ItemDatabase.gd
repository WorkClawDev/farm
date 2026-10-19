extends Node

## ItemDatabase - 物品数据库
## 从 JSON 加载物品数据，提供物品查询功能

# 物品类型
enum ItemType {
	SEED,       # 种子
	CROP,       # 作物
	TOOL,       # 工具
	FOOD,       # 食物
	RESOURCE,   # 资源材料
	FISH,       # 鱼
	DECORATION, # 装饰
	QUEST       # 任务物品
}

# 物品数据结构
class ItemData extends RefCounted:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var type: int = ItemType.RESOURCE
	var max_stack: int = 999
	var buy_price: int = 0
	var sell_price: int = 0
	var icon_path: String = ""
	var usable: bool = false
	var use_effect: Dictionary = {}
	var seasons: Array[String] = []  # 可种植季节（种子专用）
	var growth_days: int = 0        # 生长天数（种子专用）
	var crop_id: String = ""        # 产出作物ID（种子专用）

	func _to_string() -> String:
		return "[%s] %s - %s" % [id, name, ItemType.keys()[type]]

# 物品数据库
var _items: Dictionary = {}
var _is_loaded: bool = false

signal database_loaded
signal database_error(error_message: String)

const ICON_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]

func _ready() -> void:
	load_database()

## 加载物品数据库
func load_database() -> bool:
	var path := "res://data/items.json"

	if not FileAccess.file_exists(path):
		push_warning("[ItemDatabase] items.json not found at: " + path)
		_create_default_database()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		push_error("[ItemDatabase] Failed to open items.json: " + str(error))
		database_error.emit("Failed to open items.json")
		return false

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		push_error("[ItemDatabase] JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		database_error.emit("JSON parse error")
		return false

	var data: Dictionary = json.get_data()
	_parse_items(data)

	_is_loaded = true
	database_loaded.emit()
	print("[ItemDatabase] Loaded %d items" % _items.size())
	return true

## 解析物品数据
func _parse_items(data: Dictionary) -> void:
	if not data.has("items"):
		push_warning("[ItemDatabase] No 'items' array in items.json")
		return

	var items_array: Array = data["items"]
	for item_data in items_array:
		var item := _create_item_from_dict(item_data)
		if item.id != "":
			_items[item.id] = item

## 从字典创建物品
func _create_item_from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()

	item.id = data.get("id", "")
	if item.id == "":
		push_warning("[ItemDatabase] Item missing 'id' field")
		return item

	item.name = data.get("name", item.id)
	item.description = data.get("description", "")

	# 解析类型
	var type_str: String = data.get("type", "resource")
	item.type = _parse_item_type(type_str)

	item.max_stack = data.get("max_stack", 999)
	item.buy_price = data.get("buy_price", 0)
	item.sell_price = data.get("sell_price", 0)
	item.icon_path = data.get("icon", "")
	item.usable = data.get("usable", false)
	item.use_effect = data.get("use_effect", {})

	# 种子专用字段
	if data.has("seasons"):
		for season in data["seasons"]:
			item.seasons.append(season)
	item.growth_days = data.get("growth_days", 0)
	item.crop_id = data.get("crop_id", "")

	return item

## 解析物品类型字符串
func _parse_item_type(type_str: String) -> int:
	match type_str.to_lower():
		"seed": return ItemType.SEED
		"crop": return ItemType.CROP
		"tool": return ItemType.TOOL
		"food": return ItemType.FOOD
		"resource": return ItemType.RESOURCE
		"fish": return ItemType.FISH
		"decoration": return ItemType.DECORATION
		"quest": return ItemType.QUEST
		_: return ItemType.RESOURCE

## 获取物品数据
func get_item(item_id: String) -> ItemData:
	return _items.get(item_id, null)

## 检查物品是否存在
func has_item(item_id: String) -> bool:
	return _items.has(item_id)

## 获取所有物品ID
func get_all_item_ids() -> Array:
	return _items.keys()

## 鑾峰彇鎵€鏈夌墿鍝佹暟鎹?
func get_all_items() -> Array:
	return _items.values()

## 按类型获取物品
func get_items_by_type(type: int) -> Array:
	var result := []
	for item_id in _items:
		var item: ItemData = _items[item_id]
		if item.type == type:
			result.append(item)
	return result

## 创建默认数据库
func _create_default_database() -> void:
	# 创建一些基本物品
	var default_items := [
		{
			"id": "turnip_seed",
			"name": "芜菁种子",
			"type": "seed",
			"seasons": ["spring"],
			"growth_days": 4,
			"crop_id": "turnip",
			"buy_price": 20,
			"sell_price": 10,
			"description": "春天播种，4天成熟"
		},
		{
			"id": "turnip",
			"name": "芜菁",
			"type": "crop",
			"buy_price": 0,
			"sell_price": 35,
			"description": "新鲜的芜菁"
		},
		{
			"id": "hoe",
			"name": "锄头",
			"type": "tool",
			"max_stack": 1,
			"description": "用于耕地"
		},
		{
			"id": "watering_can",
			"name": "水壶",
			"type": "tool",
			"max_stack": 1,
			"description": "用于浇水"
		}
	]

	for item_data in default_items:
		var item := _create_item_from_dict(item_data)
		_items[item.id] = item

	_is_loaded = true
	print("[ItemDatabase] Created default database with %d items" % _items.size())

## 获取类型名称
func get_type_name(type: int) -> String:
	return ItemType.keys()[type]

## 获取物品图标路径
func get_icon_path(item_id: String) -> String:
	# 优先使用 item_data 中定义的 icon_path
	var item := get_item(item_id)
	if item and item.icon_path != "":
		var configured_path := _resolve_icon_path(item.icon_path)
		if configured_path != "":
			return configured_path

	# Stage D: Ninja Adventure UI icons (64×64) before old placeholders.
	var icon_path := _find_icon_in_directory("res://assets/sprites/items/ninja_adventure", item_id)
	if icon_path != "":
		return icon_path

	# 自动映射：item_id -> assets/sprites/items/{item_id}.png
	icon_path = _find_icon_in_directory("res://assets/sprites/items", item_id)
	if icon_path != "":
		return icon_path

	# 备用：尝试不带 _seed 后缀
	if item_id.ends_with("_seed"):
		var crop_id := item_id.substr(0, item_id.length() - 5)  # 去掉 "_seed"
		icon_path = _find_icon_in_directory("res://assets/sprites/items", crop_id)
		if icon_path != "":
			return icon_path

	# 工具类型尝试从 tools 文件夹加载
	if item and item.type == ItemType.TOOL:
		icon_path = _find_icon_in_directory("res://assets/sprites/tools", item_id)
		if icon_path != "":
			return icon_path

	return ""

func _resolve_icon_path(path: String) -> String:
	if path.is_empty():
		return ""

	if FileAccess.file_exists(path):
		return path

	var basename := path.get_basename()
	for extension in ICON_EXTENSIONS:
		var candidate := "%s.%s" % [basename, extension]
		if FileAccess.file_exists(candidate):
			return candidate

	return ""

func _find_icon_in_directory(directory: String, item_id: String) -> String:
	for extension in ICON_EXTENSIONS:
		var candidate := "%s/%s.%s" % [directory, item_id, extension]
		if FileAccess.file_exists(candidate):
			return candidate

	return ""

## 加载物品图标纹理
func load_icon_texture(item_id: String) -> Texture2D:
	var path := get_icon_path(item_id)
	if path == "":
		return null

	var tex := load(path)
	if tex is Texture2D:
		return tex
	return null
