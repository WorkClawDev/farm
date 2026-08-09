extends Node
class_name EventBusFishing

## EventBusFishing - 钓鱼系统事件

signal fishing_started(location: String)
signal fishing_ended(success: bool, fish_id: String, fish_size: int)
signal fish_hooked(fish_id: String, fish_name: String)
signal fish_caught(fish_id: String, fish_size: int, quality: int)
