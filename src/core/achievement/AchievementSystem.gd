extends Node

## AchievementSystem - 成就系统
## 追踪和解锁游戏成就

# 成就类别
enum AchievementCategory {
	FARMING,      # 农耕
	SOCIAL,       # 社交
	FISHING,      # 钓鱼
	MINING,       # 采矿
	COOKING,      # 烹饪
	EXPLORATION,  # 探索
	COLLECTION,   # 收集
	MONEY         # 金钱
}

# 成就数据
var _achievements: Dictionary = {}
var _unlocked_achievements: Array[String] = []

# 统计数据
var _stats: Dictionary = {
	"crops_harvested": 0,
	"fish_caught": 0,
	"money_earned": 0,
	"items_crafted": 0,
	"npcs_talked": [],
	"levels_explored": [],
	"seeds_planted": 0,
	"days_played": 0
}

# 信号
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)
signal stats_updated(stat_name: String, new_value: int)

func _ready() -> void:
	_load_achievements()
	_connect_signals()
	print("[AchievementSystem] Initialized with ", _achievements.size(), " achievements")

## 加载成就定义
func _load_achievements() -> void:
	# 农耕成就
	_register_achievement({
		"id": "first_harvest",
		"name": "初次收获",
		"description": "收获第一颗作物",
		"category": AchievementCategory.FARMING,
		"condition": {"stat": "crops_harvested", "value": 1},
		"icon": "res://assets/sprites/ui/achievements/first_harvest.png"
	})
	
	_register_achievement({
		"id": "farmer_novice",
		"name": "农作新手",
		"description": "收获10颗作物",
		"category": AchievementCategory.FARMING,
		"condition": {"stat": "crops_harvested", "value": 10},
		"icon": "res://assets/sprites/ui/achievements/farmer_novice.png"
	})
	
	_register_achievement({
		"id": "farmer_expert",
		"name": "农耕专家",
		"description": "收获100颗作物",
		"category": AchievementCategory.FARMING,
		"condition": {"stat": "crops_harvested", "value": 100},
		"icon": "res://assets/sprites/ui/achievements/farmer_expert.png"
	})
	
	_register_achievement({
		"id": "seed_planter",
		"name": "播种者",
		"description": "种植50颗种子",
		"category": AchievementCategory.FARMING,
		"condition": {"stat": "seeds_planted", "value": 50},
		"icon": "res://assets/sprites/ui/achievements/seed_planter.png"
	})
	
	# 钓鱼成就
	_register_achievement({
		"id": "first_fish",
		"name": "初次垂钓",
		"description": "钓到第一条鱼",
		"category": AchievementCategory.FISHING,
		"condition": {"stat": "fish_caught", "value": 1},
		"icon": "res://assets/sprites/ui/achievements/first_fish.png"
	})
	
	_register_achievement({
		"id": "fisherman",
		"name": "钓鱼达人",
		"description": "钓到50条鱼",
		"category": AchievementCategory.FISHING,
		"condition": {"stat": "fish_caught", "value": 50},
		"icon": "res://assets/sprites/ui/achievements/fisherman.png"
	})
	
	# 金钱成就
	_register_achievement({
		"id": "first_gold",
		"name": "第一桶金",
		"description": "累计赚取1000G",
		"category": AchievementCategory.MONEY,
		"condition": {"stat": "money_earned", "value": 1000},
		"icon": "res://assets/sprites/ui/achievements/first_gold.png"
	})
	
	_register_achievement({
		"id": "wealthy",
		"name": "小富即安",
		"description": "累计赚取50000G",
		"category": AchievementCategory.MONEY,
		"condition": {"stat": "money_earned", "value": 50000},
		"icon": "res://assets/sprites/ui/achievements/wealthy.png"
	})
	
	_register_achievement({
		"id": "millionaire",
		"name": "百万富翁",
		"description": "累计赚取100000G",
		"category": AchievementCategory.MONEY,
		"condition": {"stat": "money_earned", "value": 100000},
		"icon": "res://assets/sprites/ui/achievements/millionaire.png"
	})
	
	# 社交成就
	_register_achievement({
		"id": "friendly",
		"name": "友好邻居",
		"description": "与5个NPC交谈",
		"category": AchievementCategory.SOCIAL,
		"condition": {"stat": "npcs_talked", "value": 5},
		"icon": "res://assets/sprites/ui/achievements/friendly.png"
	})
	
	# 烹饪成就
	_register_achievement({
		"id": "first_meal",
		"name": "初次下厨",
		"description": "制作第一道料理",
		"category": AchievementCategory.COOKING,
		"condition": {"stat": "items_crafted", "value": 1},
		"icon": "res://assets/sprites/ui/achievements/first_meal.png"
	})
	
	_register_achievement({
		"id": "chef",
		"name": "厨师长",
		"description": "制作50道料理",
		"category": AchievementCategory.COOKING,
		"condition": {"stat": "items_crafted", "value": 50},
		"icon": "res://assets/sprites/ui/achievements/chef.png"
	})
	
	# 时间成就
	_register_achievement({
		"id": "first_week",
		"name": "第一周",
		"description": "游玩7天",
		"category": AchievementCategory.EXPLORATION,
		"condition": {"stat": "days_played", "value": 7},
		"icon": "res://assets/sprites/ui/achievements/first_week.png"
	})
	
	_register_achievement({
		"id": "first_month",
		"name": "满月",
		"description": "游玩28天（一个季节）",
		"category": AchievementCategory.EXPLORATION,
		"condition": {"stat": "days_played", "value": 28},
		"icon": "res://assets/sprites/ui/achievements/first_month.png"
	})
	
	_register_achievement({
		"id": "one_year",
		"name": "周年纪念",
		"description": "游玩112天（一年）",
		"category": AchievementCategory.EXPLORATION,
		"condition": {"stat": "days_played", "value": 112},
		"icon": "res://assets/sprites/ui/achievements/one_year.png"
	})

