# 🎮 田园物语 (Pastoral Tales) - 架构文档

## 1. 项目概述

### 1.1 游戏定位
- **类型**：2D 像素风农场模拟 RPG
- **风格**：类似星露谷物语 (Stardew Valley)
- **平台**：PC (Windows/Mac/Linux)
- **引擎**：Godot 4.x

### 1.2 核心玩法循环
```
早晨起床 → 查看天气/日历 → 农场工作(浇水/种植/收获) 
    → 探索/社交/任务 → 夜晚回家 → 睡觉存档 → 新的一天
```

## 2. 技术架构

### 2.1 技术栈

| 层级 | 技术 | 版本 | 说明 |
|------|------|------|------|
| 游戏引擎 | Godot | 4.2+ | 开源、轻量、GDScript |
| 脚本语言 | GDScript | - | Python-like，Godot原生 |
| 数据存储 | JSON + SQLite | - | 配置数据 + 玩家存档 |
| 版本控制 | Git | - | 代码管理 |
| 美术风格 | Pixel Art | 16x16/32x32 | 复古像素风格 |

### 2.2 项目目录结构

```
pastoral-tales/
├── 📁 assets/                    # 游戏资源
│   ├── 📁 sprites/              # 精灵图
│   │   ├── 📁 characters/       # 角色 (玩家、NPC)
│   │   ├── 📁 crops/            # 作物
│   │   ├── 📁 items/            # 物品
│   │   ├── 📁 tools/            # 工具
│   │   └── 📁 animals/          # 动物
│   ├── 📁 tiles/                # 瓦片地图
│   │   ├── 📁 farm/             # 农场地块
│   │   ├── 📁 village/          # 村庄
│   │   ├── 📁 indoors/          # 室内
│   │   └── 📁 nature/           # 自然环境
│   ├── 📁 ui/                   # UI资源
│   │   ├── 📁 icons/            # 图标
│   │   ├── 📁 panels/           # 面板
│   │   └── 📁 fonts/            # 字体
│   ├── 📁 audio/                # 音频
│   │   ├── 📁 bgm/              # 背景音乐
│   │   ├── 📁 sfx/              # 音效
│   │   └── 📁 ambient/          # 环境音
│   └── 📁 animations/           # 动画资源
│
├── 📁 src/                      # 源代码
│   ├── 📁 autoload/             # 全局单例 (AutoLoad)
│   │   ├── GameManager.gd       # 游戏主管理器
│   │   ├── SaveManager.gd       # 存档管理
│   │   ├── TimeManager.gd       # 时间系统
│   │   ├── EventBus.gd          # 事件总线
│   │   ├── AudioManager.gd      # 音频管理
│   │   └── InputManager.gd      # 输入管理
│   │
│   ├── 📁 core/                 # 核心系统
│   │   ├── 📁 time/             # 时间季节
│   │   │   ├── DayCycle.gd      # 昼夜循环
│   │   │   ├── SeasonSystem.gd  # 季节系统
│   │   │   └── Calendar.gd      # 日历
│   │   ├── 📁 inventory/        # 背包系统
│   │   │   ├── Inventory.gd     # 背包数据
│   │   │   ├── ItemDatabase.gd  # 物品数据库
│   │   │   └── Equipment.gd     # 装备系统
│   │   ├── 📁 farming/          # 种植系统
│   │   │   ├── Crop.gd          # 作物实体
│   │   │   ├── Soil.gd          # 土壤地块
│   │   │   ├── GrowthSystem.gd  # 生长系统
│   │   │   └── FarmingManager.gd # 农场管理
│   │   ├── 📁 relationship/     # 社交系统
│   │   │   ├── Friendship.gd    # 好感度
│   │   │   ├── DialogueSystem.gd # 对话
│   │   │   └── GiftSystem.gd    # 送礼
│   │   ├── 📁 economy/          # 经济系统
│   │   │   ├── MoneySystem.gd   # 货币
│   │   │   ├── ShopSystem.gd    # 商店
│   │   │   └── PriceManager.gd  # 价格管理
│   │   └── 📁 weather/          # 天气系统
│   │       ├── Weather.gd       # 天气状态
│   │       └── WeatherForecast.gd # 天气预报
│   │
│   ├── 📁 entities/             # 游戏实体
│   │   ├── 📁 player/           # 玩家
│   │   │   ├── Player.gd        # 玩家主体
│   │   │   ├── PlayerMovement.gd # 移动控制
│   │   │   ├── PlayerAnimation.gd # 动画控制
│   │   │   ├── PlayerStats.gd   # 属性 (体力/健康)
│   │   │   └── PlayerInteraction.gd # 交互
│   │   ├── 📁 npc/              # NPC
│   │   │   ├── NPC.gd           # NPC基础
│   │   │   ├── NPCSchedule.gd   # 日程AI
│   │   │   ├── NPCDialogue.gd   # 对话
│   │   │   └── NPCAnimation.gd  # 动画
│   │   ├── 📁 animals/          # 动物
│   │   │   ├── Animal.gd        # 动物基础
│   │   │   ├── Chicken.gd       # 鸡
│   │   │   ├── Cow.gd           # 牛
│   │   │   └── AnimalAI.gd      # 动物AI
│   │   └── 📁 tools/            # 工具
│   │       ├── Tool.gd          # 工具基础
│   │       ├── Hoe.gd           # 锄头
│   │       ├── WateringCan.gd   # 水壶
│   │       └── Axe.gd           # 斧头
│   │
│   ├── 📁 world/                # 世界
│   │   ├── 📁 maps/             # 地图场景
│   │   │   ├── Farm.tscn        # 农场
│   │   │   ├── Village.tscn     # 村庄
│   │   │   ├── Mine.tscn        # 矿洞
│   │   │   ├── Forest.tscn      # 森林
│   │   │   ├── Beach.tscn       # 海滩
│   │   │   └── PlayerHouse.tscn # 玩家房屋
│   │   ├── 📁 lighting/         # 光照
│   │   │   └── DayNightLighting.gd
│   │   └── 📁 transitions/      # 场景切换
│   │       └── SceneTransition.gd
│   │
│   └── 📁 ui/                   # 用户界面
│       ├── 📁 hud/              # 主界面
│       │   ├── HUD.gd           # HUD主控
│       │   ├── TimeDisplay.gd   # 时间显示
│       │   ├── EnergyBar.gd     # 体力条
│       │   └── MoneyDisplay.gd  # 金钱显示
│       ├── 📁 menus/            # 菜单
│       │   ├── MainMenu.gd      # 主菜单
│       │   ├── PauseMenu.gd     # 暂停菜单
│       │   ├── InventoryUI.gd   # 背包界面
│       │   └── ShopUI.gd        # 商店界面
│       ├── 📁 dialogs/          # 对话框
│       │   ├── DialogueBox.gd   # 对话盒子
│       │   └── ChoiceDialog.gd  # 选择对话框
│       └── 📁 notifications/    # 通知
│           └── Notification.gd  # 通知系统
│
├── 📁 data/                     # 数据配置 (JSON)
│   ├── items.json               # 物品数据
│   ├── crops.json               # 作物数据
│   ├── recipes.json             # 配方数据
│   ├── npcs.json                # NPC数据
│   ├── dialogues.json           # 对话数据
│   ├── shops.json               # 商店数据
│   └── festivals.json           # 节日数据
│
├── 📁 docs/                     # 文档
│   ├── architecture.md          # 架构文档
│   ├── api-reference.md         # API参考
│   └── design-doc.md            # 设计文档
│
├── 📁 tests/                    # 测试
│   └── unit/                    # 单元测试
│
└── 📄 project.godot             # Godot项目文件
```

