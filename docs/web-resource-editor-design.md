# Pastoral Tales Web 资源编辑器与 AI 地图 Agent 需求设计文档

## 1. 文档目的

本文档用于定义一个独立于 Godot 主工程的 Web 资源编辑器项目。该项目的职责不是替代游戏运行时，而是作为外部生产工具，负责：

- 地图编辑
- 地图对象摆放
- AI 辅助生成与完善地图
- AI 生成与管理贴图资源
- 审核、版本化、导出
- 将导出结果稳定集成到当前 `pastoral-tales` Godot 工程

本文档应足够详细，使另一个 agent 可以直接按本文档拆分任务并实现。

---

## 2. 背景与当前现状

### 2.1 当前项目里已经存在的相关能力

- 存在一个临时地图编辑器：`src/tools/FarmLayoutEditor.gd`
- 农场地图存在两条并行数据链路：
  - Tile 网格：`data/maps/farm_layout.json`
  - 场景对象：`data/farm_layout.json`
- 农场运行时入口在 `src/world/maps/Farm.gd`
- Tile JSON 读取入口在 `src/core/map/MapLoader.gd`
- 当前项目大量运行时资源直接写死为 `res://assets/...` 路径
- 当前项目已经有 AI 生成素材归档习惯：`assets/source_art/generated/`

### 2.2 当前项目存在的集成问题

#### 地图格式分裂

- 地图 Tile 与地图对象分成两个 JSON 文件
- `Farm.gd` 同时读取 `data/maps/farm_layout.json` 和 `data/farm_layout.json`
- 当前临时编辑器只覆盖对象布局，不是完整资源编辑器

#### 地图规格不一致

- `FarmConstants.gd` 中农场地图实际规格是 `50 x 35`
- 当前 `data/maps/farm_layout.json` 仍是 `30 x 20` 的旧占位格式
- 新系统不能继续把地图尺寸硬编码为 `30 x 20`

#### 资源规格不统一

- 玩家与 NPC 使用 8 帧横向 sprite sheet，当前文件为 `256 x 32`
- NPC 立绘/对话头像使用方图，当前文件为 `64 x 64`
- 动物当前运行时资源是 `64 x 64` 单图
- 建筑、作物、物品资源当前尺寸非常不统一，部分文件是 AI 原图直接进入运行时目录

#### AI 资产流程不成体系

- 已有脚本可调用 AI 生成图片，但缺少统一的任务、版本、审核、导出机制
- 现有生成脚本存在密钥管理混乱问题，新系统必须改为服务端统一托管

### 2.3 本次建设的核心目标

- 新建一个独立 Web 项目，不污染 Godot 主工程运行时代码
- 把地图编辑、资源编辑、AI 生成、审核、导出统一到一个工具里
- 定义稳定的导出协议和 Godot 兼容适配层
- 使导出后的资源可直接或经过最薄适配后接入当前项目
- 为未来多地图、多资源类型、多 AI 模型接入留出扩展位

---

## 3. 设计原则

### 3.1 两层接口原则

必须区分两层格式：

- 第 1 层：Web 编辑器自己的规范化导出格式
- 第 2 层：面向当前 `pastoral-tales` 仓库的兼容导入格式

原因：

- 当前 Godot 项目已有历史包袱，不应把这些历史格式直接固化为 Web 编辑器的内部模型
- Web 编辑器需要成为长期资产生产工具，不能被某一个阶段的 Godot 数据结构锁死

### 3.2 以“资源包导出”为核心，而不是“直接改仓库”

Web 编辑器应默认产出一个可审计的导出包，然后由 Godot 兼容导入器执行落地。

好处：

- 可以审查 diff
- 可以重放导出
- 可以做回滚
- 可以支持 CI 校验

### 3.3 AI 只能生成候选，不能直接跳过审核

所有 AI 生成结果必须进入“候选版本”状态，经过人工确认后才能导出为运行时资源。

### 3.4 所有运行时路径必须显式、稳定、可复现

新系统不能依赖“猜测文件名”才能集成。导出的清单必须明确：

- 生成了什么
- 应该落到哪里
- 哪些数据文件需要被更新
- 对当前 Godot 工程的最低兼容要求是什么

---

## 4. 当前 Godot 工程的真实集成约束

### 4.1 地图基础约束

当前农场运行时约束：

