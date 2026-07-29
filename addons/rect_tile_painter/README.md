# Rect Tile Painter

Editor-only tool for filling rectangles on a `TileMapLayer` without round-tripping
through the TileSet palette. Drag a box, and the plugin picks the right corner /
edge / fill tile for every cell automatically.

## Setup

1. Enable **Rect Tile Painter** in *Project -> Project Settings -> Plugins*.
2. Select any `TileMapLayer` in the scene tree. A **Rect Paint** strip appears in
   the 2D viewport toolbar.
3. Flip the toggle on and set **Src** (atlas source id, usually `0`) and
   **Region** (the atlas X/Y of the *top-left* tile of your 4x4 block).

The region is remembered per **TileSet**, not per node — configure it once and
every layer using that tileset picks it up. Settings live in
`tileset_regions.cfg` next to this file.

## Using it

| Action | Result |
| --- | --- |
| Toggle **Rect Paint** off | The layer edits exactly as it normally does; the plugin stops touching viewport input, and the rest of the strip collapses so it isn't stretching the viewport. Your settings are kept. |
| LMB drag | Fill the rectangle |
| RMB drag | Erase the rectangle |
| `Esc` mid-drag | Cancel |
| `Ctrl+Z` | Undoes the whole rectangle as one action |

The status text on the right shows the resolved region and turns orange if the
configured tiles do not exist in the tileset. Cells whose tile is missing get
skipped rather than painted wrong, and the names are pushed to the Output panel.

> **If dragging does nothing:** collapse the *TileMap* bottom panel. When that
> panel is open with a paint tool selected, Godot's built-in tile editor claims
> viewport clicks before any plugin sees them.

## The 4x4 layout

Every coordinate is *relative* to the region origin you set in the toolbar, so
the same dictionary works for any tileset that arranges its block the same way.

```
        x=0              x=1            x=2            x=3
 y=0  Col Top         Corner TL      Edge Top       Corner TR
 y=1  Col Mid         Edge Left      Fill           Edge Right
 y=2  Col Bot         Corner BL      Edge Bottom    Corner BR
 y=3  Single          Row Left       Row Mid        Row Right
```

`rect_tile_layout.gd` holds this as one dictionary:

```gdscript
const NAME_TO_TILE: Dictionary[String, Vector2i] = {
    "Vertical Column Top": Vector2i(0, 0),
    ...
    "Fill": Vector2i(2, 1),
}
```

If your art puts a piece somewhere else in the block, change that one
`Vector2i` — nothing else in the plugin hardcodes a position.

## Which tile goes where

`RectTileLayout.tile_name_at(column, row, width, height)` is the whole rule:

- `1x1` → `Single`
- `1xN` → `Vertical Column Top` / `Middle` / `Bottom`
- `Nx1` → `Horizontal Bar Left` / `Middle` / `Right`
- `NxM` → the 3x3 block, with `Fill` for every interior cell

## Debugging the dictionary

The **Tile** dropdown lists every name in `NAME_TO_TILE`. Leave it on `Auto` for
normal use; pick a name to flood the entire dragged rect with that one tile.
That is the fastest way to confirm an entry points where you think it does —
drag a 3x3 with `Corner Top Left` selected and see nine of them appear.
