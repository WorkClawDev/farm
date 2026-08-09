# 田园物语 - 开发任务清单

> 更新时间：2026-03-31

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
- 贴图审计 R1: 玩家正式游戏内 sprite sheet 已接入
- 贴图审计 R2: Village NPC 改为使用 8 帧 `npc_sheets` 链路
- 贴图审计 R3: 旧 1024x1024 白底角色大图迁移到 `assets/source_art/`
- 贴图审计 R4: 旧玩家 sheet 与 `crystal.jpg` 迁移到 `assets/source_art/`
- 贴图审计 R5: `npc_*.png` 单帧占位图已迁移出运行时目录，仅保留 `npc_default.png` 兜底
- 贴图审计 R6: 本轮生成的立绘 / 转身图 / sprite concept 已归档到 `assets/source_art/generated/`
- 贴图审计 R7: `output/google-character-imagegen/` 中间产物已清空

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
- ✅ Egg.tscn / Snowball.tscn 已创建

### 测试框架
- ✅ tests/ - GUT 测试框架已安装并通过 smoke test

---

## 📊 状态

- ✅ 18/18 检查通过
- ✅ 22 个系统初始化
- ⚠️ Git push 待网络恢复（4个 commits 本地待推送）