- Source Tile Size: `16`
- World Tile Size: `64`
- Render Scale: `4`
- 农场默认尺寸：`50 x 35`
- 运行时 TileSet 来源：`assets/tiles/farm_tiles.png`
- 农场对象注册表当前包含：
  - `shipping_bin`
  - `workbench`
  - `fishing_spot`
  - `player_house_exterior`
  - `coop`
  - `barn`
  - `ore`

### 4.2 当前对象可序列化属性

为了兼容当前工程，至少需要支持以下属性导出：

| object_type | 当前 scene_key | 当前关键属性 |
|---|---|---|
| shipping_bin | `shipping_bin` | `interaction_prompt`, `is_interactable` |
| workbench | `workbench` | `workbench_type`, `workbench_name`, `interaction_prompt`, `is_interactable` |
| fishing_spot | `fishing_spot` | `location_type` |
| player_house_exterior | `player_house_exterior` | 暂无必填运行时属性 |
| coop | `coop` | `building_name`, `max_animals` |
| barn | `barn` | `building_name`, `max_animals` |
| ore | `ore` | `ore_type`, `max_health`, `base_quantity`, `quality_modifier` |

### 4.3 当前资源接入约束

#### 玩家/NPC Sprite Sheet

- 当前玩家运行时资源：`assets/sprites/characters/player_spritesheet_nanobanana2.png`
- 当前 NPC 运行时资源：`assets/sprites/characters/npc_sheets/<npc_id>_sheet.png`
- 当前帧布局：一行 8 帧
- 当前运行时默认规格：`256 x 32`
- 每帧规格：`32 x 32`

#### NPC Portrait

- 当前路径：`assets/sprites/portraits/<npc_id>.png`
- 当前运行时规格：`64 x 64`
- 同时被 `data/npcs.json` 和 `data/dialogues.json` 引用

#### 动物资源

- 当前路径：`assets/sprites/animals/<Animal>.png`
- 当前运行时规格：`64 x 64`
- 当前动物运行时仍是单图模式，不是完整动画资源管线

#### 作物资源

- 当前 `data/crops.json` 使用 `stages_sprites` 数组
- 当前 `Crop.gd` 按 stage 直接加载 `res://assets/sprites/crops/<crop_id>_stageN.png`
- `crop_dead.png` 是全局枯萎图

#### 物品图标

- 当前 `data/items.json` 的 `icon` 字段允许直接指定路径
- `ItemDatabase.gd` 还带有目录回退逻辑
- 但是新系统不应依赖该回退逻辑作为主路径方案

#### 建筑资源

- `HouseExterior.gd`、`Barn.gd`、`Coop.gd` 都直接加载 `res://assets/sprites/houses/...`
- 运行时会按代码里的 display size 缩放，因此建筑源图允许高分辨率，但导出仍需标准化

### 4.4 当前开发与验证约束

落地到主工程后必须满足：

1. Godot 4.6.1 可正常打开项目
2. `bash scripts/check.sh` 通过
3. 不引入新的脚本错误和运行时错误
4. 导出的路径在主工程中可被稳定解析

---

## 5. 目标产品范围

## 5.1 In Scope

- 独立 Web 工程
- 地图编辑器
- 地图对象编辑器
- 资源库管理
- AI 图片生成
- AI 地图补全与优化
- 资源版本管理
- 导出包生成
- Godot 兼容导入器
- 导出前校验

## 5.2 Out of Scope

- 直接替换 Godot 编辑器
- 运行时在线热更新
- 多人实时协同编辑
- 在浏览器里完整运行游戏
- 自动提交到 Git 主分支

---

## 6. 推荐总体架构

推荐拆成 4 个模块：

1. `web-client`
2. `api-server`
3. `worker`
4. `godot-compat-adapter`

### 6.1 推荐技术栈

前端：

- React
- TypeScript
- Vite
- Zustand
- PixiJS 或 Canvas 作为地图主画布

后端：

- FastAPI
- Pydantic
- SQLAlchemy

异步任务：

- Redis + RQ 或 Celery

存储：

- 开发阶段：SQLite + 本地文件系统
- 可扩展阶段：PostgreSQL + S3 兼容对象存储

### 6.2 模块职责

#### web-client

- 地图编辑 UI
- 对象编辑 UI
- 资源浏览与审核 UI
- AI 任务提交 UI
- 导出 UI

#### api-server

- 项目、资源、地图、导出任务的 API
- 统一鉴权
- 统一 schema 校验
- AI 提示词模板装配

