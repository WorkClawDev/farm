# 资源缺口分析报告 - 田园物语
**日期:** 2026-03-10  
**分析范围:** 所有作物、物品、工具、角色、环境资源

---

## 📊 当前资源状态

### ✅ 已有资源

#### 作物精灵 (4个阶段)
- turnip_stage0-3.png ✓
- potato_stage0-3.png ✓
- tomato_stage0-3.png ✓
- corn_stage0-3.png ✓
- pumpkin_stage0-3.png ✓

#### 物品图标
- turnip.png, turnip_seed.png ✓
- potato.png, potato_seed.png ✓

#### 工具图标
- hoe.png, watering_can.png, axe.png, pickaxe.png, sickle.png, fishing_rod.png ✓

#### 角色
- player.png ✓
- npc_default.png, npc_blacksmith.png, npc_doctor.png, npc_farmer.png, npc_mayor.png, npc_shopkeeper.png ✓

#### 地形
- grass.png, soil.png, watered_soil.png, water.png ✓

---

## 🔴 缺失资源清单

### 1. 作物精灵 (高优先级)

根据 crops.json 配置，以下作物缺少精灵图：

| 作物ID | 名称 | 缺失文件 |
|--------|------|----------|
| cauliflower | 花椰菜 | cauliflower_stage0-3.png |
| green_bean | 青豆 | green_bean_stage0-3.png |
| strawberry | 草莓 | strawberry_stage0-3.png |
| melon | 甜瓜 | melon_stage0-3.png |
| blueberry | 蓝莓 | blueberry_stage0-3.png |
| hot_pepper | 辣椒 | hot_pepper_stage0-3.png |
| radish | 萝卜 | radish_stage0-3.png |
| eggplant | 茄子 | eggplant_stage0-3.png |
| cranberry | 蔓越莓 | cranberry_stage0-3.png |
| grape | 葡萄 | grape_stage0-3.png |
| sweet_potato | 红薯 | sweet_potato_stage0-3.png |
| carrot | 胡萝卜 | carrot_stage0-3.png |
| winter_root | 冬根 | winter_root_stage0-3.png |
| cabbage | 卷心菜 | cabbage_stage0-3.png |
| winter_melon | 冬瓜 | winter_melon_stage0-3.png |

**总计:** 15种作物 × 4个阶段 = **60张精灵图**

**额外需求:**
- crop_dead.png - 枯萎作物精灵 (1张)
- 每种作物的成熟/收获精灵 (15张)

---

### 2. 物品图标 (高优先级)

根据 items.json 和 crops.json，以下物品缺少图标：

#### 作物收获物
| 物品ID | 名称 | 缺失文件 |
|--------|------|----------|
| cauliflower | 花椰菜 | cauliflower.png |
| green_bean | 青豆 | green_bean.png |
| strawberry | 草莓 | strawberry.png |
| melon | 甜瓜 | melon.png |
| blueberry | 蓝莓 | blueberry.png |
| hot_pepper | 辣椒 | hot_pepper.png |
| radish | 萝卜 | radish.png |
| eggplant | 茄子 | eggplant.png |
| cranberry | 蔓越莓 | cranberry.png |
| grape | 葡萄 | grape.png |
| sweet_potato | 红薯 | sweet_potato.png |
| carrot | 胡萝卜 | carrot.png |
| winter_root | 冬根 | winter_root.png |
| cabbage | 卷心菜 | cabbage.png |
| winter_melon | 冬瓜 | winter_melon.png |
| tomato | 番茄 | tomato.png |
| corn | 玉米 | corn.png |
| pumpkin | 南瓜 | pumpkin.png |

