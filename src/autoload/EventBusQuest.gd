extends Node
class_name EventBusQuest

## EventBusQuest - 任务系统事件

signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_turned_in(quest_id: String, rewards: Dictionary)
signal quest_progress_updated(quest_id: String, objective_index: int, current: int, required: int)
signal quest_failed(quest_id: String, reason: String)
