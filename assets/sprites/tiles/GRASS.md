# 农场草地（方案 B，成丛变体）

用仓库内绘制的 9 个 16px 变体（最近邻 ×4）替换原来的单格底草。运行时按格子坐标做确定性散布，不改 `FarmMap.tscn` 的 Ground 数据。

已否决：方案 A（草丛太小，1280×720 下几乎看不见），以及更早的 v1 AI 换图（`grass_swap/`，整格换纹理、没有成丛变体）。不要再用那两套源图覆盖本图集。

## 游戏里草地从哪来

农场地面是 `FarmMap.tscn` 的 `Ground` TileMapLayer，TileSet 为 `assets/tiles/farm_tileset.tres`，纹理是：

`assets/tiles/kenney/farm_ground_atlas_64.png`

图集 **2176×64，34 列 × 1 行，每格 64×64，无间距**。

| 图块坐标 | 用途 |
|---|---|
| `(0, 0)` | v0 纯底（约 35%）。场景里大面积草仍写成这一格 |
| `(1, 0)` | 旧 `GRASS_2`，农场 Ground 未使用；山谷图里有，散布时不要改 |
| `(2, 0)`..`(25, 0)` | 原有装饰 / 路 / 水 / 篱笆 / 木板 / 耕地 / 石板 / 草堆等，像素未改 |
| `(26, 0)`..`(33, 0)` | v1..v8 草丛、小花、浅/深影斑。只由运行时散布写入内存，不写进场景 |

进农场时（`Farm.gd` `_setup_map`，山谷图同样）对当前 atlas 为 `(0, 0)` 的格调用 `FarmTilesetBuilder.scatter_grass`。v0 仍是 `(0, 0)`，其余改到 26–33。哈希只依赖格子 `(x, y)` 和固定常量，不用 `randi`，所以每次启动和读档后图案相同。

判断「这格是不是草」必须用 `FarmTilesetBuilder.is_grass(coords)`（`(0, 0)`、`(1, 0)`、`(26, 0)`..`(33, 0)`），不要写 `atlas == Vector2i(0, 0)`。若以后要把某格还原成草，调用 `grass_atlas_at(cell)`，不要写死 `(0, 0)`。

存档不保存 Ground 变体坐标（`FarmState` 只存耕种网格和玩家土路格子）。不要把变体写进存档。

Godot 的 `TileData.probability` 只在编辑器绘制时生效，运行时不会自动散。

## 变体与色板

源规格见 `/workspace/farm_asset_candidates/grass_v2b/README.md`。2px 边距，四边纯底色，可无缝拼接。

| id | 图集列 | 内容 | 哈希权重 |
|---|---|---|---|
| v0_plain | 0 | 纯底 | 35% |
| v1_fan | 26 | 一簇 7×5，三片竖叶，中间最高 | 16% |
| v2_wide | 27 | 一簇 9×6，五片叶，高低不齐 | 12% |
| v3_two | 28 | 两簇（左倾 + 小簇） | 12% |
| v4_three | 29 | 三簇（左倾、右倾、小簇） | 8% |
| v5_tuft_flowers | 30 | 一簇 + 3 朵黄花 | 7% |
| v6_two_flowers | 31 | 两簇 + 2 朵粉花 | 4% |
| v7_patch_dark | 32 | 不规则深影斑 + 小簇 | 4% |
| v8_patch_light | 33 | 不规则浅影斑 | 2% |

底色 `(134, 196, 106)`。叶深 `(96, 156, 74)`、叶中 `(118, 180, 90)`、叶尖 `(160, 216, 122)`。浅/深影斑只 ±6：`(140, 202, 112)` / `(128, 190, 100)`。

邻格避让：若本格不是纯底，且西格或北格的原始变体相同，则另挑一个 1..8。具体函数、锚点测试和接入步骤见同目录 `INTEGRATION.md`（接入后以 `FarmTilesetBuilder.gd` 为准）。

没有改这些：

- `assets/tiles/kenney/decor/grass_64.png`、`grass2_64.png`（村子/森林/海滩的 IllustratedMapBackdrop）
- `assets/tiles/farm/grass.png`（16px 旧占位，运行时未引用）
- `assets/tiles/farm_ground_atlas.svg`、`assets/tiles/farm_tiles.png`
- `dirt_path_atlas_alpha.png`（草色本来就是透明的，新草地会从底下露出来）
- `cliff_atlas_farm.png`（低地草已是透明，高地草仍用原来的 `HIGH_FARM` 色坡）

## 源图与授权

- 9 个变体由仓库内 `/workspace/farm_asset_candidates/grass_v2b/build_grass_v2b.py` 逐像素绘制（16px 源图，最近邻 ×4 得到 64px）。候选目录 README 写明色板、变体内容和「未改游戏文件」的提案性质。**没有第三方像素，不需要署名。**
- 不是 v1 的 AI 样张（`assets/source_art/ai_samples/processed/16px/grass.png` 等），不要把那些图重新贴进第 0 格。
- 图集第 1–25 格仍是原 Kenney Tiny Town / Roguelike 等内容（以及既有改色），沿用 `assets/third_party/kenney/ATTRIBUTION.md`。

## 备份与重建

- 接入用候选图集：`/workspace/farm_asset_candidates/grass_v2b/farm_ground_atlas_64_v2b.png`（第 0 格 = v0，追加 v1–v8，第 1–25 格与接入前逐像素相同）
- 合成脚本：`/workspace/farm_asset_candidates/grass_v2b/compose_atlas_v2b.py`（`python3 compose_atlas_v2b.py`，只写候选目录和预览）
- 变体源脚本：`/workspace/farm_asset_candidates/grass_v2b/build_grass_v2b.py`
- 散布预览：`playtest/screenshots/grass_v2b_scatter_preview.png`
- 方案对照（接入前）：`playtest/screenshots/grass_v2_options.png`

接入步骤、哈希实现、测试和验收见 `/workspace/farm_asset_candidates/grass_v2b/INTEGRATION.md`。
