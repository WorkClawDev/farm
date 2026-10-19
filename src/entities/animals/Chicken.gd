extends "res://src/entities/animals/Animal.gd"
class_name Chicken

## Chicken - 鸡
## 产出鸡蛋，可以在鸡舍中饲养

func _ready() -> void:
	animal_type = "chicken"
	production_interval = 1  # 每天产蛋
	move_speed = 25.0
	private_sheet_path = "animals/x4/chicken_sheet_x4.png"
	frame_px = 128
	idle_frames = 6
	walk_frames = 6
	sprite_offset = Vector2(0, -34)
	private_body_radius = 14.0
	private_interaction_radius = 48.0
	super._ready()

## 获取产品ID
func get_product_id() -> String:
	# 根据好感度可能产出不同品质的蛋
	if friendship >= 900:
		# 高好感度有概率产金蛋
		if randf() < 0.1:
			return "golden_egg"
	return "egg"

## 获取产品名称
func get_product_name() -> String:
	if has_product:
		match get_product_id():
			"golden_egg":
				return "金蛋"
			_:
				return "鸡蛋"
	return "蛋"

## 获取交互提示文本
func get_interaction_text() -> String:
	if has_product:
		return "收集%s的%s" % [animal_name, get_product_name()]
	elif hunger < 50:
		return "喂养%s" % animal_name
	else:
		return "查看%s（好感度：%d心）" % [animal_name, get_hearts()]

## 鸡特有的行为：啄食动画
func play_peck_animation() -> void:
	current_state = AnimalState.EATING
	await get_tree().create_timer(0.5).timeout
	current_state = AnimalState.IDLE