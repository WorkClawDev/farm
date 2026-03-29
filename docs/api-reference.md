# 📚 API 参考文档

## 全局单例 (AutoLoad)

### GameManager
游戏主管理器，控制游戏状态。

```gdscript
# 信号
signal game_started
signal game_paused
signal game_resumed

# 方法
func start_game() -> void
func pause_game() -> void
func resume_game() -> void
func save_game(slot: int = 0) -> bool
func load_game(slot: int = 0) -> bool

# 属性
var is_game_active: bool = false
var current_scene: String = ""
```

### TimeManager
时间管理器，控制游戏内时间流逝。

```gdscript
# 信号
signal time_changed(new_time: float)
signal hour_changed(new_hour: int)
signal day_changed(new_day: int)
signal season_changed(new_season: int, season_name: String)
signal year_changed(new_year: int)

# 方法
func pause_time() -> void
func resume_time() -> void
func set_time_scale(scale: float) -> void
func get_season_name() -> String
func get_formatted_time() -> String
func get_formatted_date() -> String

# 属性
var current_time: float = 6.0      # 0-24
var current_day: int = 1           # 1-28
var current_season: int = 0        # 0-3
var current_year: int = 1
var is_paused: bool = false
```

### Inventory
背包系统，管理玩家物品。

```gdscript
# 信号
signal inventory_changed()
signal slot_changed(index: int)
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)

# 方法
func add_item(item_id: String, quantity: int = 1) -> bool
func remove_item(item_id: String, quantity: int = 1) -> bool
func has_item(item_id: String, quantity: int = 1) -> bool
func get_item_count(item_id: String) -> int
func get_slot(index: int) -> InventorySlot
func get_selected_item_id() -> String

# 常量
const MAX_SLOTS: int = 36
const MAX_STACK: int = 999
const HOTBAR_SIZE: int = 9
```

### ItemDatabase
物品数据库，从JSON加载物品数据。

```gdscript
# 方法
func get_item(item_id: String) -> ItemData
func has_item(item_id: String) -> bool
func get_all_item_ids() -> Array
func get_items_by_type(type: int) -> Array

# 枚举
enum ItemType { SEED, CROP, TOOL, FOOD, RESOURCE, FISH, DECORATION, QUEST }
```

### MoneySystem
货币系统。

```gdscript
# 信号
signal money_changed(amount: int, delta: int)

# 方法
func add_money(amount: int) -> void
func spend_money(amount: int) -> bool
func get_money() -> int
func can_afford(amount: int) -> bool
```

### QuestSystem
任务系统。

```gdscript
# 信号
signal quest_accepted(quest_id: String)
signal quest_progress_updated(quest_id: String, objective_index: int, current: int, required: int)
signal quest_completed(quest_id: String)
signal quest_turned_in(quest_id: String, rewards: Dictionary)

# 方法
func accept_quest(quest_id: String) -> bool
func can_accept_quest(quest_id: String) -> bool
func get_available_quests() -> Array[QuestData]
func get_active_quests() -> Array[QuestData]
func get_quest(quest_id: String) -> QuestData
func get_quest_state(quest_id: String) -> QuestState
func update_objective_progress(quest_id: String, objective_index: int, amount: int = 1) -> void
func turn_in_quest(quest_id: String) -> bool

# 枚举
enum QuestState { LOCKED, AVAILABLE, ACTIVE, COMPLETED, TURNED_IN, FAILED }
enum ObjectiveType { COLLECT, DELIVER, TALK_TO, GIFT_TO, REACH_HEARTS, VISIT, HARVEST, FISH, MINE, CUSTOM }
```

### NPCManager
NPC管理器。

```gdscript
# 信号
signal npc_spawned(npc_id: String, npc: NPC)
signal npc_despawned(npc_id: String)
signal npc_location_changed(npc_id: String, location_id: String)

# 方法
func set_current_scene(scene: Node2D) -> void
func get_npc(npc_id: String) -> NPC
func get_all_spawned_npcs() -> Dictionary
func update_npc_positions() -> void
```

### DialogueManager
对话管理器。

```gdscript
# 信号
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal choice_made(choice_index: int, choice_data: Dictionary)

# 方法
func start_dialogue(npc_id: String, dialogue_key: String = "") -> bool
func set_dialogue_box(dialogue_box: DialogueBox) -> void
func add_friendship_points(npc_id: String, points: int) -> void
func get_friendship_hearts(npc_id: String) -> int
func set_flag(key: String, value: Variant) -> void
func get_flag(key: String, default: Variant = false) -> Variant
```