#### worker

- 调用图像生成模型
- 调用地图生成/润色模型
- 后处理
- 生成导出包
- 生成兼容导入报告

#### godot-compat-adapter

- 将规范化导出包转成当前 `pastoral-tales` 工程所需文件
- 更新 `data/*.json`
- 写入 `assets/sprites/...`
- 写入 `assets/source_art/generated/...`
- 输出变更报告与校验报告

---

## 7. 核心用户流程

### 7.1 地图制作流程

1. 选择地图类型或创建地图 Profile
2. 选择 tileset、尺寸、图层与可放置对象集合
3. 手工绘制地形
4. 放置交互对象
5. 调用 AI Agent 做局部补全或整体优化
6. 审核 AI 改动 diff
7. 通过后生成导出包
8. 通过 Godot 兼容导入器落地到主项目
9. 运行 `bash scripts/check.sh`

### 7.2 资源制作流程

1. 创建资源条目
2. 选择资源模板
3. 输入提示词、参考图、风格标签
4. 提交 AI 生成任务
5. 在候选版本中挑选、打回、继续细化
6. 通过后生成运行时资源和源素材归档
7. 更新相关数据文件引用
8. 导出并落地到主项目

---

## 8. 功能需求

### 8.1 项目与工作区管理

#### FR-001

系统必须支持“编辑器项目”的概念，一个编辑器项目至少包含：

- project id
- 名称
- 目标 Godot 工程标识
- 地图集合
- 资源集合
- 输出目录配置
- AI Provider 配置

#### FR-002

系统必须支持把“Pastoral Tales”定义成一个目标项目模板，内置：

- 目录映射
- 资源规格
- 地图 profile
- 对象注册表
- 导入兼容规则

### 8.2 地图编辑器

#### FR-010

系统必须支持 Map Profile，不得把地图尺寸、tile 大小、图层数量硬编码在前端。

#### FR-011

地图至少支持以下图层类型：

- `tile`
- `object`
- `collision_mask`
- `spawn_marker`
- `annotation`

#### FR-012

Tile 图层必须支持：

- 画笔
- 橡皮
- 框选
- 填充
- 吸管
- 图层显隐
- undo/redo
- 缩放和平移

#### FR-013

对象图层必须支持：

- 从对象注册表拖拽放置
- 编辑位置、旋转、缩放、锚点
- 编辑属性字典
- 复制、删除、锁定

#### FR-014

地图编辑器必须支持 AI 辅助操作：

- 生成初版地图
- 局部区域补全
- 根据文本描述铺设道路
- 自动生成池塘/树林/农田分区
- 自动建议对象布局
- 自动检查不可达区域和明显冲突

#### FR-015

所有 AI 地图改动必须以 patch 形式回放，用户可逐项接受或拒绝。

### 8.3 资源编辑器

#### FR-020

系统必须支持以下资源模板：

- 玩家 sprite sheet
- NPC sprite sheet
- NPC portrait
- 动物单图
- 动物 sprite sheet
- 作物阶段图组
- 物品图标
- 建筑贴图
- tileset 子块或装饰贴图

#### FR-021

每类资源模板必须有：

- 运行时规格
- 源素材规格
- 命名规则
- 输出目录
- 可选后处理流程

#### FR-022

资源生成必须支持：

- 文本提示词
- 参考图
- 负面提示词
- 风格标签
- 模板参数
- 生成批次号

#### FR-023

资源生成后必须保留：

- 原始 prompt
- 模型信息
- 生成时间
- 候选图列表
- 选择结果
- 审核结果
- 导出记录

#### FR-024

资源必须区分两个产物：

- `source master`
- `runtime asset`

`source master` 用于归档与再编辑，`runtime asset` 用于真正接入 Godot。

### 8.4 审核与版本

#### FR-030

每个地图、每个资源都必须有版本号。

#### FR-031

版本状态至少包括：

- `draft`
- `candidate`
- `approved`
- `exported`
- `archived`

#### FR-032

只有 `approved` 版本允许被导出。

### 8.5 导出与集成

#### FR-040

系统必须支持导出一个完整的“资源包”，而不是只导出散落文件。

#### FR-041

导出包必须包含：

- manifest
- 地图文档
- 资源文件
- 数据 patch
- 源素材归档
- 校验报告

#### FR-042

系统必须支持 `compatibility-v1` 模式，把导出包转成当前 `pastoral-tales` 兼容格式。

