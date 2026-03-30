extends Node

## SleepSystem - 睡眠系统
## 管理玩家睡眠、时间推进到第二天、体力恢复
## Autoload: /root/SleepSystem (通过 EventBus 调用)

# 信号
signal sleep_started
signal sleep_ended(new_day: int, new_season: String)
signal energy_restored(amount: int)

# 体力恢复配置
const ENERGY_RESTORE_AMOUNT: int = 50
const STAMINA_RESTORE_AMOUNT: int = 100

func _ready() -> void:
	print("[SleepSystem] Initialized")


## 执行睡眠（推进到第二天）
func sleep() -> void:
	sleep_started.emit()
	print("[SleepSystem] Player sleeping...")
	
	# 获取 TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		# 推进一天
		time_manager.advance_day()
		var new_day = time_manager.current_day
		var new_season = time_manager.get_season_name()
		sleep_ended.emit(new_day, new_season)
		print("[SleepSystem] Slept until day ", new_day, " (", new_season, ")")
	else:
		print("[SleepSystem] TimeManager not found!")
		sleep_ended.emit(1, "Spring")
	
	# 恢复体力/能量
	_restore_energy()
	
	# 通知天气系统生成新一天天气
	var weather = get_node_or_null("/root/WeatherSystem")
	if weather and weather.has_method("get_current_weather"):
		# WeatherSystem 会自动在 day_changed 信号时生成新天气
		pass
	
	# 显示睡眠结果通知
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.notification_shown.emit("新的一天开始了！", 2)


## 恢复体力
func _restore_energy() -> void:
	var player = _get_player_node()
	if player:
		# 尝试恢复玩家的 energy/stamina 属性
		if player.has_method("restore_energy"):
			player.restore_energy(STAMINA_RESTORE_AMOUNT)
		elif player.has_method("add_energy"):
			player.add_energy(STAMINA_RESTORE_AMOUNT)
		energy_restored.emit(STAMINA_RESTORE_AMOUNT)
		print("[SleepSystem] Restored ", STAMINA_RESTORE_AMOUNT, " energy")
	else:
		print("[SleepSystem] Player node not found, skipping energy restore")


## 获取玩家节点
func _get_player_node() -> Node:
	# 尝试多种方式获取玩家节点
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has("player"):
		return game_manager.player
	
	var scene = get_tree().current_scene
	if scene and scene.has_node("Player"):
		return scene.get_node("Player")
	
	return null


## 检查是否可以睡眠（白天不能睡眠）
func can_sleep() -> bool:
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return true
	
	var current_time = time_manager.current_time
	# 只能在晚上 18:00 到凌晨 6:00 之间睡眠
	return current_time >= 18.0 or current_time < 6.0


## 获取睡眠提示信息
func get_sleep_hint() -> String:
	if can_sleep():
		return "可以休息了"
	else:
		return "现在还不能睡觉（请等到晚上）"
