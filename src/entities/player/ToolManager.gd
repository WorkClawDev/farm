extends Node
class_name ToolManager

## ToolManager - 玩家工具管理器
## 管理玩家当前持有的工具，处理工具切换和使用

# 工具类型枚举
enum ToolType {
	NONE,
	HOE,           # 锄头
	WATERING_CAN,  # 水壶
	AXE,           # 斧头
	PICKAXE,       # 镐子
	SICKLE,        # 镰刀
	FISHING_ROD    # 鱼竿
}

# 当前工具类型。NONE 表示“收起工具、手里拿的是快捷栏选中的物品”（如种子）。
var current_tool_type: ToolType = ToolType.NONE

# 最近一次拿的工具：从“手持物品”按 Q/R 时先回到它。
var last_tool_type: ToolType = ToolType.HOE

# 工具实例
var tools: Dictionary = {}

# 工具场景路径
const TOOL_SCENES = {
	ToolType.HOE: "res://src/entities/tools/Hoe.tscn",
	ToolType.WATERING_CAN: "res://src/entities/tools/WateringCan.tscn",
	ToolType.AXE: "res://src/entities/tools/Axe.tscn",
	ToolType.PICKAXE: "res://src/entities/tools/Pickaxe.tscn",
	ToolType.SICKLE: "res://src/entities/tools/Sickle.tscn",
	ToolType.FISHING_ROD: "res://src/entities/tools/FishingRod.tscn"
}

# 信号
signal tool_changed(new_tool: ToolType, tool_name: String)
signal tool_used(tool_type: ToolType, success: bool)

# 玩家引用
var player: CharacterBody2D = null

func _ready() -> void:
	print("[ToolManager] Initialized")

## 初始化工具管理器
func initialize(player_ref: CharacterBody2D) -> void:
	player = player_ref
	_load_tools()
	# 默认选择锄头
	equip_tool(ToolType.HOE)

## 加载所有工具
func _load_tools() -> void:
	for tool_type in TOOL_SCENES.keys():
		var scene_path: String = TOOL_SCENES[tool_type]
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			var tool_instance = scene.instantiate()
			tools[tool_type] = tool_instance
			add_child(tool_instance)
			print("[ToolManager] Loaded tool: ", _get_tool_name(tool_type))
		else:
			push_warning("[ToolManager] Tool scene not found: " + scene_path)

## 装备指定工具
func equip_tool(tool_type: ToolType) -> void:
	if tool_type == current_tool_type:
		return
	
	# 隐藏当前工具
	if current_tool_type != ToolType.NONE and tools.has(current_tool_type):
		tools[current_tool_type].visible = false
	
	current_tool_type = tool_type
	if tool_type != ToolType.NONE:
		last_tool_type = tool_type
	
	# 显示新工具
	if tool_type != ToolType.NONE and tools.has(tool_type):
		tools[tool_type].visible = true
		
		# 根据玩家方向调整工具位置
		var tool_offset = Vector2(16, 0)
		if player and player.has_method("get"):
			var current_direction = player.get("current_direction")
			if current_direction != null:
				match current_direction:
					0: tool_offset = Vector2(0, 16)   # DOWN
					1: tool_offset = Vector2(0, -16)  # UP
					2: tool_offset = Vector2(-16, 0)  # LEFT
					3: tool_offset = Vector2(16, 0)   # RIGHT
		
		tools[tool_type].position = tool_offset
	
	tool_changed.emit(tool_type, _get_tool_name(tool_type))
	print("[ToolManager] Equipped: ", _get_tool_name(tool_type))

## 获取工具名称
func _get_tool_name(tool_type: ToolType) -> String:
	match tool_type:
		ToolType.HOE:
			return "锄头"
		ToolType.WATERING_CAN:
			return "水壶"
		ToolType.AXE:
			return "斧头"
		ToolType.PICKAXE:
			return "镐子"
		ToolType.SICKLE:
			return "镰刀"
		ToolType.FISHING_ROD:
			return "鱼竿"
		_:
			return "空手"

