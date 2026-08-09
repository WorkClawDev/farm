extends Node
class_name ToolUpgrade

## ToolUpgrade - 工具升级系统
## 管理工具升级、材料需求和升级效果

# 工具等级枚举
enum ToolTier {
	COPPER,   # 铜 (基础)
	IRON,     # 铁
	GOLD,     # 金
	DIAMOND   # 钻石 (最高级)
}

# 工具类型枚举
enum ToolType {
	HOE,           # 锄头
	WATERING_CAN,  # 水壶
	AXE,           # 斧头
	PICKAXE,       # 镐
	SICKLE,        # 镰刀
	HAMMER         # 锤子
}

# 信号
signal tool_upgraded(tool_type: int, new_tier: int)
signal upgrade_failed(tool_type: int, reason: String)
signal materials_insufficient(required: Dictionary, available: Dictionary)

# 升级需求配置
class UpgradeRequirement extends RefCounted:
	var material_id: String = ""
	var quantity: int = 0

	func _init(p_material_id: String = "", p_quantity: int = 0) -> void:
		material_id = p_material_id
		quantity = p_quantity

# 工具数据
class ToolData extends RefCounted:
	var tool_type: int = ToolType.HOE
	var current_tier: int = ToolTier.COPPER
	var efficiency: float = 1.0
	var range: int = 1
	var energy_cost: int = 2

	func _init(p_type: int = ToolType.HOE, p_tier: int = ToolTier.COPPER) -> void:
		tool_type = p_type
		current_tier = p_tier
		_recalculate_stats()

	func _recalculate_stats() -> void:
		# 根据等级计算属性
		match current_tier:
			ToolTier.COPPER:
				efficiency = 1.0
				range = 1
				energy_cost = 2
			ToolTier.IRON:
				efficiency = 1.5
				range = 1
				energy_cost = 2
			ToolTier.GOLD:
				efficiency = 2.0
				range = 2
				energy_cost = 1
			ToolTier.DIAMOND:
				efficiency = 3.0
				range = 3
				energy_cost = 1

	func get_tier_name() -> String:
		return ToolTier.keys()[current_tier]

	func get_type_name() -> String:
		return ToolType.keys()[tool_type]

	func to_dict() -> Dictionary:
		return {
			"tool_type": tool_type,
			"current_tier": current_tier,
			"efficiency": efficiency,
			"range": range,
			"energy_cost": energy_cost
		}

	static func from_dict(data: Dictionary) -> ToolData:
		var tool := ToolData.new(data.get("tool_type", ToolType.HOE), data.get("current_tier", ToolTier.COPPER))
		tool.efficiency = data.get("efficiency", 1.0)
		tool.range = data.get("range", 1)
		tool.energy_cost = data.get("energy_cost", 2)
		return tool

# 升级配置
const UPGRADE_REQUIREMENTS: Dictionary = {
	# 从铜升级到铁的需求
	ToolTier.COPPER: {
		"materials": [
			{"material_id": "iron_ingot", "quantity": 5},
			{"material_id": "gold_coins", "quantity": 500}
		],
		"shop_required": "blacksmith"
	},
	# 从铁升级到金的需求
	ToolTier.IRON: {
		"materials": [
			{"material_id": "gold_ingot", "quantity": 5},
			{"material_id": "gold_coins", "quantity": 1500}
		],
		"shop_required": "blacksmith"
	},
	# 从金升级到钻石的需求
	ToolTier.GOLD: {
		"materials": [
			{"material_id": "diamond", "quantity": 3},
			{"material_id": "gold_coins", "quantity": 5000}
		],
		"shop_required": "blacksmith"
	}
}

# 效率提升配置
const TIER_EFFICIENCY: Dictionary = {
	ToolTier.COPPER: 1.0,
	ToolTier.IRON: 1.5,
	ToolTier.GOLD: 2.0,
	ToolTier.DIAMOND: 3.0
}

# 范围扩大配置
const TIER_RANGE: Dictionary = {
	ToolTier.COPPER: 1,
	ToolTier.IRON: 1,
	ToolTier.GOLD: 2,
	ToolTier.DIAMOND: 3
}

# 体力消耗配置
const TIER_ENERGY_COST: Dictionary = {
	ToolTier.COPPER: 2,
	ToolTier.IRON: 2,
	ToolTier.GOLD: 1,
	ToolTier.DIAMOND: 1
}

# 玩家工具数据
var _player_tools: Dictionary = {}
var _inventory: Inventory = null

func _ready() -> void:
	_initialize_tools()
	print("[ToolUpgrade] Tool upgrade system initialized")

## 初始化所有工具为基础铜级
func _initialize_tools() -> void:
	for tool_type in ToolType.values():
		_player_tools[tool_type] = ToolData.new(tool_type, ToolTier.COPPER)

## 设置背包引用
func set_inventory(inventory: Inventory) -> void:
	_inventory = inventory

## 获取工具数据
func get_tool_data(tool_type: int) -> ToolData:
	return _player_tools.get(tool_type, null)

## 获取所有工具数据
func get_all_tools() -> Dictionary:
	return _player_tools.duplicate()

## 获取工具等级名称
func get_tier_name(tier: int) -> String:
	return ToolTier.keys()[tier]

## 获取工具类型名称
func get_type_name(tool_type: int) -> String:
	return ToolType.keys()[tool_type]

