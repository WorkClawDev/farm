extends Node
class_name PriceManager

## PriceManager - 价格管理器
## 管理动态定价、季节影响、供需关系和价格波动

signal price_updated(item_id: String, new_price: int, base_price: int)
signal market_event_triggered(event_name: String, affected_items: Array)
signal prices_changed

# 季节名称映射
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

# 价格波动配置
const DAILY_FLUCTUATION_MIN: float = 0.8   # 每日最低波动比例
const DAILY_FLUCTUATION_MAX: float = 1.2   # 每日最高波动比例
const SEASONAL_BONUS_MIN: float = 0.7       # 非季节物品最低折扣
const SEASONAL_BONUS_MAX: float = 1.3       # 季节物品最高加成
const DEMAND_IMPACT_RATE: float = 0.05      # 供需影响比率
const MAX_DEMAND_IMPACT: float = 0.3        # 最大供需影响

# 市场事件定义
enum MarketEventType {
	BOOM,           # 市场繁荣 - 价格上涨
	BUST,           # 市场萧条 - 价格下跌
	HARVEST_FESTIVAL,  # 丰收节 - 作物价格提升
	SEED_SHORTAGE,  # 种子短缺
	CROP_SURPLUS,   # 作物过剩
	TOURISM_BOOM,   # 旅游旺季
	NONE            # 无事件
}

# 市场事件数据结构
class MarketEvent extends RefCounted:
	var event_type: int = MarketEventType.NONE
	var name: String = ""
	var description: String = ""
	var duration_days: int = 1
	var remaining_days: int = 0
	var price_modifier: float = 1.0
	var affected_categories: Array[String] = []
	var affected_items: Array[String] = []

	func _to_string() -> String:
		return "[%s] %s - %.0f%% price (%d days left)" % [
			MarketEventType.keys()[event_type], name, price_modifier * 100, remaining_days
		]

# 物品价格数据
class ItemPriceData extends RefCounted:
	var item_id: String = ""
	var base_price: int = 0          # 基础价格
	var current_price: int = 0       # 当前价格
	var daily_modifier: float = 1.0  # 每日波动系数
	var seasonal_modifier: float = 1.0  # 季节系数
	var demand_modifier: float = 1.0    # 供需系数
	var event_modifier: float = 1.0     # 事件系数
	var category: String = "general"    # 物品分类
	var in_season: bool = true          # 是否在季节内
	var predicted_prices: Array[int] = []  # 未来7天预测价格

	func _to_string() -> String:
		return "[%s] Base: %d, Current: %d (%.0f%%)" % [
			item_id, base_price, current_price, (float(current_price) / base_price) * 100
		]

# 价格数据库
var _price_data: Dictionary = {}  # item_id -> ItemPriceData

# 市场事件
var _current_event: MarketEvent = null
var _event_history: Array[Dictionary] = []

# 供需追踪
var _supply_tracker: Dictionary = {}   # item_id -> 供应量
var _demand_tracker: Dictionary = {}   # item_id -> 需求量

# 历史价格记录（用于预测）
var _price_history: Dictionary = {}    # item_id -> Array of past prices
const HISTORY_LENGTH: int = 14         # 保留14天历史

# 随机数生成器
var _rng: RandomNumberGenerator

# 物品分类到季节的映射
var _category_season_map: Dictionary = {
	"spring_crops": ["Spring"],
	"summer_crops": ["Summer"],
	"fall_crops": ["Fall"],
	"spring_seeds": ["Spring"],
	"summer_seeds": ["Summer"],
	"fall_seeds": ["Fall"],
	"fish_spring": ["Spring"],
	"fish_summer": ["Summer"],
	"fish_fall": ["Fall"],
	"fish_winter": ["Winter"],
	"forage_spring": ["Spring"],
	"forage_summer": ["Summer"],
	"forage_fall": ["Fall"],
	"forage_winter": ["Winter"]
}


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	print("[PriceManager] Initialized")


## 注册物品到价格系统
func register_item(item_id: String, base_price: int, category: String = "general", seasons: Array[String] = []) -> void:
	if base_price <= 0:
		push_warning("[PriceManager] Cannot register item with invalid base price: " + str(base_price))
		return

	var price_data := ItemPriceData.new()
	price_data.item_id = item_id
	price_data.base_price = base_price
	price_data.current_price = base_price
	price_data.category = category
	price_data.in_season = _is_item_in_season(seasons)

	# 计算初始季节系数
	price_data.seasonal_modifier = _calculate_seasonal_modifier(seasons)

	_price_data[item_id] = price_data
	_supply_tracker[item_id] = 0
	_demand_tracker[item_id] = 0
	_price_history[item_id] = []

	# 初始化预测价格
	_update_predicted_prices(item_id)

	print("[PriceManager] Registered item: ", item_id, " base price: ", base_price)


