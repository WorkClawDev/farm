# Kenney assets (Stage C)

- Tiny Town — https://kenney.nl (CC0)
- Roguelike RPG Pack — https://kenney.nl (CC0)

Credit to Kenney (www.kenney.nl) appreciated, not required.

## Used in this project
- Farm ground atlas (`assets/tiles/kenney/farm_ground_atlas_64.png`): Tiny Town grass/dirt/fence + Roguelike water (1px seams cropped via stride-17 extract).
- Outdoor decor (`assets/tiles/kenney/decor/`): trees, well, fences, houses, flowers for IllustratedMapBackdrop (Village/Forest/Beach).
- Scale: 16×16 source → ×4 nearest-neighbor → 64px grid.

- Beach sand/water (`decor/sand_64.png`, `sand2_64.png`, `water_64.png`, `water2_64.png`): cropped from `farm_ground_atlas_64.png` (Tiny Town dirt + Roguelike water) for BUG-51.
- Beach sand and sea (`assets/tiles/kenney/roguelikeSheet_transparent.png`): Roguelike RPG sheet cols 8/0 sand, cols 0/0 sea, cols 10-12 rows 7-9 sand-edged pool. `beach_tiles.png` kept.

- UI Pack - Pixel Adventure 2.0 (CC0, `ui_pixel_adventure/`): Large tiles / Thick outline tile_0000, 0002, 0006, 0007, 0013, 0018, 0019, 0033 (used as 9-slice StyleBoxTexture by the UI v1 theme). Kept in the repo but not referenced by the current UI v2 theme (`src/ui/theme/GameTheme.tres`).
- Beach shore x4 (`assets/tiles/kenney/beach_x4/`): pre-cut 64px tiles from Roguelike RPG sheet (sand col 8 rows 0-1, sea col 0 row 0, pool 3x3 cols 10-12 rows 7-9). `shore_edge_a/b.png` are derived by us (sand + wet band + foam + sea from those cells), CC0-based.