#### FR-043

导出时必须检测：

- 路径冲突
- 重名资源
- 缺失引用
- 不兼容尺寸
- 不兼容对象类型
- 非法属性
- JSON schema 错误

### 8.6 安全

#### FR-050

AI Provider 密钥只能放在服务端，不能出现在前端包，也不能写入主工程仓库。

#### FR-051

生成日志里允许保存模型名、请求参数摘要和 prompt，但不得泄露真实密钥。

---

## 9. 规范化数据契约

## 9.1 ProjectManifest

```json
{
  "schema_version": "1.0",
  "project_id": "pastoral-tales",
  "project_name": "Pastoral Tales",
  "target_engine": "godot-4.6.1",
  "target_repo": "pastoral-tales",
  "profiles": ["farm", "village", "forest", "beach", "mine", "player_house"],
  "resource_templates": [
    "player_sprite_sheet",
    "npc_sprite_sheet",
    "npc_portrait",
    "animal_single",
    "crop_stage_set",
    "item_icon",
    "building_sprite"
  ]
}
```

## 9.2 MapProfile

```json
{
  "id": "farm",
  "name": "Farm",
  "source_tile_size": 16,
  "runtime_tile_size": 64,
  "default_width": 50,
  "default_height": 35,
  "tileset": {
    "atlas_path": "res://assets/tiles/farm_tiles.png",
    "palette_id": "farm_tiles_v1"
  },
  "layers": [
    {"id": "ground", "type": "tile", "required": true},
    {"id": "overlay", "type": "tile", "required": false},
    {"id": "objects", "type": "object", "required": true},
    {"id": "collision", "type": "collision_mask", "required": false},
    {"id": "spawns", "type": "spawn_marker", "required": false}
  ],
  "allowed_object_types": [
    "shipping_bin",
    "workbench",
    "fishing_spot",
    "player_house_exterior",
    "coop",
    "barn",
    "ore"
  ]
}
```

## 9.3 MapDocument

```json
{
  "schema_version": "1.0",
  "map_id": "farm_main",
  "profile_id": "farm",
  "name": "Farm Main",
  "width": 50,
  "height": 35,
  "tile_size": 16,
  "layers": [
    {
      "id": "ground",
      "type": "tile",
      "cells": [[0, 0, 6, 6]]
    }
  ],
  "objects": [
    {
      "id": "obj_shipping_bin_001",
      "type": "shipping_bin",
      "position": {"x": 400, "y": 300},
      "rotation": 0,
      "scale": {"x": 1, "y": 1},
      "properties": {}
    }
  ],
  "markers": [
    {
      "id": "player_spawn",
      "type": "spawn_marker",
      "position": {"x": 800, "y": 400}
    }
  ],
  "ai_history": [
    {
      "job_id": "job_map_fill_001",
      "instruction": "把右上角补成池塘区域",
      "status": "accepted"
    }
  ],
  "metadata": {
    "author": "designer",
    "created_at": "2026-04-01T00:00:00Z",
    "updated_at": "2026-04-01T02:00:00Z"
  }
}
```

说明：

- `layers[].cells` 推荐使用压缩格式或稀疏格式存储
- 兼容导出到当前项目时，再转成 `tiles` 二维数组

## 9.4 ObjectTypeDefinition

```json
{
  "id": "fishing_spot",
  "scene_key": "fishing_spot",
  "godot_scene": "res://src/world/objects/FishingSpot.tscn",
  "properties_schema": {
    "location_type": {
      "type": "string",
      "enum": ["lake", "river", "beach", "pond"],
      "default": "pond"
    }
  }
}
```

## 9.5 ResourceAsset

```json
{
  "schema_version": "1.0",
  "asset_id": "npc_mayor_sheet",
  "kind": "npc_sprite_sheet",
  "name": "Mayor Sprite Sheet",
  "status": "approved",
  "tags": ["npc", "village", "character"],
  "spec": {
    "runtime_width": 256,
    "runtime_height": 32,
    "frame_width": 32,
    "frame_height": 32,
    "frame_order": [
      "down_idle",
      "down_walk",
      "left_idle",
      "left_walk",
      "right_idle",
      "right_walk",
      "up_idle",
      "up_walk"
    ]
  },
  "source_master": {
    "path": "source/characters/mayor/v3/master.png"
  },
  "runtime_files": [
    {
      "path": "runtime/assets/sprites/characters/npc_sheets/mayor_sheet.png",
      "content_type": "image/png"
    }
  ],
  "integration_targets": [
    {
      "type": "json_patch",
      "file": "data/npcs.json",
      "selector": {"collection": "npcs", "id": "mayor"},
      "field": "sprite",
      "value": "res://assets/sprites/characters/npc_sheets/mayor_sheet.png"
    }
  ]
}
```