### EventBus
事件总线，全局事件系统。

```gdscript
# 游戏事件
signal game_started, game_paused, game_resumed, game_saved, game_loaded

# 时间事件
signal day_started, day_ended, hour_changed(hour: int), season_changed(season: int, season_name: String)

# 玩家事件
signal player_moved(position: Vector2), player_interacted(target: Node)
signal energy_changed(current: int, maximum: int), money_changed(amount: int, delta: int)

# 农场事件
signal crop_planted(crop_type: String, position: Vector2)
signal crop_harvested(crop_type: String, quality: int, quantity: int)
signal soil_watered(position: Vector2)

# 背包事件
signal item_added(item_id: String, quantity: int), item_removed(item_id: String, quantity: int)

# 社交事件
signal npc_interacted(npc: Node), dialogue_started(npc_id: String), dialogue_ended(npc_id: String)
signal friendship_changed(npc_id: String, hearts: int), gift_given(npc_id: String, item_id: String, reaction: int)

# 商店事件
signal shop_opened(shop_id: String), shop_closed
signal item_bought(item_id: String, price: int), item_sold(item_id: String, price: int)

# 任务事件
signal quest_accepted(quest_id: String), quest_completed(quest_id: String), quest_turned_in(quest_id: String, rewards: Dictionary)

# 钓鱼事件
signal fishing_started(location: String), fishing_ended(success: bool, fish_id: String, fish_size: int)
signal fish_hooked(fish_id: String, fish_name: String), fish_caught(fish_id: String, fish_size: int, quality: int)
```

---

## 核心系统

### GrowthSystem (种植系统)

```gdscript
# 方法
func get_crop_data(crop_id: String) -> CropData
func can_plant_in_current_season(crop_id: String) -> bool
func get_seasonal_crops() -> Array
func register_crop(crop: Crop) -> void
func harvest_crop(crop: Crop) -> Dictionary
func update_all_crops() -> int
```

### PlantingManager (种植管理器)

```gdscript
# 方法
func try_plant(seed_id: String, soil: Soil) -> bool
func get_crop_id_for_seed(seed_id: String) -> String
func get_available_seeds() -> Array
func can_plant_seed_now(seed_id: String) -> bool
```

### CookingSystem (烹饪系统)

```gdscript
# 方法
func load_recipes() -> bool
func get_recipe(recipe_id: String) -> RecipeData
func get_all_recipes() -> Array
func get_learned_recipes() -> Array
func learn_recipe(recipe_id: String) -> bool
func can_cook(recipe_id: String) -> Dictionary
func cook(recipe_id: String) -> bool
```

---

## 实体类

### Player (玩家)

```gdscript
# 属性
@export var speed: float = 150.0
var current_direction: Direction
var is_walking: bool = false
var npc_in_range: NPC = null
var tool_manager: ToolManager = null

# 方法
func set_spawn_position(pos: Vector2) -> void
func take_damage(damage: int, source: Node = null) -> void
func heal(amount: int) -> void
func get_current_health() -> int
func get_max_health() -> int
```

### NPC

```gdscript
# 属性
@export var npc_id: String = "npc_001"
@export var npc_name: String = "NPC"
@export var move_speed: float = 80.0
@export var interactable: bool = true
var current_direction: Direction
var is_walking: bool = false
var is_interacting: bool = false

# 方法
func move_to(target: Vector2) -> void
func face_position(target_pos: Vector2) -> void
func start_interaction() -> void
func end_interaction() -> void
func can_interact() -> bool
func get_friendship_hearts() -> int
func is_birthday() -> bool
```

### Soil (土壤)

```gdscript
# 枚举
enum State { UNTILLED, TILLED, WATERED }

# 属性
@export var current_state: State = State.UNTILLED
@export var max_moisture: int = 100
var moisture: int = 0
var crop: Node2D = null
var fertilizer_type: int = 0

# 方法
func till() -> bool
func water(amount: int = 50) -> bool
func can_plant() -> bool
func can_till() -> bool
func can_water() -> bool
func has_sufficient_moisture() -> bool
func get_moisture_percentage() -> float
```

### Crop (作物)

```gdscript
# 枚举
enum State { SEED, GROWING, MATURE, DEAD }

# 属性
var crop_data: CropData = null
var crop_id: String = ""
var current_stage: int = 0
var days_in_stage: int = 0
var total_days_grown: int = 0
var quality: CropData.Quality = CropData.Quality.NORMAL
var current_state: State = State.SEED

# 方法
func setup(data: CropData, pos: Vector2, fertilizer: int = 0) -> void
func on_day_passed() -> void
func water() -> void
func harvest() -> Dictionary
func can_harvest() -> bool
func is_dead() -> bool
```

