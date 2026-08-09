extends Node
class_name EventBusCraft

## EventBusCraft - 制作/加工系统事件

signal crafting_ui_opened(workbench_type: String)
signal crafting_ui_closed
signal recipe_unlocked(recipe_id: String)
signal item_crafted(recipe_id: String, result_item: String, quantity: int)
signal crafting_failed(recipe_id: String, reason: String)
signal recipe_learned(recipe_id: String)
signal recipe_cooked(recipe_id: String, quantity: int)
signal cooking_started(recipe_id: String)
signal cooking_completed(recipe_id: String, result_item: String)
signal cooking_failed(recipe_id: String, reason: String)
