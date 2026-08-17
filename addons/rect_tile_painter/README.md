# Rect Tile Painter

Editor-only tool for filling rectangles on a `TileMapLayer` without round-tripping
through the TileSet palette. Drag a box, and the plugin picks the right corner /
edge / fill tile for every cell automatically.

With **Sum** on it stops stamping rectangles and starts editing a *shape*: drags
union and subtract into whatever this region already painted, and the whole
outline is re-tiled so two overlapping drags come out as one chunk of terrain.

## Setup

1. Enable **Rect Tile Painter** in *Project -> Project Settings -> Plugins*.
2. Select any `TileMapLayer` in the scene tree. A **Rect Paint** strip appears in
   the 2D viewport toolbar.
3. Flip the toggle on and set **Src** (atlas source id, usually `0`) and
   **Region** (the atlas X/Y of the *top-left* tile of your block).

The region is remembered per **TileSet**, not per node — configure it once and
every layer using that tileset picks it up. Settings live in
`tileset_regions.cfg` next to this file.

Both modes read from the **same origin**. Basic mode uses the 4x4 block at that
origin; Sum mode uses the 8x6 block at that origin, whose top-left 4x4 *is* that
same 4x4. Switching modes never means re-entering coordinates.

## Using it

| Action | Basic (Sum off) | Summation (Sum on) |
| --- | --- | --- |
| LMB drag | Stamp the rectangle | **Add** the rectangle to the shape |
| RMB drag | Erase the rectangle | **Subtract** the rectangle from the shape |
| `Esc` mid-drag | Cancel | Cancel |
| `Ctrl+Z` | Undoes the whole drag as one action | Same |

Toggle **Rect Paint** off and the layer edits exactly as it normally does; the
plugin stops touching viewport input, and the rest of the strip collapses so it
isn't stretching the viewport. Your settings are kept.

The drag label shows `+` or `-` in Sum mode, so the button you are holding always
says what it is about to do.

> **If dragging does nothing:** collapse the *TileMap* bottom panel. When that
> panel is open with a paint tool selected, Godot's built-in tile editor claims
> viewport clicks before any plugin sees them.

## The (i) popover

Hovering the **(i)** next to the Region spinners pops a read-only preview of
exactly what the painter is about to scan: the real pixels of the region, on the
region's own grid, with the piece name and absolute atlas coord on every cell.
Cells the source has no tile for are tinted red.

It is deliberately read-only. Which piece lives at which coordinate is a fact
about the art, not a per-project setting, so it lives in code and nothing
in-engine can rebind it.

## Region presets

The dropdown beside the (i) stores named `Src` + `Region` pairs per TileSet, so
flipping between two tilesheets is one click instead of remembering four numbers.

- **+** saves the current Src + Region under a name (re-saving a name overwrites).
- **-** deletes the selected preset.

Presets work in both modes and are saved into `tileset_regions.cfg` alongside the
region itself, under the tileset's resource path.

## The 8x6 layout

Every coordinate is *relative* to the region origin you set in the toolbar, so
the same dictionary works for any tileset that arranges its block the same way.
`DebugRectText/Debug TerrainGen.png` is the reference sheet this was read off:
**red = big-block walls, yellow = small-block walls** (anything 1 tile wide or 1
tile tall), **green = the lone 1x1**, **blue = interior**, i.e. the part of the
cell that is inside the shape.

```
        x=0          x=1          x=2          x=3          x=4          x=5          x=6          x=7
 y=0  Col Top      Corner TL    Edge Top     Corner TR    Inner BR     Inner BL     Step L-T     Step L-B
 y=1  Col Mid      Edge Left    Fill         Edge Right   Inner TR     Inner TL     Step R-T     Step R-B
 y=2  Col Bot      Corner BL    Edge Bottom  Corner BR    Small Cnr TL Small Cnr TR Step T-L     Step T-R
 y=3  Single       Bar Left     Bar Mid      Bar Right    Small Cnr BL Small Cnr BR Step B-L     Step B-R
 y=4  Big Tee T    Big Tee B    Small Tee R  Small Tee L  Dbl TL-BR    StepCnr TL   StepCnr TR   Small Cross
 y=5  Big Tee L    Big Tee R    Small Tee T  Small Tee B  Dbl TR-BL    StepCnr BL   StepCnr BR   --
```

All 47 drawn tiles have a name; the only empty slot is `(7,5)`. The top-left 4x4
is untouched, so basic mode is bit-for-bit what it always was.

Pieces the sheet draws as a bare corner nub straddling a 2x2 of tiles are four
orientations of one piece, one per tile — the nub sits in the corner of the tile
it belongs to.

- **Inner corner** — a cell walled in on all four sides but missing one
  *diagonal* neighbour. Named for the corner the nub sits in, which faces the
  hole. This is what an L-shaped union needs at its reflex corner.
