extends Node
class_name EventBusInventory

## EventBusInventory - 背包系统事件

signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full