---

## 工具类

### ToolManager

```gdscript
# 枚举
enum ToolType { NONE, HOE, WATERING_CAN, AXE, PICKAXE, SICKLE, FISHING_ROD }

# 信号
signal tool_changed(new_tool: ToolType, tool_name: String)
signal tool_used(tool_type: ToolType, success: bool)

# 方法
func initialize(player_ref: CharacterBody2D) -> void
func equip_tool(tool_type: ToolType) -> void
func use_tool(target: Node = null) -> bool
func next_tool() -> void
func previous_tool() -> void
func get_current_tool() -> Node
func get_current_tool_type() -> ToolType
```

### FishingRod

```gdscript
# 枚举
enum FishingState { IDLE, CASTING, WAITING, HOOKED, MINIGAME, CATCHING, REELING }

# 信号
signal fishing_started
signal fishing_ended(success: bool, fish_id: String, size: int)
signal fish_hooked(fish_data: Dictionary)
signal catch_progress_changed(progress: float)

# 方法
func use(target_position: Vector2, location_type: String = "lake") -> bool
func cancel_fishing() -> void
func get_state_name() -> String
```

---

## UI 类

### DialogueBox

```gdscript
# 信号
signal dialogue_finished
signal choice_selected(choice_index: int)

# 方法
func show_dialogue_advanced(dialogue_data: Dictionary) -> void
func show_dialogue(speaker: String, text: String, choices: Array = []) -> void
func hide_dialogue() -> void
func display_next_line() -> void
```

### SeedShopUI

```gdscript
# 信号
signal shop_closed
signal item_bought(item_id: String, quantity: int, total_price: int)

# 方法
func open_shop() -> void
func _setup_shop_items() -> void
func _on_buy_button_pressed() -> void
func _on_close_button_pressed() -> void
```

### QuestTracker

```gdscript
# 方法
func _refresh_quest_list() -> void
func _create_quest_item(quest: QuestSystem.QuestData) -> Control
func _update_quest_item(quest_id: String) -> void
func toggle_visibility() -> void
```

---

## 数据格式

### 物品数据 (items.json)

```json
{
  "id": "turnip_seed",
  "name": "芜菁种子",
  "type": "seed",
  "seasons": ["spring"],
  "growth_days": 4,
  "crop_id": "turnip",
  "buy_price": 20,
  "sell_price": 10,
  "description": "春天播种，4天成熟"
}
```

### 作物数据 (crops.json)

```json
{
  "id": "turnip",
  "name": "芜菁",
  "seed_id": "turnip_seed",
  "growth_days": [1, 1, 1, 1],
  "season": ["Spring"],
  "regrow": false,
  "stages_sprites": [...],
  "sell_price": 35,
  "exp": 8
}
```

### 配方数据 (recipes.json)

```json
{
  "id": "fried_egg",
  "name": "煎蛋",
  "ingredients": [{"item_id": "egg", "quantity": 1}],
  "result_item": "fried_egg",
  "result_quantity": 1,
  "cooking_time": 0.5,
  "energy_cost": 3,
  "effects": {"energy": 35}
}
```

### NPC数据 (npcs.json)

```json
{
  "id": "mayor",
  "name": "镇长·威廉",
  "default_location": "village",
  "birthday": {"season": "Spring", "day": 14},
  "personality": "friendly",
  "gift_preferences": {
    "love": ["flower_spring", "cheese"],
    "like": ["bread", "wood"],
    "dislike": ["fiber"]
  },
  "schedule": [...]
}
```

### 对话数据 (dialogues.json)

```json
{
  "npc_id": "mayor",
  "dialogues": {
    "greeting": {
      "id": "mayor_greeting",
      "priority": 0,
      "conditions": [],
      "lines": [
        {"speaker": "镇长托马斯", "text": "欢迎来到我们美丽的村庄！"}
      ]
    }
  }
}
```

---

## 输入映射

| 按键 | 功能 |
|------|------|
| WASD / 方向键 | 移动 |
| E / 空格 | 交互/使用工具 |
| I | 打开背包 |
| ESC | 暂停菜单 |
| 1-6 | 快速选择工具 |
| Q | 切换到上一个工具 |
| E | 切换到下一个工具 |

---

## 图层设置

| 图层 | 用途 |
|------|------|
| Layer 1 | World (世界) |
| Layer 2 | Player (玩家) |
| Layer 3 | NPC |
| Layer 4 | Items (物品) |
| Layer 5 | Crops (作物) |
