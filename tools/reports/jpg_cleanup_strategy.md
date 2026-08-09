# JPG Cleanup Strategy

This report tracks cleanup status after the PNG replacement batches.
The major delete batches have now been executed.

## Summary

- Runtime `data/` and `src/` references to old `.jpg` assets: `0`
- JPG files that still have same-name PNG replacements: `0`
- JPG files that still have no PNG replacement and should be kept: `22`

## Completed Cleanup

These cleanup batches have already been executed:

- `assets/sprites/houses`
- `assets/sprites/items`
- safe subset of `assets/tiles/village`
- safe subset of `assets/tiles/indoors`

Their old JPG files and matching `.jpg.import` sidecars have already been removed.

## Remaining JPG Assets

No delete candidates remain with same-name PNG replacements.
The remaining JPGs below are the keep-list until they are manually reviewed.

## Keep

These JPGs should stay for now because they were intentionally skipped,
are still source-only, or do not have safe PNG replacements yet.

- `assets/sprites/houses/floor_tiles.jpg`
- `assets/sprites/houses/wall_tiles.jpg`
- `assets/source_art/items/reference/crystal.jpg`
- `assets/sprites/ui/festival/fall_harvest_bg.jpg`
- `assets/sprites/ui/festival/spring_festival_bg.jpg`
- `assets/sprites/ui/festival/summer_beach_bg.jpg`
- `assets/sprites/ui/festival/winter_festival_bg.jpg`
- `assets/tiles/indoors/indoor_door.jpg`
- `assets/tiles/indoors/indoor_floor_carpet.jpg`
- `assets/tiles/indoors/indoor_floor_stone.jpg`
- `assets/tiles/indoors/indoor_floor_wood.jpg`
- `assets/tiles/indoors/indoor_stairs.jpg`
- `assets/tiles/indoors/indoor_wall_plaster.jpg`
- `assets/tiles/indoors/indoor_wall_stone.jpg`
- `assets/tiles/indoors/indoor_wall_wood.jpg`
- `assets/tiles/village/village_fence_stone.jpg`
- `assets/tiles/village/village_fence_wood.jpg`
- `assets/tiles/village/village_grass.jpg`
- `assets/tiles/village/village_road_dirt.jpg`
- `assets/tiles/village/village_road_stone.jpg`
- `assets/tiles/village/village_roof_shingle.jpg`
- `assets/tiles/village/village_roof_tile.jpg`

## Sidecar Status

All `.jpg.import` sidecars for already-cleaned JPG files should now be gone.
For the keep-list above, the matching `.jpg.import` files should remain.

## Tooling / Report Notes

These are not runtime blockers, but they still need small maintenance:

- `tools/fix_white_backgrounds.py`

Recommended handling:

- Keep `tools/white_to_alpha.py` as-is. It should continue to support JPG input.
- The old generated `white_background_report.json` has been removed because it was stale.
- Keep `jpg_cleanup_strategy.md` as the current source of truth.
- Keep `fix_white_backgrounds.py`, but ensure its example commands only reference existing files.

## Recommended Order

1. Commit all generated PNGs.
2. Keep the remaining 22 JPG files until they are reviewed one by one.
3. If more PNG replacements are created later, delete the matching JPG and `.jpg.import` together.
