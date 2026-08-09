extends Node

## FurnitureDatabase - 家具数据库
## 管理所有可用的家具数据

# 家具类型
enum FurnitureCategory {
	DECORATION,  # 装饰
	STORAGE,     # 储物
	KITCHEN,     # 厨房
	BEDROOM,     # 卧室
	LIVING       # 客厅
}

# 家具数据
var _furniture_data: Dictionary = {}

func _ready() -> void:
	_load_default_furniture()
	print("[FurnitureDatabase] Loaded ", _furniture_data.size(), " furniture items")

## 加载默认家具
func _load_default_furniture() -> void:
	# 装饰类
	_register_furniture({
		"id": "wooden_table",
		"name": "木桌",
		"description": "简单的木制桌子",
		"category": "living",
		"width": 2, "height": 1,
		"is_interactive": true,
		"interaction_type": "sit",
		"comfort_bonus": 5,
		"buy_price": 500,
		"sell_price": 250
	})
	
	_register_furniture({
		"id": "wooden_chair",
		"name": "木椅",
		"description": "简单的木制椅子",
		"category": "living",
		"width": 1, "height": 1,
		"is_interactive": true,
		"interaction_type": "sit",
		"comfort_bonus": 3,
		"buy_price": 200,
		"sell_price": 100
	})
	
	_register_furniture({
		"id": "basic_bed",
		"name": "普通床铺",
		"description": "舒适的床铺，恢复体力",
		"category": "bedroom",
		"width": 2, "height": 2,
		"is_interactive": true,
		"interaction_type": "sleep",
		"comfort_bonus": 10,
		"buy_price": 1000,
		"sell_price": 500
	})
	
	_register_furniture({
		"id": "luxury_bed",
		"name": "豪华大床",
		"description": "豪华的双人床，大幅恢复体力",
		"category": "bedroom",
		"width": 3, "height": 2,
		"is_interactive": true,
		"interaction_type": "sleep",
		"comfort_bonus": 20,
		"buy_price": 5000,
		"sell_price": 2500
	})
	
	_register_furniture({
		"id": "wooden_cabinet",
		"name": "木柜",
		"description": "小型储物柜",
		"category": "storage",
		"width": 1, "height": 2,
		"is_interactive": true,
		"interaction_type": "storage",
		"comfort_bonus": 2,
		"buy_price": 800,
		"sell_price": 400
	})
	
	_register_furniture({
		"id": "large_cabinet",
		"name": "大衣柜",
		"description": "大型储物柜，增加储物空间",
		"category": "storage",
		"width": 2, "height": 2,
		"is_interactive": true,
		"interaction_type": "storage",
		"comfort_bonus": 5,
		"buy_price": 2000,
		"sell_price": 1000
	})
	
	_register_furniture({
		"id": "basic_stove",
		"name": "基础炉灶",
		"description": "简单的烹饪炉灶",
		"category": "kitchen",
		"width": 1, "height": 1,
		"is_interactive": true,
		"interaction_type": "cooking",
		"comfort_bonus": 0,
		"buy_price": 1500,
		"sell_price": 750
	})
	
	_register_furniture({
		"id": "luxury_stove",
		"name": "豪华炉灶",
		"description": "高级烹饪设备，解锁更多配方",
		"category": "kitchen",
		"width": 2, "height": 1,
		"is_interactive": true,
		"interaction_type": "cooking",
		"comfort_bonus": 5,
		"buy_price": 8000,
		"sell_price": 4000
	})
	
	_register_furniture({
		"id": "potted_plant",
		"name": "盆栽植物",
		"description": "美化环境的绿色植物",
		"category": "decoration",
		"width": 1, "height": 1,
		"is_interactive": false,
		"aesthetics_bonus": 5,
		"buy_price": 300,
		"sell_price": 150
	})
	
	_register_furniture({
		"id": "flower_vase",
		"name": "花瓶",
		"description": "精美的花瓶装饰",
		"category": "decoration",
		"width": 1, "height": 1,
		"is_interactive": false,
		"aesthetics_bonus": 8,
		"buy_price": 500,
		"sell_price": 250
	})
	
	_register_furniture({
		"id": "painting",
		"name": "画作",
		"description": "挂在墙上的艺术画作",
		"category": "decoration",
		"width": 2, "height": 1,
		"is_interactive": false,
		"aesthetics_bonus": 10,
		"buy_price": 1000,
		"sell_price": 500
	})
	
	_register_furniture({
		"id": "bookshelf",
		"name": "书架",
		"description": "摆满书籍的书架",
		"category": "living",
		"width": 2, "height": 2,
		"is_interactive": true,
		"interaction_type": "read",
		"aesthetics_bonus": 8,
		"buy_price": 1500,
		"sell_price": 750
	})
	
	_register_furniture({
		"id": "rug",
		"name": "地毯",
		"description": "温暖舒适的地毯",
		"category": "decoration",
		"width": 2, "height": 2,
		"is_interactive": false,
		"comfort_bonus": 5,
		"aesthetics_bonus": 5,
		"buy_price": 600,
		"sell_price": 300
	})
	
	_register_furniture({
		"id": "lamp",
		"name": "台灯",
		"description": "提供照明的台灯",
		"category": "decoration",
		"width": 1, "height": 1,
		"is_interactive": true,
		"interaction_type": "light",
		"comfort_bonus": 2,
		"buy_price": 400,
		"sell_price": 200
	})

## 注册家具
func _register_furniture(data: Dictionary) -> void:
	_furniture_data[data.id] = data

## 获取家具数据
func get_furniture(furniture_id: String) -> Dictionary:
	return _furniture_data.get(furniture_id, {})

## 检查家具是否存在
func has_furniture(furniture_id: String) -> bool:
	return _furniture_data.has(furniture_id)

## 获取所有家具ID
func get_all_furniture_ids() -> Array:
	return _furniture_data.keys()

## 按类别获取家具
func get_furniture_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for furniture_id in _furniture_data:
		var data = _furniture_data[furniture_id]
		if data.get("category", "") == category:
			result.append(data)
	return result

## 获取可交互家具
func get_interactive_furniture() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for furniture_id in _furniture_data:
		var data = _furniture_data[furniture_id]
		if data.get("is_interactive", false):
			result.append(data)
	return result