## 注册成就
func _register_achievement(data: Dictionary) -> void:
	_achievements[data.id] = data

## 连接信号
func _connect_signals() -> void:
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.day_changed.connect(_on_day_changed)
	
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.farm.crop_harvested.connect(_on_crop_harvested)
		event_bus.fishing.fish_caught.connect(_on_fish_caught)

## 更新统计
func update_stat(stat_name: String, value: int = 1) -> void:
	if _stats.has(stat_name):
		if typeof(_stats[stat_name]) == TYPE_INT:
			_stats[stat_name] += value
		elif typeof(_stats[stat_name]) == TYPE_ARRAY:
			if not _stats[stat_name].has(value):
				_stats[stat_name].append(value)
		stats_updated.emit(stat_name, _stats[stat_name])
		_check_achievements()

## 检查成就解锁
func _check_achievements() -> void:
	for achievement_id in _achievements.keys():
		if _unlocked_achievements.has(achievement_id):
			continue
		
		var achievement = _achievements[achievement_id]
		var condition = achievement.condition
		var stat_name = condition.stat
		var required_value = condition.value
		
		if _stats.has(stat_name):
			var current_value
			if typeof(_stats[stat_name]) == TYPE_INT:
				current_value = _stats[stat_name]
			elif typeof(_stats[stat_name]) == TYPE_ARRAY:
				current_value = _stats[stat_name].size()
			else:
				continue
			
			if current_value >= required_value:
				unlock_achievement(achievement_id)

## 解锁成就
func unlock_achievement(achievement_id: String) -> void:
	if _unlocked_achievements.has(achievement_id):
		return
	
	if not _achievements.has(achievement_id):
		return
	
	_unlocked_achievements.append(achievement_id)
	
	var achievement = _achievements[achievement_id]
	achievement_unlocked.emit(achievement_id, achievement)
	
	print("[AchievementSystem] 成就解锁: ", achievement.name)
	
	# 发送通知
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus and event_bus.ui:
		event_bus.ui.notification_shown.emit("成就解锁: " + achievement.name, 1)

## 检查成就是否已解锁
func is_achievement_unlocked(achievement_id: String) -> bool:
	return _unlocked_achievements.has(achievement_id)

## 获取所有成就
func get_all_achievements() -> Dictionary:
	return _achievements.duplicate()

## 获取已解锁成就
func get_unlocked_achievements() -> Array[String]:
	return _unlocked_achievements.duplicate()

## 获取成就进度
func get_achievement_progress(achievement_id: String) -> Dictionary:
	if not _achievements.has(achievement_id):
		return {}
	
	var achievement = _achievements[achievement_id]
	var condition = achievement.condition
	var stat_name = condition.stat
	var required = condition.value
	var current = 0
	
	if _stats.has(stat_name):
		if typeof(_stats[stat_name]) == TYPE_INT:
			current = _stats[stat_name]
		elif typeof(_stats[stat_name]) == TYPE_ARRAY:
			current = _stats[stat_name].size()
	
	return {
		"current": current,
		"required": required,
		"progress": min(float(current) / float(required), 1.0)
	}

## 获取解锁数量
func get_unlocked_count() -> int:
	return _unlocked_achievements.size()

## 获取总成就数量
func get_total_count() -> int:
	return _achievements.size()

# 事件回调
func _on_day_changed(new_day: int) -> void:
	update_stat("days_played", 1)

func _on_crop_harvested(_crop_type: String, _quality: int, quantity: int) -> void:
	update_stat("crops_harvested", quantity)

func _on_fish_caught(_fish_id: String, _size: int, _quality: int) -> void:
	update_stat("fish_caught", 1)

## 保存状态
func save_state() -> Dictionary:
	return {
		"unlocked": _unlocked_achievements,
		"stats": _stats.duplicate(true)
	}

## 加载状态
func load_state(data: Dictionary) -> void:
	if data.has("unlocked"):
		_unlocked_achievements = data.unlocked
	if data.has("stats"):
		_stats = data.stats.duplicate(true)
	print("[AchievementSystem] Loaded ", _unlocked_achievements.size(), " unlocked achievements")
