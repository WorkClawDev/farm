extends Node
class_name EventBusMine

## EventBusMine - 矿洞系统事件

signal mine_entered(floor: int)
signal mine_exited
signal mine_floor_changed(old_floor: int, new_floor: int)
signal ore_mined(ore_type: String, quantity: int, quality: int)
signal ore_depleted(ore_id: String)
signal ore_respawned(ore_id: String)
signal ladder_used(direction: int)  # -1: up, 1: down
