class_name Item
extends Resource

## Item - 物品基类
## 所有物品的基类，定义通用属性和方法

# 物品类型枚举
enum ItemType {
	SEED,       # 种子
	CROP,       # 作物收获物
	TOOL,       # 工具
	FOOD,       # 食物
	RESOURCE,   # 资源材料
	FISH,       # 鱼类
	MINERAL,    # 矿物
	DECORATION, # 装饰品
	QUEST       # 任务物品
}

# 物品ID
@export var item_id: String = ""

# 物品名称
@export var item_name: String = ""

# 物品类型
@export var item_type: ItemType = ItemType.RESOURCE

# 描述
@export_multiline var description: String = ""

# 图标路径
@export var icon_path: String = ""

# 最大堆叠数量
@export var max_stack: int = 999

# 购买价格
@export var buy_price: int = 0

# 出售价格
@export var sell_price: int = 0

# 当前数量
var quantity: int = 1


## 是否可以堆叠
func can_stack_with(other: Item) -> bool:
	if other == null:
		return false
	return item_id == other.item_id and item_type == other.item_type


## 堆叠物品
func stack_with(other: Item) -> int:
	if not can_stack_with(other):
		return 0

	var space_available := max_stack - quantity
	var amount_to_take := mini(space_available, other.quantity)

	quantity += amount_to_take
	other.quantity -= amount_to_take

	return amount_to_take


## 分割物品
func split(amount: int) -> Item:
	if amount >= quantity:
		return null

	var new_item := duplicate()
	new_item.quantity = amount
	quantity -= amount

	return new_item


## 获取显示名称
func get_display_name() -> String:
	return item_name if not item_name.is_empty() else item_id


## 获取完整描述（包含数量）
func get_full_description() -> String:
	var result := get_display_name() + "\n"
	result += description + "\n"
	result += "数量: " + str(quantity)

	if sell_price > 0:
		result += "\n售价: " + str(sell_price) + "G"

	return result


## 使用物品（子类重写）
func use(_user: Node) -> bool:
	push_warning("Item.use() should be overridden by subclass")
	return false


## 序列化保存
func save_state() -> Dictionary:
	return {
		"item_id": item_id,
		"item_name": item_name,
		"item_type": item_type,
		"description": description,
		"icon_path": icon_path,
		"max_stack": max_stack,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"quantity": quantity
	}


## 反序列化加载
func load_state(data: Dictionary) -> void:
	item_id = data.get("item_id", "")
	item_name = data.get("item_name", "")
	item_type = data.get("item_type", ItemType.RESOURCE)
	description = data.get("description", "")
	icon_path = data.get("icon_path", "")
	max_stack = data.get("max_stack", 999)
	buy_price = data.get("buy_price", 0)
	sell_price = data.get("sell_price", 0)
	quantity = data.get("quantity", 1)