extends Node
class_name EventBusPlayer

## EventBusPlayer - 玩家事件

signal player_moved(position: Vector2)
signal player_interacted(target: Node)
signal energy_changed(current: int, maximum: int)
signal health_changed(current: int, maximum: int)
signal combat_started
signal combat_ended
signal spawn_point_changed(spawn_point: String)
