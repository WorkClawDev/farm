extends "res://src/entities/animals/Animal.gd"
class_name Cow

## Cow - 牛
## 产出牛奶，可以在牛棚中饲养

func _ready() -> void:
	animal_type = "cow"
	production_interval = 1  # 每天产奶
	move_speed = 20.0
	max_hunger = 150  # 牛需要更多食物
	super._ready()

## 获取产品ID
func get_product_id() -> String:
	# 根据好感度产出不同品质的奶
	if friendship >= 800:
		# 高好感度可能产高品质奶
		if randf() < 0.3:
			return "quality_milk"
	return "milk"

## 获取产品名称
func get_product_name() -> String:
	if has_product:
		match get_product_id():
			"quality_milk":
				return "高品质牛奶"
			_:
				return "牛奶"
	return "奶"

## 获取交互提示文本
func get_interaction_text() -> String:
	if has_product:
		return "挤%s的奶" % animal_name
	elif hunger < 50:
		return "喂养%s" % animal_name
	else:
		return "查看%s（好感度：%d心）" % [animal_name, get_hearts()]

## 牛特有的行为：哞叫
func moo() -> void:
	print("[Cow] %s says: Moo!" % animal_name)
	# 可以播放音效