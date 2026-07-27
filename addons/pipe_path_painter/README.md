# Pipe Path Painter

Editor-only tool for drawing pipe-style runs on a `TileMapLayer`. Drag a path
and every cell resolves to the right straight, L turn, T junction, cross or
dead end on its own -- and crossing something already on the layer merges with
it instead of stamping over it.

## Setup

1. Enable **Pipe Path Painter** in *Project -> Project Settings -> Plugins*.
2. Select a `TileMapLayer`. A **Pipe Path** strip appears in the 2D viewport
   toolbar.
3. Press **Configure Tiles...** and assign the 15 shapes (see below). Nothing
   paints until a shape has a tile.

Assignments are saved per **TileSet**, in `pipe_tiles.cfg` next to this file,
so configuring a tileset once covers every layer that uses it.

## Drawing

| Action | Result |
| --- | --- |
| Toggle **Pipe Path** off | The layer edits exactly as it normally does |
| LMB drag | Paint a freehand path, snapped to 90-degree turns |
| RMB drag | Erase along the path |
| Hold **Shift** | The stroke becomes a straight run from where you are to the cursor |
| Hold **Alt** | That run travels vertically first instead of horizontally |
| Drag back one cell | Un-draws the last step, so you can correct without releasing |
| `Esc` mid-drag | Cancel |
| `Ctrl+Z` | Undoes the whole stroke as one action |

Shift and Alt are read live, so you can flip either one mid-drag and watch the
preview change. Releasing Shift bakes the previewed line into the trail and
freehand carries on from its end -- Shift-line and freehand segments compose in
a single stroke. Alt does nothing outside line mode, by design.

The preview draws each cell with the connections it will end up with, so a
merge is visible before you commit. Cells whose shape has no tile assigned
draw amber and are skipped rather than painted wrong.

> **If dragging does nothing:** collapse the *TileMap* bottom panel. When that
> panel is open with a paint tool selected, Godot's built-in tile editor claims
> viewport clicks before any plugin sees them.
>
> Only one of Pipe Path and Rect Paint can be armed at a time; switching one on
> switches the other off.

## Merging

Every pipe tile is really a 4-bit mask of which sides it connects to. Painting
combines masks with OR, which is where the merge behaviour comes from:

| Situation | Result |
| --- | --- |
| Horizontal run passes through a vertical pipe | `E-W \| N-S` = **Cross** |
| Horizontal run stops on a vertical pipe | `W \| N-S` = **Tee West** |
| A neighbouring tile already points into a cell | That connection is honoured, so junctions never render half-drawn |
| **Join ends** on, path starts/stops beside a pipe | The two are connected and the neighbour is upgraded to a T |

**Join ends** only applies at the two endpoints of a stroke. A path running
alongside an existing pipe is never welded to it along its length.

Erasing runs the same rule backwards: neighbours lose the connection that
pointed into the erased cell, so a cross demotes to a T, a T to a corner, and
a stub with nothing left to hold onto is removed too.

## The 15 shapes

`Configure Tiles...` lists them with a connection diagram beside each one, so a
name can't be misread. The atlas is drawn on the right; select a slot, click
its tile. With **Auto-advance** on it jumps to the next unassigned slot, so all
15 take 15 clicks. Tiles you've already assigned are tinted green in the atlas
with a miniature diagram, and hovering any tile shows its coordinate and a
blown-up preview.

| Category | Slots |
| --- | --- |
| Straights | Straight Horizontal (E-W), Straight Vertical (N-S) |
| L Turns | Turn North-East, North-West, South-East, South-West |
| T Junctions | Tee North (N-E-W), Tee East (N-E-S), Tee South (E-S-W), Tee West (N-S-W) |
| Four-Way | Cross |
| Dead Ends | End North, End East, End South, End West |

A **Tee**/**End** is named for the direction that makes it distinctive: *Tee
North* is the one whose extra arm points north, *End North* the stub whose only
opening faces north. The connected sides are spelled out in each row's tooltip.

Godot's own tile palette doesn't publish a drag payload a plugin can accept,
which is why the atlas is redrawn inside the dialog rather than dragged out of
the palette.

## Where the rules live

`pipe_tile_layout.gd` holds all of it and touches no engine state:

- `NAME_TO_MASK` -- the 15 shapes. Masks are fixed by geometry; renaming a slot
  orphans its saved coordinate.
- `bridge_cells` / `line_cells` -- axis-aligned pathing, never diagonal.
- `path_masks` -- connections implied by walking a path. A path that crosses
  itself makes its own four-way with no help from the layer.
- `resolve_paint` / `resolve_erase` -- the merge rules. Both take the existing
  layer as a `Callable`, so they can be exercised without a live TileMapLayer.
- `SINGLE_CELL_MASK` -- what a single click with nothing to connect to becomes.
  Defaults to a horizontal straight.