## 使用当前工具
func use_tool(target: Node = null) -> bool:
	if current_tool_type == ToolType.NONE:
		print("[ToolManager] No tool equipped")
		return false
	
	if not tools.has(current_tool_type):
		print("[ToolManager] Tool not available")
		return false
	
	var tool = tools[current_tool_type]
	var success = false
	
	# 根据工具类型调用不同的使用方式
	match current_tool_type:
		ToolType.HOE:
			if tool.has_method("use") and target is Soil:
				success = tool.use(target)
		
		ToolType.WATERING_CAN:
			# 只有真的对着可浇水的土壤才用水；对着空地/草地按空格不再白白扣水。
			# 农场地块走 Farm.perform_farm_action -> FarmState.water_with_can。
			if tool.has_method("use") and target is Soil and target.can_water():
				success = tool.use(_get_target_position())
				if success:
					target.water()
		
		ToolType.AXE, ToolType.PICKAXE, ToolType.SICKLE:
			if tool.has_method("use") and target != null:
				success = tool.use(target)
		
		ToolType.FISHING_ROD:
			if tool.has_method("use") and target != null:
				var location_type: String = str(target.get("location_type")) if "location_type" in target else "lake"
				success = tool.use(target.global_position, location_type)
	
	tool_used.emit(current_tool_type, success)
	return success

## 获取目标位置（玩家面向方向的一定距离）
func _get_target_position() -> Vector2:
	if player == null:
		return Vector2.ZERO
	
	var direction = Vector2.ZERO
	if player.has_method("get_direction"):
		direction = player.get_direction()
	else:
		# 默认向下
		direction = Vector2.DOWN
	
	return player.global_position + direction * 32.0

## 收起工具，改用快捷栏选中的物品（按数字键选物品时调用）
func put_away_tool() -> void:
	equip_tool(ToolType.NONE)

## 是否收起了工具（手持快捷栏物品）
func is_using_hotbar_item() -> bool:
	return current_tool_type == ToolType.NONE

## 切换到下一个工具
func next_tool() -> void:
	if current_tool_type == ToolType.NONE:
		equip_tool(last_tool_type)
		return
	var tool_list = [ToolType.HOE, ToolType.WATERING_CAN, ToolType.AXE, 
					 ToolType.PICKAXE, ToolType.SICKLE, ToolType.FISHING_ROD]
	var current_index = tool_list.find(current_tool_type)
	var next_index = (current_index + 1) % tool_list.size()
	equip_tool(tool_list[next_index])

## 切换到上一个工具
func previous_tool() -> void:
	if current_tool_type == ToolType.NONE:
		equip_tool(last_tool_type)
		return
	var tool_list = [ToolType.HOE, ToolType.WATERING_CAN, ToolType.AXE, 
					 ToolType.PICKAXE, ToolType.SICKLE, ToolType.FISHING_ROD]
	var current_index = tool_list.find(current_tool_type)
	var prev_index = (current_index - 1 + tool_list.size()) % tool_list.size()
	equip_tool(tool_list[prev_index])

## 获取当前工具
func get_current_tool() -> Node:
	if current_tool_type == ToolType.NONE:
		return null
	return tools.get(current_tool_type, null)

## 获取当前工具类型
func get_current_tool_type() -> ToolType:
	return current_tool_type

## 检查是否持有指定工具
func has_tool(tool_type: ToolType) -> bool:
	return tools.has(tool_type)

## 水壶水量统一由 FarmState 管理（跨场景、进存档），这里只是转发。
func consume_watering_charge() -> bool:
	if not FarmState.has_watering_charge():
		return false
	FarmState.set_watering_can_water(
		FarmState.get_watering_can_water() - FarmState.WATERING_CAN_WATER_PER_USE
	)
	return true

func has_watering_charge() -> bool:
	return FarmState.has_watering_charge()

## 装满水壶；返回 false 表示本来就是满的。
func refill_tools() -> bool:
	return FarmState.refill_watering_can()
