# Pastoral Tales 地图编辑器

地图编辑器是 Godot 编辑器插件，启用后显示在右侧的 **Pastoral Map** 面板。地图内容以 `.tscn` 和 `.tres` 为唯一权威来源；运行时不会修改这些文件，也不再读取农场旧 JSON。

## 打开与编辑农场

1. 在 Godot 中打开 `res://src/world/maps/content/FarmMap.tscn`。
2. 在图层面板选择目标图层。隐藏或锁定图层不会接受编辑操作。
3. TileMapLayer 可使用画笔、橡皮、取色、矩形、填充和 Terrain 工具。
4. 资源库中的贴图或 PackedScene 可拖放/选择后放入匹配图层。
5. 碰撞图层可绘制矩形、圆形和多边形，并使用具名碰撞预设。
6. 保存前点击“校验”；问题列表可定位到对应节点。

面板顶部的“地图尺寸”可以调整格子宽高。扩大地图时新增区域自动使用地面图层的默认瓦片填充，四向世界边界同步重建；缩小时会裁剪瓦片，但如果对象、碰撞或标记会落到地图外则拒绝操作。鼠标经过画布时，面板底部会显示当前格坐标和世界坐标。

Terrain 工具不再固定使用第一个 Terrain。先在瓦片调色板下方选择 Path、Water、Fence 等 Terrain 类型，再在画布中绘制。Godot 文件系统面板中的 TileSet、Texture2D 和 PackedScene 可以直接拖到 Pastoral Map 面板完成登记。

所有绘制、放置、碰撞和图层操作通过 Godot 的 `EditorUndoRedoManager` 登记，可以使用编辑器原生撤销/重做。保存状态由 Godot 场景系统负责。

## 数据结构

- `EditableMap2D`：地图根节点，提供 `get_layer()`、`get_marker()`、`validate()`、摄像机限制和世界边界重建接口。
- `MapProfile`：地图尺寸、图层模板、主 TileSet、资源库和碰撞预设。
- `MapTileLayer`：基于 Godot 4 的 `TileMapLayer`，用于地面和 Terrain 覆盖。
- `MapLayer2D`：装饰、对象、碰撞和标记的容器。
- `MapDecoration2D`、`MapCollisionBody2D`、`MapMarker2D`：自由贴图、地图碰撞和逻辑标记。

农场资源位于：

- 地图：`res://src/world/maps/content/FarmMap.tscn`
- Profile：`res://data/maps/farm/farm_profile.tres`
- 资源库：`res://data/maps/farm/farm_asset_library.tres`
- TileSet：`res://assets/tiles/farm_tileset.tres`
- 原创分区示例地图：`res://src/world/maps/content/PastoralValleyMap.tscn`

`PastoralValleyMap.tscn` 使用住宅区、横向主路、耕地区、牧场、池塘和林地区域展示完整编辑器数据结构。它只借鉴经典农场游戏清晰分区与环路设计的思路，没有复制商业游戏地图或美术资源。其可重放 Agent recipe 位于 `res://tools/map_editor/examples/pastoral_valley_recipe.json`。

## 资源管理

“登记资源”只把已有 `res://` 资源加入资源库。“取消登记”不会删除源文件。外部图片通过“导入图片”复制到项目资源目录；若文件重名会自动追加编号且绝不覆盖。通过“由贴图创建 TileSet”可设置瓦片宽高、边距和间距并保存 `.tres`，之后可在 Godot 原生 TileSet 编辑器中继续配置 Terrain 和逐瓦片物理多边形。

## 校验与迁移

执行 `bash scripts/check.sh` 会先运行 `res://tools/map_editor/validate_maps.gd`，检查农场尺寸、必需图层、资源、对象、标记、碰撞、Terrain 和 TileSet 物理数据。

地图边缘由两层共同保护：玩家的 `Camera2D` 在场景加载时限制到地图全局矩形，碰撞层包含北、南、西、东四个矩形世界边界。修改地图尺寸时应调用 `EditableMap2D.rebuild_world_boundaries()`；使用 Agent 时应提交 `resize_map` 操作，不要手工移动边界节点。

如需从保留的旧 JSON fixture 重新生成农场资源，可运行：

```bash
godot --headless --path . --script res://tools/map_editor/generate_farm_map.gd
```

生成器是迁移工具，不在游戏运行链路中。迁移其他地图时，应先创建各自 profile、独立内容场景和校验用例，再替换对应运行时加载逻辑。

需要让自动化 Agent 查询资源、生成候选地图或执行受限区域修改时，请使用 [地图 Agent API](map-agent-api.md)。
