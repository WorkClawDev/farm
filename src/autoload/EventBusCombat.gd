extends Node
class_name EventBusCombat

## EventBusCombat - 战斗系统事件

signal enemy_spawned(enemy: Node)
signal enemy_damaged(enemy: Node, damage: int)
signal enemy_died(enemy: Node, loot: Dictionary)
signal player_damaged(damage: int, source: Node)
signal player_attacked(weapon: String, damage: int)
signal combat_started
signal combat_ended
