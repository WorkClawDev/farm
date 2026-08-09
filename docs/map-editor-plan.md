# 田园物语地图编辑器规划

## 目标
为 Pastoral Tales 游戏制作一个可视化的地图编辑器，可在 Godot 编辑器内运行（EditorPlugin 或独立工具场景），也可以是独立的 Python 网页工具。

## 当前地图系统

### 瓦片规格
- 瓦片大小：16×16 像素
- 地图大小：30×20 格（从 Farm.gd 的 _DEFAULT_LAYOUT 确认）
- 瓦片图集：`assets/tiles/farm_tiles.png`（1024×1024，64×64 网格）
- TileSet：通过 FarmTilesetBuilder 在运行时从图集自动生成

### 瓦片定义（FarmTilesetBuilder._TILE_PROPERTIES）
```
id=0: col=0,row=0, name="grass",         walkable=true
id=1: col=1,row=0, name="dark_grass",   walkable=true
id=2: col=2,row=0, name="medium_grass", walkable=true
id=3: col=3,row=0, name="light_grass",  walkable=true
id=4: col=4,row=0, name="dry_grass",    walkable=true
id=5: col=5,row=0, name="flower_grass", walkable=true
id=6: col=6,row=0, name="path",         walkable=true
id=7: col=7,row=0, name="dirt",         walkable=true
id=8: col=0,row=1, name="water",        walkable=false
id=9: col=1,row=1, name="shallow_water", walkable=false
id=10: col=2,row=1, name="sand",         walkable=true
id=11: col=3,row=1, name="fence",        walkable=false
id=12: col=4,row=1, name="gate",         walkable=true
id=13: col=5,row=1, name="wood_floor",   walkable=true
id=14: col=6,row=1, name="stone_floor",  walkable=true
id=15: col=7,row=1, name="farmland",     walkable=true
```

### 当前布局（Farm.gd._DEFAULT_LAYOUT）
- 30×20 的二维数组，每格存 tile_id（0-15）
- 硬编码在 _DEFAULT_LAYOUT 常量中

## 地图编辑器设计方案

### 方案 A：独立 Python 网页工具（推荐）
用 Python + Flask + 浏览器实现，无需 Godot 依赖，独立运行。

**技术栈：**
- Python 3 + Flask（轻量 web 服务）
- HTML5 Canvas（地图渲染）
- JSON 文件存储地图数据

**界面布局（左右分栏）：**
```
┌──────────────────────────────────────────┐
│  🌾 Pastoral Tales 地图编辑器  v1.0       │
├─────────────┬────────────────────────────┤
│  瓦片调色板  │                            │
│  ┌──┬──┬──┐ │      地图画布              │
│  │ 0│ 1│ 2│ │   (30×20 网格)            │
│  ├──┼──┼──┤ │                            │
│  │ 3│ 4│ 5│ │   点击/拖拽放置瓦片         │
│  ├──┼──┼──┤ │                            │
│  │ 6│ 7│ 8│ │                            │
│  ├──┼──┼──┤ │                            │
│  │ 9│10│11│ │                            │
│  ├──┼──┼──┤ │                            │
│  │12│13│14│ │                            │
│  ├──┼──┼──┤ │                            │
│  │15│   │  │                            │
│  └──┴──┴──┘ │                            │
│             │                            │
│  [工具]     │                            │
│  ○ 画笔     │                            │
│  ○ 填充     │                            │
│  ○ 橡皮擦   │                            │
│             │                            │
│  [操作]     │                            │
│  [保存地图]  │                            │
│  [加载地图]  │                            │
│  [导出代码]  │                            │
│  [预览]     │                            │
├─────────────┴────────────────────────────┤
│  状态栏：光标位置 (x, y) | 当前瓦片 |     │
└──────────────────────────────────────────┘
```

### 方案 B：Godot 编辑器插件
作为 EditorPlugin 集成到 Godot 编辑器中。

**优点：** 可以直接在游戏编辑器里用
**缺点：** 需要在 Godot 里操作

### 推荐：方案 A（独立工具）

