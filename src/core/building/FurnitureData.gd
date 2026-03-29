extends Resource
class_name FurnitureData

## FurnitureData - 家具数据资源
## 定义单个家具的属性

@export var furniture_id: String = ""
@export var furniture_name: String = "家具"
@export var description: String = ""
@export var category: String = "decoration"  # decoration, storage, kitchen, bedroom, living

# 尺寸（占用槽位）
@export var width: int = 1
@export var height: int = 1

# 功能
@export var is_interactive: bool = false
@export var interaction_type: String = ""  # storage, cooking, sleep, sit

# 美观度加成
@export var comfort_bonus: int = 0
@export var aesthetics_bonus: int = 0

# 购买价格
@export var buy_price: int = 100
@export var sell_price: int = 50

# 图标路径
@export var icon_path: String = ""

func _init(id: String = "", name: String = "") -> void:
	furniture_id = id
	furniture_name = name