## 9.6 GenerationJob

```json
{
  "job_id": "job_001",
  "job_type": "generate_asset",
  "target_kind": "npc_portrait",
  "status": "running",
  "provider": "openai",
  "model": "gpt-image-1",
  "prompt": "为镇长生成 64x64 的对话头像...",
  "negative_prompt": "text, watermark, realistic",
  "references": [],
  "created_at": "2026-04-01T03:00:00Z"
}
```

## 9.7 ExportManifest

```json
{
  "schema_version": "1.0",
  "export_id": "export_20260401_001",
  "project_id": "pastoral-tales",
  "compatibility_mode": "godot-v1",
  "maps": [
    {
      "map_id": "farm_main",
      "canonical_path": "maps/farm_main.map.json",
      "compat_outputs": [
        "data/maps/farm_layout.json",
        "data/farm_layout.json"
      ]
    }
  ],
  "assets": [
    {
      "asset_id": "npc_mayor_sheet",
      "runtime_outputs": [
        "assets/sprites/characters/npc_sheets/mayor_sheet.png"
      ],
      "source_archive_outputs": [
        "assets/source_art/generated/npc/mayor/v3/master.png"
      ]
    }
  ],
  "patches": [
    "patches/data.npcs.patch.json",
    "patches/data.dialogues.patch.json"
  ],
  "validation": {
    "errors": [],
    "warnings": [
      "farm layout converted from canonical multi-layer format to legacy single-layer JSON"
    ]
  }
}
```

## 9.8 DataPatch

```json
{
  "schema_version": "1.0",
  "file": "data/crops.json",
  "operation": "upsert_by_id",
  "collection": "crops",
  "id": "turnip",
  "value": {
    "id": "turnip",
    "stages_sprites": [
      "res://assets/sprites/crops/turnip_stage0.png",
      "res://assets/sprites/crops/turnip_stage1.png",
      "res://assets/sprites/crops/turnip_stage2.png",
      "res://assets/sprites/crops/turnip_stage3.png"
    ],
    "harvest_sprite": "res://assets/sprites/items/turnip.png"
  }
}
```

---

## 10. Pastoral Tales 兼容导出规则

## 10.1 地图兼容规则

对于 `farm` 地图，`compatibility-v1` 必须输出：

### Tile 输出

写入：

- `data/maps/farm_layout.json`

格式要求：

```json
{
  "name": "farm_layout",
  "width": 50,
  "height": 35,
  "tile_size": 16,
  "tiles": [[0, 0, 0]]
}
```

### 对象输出

写入：

- `data/farm_layout.json`

格式要求：

```json
{
  "grid_size": 32,
  "objects": [
    {
      "kind": "scene",
      "name": "ShippingBin",
      "scene_key": "shipping_bin",
      "position": {"x": 400, "y": 300},
      "properties": {}
    }
  ]
}
```

### 兼容注意事项

- 当前 `Farm.gd` 只会消费 `tiles` 二维数组
- 当前 `Farm.gd` 只认识 `scene_key`
- 新编辑器的多图层能力在兼容导出时需要降级
- 降级逻辑必须写进导出报告

## 10.2 资源兼容规则

| 资源类型 | 兼容输出路径 | 必须同步更新 |
|---|---|---|
| 玩家 sheet | `assets/sprites/characters/<file>.png` | `src/entities/player/Player.tscn` 或额外 patch |
| NPC sheet | `assets/sprites/characters/npc_sheets/<npc_id>_sheet.png` | `data/npcs.json` |
| NPC portrait | `assets/sprites/portraits/<npc_id>.png` | `data/npcs.json`, `data/dialogues.json` |
| 动物单图 | `assets/sprites/animals/<Animal>.png` | 对应 `.tscn` 如路径变化则 patch |
| 作物阶段图 | `assets/sprites/crops/<crop_id>_stageN.png` | `data/crops.json` |
| 作物收获图 | `assets/sprites/items/<crop_id>.png` | `data/items.json` 或 `data/crops.json.harvest_sprite` |
| 物品图标 | `assets/sprites/items/<item_id>.png` | `data/items.json` |
| 建筑贴图 | `assets/sprites/houses/<file>.png` | 相关对象脚本或配置 |

