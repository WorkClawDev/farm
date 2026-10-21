# Kenney assets (Stage C)

- Tiny Town — https://kenney.nl (CC0)
- Roguelike RPG Pack — https://kenney.nl (CC0)

Credit to Kenney (www.kenney.nl) appreciated, not required.

## Used in this project
- Farm ground atlas (`assets/tiles/kenney/farm_ground_atlas_64.png`): Tiny Town grass/dirt/fence + Roguelike water (1px seams cropped via stride-17 extract).
- Outdoor decor (`assets/tiles/kenney/decor/`): trees, well, fences, houses, flowers for IllustratedMapBackdrop (Village/Forest/Beach).
- Scale: 16×16 source → ×4 nearest-neighbor → 64px grid.

- Beach sand/water (`decor/sand_64.png`, `sand2_64.png`, `water_64.png`, `water2_64.png`): cropped from `farm_ground_atlas_64.png` (Tiny Town dirt + Roguelike water) for BUG-51.

- UI Pack - Pixel Adventure 2.0 (CC0, `ui_pixel_adventure/`): Large tiles / Thick outline tile_0000, 0002, 0006, 0007, 0013, 0018, 0019, 0033 (used as 9-slice StyleBoxTexture by the UI v1 theme). Kept in the repo but not referenced by the current UI v2 theme (`src/ui/theme/GameTheme.tres`).
