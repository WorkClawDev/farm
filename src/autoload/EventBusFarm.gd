extends Node
class_name EventBusFarm

## EventBusFarm - 农场系统事件

signal crop_planted(crop_type: String, position: Vector2)
signal crop_grew(crop_type: String, stage: int)
signal crop_harvested(crop_type: String, quality: int, quantity: int)
signal soil_watered(position: Vector2)
signal soil_dried(position: Vector2)
