# 资源 Sitemap 使用说明

## 1. 功能目的

`resource sitemap` 是当前仓库的统一资源索引文件，用来解决两个问题：

1. 外部地图编辑器或资源编辑器导入 GitHub 仓库资源时，不知道资源在哪里。
2. 外部编辑器导出资源后，不知道应该放回仓库的哪个位置，以及还需要更新哪些数据绑定。

这个功能现在以仓库级脚本实现，不依赖旧的 `tools/map_editor/`。旧编辑器已经废弃，新的编辑器仓库应直接消费本仓库生成的 sitemap。

新的编辑器仓库地址：

- `https://github.com/changerabc181-wq/farm-editor`

---

## 2. 输出文件

默认输出文件：

- `data/resource_sitemap.json`

这个文件应被视为：

- 当前资源布局的真实快照
- 导入器/编辑器的资源定位表
- 资源导出回填时的目标路径说明书

---

## 3. 生成方式

## 3.1 手动生成

推荐在仓库根目录执行：

```bash
bash scripts/generate_resource_sitemap.sh
```

成功后会输出类似结果：

```json
{
  "success": true,
  "output_path": "/abs/path/to/data/resource_sitemap.json",
  "summary": {
    "tileset_count": 1,
    "map_count": 1,
    "object_layout_count": 1,
    "asset_count": 442
  }
}
```

如果你想指定输出路径，也可以直接调用底层 Python 脚本：

```bash
python3 tools/generate_resource_sitemap.py --project-root . --output data/resource_sitemap.json
```

## 3.2 提交前自动生成

仓库提供了 Git pre-commit hook 模板：

- `.githooks/pre-commit`

安装命令：

```bash
bash scripts/install_git_hooks.sh
```

安装后，每次执行 `git commit` 前都会自动：

1. 重新生成 `data/resource_sitemap.json`
2. 自动把更新后的 sitemap 加入暂存区

## 3.3 检查流程自动生成

仓库的 `scripts/check.sh` 现在会自动刷新 sitemap。

也就是说，按当前仓库规范：

```bash
bash scripts/check.sh
```

执行后一定会先更新：

- `data/resource_sitemap.json`

然后再继续 Godot 检查和单元测试。

如果不想装 Git hook，至少要在提交前跑一次：

```bash
bash scripts/generate_resource_sitemap.sh
bash scripts/check.sh
```

---

## 4. Sitemap 结构

顶层字段如下：

| 字段 | 作用 |
|---|---|
| `schema_version` | sitemap 的 schema 版本 |
| `generated_at` | 生成时间 |
| `generator` | 生成器脚本信息 |
| `project` | 当前仓库基础信息 |
| `integration` | 与外部编辑器/导入器对接的关键路径 |
| `placement_rules` | 不同资源类型应该落到哪里 |
| `tilesets` | atlas 和 tile 元素定义 |
| `maps` | tile map 布局与每个 tile 的位置 |
| `object_layouts` | 场景对象布局和每个对象的位置 |
| `bindings` | `data/*.json` 与资源路径之间的绑定关系 |
| `assets` | 当前 `assets/` 下的资源清单 |
| `summary` | 统计汇总 |

---

## 5. 外部编辑器应该重点读取哪些字段

## 5.1 导入当前仓库资源

优先读取：

1. `assets.inventory`
2. `bindings`
3. `tilesets`
4. `maps`
5. `object_layouts`

### `assets.inventory`

这是仓库当前资源文件清单。每条记录至少包含：

- `path`
- `godot_path`
- `category`
- `size_bytes`
- 可选的 `media.image.width/height`
- 可选的 `linked_by`

可用它构建编辑器资源浏览器。

### `bindings`

这是资源与业务数据的关联关系。

例如：

- NPC 立绘和 `data/npcs.json` / `data/dialogues.json` 的绑定
- 作物阶段图和 `data/crops.json` 的绑定
- 物品图标和 `data/items.json` 的绑定

可用它确定“这个资源为什么存在”。

## 5.2 获取元素位置

### atlas 内位置

读取：

- `tilesets[].elements[]`

每个 tile 元素都有：