## 批量注册物品
func register_items(items: Array[Dictionary]) -> void:
	for item in items:
		var item_id: String = item.get("id", "")
		var base_price: int = item.get("base_price", 0)
		var category: String = item.get("category", "general")
		var seasons: Array = item.get("seasons", [])

		if item_id != "" and base_price > 0:
			register_item(item_id, base_price, category, seasons)


## 获取当前价格
func get_current_price(item_id: String) -> int:
	if not _price_data.has(item_id):
		push_warning("[PriceManager] Item not registered: " + item_id)
		return 0

	return _price_data[item_id].current_price


## 获取基础价格
func get_base_price(item_id: String) -> int:
	if not _price_data.has(item_id):
		return 0
	return _price_data[item_id].base_price


## 获取价格详情
func get_price_details(item_id: String) -> Dictionary:
	if not _price_data.has(item_id):
		return {}

	var data: ItemPriceData = _price_data[item_id]
	return {
		"item_id": data.item_id,
		"base_price": data.base_price,
		"current_price": data.current_price,
		"daily_modifier": data.daily_modifier,
		"seasonal_modifier": data.seasonal_modifier,
		"demand_modifier": data.demand_modifier,
		"event_modifier": data.event_modifier,
		"in_season": data.in_season,
		"predicted_prices": data.predicted_prices.duplicate()
	}


## 每日更新价格（由TimeManager调用）
func on_day_changed() -> void:
	# 更新市场事件
	_update_market_event()

	# 更新所有物品价格
	for item_id in _price_data:
		_update_item_daily_price(item_id)

	# 应用供需影响
	_apply_supply_demand_impact()

	# 记录历史价格
	_record_daily_prices()

	# 更新预测价格
	for item_id in _price_data:
		_update_predicted_prices(item_id)

	# 重置供需追踪
	_reset_daily_trackers()

	prices_changed.emit()
	print("[PriceManager] Daily prices updated")


## 季节变化时更新价格（由TimeManager调用）
func on_season_changed(new_season: int) -> void:
	var season_name: String = SEASONS[new_season]

	for item_id in _price_data:
		var data: ItemPriceData = _price_data[item_id]
		var category: String = data.category

		# 检查是否在新季节
		var seasons: Array = _get_seasons_for_category(category)
		data.in_season = season_name in seasons or seasons.is_empty()

		# 更新季节系数
		data.seasonal_modifier = _calculate_seasonal_modifier_for_category(category, season_name)

		# 重新计算当前价格
		_recalculate_current_price(item_id)

		# 更新预测
		_update_predicted_prices(item_id)

	print("[PriceManager] Seasonal prices updated for: ", season_name)
	prices_changed.emit()


## 记录交易（影响供需）
func record_transaction(item_id: String, quantity: int, is_buying: bool) -> void:
	if not _price_data.has(item_id):
		return

	if is_buying:
		# 玩家购买 = 市场需求增加
		_demand_tracker[item_id] = _demand_tracker.get(item_id, 0) + quantity
	else:
		# 玩家出售 = 市场供应增加
		_supply_tracker[item_id] = _supply_tracker.get(item_id, 0) + quantity


## 触发随机市场事件
func trigger_random_event() -> MarketEvent:
	var roll: float = _rng.randf()

	# 10% 几率触发事件
	if roll > 0.1:
		return null

	var event_types: Array[int] = [
		MarketEventType.BOOM,
		MarketEventType.BUST,
		MarketEventType.HARVEST_FESTIVAL,
		MarketEventType.SEED_SHORTAGE,
		MarketEventType.CROP_SURPLUS,
		MarketEventType.TOURISM_BOOM
	]

	var selected_type: int = event_types[_rng.randi() % event_types.size()]
	return create_market_event(selected_type)


