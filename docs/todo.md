# 田园物语 - 开发任务清单

> 更新时间：2026-03-25

## ✅ 已完成（本次会话）

### 高优先级 R1-R4
- ✅ R1: **WeatherSystem** - 新 Autoload
- ✅ R2: **Festival Minigame 集成**
- ✅ R3: **SleepSystem** - 新 Autoload
- ✅ R4: **FishingSystem** - 新 Autoload

### 代码质量修复（25+ 文件）
**TileSetBuilders 重复 key 问题：**
- 修复 Farm/Beach/Forest/Mine/Indoor 的 enum 重复 tile_id
- TILE_PROPERTIES 改用 tile_id 作为属性存储

**缺失 class_name：**
- 添加: CraftingSystem, CookingSystem, ShopSystem, FishingSystem, WeatherSystem, SleepSystem, FurnitureSystem, SeasonSystem, Enemy

**Autoload 注册：**
- 添加: SeasonSystem, WeatherSystem, SleepSystem, FishingSystem, Friendship, CraftingSystem

**API 调用修复：**
- MoneySystem: add_money/spend_money 改为3参数
- CookingSystem: recipe.energy_cost 属性访问
- Enemy: area.get_meta() for damage/owner
- InventoryUI: item 强转为 Dictionary, slot_index 强转为 String

**类型推断修复（Variant → 显式类型）：**
- ToolUpgrade, FishingRod, Farm, FarmLayoutEditor, FestivalUI, FestivalNotification

**场景文件：**
- 创建 FestivalNotificationPopup.tscn, FestivalActivityButton.tscn, FestivalRewardButton.tscn

**其他：**
- VillageBuilder: 移除 TileMap.FORMAT_2
- Village: 移除重复 FARM_SCENE 常量
- UpgradeAnimation: 返回类型 Sprite2D → Node2D
- CombatHints: 变量/函数名冲突
- FishingSpot: 移除缺失的 FishingRod.tscn preload
- FarmLayoutEditor: reversed() → [::-1]

---

## 🟡 剩余任务

### 中优先级
- ✅ R5: FestivalMinigame 基类 9个 pass 回调
- ✅ R6: NPCSchedule 天气条件存根
- ✅ R7: NPCSchedule 扩展
- ✅ R8: MainMenu 存档加载/设置菜单
- ✅ R9: HouseUpgradeUI 消息显示
- ✅ R10: QuestSystem 经验系统
- ✅ R11: QuestSystem NPC数据库

### 缺失场景
- ⬜ Egg.tscn / Snowball.tscn（已设为 null）

### 测试框架
- ⬜ tests/ - GUT 测试框架未安装（不影响游戏运行）

---

## 📊 状态

- ✅ 18/18 检查通过
- ✅ 22 个系统初始化
- ⚠️ Git push 待网络恢复（4个 commits 本地待推送）