- `tile_id`
- `atlas_position.col`
- `atlas_position.row`
- `pixel_rect`

可用它在 atlas 中定位元素。

### 地图中的 tile 位置

读取：

- `maps[].tile_usages[]`

每个 tile usage 都有：

- `tile_id`
- `tile_name`
- `count`
- `positions[]`

每个 position 都有：

- `grid.x`
- `grid.y`
- `pixel.x`
- `pixel.y`

可用它恢复“某个元素当前在地图上被放到了哪里”。

### 场景对象位置

读取：

- `object_layouts[].objects[]`

每个对象都有：

- `scene_key`
- `scene_path`
- `position`
- `properties`

可用它恢复：

- 钓鱼点位置
- 出货箱位置
- 鸡舍/牛棚位置
- 建筑和交互物位置

---

## 6. 外部编辑器导出资源时如何回填

重点读取：

- `placement_rules`

这是导出回填规则表。每条规则定义：

- 资源类型
- 仓库目标路径模式
- Godot 路径模式
- 相关数据绑定文件

例如：

### NPC 立绘

规则会告诉你：

- 目标路径：`assets/sprites/portraits/{npc_id}.png`
- 还需要同步更新：
  - `data/npcs.json`
  - `data/dialogues.json`

### NPC sprite sheet

规则会告诉你：

- 目标路径：`assets/sprites/characters/npc_sheets/{npc_id}_sheet.png`
- 还需要同步更新：
  - `data/npcs.json`

### 作物阶段图

规则会告诉你：

- 目标路径：`assets/sprites/crops/{crop_id}_stage{stage}.png`
- 还需要同步更新：
  - `data/crops.json`

### 物品图标

规则会告诉你：

- 目标路径：`assets/sprites/items/{item_id}.png`
- 还需要同步更新：
  - `data/items.json`
  - 某些鱼类场景下还可能是 `data/fish.json`

---

## 7. 推荐给另一个 agent 的接入方式

如果另一个 agent 要实现新的外部编辑器，建议按以下顺序接入：

1. 读取 `data/resource_sitemap.json`
2. 用 `assets.inventory` 建立资源库
3. 用 `tilesets` 建立 atlas 元素索引
4. 用 `maps` 与 `object_layouts` 恢复已有地图内容
5. 用 `placement_rules` 决定导出资源应该写回哪里
6. 用 `bindings` 决定导出后还要更新哪些数据文件

---

## 8. 常见场景

## 8.1 我要知道某个 tile 在 atlas 里的位置

查：

- `tilesets[0].elements`

按 `tile_id` 找到对应记录即可。

## 8.2 我要知道某个 tile 在地图里被放了哪些位置

查：

- `maps[?].tile_usages`

按 `tile_id` 过滤即可。

## 8.3 我要知道某个 NPC 的立绘和行走图放在哪里

查：

- `bindings.npcs`

按 `id` 找到：

- `portrait`
- `sprite`

## 8.4 我要把编辑器导出的新资源放回仓库

查：

- `placement_rules`

先确定目标文件路径，再更新 `bindings` 对应的数据文件。

---

## 9. 注意事项

1. `resource_sitemap.json` 是生成文件，不应该手改。
2. 修改资源后应重新生成 sitemap。
3. 当前仓库已经把 sitemap 刷新接入 `scripts/check.sh`，提交前跑检查会自动更新。
4. 外部编辑器不要依赖已废弃的 `tools/map_editor/`，应只依赖 sitemap 和当前仓库数据。
5. 如果后续资源规范变化，应优先升级 sitemap schema，不要让外部编辑器去猜路径。

---

## 10. 对外约定

对于新的 `farm-editor` 或其他外部资源编辑器，这个仓库现在提供的稳定接口是：

1. `data/resource_sitemap.json`
2. `scripts/generate_resource_sitemap.sh`
3. `tools/generate_resource_sitemap.py`
3. `placement_rules` + `bindings` + `maps` + `object_layouts` 这套 schema

外部工具只要认这三层，就能：

- 读当前资源
- 识别位置
- 知道导出目标
- 知道需要更新哪些配置文件
