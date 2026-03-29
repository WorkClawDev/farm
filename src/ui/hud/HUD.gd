extends CanvasLayer

## 游戏主HUD - 显示体力/金钱/日期/季节

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var stamina_label: Label = $StaminaBar/StaminaLabel
@onready var money_label: Label = $MoneyContainer/MoneyLabel
@onready var day_label: Label = $DayContainer/DayLabel
@onready var gold_icon: ColorRect = $MoneyContainer/GoldIcon

var _game_manager: Node = null
var _time_manager: Node = null

func _ready() -> void:
	_game_manager = get_node_or_null("/root/GameManager")
	_time_manager = get_node_or_null("/root/TimeManager")
	_update_display()

func _process(_delta: float) -> void:
	_update_display()

func _update_display() -> void:
	# 体力条
	if _game_manager:
		var stamina = _game_manager.get("current_stamina") if _game_manager.has_method("current_stamina") else _game_manager.get("current_stamina", 100.0)
		var max_stamina = _game_manager.get("max_stamina") if _game_manager.has_method("max_stamina") else 100.0
		var ratio = clampf(stamina / max_stamina if max_stamina > 0 else 0.0, 0.0, 1.0)
		stamina_bar.value = ratio * 100.0
		stamina_label.text = "%d/%d" % [int(stamina), int(max_stamina)]

		# 体力条颜色：绿>黄>红
		if ratio > 0.6:
			stamina_bar.modulate = Color(0.3, 0.9, 0.3, 1.0)  # 绿色
		elif ratio > 0.3:
			stamina_bar.modulate = Color(0.9, 0.8, 0.2, 1.0)  # 黄色
		else:
			stamina_bar.modulate = Color(0.9, 0.3, 0.2, 1.0)  # 红色

		# 金钱
		var money = _game_manager.get_money() if _game_manager.has_method("get_money") else 0
		money_label.text = "%,d" % money

	# 日期/季节
	if _time_manager:
		var day = _time_manager.get_current_day() if _time_manager.has_method("get_current_day") else 1
		var season = _time_manager.get_season_name() if _time_manager.has_method("get_season_name") else "Spring"
		var season_cn = {"Spring": "春", "Summer": "夏", "Fall": "秋", "Winter": "冬"}.get(season, season)
		day_label.text = "%s 第%d天" % [season_cn, day]