## 创建指定类型的市场事件
func create_market_event(event_type: int, custom_duration: int = -1) -> MarketEvent:
	var event := MarketEvent.new()
	event.event_type = event_type
	event.remaining_days = custom_duration if custom_duration > 0 else _rng.randi_range(2, 5)

	match event_type:
		MarketEventType.BOOM:
			event.name = "Market Boom"
			event.description = "The market is thriving! Prices are up."
			event.price_modifier = _rng.randf_range(1.15, 1.3)
			event.affected_categories = ["crops", "fish", "forage"]

		MarketEventType.BUST:
			event.name = "Market Downturn"
			event.description = "The market is struggling. Prices are down."
			event.price_modifier = _rng.randf_range(0.7, 0.85)
			event.affected_categories = ["crops", "fish", "forage"]

		MarketEventType.HARVEST_FESTIVAL:
			event.name = "Harvest Festival"
			event.description = "The harvest festival is here! Crop prices are high."
			event.price_modifier = _rng.randf_range(1.2, 1.5)
			event.affected_categories = ["crops", "spring_crops", "summer_crops", "fall_crops"]

		MarketEventType.SEED_SHORTAGE:
			event.name = "Seed Shortage"
			event.description = "Seeds are in short supply! Prices increased."
			event.price_modifier = _rng.randf_range(1.3, 1.6)
			event.affected_categories = ["seeds", "spring_seeds", "summer_seeds", "fall_seeds"]

		MarketEventType.CROP_SURPLUS:
			event.name = "Crop Surplus"
			event.description = "There's a surplus of crops. Prices are lower."
			event.price_modifier = _rng.randf_range(0.6, 0.8)
			event.affected_categories = ["crops", "spring_crops", "summer_crops", "fall_crops"]

		MarketEventType.TOURISM_BOOM:
			event.name = "Tourism Boom"
			event.description = "Tourists are visiting! All prices are slightly higher."
			event.price_modifier = _rng.randf_range(1.1, 1.2)
			event.affected_categories = ["crops", "fish", "forage", "crafts"]

		_:
			return null

	event.duration_days = event.remaining_days
	_current_event = event

	# 应用事件到相关物品
	_apply_market_event(event)

	# 记录事件
	_event_history.append({
		"event_type": MarketEventType.keys()[event_type],
		"name": event.name,
		"duration": event.duration_days,
		"timestamp": Time.get_unix_time_from_system()
	})

	market_event_triggered.emit(event.name, event.affected_categories)
	print("[PriceManager] Market event: ", event.name, " (", event.price_modifier * 100, "%)")

	return event


## 获取当前市场事件
func get_current_event() -> MarketEvent:
	return _current_event


## 清除市场事件
func clear_market_event() -> void:
	if _current_event == null:
		return

	# 移除事件影响
	for item_id in _price_data:
		var data: ItemPriceData = _price_data[item_id]
		if _current_event.category in data.category or data.category in _current_event.affected_categories:
			data.event_modifier = 1.0
			_recalculate_current_price(item_id)

	_current_event = null
	prices_changed.emit()


## 获取预测价格
func get_predicted_prices(item_id: String, days: int = 7) -> Array[int]:
	if not _price_data.has(item_id):
		return []

	var predictions: Array[int] = []
	var data: ItemPriceData = _price_data[item_id]

	for i in range(min(days, data.predicted_prices.size())):
		predictions.append(data.predicted_prices[i])

	return predictions


## 获取价格趋势
func get_price_trend(item_id: String) -> String:
	if not _price_data.has(item_id):
		return "unknown"

	var data: ItemPriceData = _price_data[item_id]
	var ratio: float = float(data.current_price) / float(data.base_price)

	if ratio > 1.15:
		return "rising"
	elif ratio < 0.85:
		return "falling"
	else:
		return "stable"


## 获取所有物品价格
func get_all_prices() -> Dictionary:
	var result: Dictionary = {}
	for item_id in _price_data:
		result[item_id] = _price_data[item_id].current_price
	return result


## 获取市场摘要
func get_market_summary() -> Dictionary:
	var rising: Array[String] = []
	var falling: Array[String] = []
	var stable: Array[String] = []

	for item_id in _price_data:
		var trend: String = get_price_trend(item_id)
		match trend:
			"rising": rising.append(item_id)
			"falling": falling.append(item_id)
			"stable": stable.append(item_id)

	return {
		"current_event": _current_event.name if _current_event else "None",
		"rising_items": rising,
		"falling_items": falling,
		"stable_items": stable,
		"total_items": _price_data.size()
	}


## 强制设置物品价格（用于特殊事件）
func set_item_price(item_id: String, price: int) -> void:
	if not _price_data.has(item_id):
		return

	_price_data[item_id].current_price = price
	price_updated.emit(item_id, price, _price_data[item_id].base_price)


## 重置物品到基础价格
func reset_item_price(item_id: String) -> void:
	if not _price_data.has(item_id):
		return

	var data: ItemPriceData = _price_data[item_id]
	data.daily_modifier = 1.0
	data.event_modifier = 1.0
	data.current_price = data.base_price

	price_updated.emit(item_id, data.base_price, data.base_price)


