# 地图 Agent API

地图 Agent API 让自动化 Agent 使用语义操作生成或修改地图，而不是直接编辑 TileMap 的场景序列化数据。操作清单只是一次性指令；执行完成后，`.tscn/.tres` 仍然是唯一权威来源。

## 基本调用

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/map-agent.ps1 schema
powershell -ExecutionPolicy Bypass -File scripts/map-agent.ps1 inspect res://src/world/maps/content/FarmMap.tscn
```

Linux、WSL 或 Git Bash：

```bash
GODOT=/path/to/godot bash scripts/map-agent.sh schema
GODOT=/path/to/godot bash scripts/map-agent.sh inspect res://src/world/maps/content/FarmMap.tscn
```

每次调用最后都会输出一行：

```text
MAP_AGENT_RESULT={...JSON...}
```

Agent 应以该前缀定位机器可读结果，并根据 `ok` 判断成功或失败。

## 推荐工作流

1. 执行 `inspect`，获取地图哈希、尺寸、图层、资源、可编辑属性、TileSet 坐标、Terrain 和碰撞预设。
2. 根据用户要求生成临时 recipe JSON。
3. 先使用 `apply ... --dry-run` 验证操作、区域约束和最终地图校验。
4. 使用不同的输出路径生成候选地图。
5. 对候选地图执行 `validate` 和 `render`。
6. 用户确认后，才允许覆盖正式地图。

## 命令

### 查询协议

```bash
bash scripts/map-agent.sh schema
```

### 查询地图和资源目录

```bash
bash scripts/map-agent.sh inspect res://src/world/maps/content/FarmMap.tscn
```

结果包含 `scene_sha256`。把它写入 recipe 的 `expected_scene_sha256`，可以防止 Agent 在地图已被其他人修改后继续覆盖旧版本。

### 新建地图

```bash
bash scripts/map-agent.sh create \
  res://data/maps/farm/farm_profile.tres \
  res://src/world/maps/content/NewFarmMap.tscn \
  new_farm "新农场"
```

默认拒绝覆盖已有文件。确实需要替换时必须显式添加 `--force`。

### 应用操作清单

```bash
bash scripts/map-agent.sh apply \
  res://src/world/maps/content/FarmMap.tscn \
  res://tools/map_editor/examples/farm_orchard_recipe.json \
  res://src/world/maps/content/FarmMapCandidate.tscn \
  --dry-run
```

省略输出路径时会以原地图为目标；建议 Agent 先生成候选场景。`--dry-run` 只在内存中执行和校验，不写文件。

示例清单位于 [farm_orchard_recipe.json](../tools/map_editor/examples/farm_orchard_recipe.json)。

### 校验地图

```bash
bash scripts/map-agent.sh validate res://src/world/maps/content/FarmMapCandidate.tscn
```

### 生成语义预览

```bash
bash scripts/map-agent.sh render \
  res://src/world/maps/content/FarmMap.tscn \
  res://artifacts/farm_preview.png 1280 896
```

语义预览不依赖 GPU，可在完全无头环境运行。颜色表示地面、道路、水、农田、对象、碰撞和标记，适合 Agent 检查整体布局；最终美术效果仍应在 Godot 编辑器或游戏中验收。

## Recipe 格式

```json
{
  "version": 1,
  "expected_map_id": "farm_main",
  "expected_scene_sha256": "inspect 返回的哈希，可选",
  "allowed_region": {"x": 32, "y": 23, "width": 10, "height": 8},
  "allow_locked_layers": false,
  "operations": []
}
```

`allowed_region` 使用瓦片坐标。所有绘制、对象锚点、碰撞范围和标记必须位于该区域内。默认不能修改锁定图层。

支持的操作：

- `set_map_metadata`：设置候选地图自己的 `map_id` 和显示名称。
- `paint_rect`：矩形绘制瓦片。
- `paint_cells`：绘制指定格子集合。
- `erase_rect`：擦除矩形区域。
- `terrain_connect`：调用 TileSet Terrain 自动连接。
- `place_asset`：按照资源库 ID 放置贴图或 PackedScene，只允许设置白名单属性。
- `move_node`、`remove_node`：移动或移除图层的直接子节点。
- `collision_rect`、`collision_circle`、`collision_polygon`：创建具名预设碰撞。
- `marker`：创建或更新出生、传送和锚点标记。
- `set_layer`：设置显示、锁定、透明度、Y Sort 和 Z Index。
- `resize_map`：修改地图格子尺寸，可用 `fill` 填充扩展区域，并自动重建四向世界边界。缩小时若会裁掉瓦片、对象、碰撞或标记，则整个事务失败。该操作不能与 `allowed_region` 同时使用。

扩展农场到 52×36 的示例：

```json
{
  "op": "resize_map",
  "size": [52, 36],
  "ground_layer": "ground",
  "fill": {"source": 0, "atlas": [0, 0], "alternative": 0}
}
```

坐标字段支持 `[x, y]` 或 `{"x": x, "y": y}`。对象、碰撞和标记的 `space` 可以是 `world` 或 `tile`。

## 安全规则

- 任何未知操作、资源、图层、TileSet 坐标、Terrain 或碰撞预设都会让整个事务失败。
- 任何越界或超出 `allowed_region` 的修改都会让整个事务失败。
- 地图 ID 或场景哈希不匹配时拒绝执行。
- 资源的非白名单属性不能由 Agent 修改。
- 操作完成后自动运行 `EditableMap2D.validate()`；存在错误时不保存。
- Agent 操作不会修改或删除资源库中的源图片和 PackedScene。
- Agent 不应直接写 `size_in_tiles` 或移动边界节点；必须通过 `resize_map`，确保地图尺寸、地面和物理边界保持一致。
