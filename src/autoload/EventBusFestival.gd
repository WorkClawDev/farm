extends Node
class_name EventBusFestival

## EventBusFestival - 节日系统事件

signal festival_started(festival_id: String, festival_data: Dictionary)
signal festival_ended(festival_id: String, festival_data: Dictionary)
signal festival_upcoming(festival_id: String, days_until: int)
signal festival_activity_completed(festival_id: String, activity_id: String, rewards: Dictionary)
signal festival_reward_claimed(festival_id: String, reward_id: String)
signal festival_notification(message: String, festival_id: String)
