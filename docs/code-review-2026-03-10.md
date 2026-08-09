# 代码审查报告 - 田园物语
**日期:** 2026-03-10  
**审查范围:** Player.gd, Soil.gd, Crop.gd, PlantingManager.gd, Farm.gd, ToolManager.gd  
**审查者:** GameBoy (AI Architecture)

---

## 🔴 高优先级修复

### 1. Player.gd - 工具切换输入未调用

**问题:** `_handle_tool_input()` 函数已定义但从未在 `_physics_process` 中调用，导致玩家无法切换工具。

**修复位置:** `src/entities/player/Player.gd` 第 ~80 行

**修复代码:**
```gdscript
func _physics_process(_delta: float) -> void:
    # 获取输入方向
    var input_direction := _get_input_direction()

    # 更新速度
    velocity = input_direction * speed

    # 更新方向和动画
    _update_direction(input_direction)
    _update_animation()

    # 移动
    move_and_slide()

    # 处理NPC交互
    _handle_interaction()

    # 处理战斗输入
    _handle_combat_input()
    
    # 处理工具切换输入 - 添加这行
    _handle_tool_input()
```

---

### 2. Soil.gd - 硬编码 EventBus 路径（多处）

**问题:** 使用 `get_node("/root/EventBus")` 而不是安全的 `get_node_or_null`，节点不存在时会崩溃。

**修复位置:** `src/core/farming/Soil.gd`

**需要修复的行:**
- 第 ~95 行: `till()` 函数
- 第 ~115 行: `water()` 函数
- 第 ~140 行: `_process_daily_moisture()` 函数
- 第 ~155 行: `dry()` 函数
- 第 ~175 行: `plant_crop()` 函数
- 第 ~195 行: `_on_interaction_area_input_event()` 函数

**修复代码:**
```gdscript
## 耕地 - 使用锄头
func till() -> bool:
    if current_state != State.UNTILLED:
        print("[Soil] Cannot till - already tilled or watered")
        return false

    current_state = State.TILLED
    soil_tilled.emit(self)
    
    # 修复: 使用 get_node_or_null
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.crop_planted.emit("soil_tilled", global_position)
    
    print("[Soil] Tilled at ", grid_position)
    return true

## 浇水
func water(amount: int = 50) -> bool:
    if current_state == State.UNTILLED:
        print("[Soil] Cannot water - untilled soil")
        return false

    moisture += amount
    if current_state == State.TILLED:
        current_state = State.WATERED

    soil_watered.emit(self)
    
    # 修复: 使用 get_node_or_null
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.soil_watered.emit(global_position)
    
    print("[Soil] Watered at ", grid_position, ", moisture: ", moisture, "/", max_moisture)
    return true

## 处理每日水分消耗
func _process_daily_moisture() -> void:
    if current_state == State.UNTILLED:
        return

    moisture -= moisture_consumption_per_day

    if moisture <= 0:
        moisture = 0
        if current_state == State.WATERED:
            current_state = State.TILLED
            soil_dried.emit(self)
            
            # 修复: 使用 get_node_or_null
            var event_bus = get_node_or_null("/root/EventBus")
            if event_bus:
                event_bus.soil_dried.emit(global_position)
            
            print("[Soil] Dried at ", grid_position)

    _update_visual()

## 干燥
func dry() -> void:
    if current_state == State.WATERED:
        current_state = State.TILLED
        moisture = 0
        soil_dried.emit(self)
        
        # 修复: 使用 get_node_or_null
        var event_bus = get_node_or_null("/root/EventBus")
        if event_bus:
            event_bus.soil_dried.emit(global_position)
        
        print("[Soil] Dried at ", grid_position)

## 种植作物
func plant_crop(crop_scene: PackedScene, crop_id: String) -> bool:
    if current_state == State.UNTILLED:
        print("[Soil] Cannot plant - untilled soil")
        return false

    if crop != null:
        print("[Soil] Cannot plant - already has crop")
        return false

    var new_crop := crop_scene.instantiate()
    new_crop.global_position = global_position
    get_parent().add_child(new_crop)
    crop = new_crop

    crop_planted.emit(self, crop_id)
    
    # 修复: 使用 get_node_or_null
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.crop_planted.emit(crop_id, global_position)
    
    print("[Soil] Planted ", crop_id, " at ", grid_position)
    return true

# 交互事件处理
func _on_interaction_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        # 修复: 使用 get_node_or_null
        var event_bus = get_node_or_null("/root/EventBus")
        if event_bus:
            event_bus.player_interacted.emit(self)
```

---

### 3. Crop.gd - 季节检查可能崩溃

**问题:** `get_node("/root/TimeManager")` 如果节点不存在会崩溃。

**修复位置:** `src/core/farming/Crop.gd` 第 ~50 行

**修复代码:**
```gdscript
## 每日更新（由 GrowthSystem 调用）
func on_day_passed() -> void:
    if current_state == State.DEAD:
        return

    # 修复: 安全获取 TimeManager
    var time_manager = get_node_or_null("/root/TimeManager")
    
    # 检查是否在正确季节
    if crop_data and crop_data.dies_out_of_season:
        if time_manager:
            if not crop_data.can_grow_in_season(time_manager.get_season_name()):
                _die()
                return
        else:
            # 如果没有 TimeManager，假设季节合适
            pass

    # 检查是否需要浇水
    if crop_data and crop_data.requires_water and not is_watered:
        is_watered = false
        return

    _grow()
    is_watered = false
```

**同时修复第 ~75 行的 water() 函数:**
```gdscript
## 浇水
func water() -> void:
    is_watered = true
    _update_sprite()
    
    # 修复: 使用 get_node_or_null
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.soil_watered.emit(soil_position)
```