## 3. 核心系统设计

### 3.1 时间系统 (Time System)

```gdscript
# 核心参数
const REAL_SECONDS_PER_GAME_MINUTE = 0.7  # 现实1秒 = 游戏1分钟
const GAME_HOURS_PER_DAY = 20              # 游戏一天20小时 (6:00-2:00)
const DAYS_PER_SEASON = 28                 # 每季28天
const SEASONS = ["Spring", "Summer", "Fall", "Winter"]

# 状态
current_time: float      # 当前时间 (0.0 - 24.0)
current_day: int         # 当前日期 (1-28)
current_season: int      # 当前季节 (0-3)
current_year: int        # 当前年份
is_paused: bool          # 是否暂停
```

### 3.2 种植系统 (Farming System)

```gdscript
# 土壤状态
class Soil:
    is_tilled: bool      # 是否耕地
    is_watered: bool     # 是否浇水
    crop: Crop           # 种植的作物
    fertilizer: int      # 肥料类型

# 作物生长
class Crop:
    crop_id: String      # 作物ID
    growth_stage: int    # 生长阶段 (0-4)
    days_in_stage: int   # 当前阶段天数
    quality: int         # 品质 (0-3)
    is_dead: bool        # 是否枯萎
```

### 3.3 背包系统 (Inventory System)

```gdscript
# 背包格子
const MAX_SLOTS = 36     # 最大格子数
const MAX_STACK = 999    # 最大堆叠数

class InventorySlot:
    item: Item           # 物品
    quantity: int        # 数量

# 物品类型
enum ItemType {
    SEED, CROP, TOOL, 
    FOOD, RESOURCE, FISH,
    DECORATION, QUEST
}
```

### 3.4 社交系统 (Relationship System)

```gdscript
# 好感度
class Friendship:
    npc_id: String
    hearts: int          # 心数 (0-10)
    points: int          # 具体点数 (0-2500)
    
# 对话系统
class Dialogue:
    dialogue_id: String
    text: String
    choices: Array       # 选项
    conditions: Array    # 触发条件
```

## 4. 数据配置规范

### 4.1 items.json 结构
```json
{
  "items": [
    {
      "id": "turnip_seed",
      "name": "芜菁种子",
      "type": "seed",
      "season": ["spring"],
      "buy_price": 20,
      "sell_price": 10,
      "description": "春天播种，4天成熟",
      "icon": "res://assets/sprites/items/turnip_seed.png"
    }
  ]
}
```

### 4.2 crops.json 结构
```json
{
  "crops": [
    {
      "id": "turnip",
      "name": "芜菁",
      "seed_id": "turnip_seed",
      "growth_days": [1, 1, 1, 1],
      "season": ["spring"],
      "regrow": false,
      "stages_sprites": [
        "crop_turnip_0.png",
        "crop_turnip_1.png",
        "crop_turnip_2.png",
        "crop_turnip_3.png",
        "crop_turnip_4.png"
      ]
    }
  ]
}
```

## 5. 开发规则 (Architecture Rules)

### 5.1 代码规范
- 使用 GDScript，遵循 GDQuest 风格指南
- 所有系统类使用 AutoLoad 全局单例
- 信号 (Signal) 用于组件间通信
- 避免循环依赖

### 5.2 资源命名
- 场景文件: `PascalCase.tscn`
- 脚本文件: `PascalCase.gd`
- 资源文件: `snake_case.png`
- 常量: `UPPER_SNAKE_CASE`

### 5.3 数据驱动
- 所有配置数据使用 JSON
- 游戏逻辑与数据分离
- 支持运行时热重载配置

### 5.4 测试要求
- 每个核心系统需有基础测试
- 存档系统必须100%可靠