#### 种子
| 种子ID | 名称 | 缺失文件 |
|--------|------|----------|
| cauliflower_seed | 花椰菜种子 | cauliflower_seed.png |
| green_bean_seed | 青豆种子 | green_bean_seed.png |
| strawberry_seed | 草莓种子 | strawberry_seed.png |
| melon_seed | 甜瓜种子 | melon_seed.png |
| blueberry_seed | 蓝莓种子 | blueberry_seed.png |
| hot_pepper_seed | 辣椒种子 | hot_pepper_seed.png |
| radish_seed | 萝卜种子 | radish_seed.png |
| eggplant_seed | 茄子种子 | eggplant_seed.png |
| cranberry_seed | 蔓越莓种子 | cranberry_seed.png |
| grape_seed | 葡萄种子 | grape_seed.png |
| sweet_potato_seed | 红薯种子 | sweet_potato_seed.png |
| carrot_seed | 胡萝卜种子 | carrot_seed.png |
| winter_root_seed | 冬根种子 | winter_root_seed.png |
| cabbage_seed | 卷心菜种子 | cabbage_seed.png |
| winter_melon_seed | 冬瓜种子 | winter_melon_seed.png |
| tomato_seed | 番茄种子 | tomato_seed.png |
| corn_seed | 玉米种子 | corn_seed.png |
| pumpkin_seed | 南瓜种子 | pumpkin_seed.png |

**总计:** 36张物品图标

---

### 3. 动物资源 (中优先级)

根据游戏设计，需要以下动物精灵：

| 动物 | 需求 |
|------|------|
| chicken | 鸡 (行走、产蛋动画) |
| cow | 牛 (行走、产奶动画) |
| pig | 猪 (行走、找松露动画) |
| sheep | 绵羊 (行走、产毛动画) |
| duck | 鸭子 (行走、产蛋动画) |
| rabbit | 兔子 (行走动画) |

每种动物需要:
- 4方向行走动画 (4帧 × 4方向 = 16张)
- 静止状态 (4张)
- 产品图标 (鸡蛋、牛奶、羊毛等)

**总计:** 约 20+ 张精灵图

---

### 4. 环境资源 (中优先级)

#### 树木
- tree_oak.png (橡树)
- tree_pine.png (松树)
- tree_apple.png (苹果树)
- tree_orange.png (橘子树)
- tree_stump.png (树桩)
- tree_fallen.png (倒下的树)

#### 矿石
- rock_normal.png (普通石头)
- rock_copper.png (铜矿石)
- rock_iron.png (铁矿石)
- rock_gold.png (金矿石)
- rock_coal.png (煤矿石)
- rock_gem.png (宝石矿石)

#### 可采集物
- forage_leek.png (韭菜)
- forage_dandelion.png (蒲公英)
- forage_leek.png (韭葱)
- forage_spring_onion.png (大葱)
- forage_hazelnut.png (榛子)
- forage_wild_plum.png (野李子)
- forage_berry.png (浆果)
- forage_coconut.png (椰子)
- forage_coral.png (珊瑚)
- forage_sea_urchin.png (海胆)

#### 装饰物
- fence_wood.png (木栅栏)
- fence_stone.png (石栅栏)
- fence_iron.png (铁栅栏)
- gate.png (门)
- chest.png (箱子)
- shipping_bin.png (出货箱)
- scarecrow.png (稻草人)
- sprinkler.png (洒水器)
- beehive.png (蜂箱)

---

### 5. UI 资源 (中优先级)

- energy_bar.png (体力条)
- energy_icon.png (体力图标)
- money_icon.png (金钱图标)
- time_icon.png (时间图标)
- season_spring.png (春季图标)
- season_summer.png (夏季图标)
- season_fall.png (秋季图标)
- season_winter.png (冬季图标)
- heart_empty.png (空心好感度)
- heart_full.png (实心好感度)
- dialog_box.png (对话框背景)
- inventory_slot.png (背包格子)
- selected_slot.png (选中格子)
- button_normal.png (普通按钮)
- button_hover.png (悬停按钮)
- button_pressed.png (按下按钮)

---

### 6. 建筑资源 (低优先级)

- house_player.png (玩家房屋)
- house_upgrade1.png (房屋升级1)
- house_upgrade2.png (房屋升级2)
- barn.png (谷仓)
- coop.png (鸡舍)
- silo.png (筒仓)
- well.png (水井)
- shop_general.png (杂货店)
- shop_blacksmith.png (铁匠铺)
- shop_saloon.png (酒馆)