- **Double inner corner** — the same cell, but with *both* diagonals of one axis
  missing, so it takes two nubs. This is what the inside of a filled hashtag
  needs. Named for the two notched corners: `Top Left Bottom Right` is the `\`
  pair, `Top Right Bottom Left` the `/` pair.
- **Small corner** — a 1-wide run turning 90 degrees. Named like the big corners:
  `Top Left` means the walls are on the top and left.
- **Big tee** — a big block's edge cell with a 1-wide arm branching out of it,
  named for where the arm points.
- **Small tee** — three 1-wide runs meeting, named for the odd arm out.
- **Step** — a big block's *edge* cell whose perpendicular neighbour is a 1-wide
  arm, i.e. the arm leaves flush with the block instead of centred in it, so the
  wall jogs from 4px down to 2px. Named `Step <wall side> <arm side>`, and laid
  out on that grid: row picks the wall, column picks the arm.
- **Step corner** — the corner counterpart: both open sides of a block *corner*
  carry a 1-wide arm, so the cell reads as a pseudo 4-way. Named for which corner
  of the block it is, like the plain corners — `Top Left` means the arms leave up
  and left. Three nubs, one per pair of walls that meet; the inside corner stays
  open.

`rect_tile_layout.gd` holds all of it as one dictionary:

```gdscript
const NAME_TO_TILE: Dictionary[String, Vector2i] = {
    "Vertical Column Top": Vector2i(0, 0),
    ...
    "Small Cross": Vector2i(4, 4),
}
```

If your art puts a piece somewhere else in the block, change that one
`Vector2i` — nothing else in the plugin hardcodes a position.

## Which tile goes where

### Basic mode

`RectTileLayout.tile_name_at(column, row, width, height)` is the whole rule:

- `1x1` → `Single`
- `1xN` → `Vertical Column Top` / `Middle` / `Bottom`
- `Nx1` → `Horizontal Bar Left` / `Middle` / `Right`
- `NxM` → the 3x3 block, with `Fill` for every interior cell

### Summation mode

`RectTileLayout.terrain_tile_name(is_thick, filled, thin_sides)` is the whole
rule, and it is a pure function of the eight neighbours.

A cell is **thick** when it belongs to a solid 2x2 anywhere, and **thin**
otherwise. That is exactly the old rule generalised: drag a `1xN` and every cell
is thin, drag anything fatter and they are all thick — so a single rectangle
painted in Sum mode comes out identical to the same rectangle in basic mode.

| Cell | Neighbours | Piece |
| --- | --- | --- |
| thick | one side open | `Edge <side>` |
| thick | two adjacent sides open | `Corner <v> <h>` |
| thick | one side open, a perpendicular side is a thin arm | `Step <wall> <arm>` |
| thick | boxed in, one side is a thin arm | `Big Tee <arm>` |
| thick | boxed in, two perpendicular sides are thin arms | `Step Corner <v> <h>` |
| thick | boxed in, one diagonal open | `Inner Corner <diagonal>` |
| thick | boxed in, both diagonals of one axis open | `Double Inner Corner <v> <h> <v> <h>` |
| thick | boxed in, nothing missing | `Fill` |
| thin | 0 neighbours | `Single` |
| thin | 1 neighbour | the capped end of a run |
| thin | 2 opposite | `Column Middle` / `Bar Middle` |
| thin | 2 adjacent | `Small Corner <v> <h>` |
| thin | 3 | `Small Tee <odd arm>` |
| thin | 4 | `Small Cross` |

Membership is *derived*, not stored: a cell belongs to the shape when its source
id matches and its atlas coord lands inside the configured region. So the tool
picks up terrain painted in earlier sessions, and it will never claim — or erase
— a cell belonging to some other part of the tileset.

Each drag re-picks tiles two cells beyond the rectangle (`RETILE_MARGIN`), and
reads occupancy two cells beyond that, because adding a cell changes its
neighbours' thickness, which changes *their* neighbours' pieces.

## Drawing the sheet incrementally

The painter never trusts a coordinate blindly. For every cell it walks the
piece's `FALLBACK` chain and uses the first coordinate the tileset **actually has
a tile at**, so a sheet that hasn't been extended yet degrades to the nearest
piece instead of leaving holes.

**Every substitution is reported.** The status text turns orange with a count and
the Output panel names the piece, the coord it wanted and what it drew instead. A
silent fallback is indistinguishable from the tool picking the wrong piece, so it
never happens quietly — if a drag comes out looking wrong, check Output first.

Note that a tile has to *exist in the atlas source*, not merely have pixels under
it. A `TileSetAtlasSource` only has a tile where one was created, so art you drew
into the sheet after setting the tileset up is invisible to the painter until you
create those tiles too.

Every piece in the reference sheet is drawn, but an individual tileset may not
have caught up yet — that is what the chain is for:

- The 8 **step** pieces fall back to the plain `Edge` piece, so you get a visible
  seam where the wall thickness changes, never a wrong shape.
- The 4 **step corner** pieces fall back to `Fill`. The plain corner piece would
  be worse, not better: both of that corner's sides are open here, so `Corner`
  would wall the two arms off.

Two situations have no piece anywhere and always take a seam:

- **Adjacent-notch inner corners** — a cell boxed in on all four sides with two
  *adjacent* diagonals missing, or three, or four. Singles and opposite pairs
  both have art; anything else takes the first notch and seams the rest.
- **Three or more arms off one thick cell**, or two arms leaving straight through
  opposite sides. Both resolve to `Fill`.

The (i) popover tints any mapped-but-absent tile red and counts them in its
footer, so it doubles as a to-draw list.

## Debugging the dictionary

The **Tile** dropdown lists every mapped name. Leave it on `Auto` for normal use;
pick a name to flood the entire dragged rect with that one tile. That is the
fastest way to confirm an entry points where you think it does — drag a 3x3 with
`Corner Top Left` selected and see nine of them appear.

It is disabled in Sum mode, which has to decide per cell.

The status text on the right shows the resolved region and turns orange if the
configured tiles do not exist in the tileset. Cells whose tile is missing get
skipped rather than painted wrong, and the names are pushed to the Output panel.