## 获取下一等级
func get_next_tier(current_tier: int) -> int:
	match current_tier:
		ToolTier.COPPER:
			return ToolTier.IRON
		ToolTier.IRON:
			return ToolTier.GOLD
		ToolTier.GOLD:
			return ToolTier.DIAMOND
		_:
			return -1  # 已是最高等级

## 获取升级需求
func get_upgrade_requirements(current_tier: int) -> Array:
	var requirements: Array = []

	var tier_config: Dictionary = UPGRADE_REQUIREMENTS.get(current_tier, {})
	var materials: Array = tier_config.get("materials", [])

	for mat in materials:
		requirements.append(UpgradeRequirement.new(mat.material_id, mat.quantity))

	return requirements

## 获取升级费用
func get_upgrade_cost(current_tier: int) -> int:
	var tier_config: Dictionary = UPGRADE_REQUIREMENTS.get(current_tier, {})
	var materials: Array = tier_config.get("materials", [])

	for mat in materials:
		if mat.material_id == "gold_coins":
			return mat.quantity

	return 0

## 检查是否可以升级
func can_upgrade(tool_type: int) -> Dictionary:
	var result := {
		"can_upgrade": false,
		"reason": "",
		"missing_materials": [],
		"next_tier": -1
	}

	var tool := get_tool_data(tool_type)
	if tool == null:
		result.reason = "tool_not_found"
		return result

	var next_tier := get_next_tier(tool.current_tier)
	if next_tier == -1:
		result.reason = "max_tier_reached"
		return result

	result.next_tier = next_tier

	# 检查材料需求
	var requirements := get_upgrade_requirements(tool.current_tier)
	var missing: Array = []

	for req in requirements:
		if _inventory == null or not _inventory.has_item(req.material_id, req.quantity):
			missing.append({
				"material_id": req.material_id,
				"required": req.quantity,
				"available": _inventory.get_item_count(req.material_id) if _inventory else 0
			})

	if missing.size() > 0:
		result.reason = "insufficient_materials"
		result.missing_materials = missing
		return result

	result.can_upgrade = true
	return result

## 执行工具升级
func upgrade_tool(tool_type: int) -> bool:
	var check := can_upgrade(tool_type)

	if not check.can_upgrade:
		upgrade_failed.emit(tool_type, check.reason)
		if check.reason == "insufficient_materials":
			var missing_dict: Dictionary = {}
			var available_dict: Dictionary = {}
			for mat in check.missing_materials:
				missing_dict[mat.material_id] = mat.required
				available_dict[mat.material_id] = mat.available
			materials_insufficient.emit(missing_dict, available_dict)
		return false

	var tool := get_tool_data(tool_type)
	if tool == null:
		return false

	# 消耗材料
	var requirements := get_upgrade_requirements(tool.current_tier)
	for req in requirements:
		if _inventory:
			_inventory.remove_item(req.material_id, req.quantity)

	# 升级工具
	var old_tier := tool.current_tier
	tool.current_tier = check.next_tier
	tool._recalculate_stats()

	# 发射升级成功信号
	tool_upgraded.emit(tool_type, tool.current_tier)

	print("[ToolUpgrade] Upgraded %s from %s to %s" % [
		get_type_name(tool_type),
		get_tier_name(old_tier),
		get_tier_name(tool.current_tier)
	])

	return true

## 获取升级效果描述
func get_upgrade_effect_description(current_tier: int, next_tier: int) -> String:
	var current_eff: float = TIER_EFFICIENCY.get(current_tier, 1.0)
	var next_eff: float = TIER_EFFICIENCY.get(next_tier, 1.0)

	var current_range: int = TIER_RANGE.get(current_tier, 1)
	var next_range: int = TIER_RANGE.get(next_tier, 1)

	var current_energy: int = TIER_ENERGY_COST.get(current_tier, 2)
	var next_energy: int = TIER_ENERGY_COST.get(next_tier, 2)

	var desc := "升级效果:\n"

	if next_eff > current_eff:
		desc += "- 效率: %.1fx -> %.1fx\n" % [current_eff, next_eff]

	if next_range > current_range:
		desc += "- 范围: %d格 -> %d格\n" % [current_range, next_range]

	if next_energy < current_energy:
		desc += "- 体力消耗: %d -> %d\n" % [current_energy, next_energy]

	return desc

## 获取升级所需商店
func get_required_shop(tier: int) -> String:
	var tier_config: Dictionary = UPGRADE_REQUIREMENTS.get(tier, {})
	return tier_config.get("shop_required", "blacksmith")

## 保存数据
func save_state() -> Dictionary:
	var data := {}
	for tool_type in _player_tools:
		var tool: ToolData = _player_tools[tool_type]
		data[str(tool_type)] = tool.to_dict()
	return data

## 加载数据
func load_state(data: Dictionary) -> void:
	_initialize_tools()

	for key in data:
		var tool_type := int(key)
		if _player_tools.has(tool_type):
			var tool: ToolData = _player_tools[tool_type]
			var tool_data: Dictionary = data[key]
			tool.current_tier = tool_data.get("current_tier", ToolTier.COPPER)
			tool._recalculate_stats()

	print("[ToolUpgrade] Loaded tool data for %d tools" % data.size())
