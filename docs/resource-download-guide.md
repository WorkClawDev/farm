# 开源资源下载指南 - 田园物语
**日期:** 2026-03-10  
**状态:** 占位符资源已生成 ✓

---

## ✅ 已完成

### 占位符资源 (97张)

我已经使用 Python 脚本生成了所有缺失的占位符图片：

| 类别 | 数量 | 位置 |
|------|------|------|
| 作物精灵 | 81张 | `assets/sprites/crops/` |
| 物品图标 | 40张 | `assets/sprites/items/` |
| 枯萎作物 | 1张 | `assets/sprites/crops/crop_dead.png` |

**生成脚本:** `tools/generate_placeholder_assets.py`

---

## 🌐 推荐的开源资源网站

### 1. OpenGameArt.org (首选)
**网址:** https://opengameart.org/

**搜索关键词:**
- "farming crops pixel art"
- "stardew valley style"
- "farm simulation sprites"
- "pixel art plants"

**推荐资源包:**
- LPC (Liberated Pixel Cup) 资源
- 搜索 "CC0" 或 "CC-BY" 许可

---

### 2. itch.io (免费资源区)
**网址:** https://itch.io/game-assets/free

**搜索关键词:**
- "pixel art farming"
- "crops sprite pack"
- "farm game assets"

**推荐资源:**
- "Free Farming Pixel Art Pack"
- "Pixel Art Crops"
- "Stardew-like Assets"

---

### 3. Kenney Assets
**网址:** https://kenney.nl/assets

**特点:**
- 全部免费商用
- 风格统一
- 包含 UI、图标、环境

**推荐下载:**
- "Pixel Platformer" (可作为基础)
- "RPG Assets"

---

### 4. Craftpix.net
**网址:** https://craftpix.net/freebies/

**特点:**
- 免费区有大量资源
- 需要注册

---

### 5. Game-icons.net
**网址:** https://game-icons.net/

**特点:**
- 图标资源
- 可下载 PNG/SVG
- 适合 UI 图标

---

## 📥 手动下载步骤

### 步骤 1: 访问 OpenGameArt

1. 打开 https://opengameart.org/
2. 在搜索框输入 "farming crops pixel art"
3. 筛选条件:
   - License: CC0 或 CC-BY
   - Type: 2D Art

### 步骤 2: 下载推荐资源

**推荐资源 1: LPC Farming Tileset**
- 包含: 作物、工具、环境
- 许可: CC-BY-SA 3.0 / GPL 3.0
- 链接: 搜索 "LPC farming"

**推荐资源 2: Pixel Art Crops**
- 包含: 多种作物精灵
- 许可: CC0
- 搜索: "crops pixel art"

**推荐资源 3: UI Elements**
- 搜索: "pixel art UI"
- 包含: 按钮、图标、对话框

### 步骤 3: 解压并整理

下载后，将资源解压到正确位置:

```
assets/
├── sprites/
│   ├── crops/          # 作物精灵
│   ├── items/          # 物品图标
│   ├── characters/     # 角色精灵
│   ├── tools/          # 工具图标
│   └── ui/             # UI元素
├── tiles/              # 地图瓦片
└── audio/              # 音效音乐
```

---

## 🎨 使用占位符的优缺点

### 优点
✓ 项目可以立即运行
✓ 测试游戏逻辑
✓ 确定需要的资源规格

### 缺点
✗ 视觉效果简陋
✗ 没有艺术风格统一性
✗ 不适合发布

---

## 🔄 替换占位符

当你获得真实资源后，替换步骤:

1. **备份占位符**
   ```bash
   mv assets/sprites/crops assets/sprites/crops_placeholder
   ```

2. **创建新目录**
   ```bash
   mkdir assets/sprites/crops
   ```

3. **放入真实资源**
   - 确保文件名与占位符相同
   - 或者更新代码中的路径

4. **测试**
   - 在 Godot 中运行项目
   - 检查资源是否正确加载

---

## 📋 资源清单 (需要替换)

### 高优先级 (影响游戏玩法)

| 资源 | 当前状态 | 建议来源 |
|------|----------|----------|
| 作物精灵 (20种) | 占位符 | OpenGameArt |
| 物品图标 (40个) | 占位符 | OpenGameArt |
| 工具图标 | 已有 ✓ | - |
| 角色精灵 | 已有 ✓ | - |

### 中优先级 (提升体验)

| 资源 | 当前状态 | 建议来源 |
|------|----------|----------|
| 动物精灵 | 缺失 | itch.io |
| 树木/矿石 | 缺失 | Kenney |
| UI元素 | 部分 | Kenney |

### 低优先级 ( polish )

| 资源 | 当前状态 | 建议来源 |
|------|----------|----------|
| 建筑 | 缺失 | OpenGameArt |
| 特效 | 缺失 | 自制 |
| 音效 | 缺失 | OpenGameArt |

---

## 💡 快速获取建议

如果你急需更好的资源，建议:

1. **购买廉价资源包** (itch.io 上 $1-5)
   - 质量比免费资源高
   - 风格统一
   - 节省时间

2. **雇佣像素艺术家** (Fiverr/Upwork)
   - 定制资源
   - 风格完全匹配
   - 成本 $50-200

3. **使用 AI 生成** (Midjourney/DALL-E)
   - 快速生成概念图
   - 需要后期处理
   - 适合参考

---

## 🔧 生成更多占位符

如果需要生成其他类型的占位符，可以修改脚本:

```python
# 编辑 tools/generate_placeholder_assets.py
# 添加新的资源类型

# 例如: 生成动物占位符
def create_animal_sprite(animal_name, direction):
    # 实现代码...
    pass
```

运行脚本:
```bash
cd /home/admin/gameboy-workspace/pastoral-tales
python3 tools/generate_placeholder_assets.py
```

---

## ✅ 当前项目状态

**可以运行的功能:**
- ✓ 玩家移动和动画
- ✓ 工具系统 (锄头、水壶等)
- ✓ 耕地和种植
- ✓ 作物生长
- ✓ 收获和出售
- ✓ 时间系统
- ✓ 背包系统

**使用占位符显示:**
- 所有作物都有可视化表示
- 所有物品都有图标
- 游戏可以完整运行

---

**报告生成:** 2026-03-10  
**GameBoy** 🎮
