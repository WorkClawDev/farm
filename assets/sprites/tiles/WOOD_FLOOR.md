# 室内木地板接入说明（给 Grok Build）

素材已备好，**不要 commit，先不要改场景/代码**（等 charswap 收口、统筹排单后再接）。

## 路径与规格

- 图集：`res://assets/sprites/tiles/wood_floor.png`（128×64，RGBA，硬边 alpha）
- 规格：16×16 源艺术 ×4 最近邻 = **64×64 / 格**，与 `GameConstants.WORLD_TILE_SIZE` 一致
- 布局（从左到右，单行两格）：
  - 格 0（`Rect2(0, 0, 64, 64)`）：净板，Kenney Roguelike 格 `(col=13, row=16)`
  - 格 1（`Rect2(64, 0, 64, 64)`）：磨损/节疤变体，格 `(col=18, row=18)`
- 过滤：`TEXTURE_FILTER_NEAREST`，不要生成 mipmaps
- 许可：Kenney Roguelike RPG Pack，CC0（署名见 `assets/third_party/kenney/ATTRIBUTION.md`）

两格左右/上下对边像素完全一致，单独 6×4 或按约 1/4 混铺，接缝处色差均为 0，可任意相邻。颜色是浅暖木色，能和锈棕门垫（`res://assets/sprites/props/doormat.png`）分开。

## 当前地面是怎么画的

运行时**不是** `PlayerHouseMap` 的 `Ground` TileMapLayer（该层 `visible = false`，16px 图集 `indoors_tiles.png`、`scale = Vector2(4, 4)`）。

实际看到的纯米色来自 `PlayerHouseMap/Decoration/IllustratedBackdrop`（`IllustratedMapBackdrop.gd`，`map_style = "house"`）里的 `_draw_house_fallback()`：

- 外圈 `OUTER_RECT`：`Color("#c4a882")`
- 内圈 `Rect2(80, 80, 960, 640)`：`Color("#e6d2b0")`（就是现在的地板）

`PlayerHouse.gd` 里的 `_setup_illustrated_backdrop()` / `_setup_tilemap()` 是旧路径，运行时不再走。门垫由 `_spawn_doormat()` 挂在 decoration 层，`z_index = -1`。

地图：`size_in_tiles = Vector2i(12, 7)`，原点在场景里 `(45, 50)`；Backdrop 本地再偏 `(-45, -50)`，所以填充坐标对齐房屋场景原点。格宽 64px。

## 建议接法（三选一，优先 1）

1. **改 `_draw_house_fallback()`（最贴现状）**  
   像村庄草地 / 沙滩那样用已有的 `_fill_tiles(tex, rect, alt)`。把两格做成 `AtlasTexture`（或两张 ImageTexture），主纹理用格 0，`alt` 用格 1。内圈 `Rect2(80, 80, 960, 640)` 换成铺木板；外圈可继续用 `#c4a882`，或同样铺木板。Backdrop 已是 `TEXTURE_FILTER_NEAREST`，`CELL = 64`。

2. **打开并改 Ground `TileMapLayer`**  
   把 `PlayerHouseMap.tscn` 的 Ground 设为可见，TileSet 指向 `wood_floor.png`。若图集按 **64px** 源导入，层 `scale` 改为 `(1, 1)`，`tile_size = 64`；若保持 16px 源 + `scale (4, 4)`，需要另出 16px 图集（不建议混用当前 64px 图）。按格交错放置变体 0/1。地图现为 12×7，只盖可行走区域，四周仍可能露出 Backdrop 纯色，需一并处理。

3. **不建议用普通 `TextureRect` 拉伸。** 若用 Control，必须 `stretch_mode = STRETCH_TILE`，尺寸对齐 64 像素，并同样用最近邻。

预览：`playtest/screenshots/wood_floor_preview.png`（左旧米色，右 8×6 混铺 + 门垫）。