# ============== 内部方法 ==============

## 更新单个物品的每日价格
func _update_item_daily_price(item_id: String) -> void:
	var data: ItemPriceData = _price_data[item_id]

	# 计算新的每日波动
	data.daily_modifier = _rng.randf_range(DAILY_FLUCTUATION_MIN, DAILY_FLUCTUATION_MAX)

	# 重新计算当前价格
	_recalculate_current_price(item_id)


## 重新计算当前价格
func _calculate_seasonal_modifier(seasons: Array[String]) -> float:
	if seasons.is_empty():
		return 1.0

	# 获取当前季节
	var current_season: String = ""
	if TimeManager:
		current_season = get_node("/root/TimeManager").get_season_name()

	if current_season in seasons:
		# 在季节内，价格正常或略高
		return _rng.randf_range(1.0, SEASONAL_BONUS_MAX)
	else:
		# 不在季节，价格略低（代表进口/储存成本）
		return _rng.randf_range(SEASONAL_BONUS_MIN, 1.0)


## 根据分类计算季节系数
func _calculate_seasonal_modifier_for_category(category: String, current_season: String) -> float:
	var seasons: Array = _get_seasons_for_category(category)

	if seasons.is_empty():
		return 1.0

	if current_season in seasons:
		return _rng.randf_range(1.0, SEASONAL_BONUS_MAX)
	else:
		return _rng.randf_range(SEASONAL_BONUS_MIN, 1.0)


## 获取分类对应的季节
func _get_seasons_for_category(category: String) -> Array:
	if _category_season_map.has(category):
		return _category_season_map[category]
	return []


## 检查物品是否在季节
func _is_item_in_season(seasons: Array[String]) -> bool:
	if seasons.is_empty():
		return true

	var current_season: String = ""
	if TimeManager:
		current_season = get_node("/root/TimeManager").get_season_name()

	return current_season in seasons


## 重新计算当前价格
func _recalculate_current_price(item_id: String) -> void:
	var data: ItemPriceData = _price_data[item_id]

	var final_price: float = float(data.base_price)
	final_price *= data.daily_modifier
	final_price *= data.seasonal_modifier
	final_price *= data.demand_modifier
	final_price *= data.event_modifier

	# 确保价格不低于基础价格的50%
	data.current_price = int(max(data.base_price * 0.5, final_price))

	price_updated.emit(item_id, data.current_price, data.base_price)


## 更新市场事件
func _update_market_event() -> void:
	if _current_event == null:
		# 尝试触发随机事件
		trigger_random_event()
		return

	_current_event.remaining_days -= 1

	if _current_event.remaining_days <= 0:
		clear_market_event()


## 应用市场事件
func _apply_market_event(event: MarketEvent) -> void:
	for item_id in _price_data:
		var data: ItemPriceData = _price_data[item_id]

		# 检查物品是否受影响
		var is_affected: bool = false
		for cat in event.affected_categories:
			if cat in data.category or data.category in cat:
				is_affected = true
				break

		if is_affected:
			data.event_modifier = event.price_modifier
			_recalculate_current_price(item_id)


## 应用供需影响
func _apply_supply_demand_impact() -> void:
	for item_id in _price_data:
		var supply: int = _supply_tracker.get(item_id, 0)
		var demand: int = _demand_tracker.get(item_id, 0)

		var data: ItemPriceData = _price_data[item_id]

		# 计算供需比
		if demand > 0 or supply > 0:
			var ratio: float
			if demand == 0:
				ratio = 0.0  # 只有供应，价格下降
			elif supply == 0:
				ratio = 1.0  # 只有需求，价格上涨
			else:
				ratio = float(demand) / float(demand + supply)

			# 供需影响价格（需求高 -> 价格高，供应高 -> 价格低）
			var impact: float = (ratio - 0.5) * 2 * DEMAND_IMPACT_RATE
			impact = clamp(impact, -MAX_DEMAND_IMPACT, MAX_DEMAND_IMPACT)

			data.demand_modifier = 1.0 + impact
			_recalculate_current_price(item_id)


## 记录每日价格历史
func _record_daily_prices() -> void:
	for item_id in _price_data:
		var data: ItemPriceData = _price_data[item_id]

		if not _price_history.has(item_id):
			_price_history[item_id] = []

		_price_history[item_id].append(data.current_price)

		# 保持历史记录长度
		while _price_history[item_id].size() > HISTORY_LENGTH:
			_price_history[item_id].remove_at(0)