---

### 7. 特效资源 (低优先级)

- effect_water.png (浇水特效)
- effect_harvest.png (收获特效)
- effect_plant.png (种植特效)
- effect_levelup.png (升级特效)
- effect_heart.png (好感度特效)
- particle_water.png (水花粒子)
- particle_sparkle.png (闪光粒子)

---

## 📈 资源统计

| 类别 | 已有 | 缺失 | 总计 |
|------|------|------|------|
| 作物精灵 | 20 | 76 | 96 |
| 物品图标 | 4 | 36 | 40 |
| 动物 | 0 | 20+ | 20+ |
| 环境 | 4 | 50+ | 54+ |
| UI | 1 | 20+ | 21+ |
| 建筑 | 0 | 10+ | 10+ |
| 特效 | 0 | 10+ | 10+ |
| **总计** | **29** | **222+** | **251+** |

---

## 🎯 获取建议

### 方案 1: 使用开源资源包 (推荐)

**推荐资源:**
1. **LPC (Liberated Pixel Cup)** - 开源像素艺术资源
   - 网站: https://lpc.opengameart.org/
   - 包含: 角色、作物、环境

2. **OpenGameArt.org**
   - 搜索: "farming", "crops", "pixel art"
   - 筛选: CC0 或 CC-BY 许可

3. **itch.io (免费资源)**
   - 搜索: "pixel art farming pack"
   - 很多免费或低价的资源包

4. **Kenney Assets**
   - 网站: https://kenney.nl/assets
   - 包含: UI、图标、环境

### 方案 2: AI 生成 (快速但需后期处理)

使用 AI 工具生成基础精灵，然后手动调整：
- DALL-E / Midjourney
- Stable Diffusion (Pixel Art 模型)
- 提示词: "pixel art [作物名称], 16x16, transparent background, farming game"

### 方案 3: 程序化生成 (技术方案)

使用代码生成基础形状，然后手动细化：
- 使用 Python + Pillow 生成基础像素图
- 基于已有作物的颜色模式生成新作物

---

## 📝 给 Agent 的 Prompt

```
请帮田园物语项目获取缺失的游戏资源图片。

项目路径: /home/admin/gameboy-workspace/pastoral-tales/
资源分析: /home/admin/gameboy-workspace/pastoral-tales/docs/resource-gap-analysis.md

优先获取以下资源（按优先级排序）:

### 高优先级
1. 作物精灵 (15种作物 × 4个阶段 = 60张)
   - 尺寸: 16x16 或 32x32 像素
   - 风格: 像素艺术，与现有 turnip_stage0-3.png 保持一致
   - 透明背景

2. 物品图标 (36张)
   - 尺寸: 16x16 像素
   - 风格: 像素艺术
   - 包含: 作物收获物和种子

### 中优先级
3. 动物精灵 (鸡、牛、猪、绵羊等)
4. 环境资源 (树木、矿石、可采集物)
5. UI 资源 (图标、按钮、对话框)

### 低优先级
6. 建筑资源
7. 特效资源

获取方式建议:
1. 从 OpenGameArt.org 搜索开源资源
2. 使用 CC0 或 CC-BY 许可的资源
3. 确保风格统一 (像素艺术)
4. 下载后放置到正确的 assets/ 目录

请记录:
- 每个资源的来源和许可
- 下载的文件列表
- 放置的路径
```

---

## 💡 快速启动方案

如果急需可玩版本，建议：

1. **复用现有资源**
   - 用 turnip 精灵作为所有作物的占位符
   - 修改颜色来区分不同作物

2. **使用色块占位符**
   - 创建纯色 16x16 图片
   - 用颜色代表不同作物

3. **优先获取核心资源**
   - 只获取 5-10 种核心作物
   - 其他用占位符代替

---

**报告生成:** 2026-03-10  
**GameBoy** 🎮
