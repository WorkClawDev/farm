extends Node
class_name EventBusGame

## EventBusGame - 游戏状态事件

signal game_started
signal game_paused
signal game_resumed
signal game_saved
signal game_loaded
signal scene_transition_started(target_scene: String)
signal scene_transition_completed