**同时修复第 ~145 行的 harvest() 函数:**
```gdscript
## 收获
func harvest() -> Dictionary:
    if current_state != State.MATURE:
        return {}

    var quantity: int = randi_range(crop_data.min_harvest, crop_data.max_harvest)

    crop_harvested.emit(crop_id, quality, quantity)
    
    # 修复: 使用 get_node_or_null
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.crop_harvested.emit(crop_id, quality, quantity)
    
    # ... 剩余代码不变
```

**同时修复第 ~210 行的 _load_crop_data() 函数:**
```gdscript
## 从数据库加载作物数据
func _load_crop_data() -> void:
    var growth_system = get_node_or_null("/root/GrowthSystem")
    if growth_system:
        crop_data = growth_system.get_crop_data(crop_id)
```

---

## 🟡 中优先级修复

### 4. Farm.gd - 重复的信号发射

**问题:** `_on_player_interacted` 函数最后又发射了一次 `player_interacted` 信号，可能导致循环。

**修复位置:** `src/world/maps/Farm.gd` 第 ~107 行

**修复代码:**
```gdscript
func _on_player_interacted(target: Node) -> void:
    # 处理玩家与土壤的交互
    if target is Soil:
        var soil := target as Soil
        
        # 如果土壤未耕地，使用锄头
        if soil.can_till():
            if hoe_tool:
                hoe_tool.use(soil)
        return
    
    # 删除这行重复的信号发射
    # get_node("/root/EventBus").player_interacted.emit(target)  # 删除此行
```

---

### 5. ToolManager.gd - 工具位置硬编码

**问题:** 工具位置固定为 `Vector2(16, 0)`，应该根据玩家方向调整。

**修复位置:** `src/entities/player/ToolManager.gd` 第 ~75 行

**修复代码:**
```gdscript
## 装备指定工具
func equip_tool(tool_type: ToolType) -> void:
    if tool_type == current_tool_type:
        return
    
    # 隐藏当前工具
    if current_tool_type != ToolType.NONE and tools.has(current_tool_type):
        tools[current_tool_type].visible = false
    
    current_tool_type = tool_type
    
    # 显示新工具 - 根据玩家方向调整位置
    if tool_type != ToolType.NONE and tools.has(tool_type):
        tools[tool_type].visible = true
        
        # 修复: 根据玩家方向调整工具位置
        var tool_offset = Vector2(16, 0)
        if player and player is Player:
            match player.current_direction:
                Player.Direction.LEFT: tool_offset = Vector2(-16, 0)
                Player.Direction.RIGHT: tool_offset = Vector2(16, 0)
                Player.Direction.UP: tool_offset = Vector2(0, -16)
                Player.Direction.DOWN: tool_offset = Vector2(0, 16)
        
        tools[tool_type].position = tool_offset
    
    tool_changed.emit(tool_type, _get_tool_name(tool_type))
    print("[ToolManager] Equipped: ", _get_tool_name(tool_type))
```

---

## 🟢 低优先级修复

### 6. PlantingManager.gd - 类型检查不明确

**问题:** 代码检查 `item_data.type == 0`，但 ItemType 枚举可能不匹配。

**修复位置:** `src/core/farming/PlantingManager.gd` 第 ~20 行

**修复代码:**
```gdscript
## 加载种子数据
func _load_seed_data() -> void:
    var item_database = get_node_or_null("/root/ItemDatabase")
    if item_database:
        # 获取 ItemType 枚举（假设在 ItemDatabase 中定义）
        const ItemType_SEED = 0  # 或者从 ItemDatabase 导入
        
        for item_id in item_database.get_all_item_ids():
            var item_data = item_database.get_item(item_id)
            # 修复: 使用明确的常量
            if item_data and item_data.type == ItemType_SEED:
                var crop_id = item_data.get("crop_id", "")
                if crop_id != "":
                    seed_to_crop[item_id] = crop_id
                    print("[PlantingManager] Registered seed: ", item_id, " -> ", crop_id)
```

---

## 📋 修复检查清单

修复完成后，请检查:

- [ ] Player.gd 中添加了 `_handle_tool_input()` 调用
- [ ] Soil.gd 中所有 `get_node("/root/EventBus")` 改为 `get_node_or_null`
- [ ] Crop.gd 中 `get_node("/root/TimeManager")` 改为 `get_node_or_null`
- [ ] Crop.gd 中 `get_node("/root/EventBus")` 改为 `get_node_or_null`
- [ ] Crop.gd 中 `get_node("/root/GrowthSystem")` 改为 `get_node_or_null`
- [ ] Farm.gd 中删除了重复的信号发射
- [ ] ToolManager.gd 中工具位置根据玩家方向调整
- [ ] PlantingManager.gd 中使用了明确的 ItemType 常量

---

## 🎮 测试建议

修复后请测试:

1. **工具切换**: 按数字键 1-6 和 Q/E 键能否正常切换工具
2. **耕地**: 装备锄头后按交互键能否耕地
3. **浇水**: 装备水壶后能否给土壤浇水
4. **种植**: 在耕好的土地上能否种植作物
5. **收获**: 作物成熟后能否收获
6. **季节变化**: 作物在错误季节是否会枯萎

---

## 💡 额外建议

### 添加日志级别控制（可选）
在主要脚本中添加日志级别控制，方便调试:

```gdscript
# 在脚本开头添加
const LOG_LEVEL = 2  # 0=错误, 1=警告, 2=信息, 3=调试

func _log(msg: String, level: int = 2) -> void:
    if level <= LOG_LEVEL:
        print(msg)
```

然后替换所有 `print` 调用为 `_log`。

---

**报告生成时间:** 2026-03-10 09:41  
**GameBoy** 🎮