## 10.3 源素材归档规则

所有批准通过的 AI 素材必须同步归档到：

- `assets/source_art/generated/<category>/<entity>/<version>/`

至少保存：

- `master.png`
- `request.json`
- `response.txt`
- `metadata.json`

说明：

- 这延续当前仓库已有的 `assets/source_art/generated/` 习惯
- 运行时目录只放处理后的真正游戏资源

---

## 11. 资源规格标准

下表定义的是“新系统应该导出的运行时规格”，不是 AI 原始输出规格。

| 模板 | 运行时规格 | 说明 |
|---|---|---|
| `player_sprite_sheet` | PNG RGBA, `256x32`, 8 帧横排，每帧 `32x32` | 与当前 `Player.tscn` 兼容 |
| `npc_sprite_sheet` | PNG RGBA, `256x32`, 8 帧横排，每帧 `32x32` | 与当前 `NPC.gd` 兼容 |
| `npc_portrait` | PNG, `64x64` | 与当前对话数据兼容 |
| `animal_single` | PNG RGBA, `64x64` | 兼容当前动物单图 |
| `animal_sheet` | PNG RGBA，建议 `256x64` 或 `256x128` | 预留未来动画升级 |
| `item_icon` | PNG RGBA, `32x32` 或 `64x64` | 推荐统一为 `64x64` |
| `crop_stage_set` | 4 张或 5 张透明 PNG，建议 `64x64` | 适配当前作物显示 |
| `building_sprite` | PNG RGBA，高分辨率允许 | 由运行时脚本缩放 |
| `tileset_patch` | PNG RGBA, 按 atlas 子块规则 | 用于补充 tileset |

补充要求：

- 默认透明背景
- 不允许白底成品直接进入运行时目录
- 原始高分辨率图保留在 `source master`
- 运行时资源必须经过规格化处理

---

## 12. API 设计

以下 API 为建议实现形态，供实现 agent 直接参考。

## 12.1 Catalog API

### `GET /api/catalog/project-template/{project_id}`

返回目标项目模板，包括：

- map profiles
- object registry
- resource templates
- compatibility rules

### `GET /api/catalog/object-types`

返回对象定义与属性 schema。

### `GET /api/catalog/resource-templates`

返回资源模板定义。

## 12.2 Map API

### `POST /api/maps`

创建地图文档。

请求：

```json
{
  "project_id": "pastoral-tales",
  "profile_id": "farm",
  "name": "Farm Main"
}
```

### `GET /api/maps/{map_id}`

获取完整地图文档。

### `PUT /api/maps/{map_id}`

保存地图文档。

### `POST /api/maps/{map_id}/assist/generate`

根据文本描述生成地图初稿。

请求：

```json
{
  "instruction": "生成一个有主路、池塘、房屋前院和农田分区的农场地图",
  "scope": "whole_map",
  "constraints": {
    "must_keep_player_spawn": true,
    "allowed_tiles": ["grass", "path", "water", "wood_floor", "farmland"]
  }
}
```

### `POST /api/maps/{map_id}/assist/polish`

基于当前地图生成 patch。

## 12.3 Asset API

### `POST /api/assets`

创建资源条目。

### `POST /api/assets/{asset_id}/generate`

提交生成任务。

### `POST /api/assets/{asset_id}/variations`

基于某个候选继续出变体。

### `POST /api/assets/{asset_id}/approve`

批准某个候选成为导出版本。

### `GET /api/assets/{asset_id}/history`

读取生成历史、审核历史、导出历史。

## 12.4 Export API

### `POST /api/exports`

生成导出包。

请求：

```json
{
  "project_id": "pastoral-tales",
  "compatibility_mode": "godot-v1",
  "maps": ["farm_main"],
  "assets": ["npc_mayor_sheet", "npc_mayor_portrait"]
}
```

### `GET /api/exports/{export_id}`

获取导出状态、清单、报告。

---

## 13. AI 服务抽象

后端不要把 AI 调用逻辑直接写死在业务代码里，必须抽象 Provider 接口。

### 13.1 图像生成接口

```python
class ImageGenerationProvider(Protocol):
    def generate(self, request: ImageGenerationRequest) -> ImageGenerationResult: ...
    def create_variations(self, request: VariationRequest) -> VariationResult: ...
```