**理由：**
1. 独立于游戏代码，不污染项目
2. 用浏览器 Canvas 操作更流畅
3. 易于分享和协作
4. 地图保存为 JSON，可直接被游戏加载

## 详细功能规格

### 1. 瓦片调色板（左侧面板）
- 16 个瓦片按钮（2列×8行），显示每个瓦片的缩略图
- 瓦片名称悬停提示
- 当前选中瓦片高亮（黄色边框）
- 从 `assets/tiles/farm_tiles.png` 动态切割 16×16 缩略图

### 2. 地图画布（右侧主区域）
- 30×20 网格，每格 24×24 像素显示（可缩放）
- 网格线默认显示，可切换隐藏
- 鼠标悬停显示坐标 tooltip
- 左键：放置当前瓦片
- 右键：快速切换到橡皮擦工具
- 拖拽：连续放置/擦除

### 3. 工具栏
- **画笔**：在空地或已有瓦片上绘制
- **填充**：Flood-fill 工具，填充连通区域
- **橡皮擦**：清除为草地（tile_id=0）
- **取色器**：点击地图上的瓦片，切换为当前选中瓦片

### 4. 操作按钮
- **新建**：创建空白 30×20 地图（填满草地）
- **保存**：保存为 JSON 文件（`data/maps/farm_layout.json`）
- **加载**：从 JSON 文件加载地图
- **导出代码**：生成 GDScript 代码片段，直接粘贴到 Farm.gd
- **预览**：弹出窗口以实际 TileSet 图集渲染地图预览

### 5. 地图数据 JSON 格式
```json
{
  "name": "farm_layout",
  "width": 30,
  "height": 20,
  "tiles": [
	[0,0,0,1,1,0,0,...],  // 第0行，30个tile_id
	[0,2,2,2,2,2,0,...],  // 第1行
	...
  ],
  "tile_size": 16,
  "tile_properties": {
	"0": {"name": "grass", "walkable": true},
	...
  }
}
```

### 6. 与游戏集成
地图编辑器生成的 JSON 由 `MapLoader.gd`（新建）读取：
```gdscript
# MapLoader.gd - Autoload
func load_layout(path: String) -> Array:
	# 读取 JSON → 返回 tile_id 二维数组
	pass
```

Farm.gd 修改为优先从 `MapLoader` 加载布局：
```gdscript
func _ready():
	_layout = MapLoader.load_layout("res://data/maps/farm_layout.json")
	if _layout.is_empty():
		_layout = _DEFAULT_LAYOUT.duplicate(true)
	_paint_default_farm()
```

## 文件结构

```
 pastoral-tales/
  data/
	maps/
	  farm_layout.json    # 主地图（由编辑器生成）
	  village_layout.json
  tools/
	map_editor/
	  app.py              # Flask 主程序
	  static/
		editor.js         # 前端编辑器逻辑
		editor.css        # 样式
	  templates/
		editor.html       # 主页面
	  requirements.txt    # Python 依赖
  src/
	core/
	  MapLoader.gd       # 新增：从 JSON 加载地图
```

## 实现步骤（交给 Codex）

### Phase 1: 基础地图编辑器（map_editor/app.py + HTML/JS）
1. 实现 Flask 服务器 + HTML Canvas
2. 瓦片调色板（从 farm_tiles.png 切割缩略图）
3. 30×20 地图画布，鼠标放置瓦片
4. 画笔和橡皮擦工具
5. 保存/加载 JSON

### Phase 2: 完善功能
6. 填充工具
7. 取色器工具
8. 导出 GDScript 代码
9. 地图预览窗口
10. 新建/重置地图

### Phase 3: 与游戏集成
11. 创建 `src/core/map/MapLoader.gd`
12. 修改 `Farm.gd` 支持从 MapLoader 加载
13. 确认 Farm 场景正确渲染编辑器生成的地图
14. 更新 check.sh 添加地图相关检查

## 注意事项
- 地图尺寸固定为 30×20，后续可扩展
- 所有 16 个瓦片类型都支持
- JSON 格式保持简洁，便于人工检查和修改
- 编辑器工具放在 `tools/map_editor/` 目录，与游戏主代码分离
