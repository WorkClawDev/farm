extends Node
class_name EventBusTime

## EventBusTime - 时间系统事件

signal day_started
signal day_ended
signal hour_changed(hour: int)
signal season_changed(season: int, season_name: String)