### 13.2 地图生成接口

```python
class MapGenerationProvider(Protocol):
    def generate_layout(self, request: MapGenerationRequest) -> MapPatchResult: ...
    def polish_layout(self, request: MapPolishRequest) -> MapPatchResult: ...
```

### 13.3 必须支持的任务类型

- `generate_asset`
- `generate_map`
- `polish_map`
- `generate_variations`
- `upscale_or_cleanup`
- `pixel_normalize`
- `export_runtime_asset`

---

## 14. Godot 兼容导入器要求

建议在主仓库里新增一个独立脚本，例如：

- `tools/import_resource_editor_export.py`

职责：

1. 读取导出包
2. 校验 manifest
3. 复制运行时资源到目标路径
4. 归档源素材
5. 应用 `data/*.json` patch
6. 生成导入报告
7. 可选触发 `bash scripts/check.sh`

### 14.1 CLI 示例

```bash
python tools/import_resource_editor_export.py \
  --export /path/to/export_20260401_001 \
  --project-root /home/admin/gameboy-workspace/pastoral-tales \
  --mode compatibility-v1 \
  --run-check
```

### 14.2 导入器必须具备的保护

- 不覆盖未声明的文件
- patch 前先备份目标 JSON
- patch 后重新校验 JSON 格式
- 输出所有变更列表
- 遇到不支持的 object type 必须报错，不允许静默忽略

---

## 15. 验收标准

## 15.1 地图验收

- 能创建 `farm` profile 地图，尺寸为 `50 x 35`
- 能导出兼容当前 `Farm.gd` 的 Tile JSON
- 能导出兼容当前 `data/farm_layout.json` 的对象 JSON
- `Farm.gd` 能读取导出结果并正常显示

## 15.2 资源验收

- 能生成并批准一个 NPC sprite sheet
- 能生成并批准一个 NPC portrait
- 能生成并批准一组 crop stage 图
- 导出后数据文件引用正确
- Godot 工程可加载资源且无路径错误

## 15.3 工程验收

- 导出包可重放
- 兼容导入器可重复执行
- 导入后 `bash scripts/check.sh` 通过
- 不出现硬编码 API Key 落库或入仓库

---

## 16. 分阶段实现建议

## Phase 1

- 项目模板
- `farm` map profile
- Tile 地图编辑
- 对象编辑
- 导出 `farm_layout` 兼容格式

## Phase 2

- 资源模板系统
- 图像生成任务队列
- 候选图审核
- 资源导出与数据 patch

## Phase 3

- AI 地图润色
- 地图 patch 审核
- 导入器与自动验证

## Phase 4

- 多地图 profile
- 动物动画资源
- tileset 局部生成
- 批量导出

---

## 17. 实现时必须特别注意的坑

### 17.1 不要直接复用当前临时编辑器数据模型

当前 `FarmLayoutEditor.gd` 只适合作为现状参考，不适合作为新系统的内部规范。

### 17.2 不要把当前 `30 x 20` 的旧地图 JSON 当成权威规格

权威规格应来自 Map Profile，农场当前应该是 `50 x 35`。

### 17.3 不要把 AI 原图直接塞进运行时目录

必须有：

- 源素材归档
- 运行时规格化

### 17.4 不要依赖 Godot 运行时的回退逻辑掩盖路径问题

例如 `ItemDatabase.gd` 的 icon fallback 只能作为兜底，不能作为主集成方式。

### 17.5 不要在前端持有任何 AI Provider 密钥

所有模型访问必须走后端。

---

## 18. 建议输出物

实现该 Web 项目的 agent，最终至少应交付：

1. 独立 Web 项目源码
2. `pastoral-tales` 项目模板配置
3. `farm` 的 map profile
4. 资源模板定义
5. AI provider 抽象层
6. 导出包 schema
7. Godot 兼容导入器
8. 导入报告样例
9. 至少一个端到端示例：
   - 新地图导出到 `Farm`
   - 一个 NPC 资源集导出并接入

---

## 19. 一句话结论

这个新项目本质上不应只是“另一个地图编辑器”，而应被定义为：

**一个面向 `Pastoral Tales` 的外部 Web 资源生产平台，内含地图编辑器、AI 资源生成器、AI 地图 Agent、版本审核系统，以及一套对当前 Godot 工程的稳定兼容导出协议。**
