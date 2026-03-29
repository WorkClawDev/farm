# Pastoral Tales 重构任务清单

> 创建时间：2026-03-26
> 目标：拆分 EventBus、GameManager，统一代码规范

---

## 🔴 P1: 拆分 EventBus（上帝对象问题）

### P1-T1: 创建领域 EventBus 文件
**状态：** ⬜ 未开始
**优先级：** 最高

创建以下文件：
- `src/autoload/EventBusGame.gd` — 游戏状态事件（game_started/paused/resumed/saved/loaded）
- `src/autoload/EventBusFarm.gd` — 农场系统事件（crop_planted/grew/harvested/soil_watered/dried）
- `src/autoload/EventBusSocial.gd` — 社交/NPC 事件（npc_interacted/dialogue_started/friendship_changed/gift_given）
- `src/autoload/EventBusShop.gd` — 商店/经济事件（shop_opened/closed/item_bought/sold）
- `src/autoload/EventBusUI.gd` — UI 事件（ui_opened/closed/notification_shown）

### P1-T2: 迁移现有信号
**状态：** ⬜ 未开始
**依赖：** P1-T1

将 `EventBus.gd` 的 60+ 个信号迁移到对应领域文件。

### P1-T3: 更新所有调用方
**状态：** ⬜ 未开始
**依赖：** P1-T2

扫描所有 `.gd` 文件，将 `EventBus.xxx` 调用改为 `EventBusGame.xxx` / `EventBusFarm.xxx` 等。

### P1-T4: 保留兼容层（可选）
**状态：** ⬜ 未开始
**依赖：** P1-T3

创建 `EventBus.gd` 作为统一入口，内部转发到各子 EventBus，标记 `@deprecated`。

---

## 🔴 P2: 拆分 GameManager（职责过重）

### P2-T1: 创建 InventoryManager
**状态：** ⬜ 未开始
**优先级：** 高

从 `GameManager.gd` 提取：
- `add_item() / remove_item() / has_item() / get_item_quantity()`
- `get_inventory() / MAX_INVENTORY_SLOTS`
- `inventory_full` 信号

新建 `src/core/inventory/InventoryManager.gd`

### P2-T2: 创建 MoneyManager
**状态：** ⬜ 未开始
**依赖：** P2-T1

从 `GameManager.gd` 提取：
- `money` 变量
- `add_money() / spend_money()`
- `money_changed` 信号

新建 `src/core/economy/MoneyManager.gd`

### P2-T3: 创建 StaminaManager
**状态：** ⬜ 未开始
**依赖：** P2-T1

从 `GameManager.gd` 提取：
- `current_stamina / max_stamina`
- `use_stamina() / restore_stamina()`
- `stamina_changed` 信号

新建 `src/core/systems/StaminaManager.gd`

### P2-T4: 简化 GameManager
**状态：** ⬜ 未开始
**依赖：** P2-T1, P2-T2, P2-T3

GameManager 只保留：
- `current_state` (GameState enum)
- `is_game_active`
- `start_game() / pause_game() / resume_game()`
- `save_game() / load_game() / quit_game()`
- `register_player()`

### P2-T5: 更新所有调用方
**状态：** ⬜ 未开始
**依赖：** P2-T4

扫描所有 `.gd` 文件，更新对 GameManager 的调用。

---

## 🟡 P3: 统一异常处理规范

### P3-T1: 制定异常处理规范
**状态：** ⬜ 未开始

规范：
- `push_error()` — 游戏无法继续的错误
- `push_warning()` — 可恢复的异常
- `print()` — 仅用于调试日志（正式发布应移除或设为 debug）

### P3-T2: 扫描并修复 push_error 缺失
**状态：** ⬜ 未开始

扫描所有文件，找出应该用 `push_error` 但只用了 `print` 或 `push_warning` 的地方。

---

## 🟡 P4: Farm TileMap 化

### P4-T1: 分析 farm_tiles.png 结构
**状态：** ⬜ 未开始

用 image 分析工具获取 tile 种类、排列、尺寸。

### P4-T2: 创建 FarmTilesetBuilder
**状态：** ⬜ 未开始

参考 `VillageTilesetBuilder.gd`，创建 Farm 专用 TileSet 构建器。

### P4-T3: 重写 FarmBuilder
**状态：** ⬜ 未开始

参考 `VillageBuilder.gd`，用真实 tile 填充 Farm 地图。

### P4-T4: 移除 farm_layout.json 的 ColorRect
**状态：** ⬜ 未开始

将 `farm_layout.json` 的 rect 物体迁移到 TileMap。

---

## 🟡 P5: 消除魔法数字

### P5-T1: 提取常量到配置
**状态：** ⬜ 未开始

在 `src/core/constants/` 创建常量定义文件：
- `GameConstants.gd` — 游戏全局常量（地图尺寸、格子大小等）
- `FarmConstants.gd` — 农场相关常量
- `VillageConstants.gd` — 村庄相关常量

### P5-T2: 替换魔法数字
**状态：** ⬜ 未开始

扫描代码，将硬编码的数字替换为常量引用。

---

## 🟢 P6: 测试框架（长期）

### P6-T1: 安装 GUT 测试框架
**状态：** ⬜ 未开始

参考 Godot 文档安装 GUT。

### P6-T2: 编写核心系统测试
**状态：** ⬜ 未开始

优先测试：
- TimeManager
- InventoryManager
- SaveManager

---

## 📊 任务状态总览

| 任务 | 状态 | 依赖 |
|------|------|------|
| P1-T1 EventBus 拆分 | ⬜ | - |
| P1-T2 迁移信号 | ⬜ | P1-T1 |
| P1-T3 更新调用方 | ⬜ | P1-T2 |
| P2-T1 InventoryManager | ⬜ | - |
| P2-T2 MoneyManager | ⬜ | P2-T1 |
| P2-T3 StaminaManager | ⬜ | P2-T1 |
| P2-T4 简化 GameManager | ⬜ | P2-T1/2/3 |
| P2-T5 更新调用方 | ⬜ | P2-T4 |
| P3-T1 异常处理规范 | ⬜ | - |
| P3-T2 修复 push_error | ⬜ | P3-T1 |
| P4-T1 分析 farm_tiles | ⬜ | - |
| P4-T2 FarmTilesetBuilder | ⬜ | P4-T1 |
| P4-T3 重写 FarmBuilder | ⬜ | P4-T2 |
| P4-T4 移除 ColorRect | ⬜ | P4-T3 |
| P5-T1 常量配置 | ⬜ | - |
| P5-T2 替换魔法数字 | ⬜ | P5-T1 |
| P6-T1 GUT 安装 | ⬜ | - |
| P6-T2 核心测试 | ⬜ | P6-T1 |

---

## 执行顺序建议

**Phase 1（立即）：** P1 (EventBus) + P2 (GameManager)
**Phase 2（其次）：** P3 (异常处理) + P5 (常量)
**Phase 3（最后）：** P4 (Farm TileMap)
**Phase 4（长期）：** P6 (测试)
