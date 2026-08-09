extends Resource
class_name CropData

## CropData - 作物数据资源
## 定义作物的静态属性和生长参数

## 作物品质枚举
enum Quality {
	NORMAL,      # 普通
	SILVER,      # 银品质
	GOLD,        # 金品质
	IRIDIUM      # 铱品质
}

## 作物ID
@export var crop_id: String = ""
## 作物名称
@export var crop_name: String = ""
## 种子ID
@export var seed_id: String = ""
## 描述
@export_multiline var description: String = ""

## 生长天数（每个阶段的天数数组）
@export var growth_days: Array[int] = [1, 1, 1, 1]
## 适合生长的季节
@export var seasons: Array[String] = ["Spring"]
## 是否可以重复收获
@export var regrow: bool = false
## 重复收获需要的天数（如果可以重复收获）
@export var regrow_days: int = 0

## 精灵图路径（每个阶段的精灵）
@export var stage_sprites: Array[String] = []
## 收获物精灵
@export var harvest_sprite: String = ""

## 基础售价
@export var base_sell_price: int = 50
## 基础经验值
@export var base_exp: int = 10

## 最小产量
@export var min_harvest: int = 1
## 最大产量
@export var max_harvest: int = 1

## 需要浇水才能生长
@export var requires_water: bool = true
## 错过季节会枯萎
@export var dies_out_of_season: bool = true


func get_total_growth_days() -> int:
	var total: int = 0
	for days in growth_days:
		total += days
	return total


func get_stage_count() -> int:
	return growth_days.size()


func can_grow_in_season(season: String) -> bool:
	return season in seasons


func get_quality_price(quality: Quality) -> int:
	var multiplier: float = 1.0
	match quality:
		Quality.SILVER:
			multiplier = 1.25
		Quality.GOLD:
			multiplier = 1.5
		Quality.IRIDIUM:
			multiplier = 2.0
	return int(base_sell_price * multiplier)