## 更新预测价格
func _update_predicted_prices(item_id: String) -> void:
	if not _price_data.has(item_id):
		return

	var data: ItemPriceData = _price_data[item_id]
	data.predicted_prices.clear()

	var history: Array = _price_history.get(item_id, [])

	# 基于历史数据预测未来7天价格
	for day in range(7):
		var prediction: float = float(data.current_price)

		# 如果有足够历史数据，计算趋势
		if history.size() >= 3:
			var recent_avg: float = 0.0
			var count: int = min(3, history.size())
			for i in range(count):
				recent_avg += history[history.size() - 1 - i]
			recent_avg /= count

			# 添加随机波动
			var daily_fluctuation: float = _rng.randf_range(-0.05, 0.05)
			prediction = recent_avg * (1.0 + daily_fluctuation)

		# 添加每日波动
		prediction *= _rng.randf_range(0.95, 1.05)

		# 确保预测价格合理
		prediction = max(data.base_price * 0.5, prediction)

		data.predicted_prices.append(int(prediction))


## 重置每日追踪器
func _reset_daily_trackers() -> void:
	for item_id in _supply_tracker:
		_supply_tracker[item_id] = 0
	for item_id in _demand_tracker:
		_demand_tracker[item_id] = 0


## 序列化保存
func save_state() -> Dictionary:
	var prices_data: Dictionary = {}
	for item_id in _price_data:
		var data: ItemPriceData = _price_data[item_id]
		prices_data[item_id] = {
			"base_price": data.base_price,
			"current_price": data.current_price,
			"daily_modifier": data.daily_modifier,
			"seasonal_modifier": data.seasonal_modifier,
			"demand_modifier": data.demand_modifier,
			"event_modifier": data.event_modifier,
			"category": data.category,
			"in_season": data.in_season
		}

	return {
		"prices": prices_data,
		"current_event": {
			"type": _current_event.event_type if _current_event else -1,
			"name": _current_event.name if _current_event else "",
			"remaining_days": _current_event.remaining_days if _current_event else 0,
			"price_modifier": _current_event.price_modifier if _current_event else 1.0,
			"affected_categories": _current_event.affected_categories if _current_event else []
		},
		"event_history": _event_history.slice(-10),
		"price_history": _price_history
	}


## 反序列化加载
func load_state(data: Dictionary) -> void:
	var prices_data: Dictionary = data.get("prices", {})
	for item_id in prices_data:
		var item_data: Dictionary = prices_data[item_id]
		var price_data := ItemPriceData.new()
		price_data.item_id = item_id
		price_data.base_price = item_data.get("base_price", 0)
		price_data.current_price = item_data.get("current_price", 0)
		price_data.daily_modifier = item_data.get("daily_modifier", 1.0)
		price_data.seasonal_modifier = item_data.get("seasonal_modifier", 1.0)
		price_data.demand_modifier = item_data.get("demand_modifier", 1.0)
		price_data.event_modifier = item_data.get("event_modifier", 1.0)
		price_data.category = item_data.get("category", "general")
		price_data.in_season = item_data.get("in_season", true)

		_price_data[item_id] = price_data

	# 恢复市场事件
	var event_data: Dictionary = data.get("current_event", {})
	var event_type: int = event_data.get("type", -1)
	if event_type >= 0:
		_current_event = MarketEvent.new()
		_current_event.event_type = event_type
		_current_event.name = event_data.get("name", "")
		_current_event.remaining_days = event_data.get("remaining_days", 0)
		_current_event.price_modifier = event_data.get("price_modifier", 1.0)
		_current_event.affected_categories.clear()
		var categories_value: Variant = event_data.get("affected_categories", [])
		if categories_value is Array:
			for category in categories_value:
				_current_event.affected_categories.append(str(category))
	else:
		_current_event = null

	# 恢复事件历史
	_event_history.clear()
	var history_value: Variant = data.get("event_history", [])
	if history_value is Array:
		for history_entry in history_value:
			if history_entry is Dictionary:
				_event_history.append(history_entry.duplicate(true))

	# 恢复价格历史
	var saved_price_history: Dictionary = data.get("price_history", {})
	_price_history.clear()
	for item_id in saved_price_history:
		_price_history[item_id] = saved_price_history[item_id]

	print("[PriceManager] Loaded state with ", _price_data.size(), " items")


## 重置到初始状态
func reset() -> void:
	_price_data.clear()
	_current_event = null
	_event_history.clear()
	_supply_tracker.clear()
	_demand_tracker.clear()
	_price_history.clear()
	print("[PriceManager] Reset to initial state")
