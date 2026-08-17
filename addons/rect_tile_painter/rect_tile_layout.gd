@tool
class_name RectTileLayout
extends RefCounted

## Single source of truth for "which named piece lives where in the tileset".
##
## Two layouts share one origin, so a tileset only ever needs ONE coordinate
## configured no matter which mode you paint in:
##
##   BASIC   -- the original 4x4 block. `tile_name_at()` drives it. Untouched.
##   TERRAIN -- a 6x6 block whose top-left 4x4 IS the basic block, byte for
##              byte, plus the pieces summation mode needs.
##              `terrain_tile_name()` drives it.
##
## Nothing else in the plugin hardcodes a coordinate. To move a piece, edit
## NAME_TO_TILE below and you are done -- the toolbar, the (i) popover, the
## painter and the warnings all read it from here. The editor UI is
## deliberately read-only about this table: the (i) popover previews what is
## being scanned, but nothing in-engine can rebind a name to a coordinate.
##
## The 8x6 terrain block, exactly as laid out in
## DebugRectText/Debug TerrainGen.png. All 47 drawn tiles have a name here; the
## only empty slot is (7,5).
##
##          x=0          x=1          x=2         x=3          x=4         x=5         x=6         x=7
##   y=0  Col Top      Corner TL    Edge Top    Corner TR    Inner BR    Inner BL    Step L-T    Step L-B
##   y=1  Col Mid      Edge Left    Fill        Edge Right   Inner TR    Inner TL    Step R-T    Step R-B
##   y=2  Col Bot      Corner BL    Edge Bottom Corner BR    Small TL    Small TR    Step T-L    Step T-R
##   y=3  Single       Bar Left     Bar Mid     Bar Right    Small BL    Small BR    Step B-L    Step B-R
##   y=4  Big Tee T    Big Tee B    Small Tee R Small Tee L  Dbl TL-BR   StepCnr TL  StepCnr TR  Small Cross
##   y=5  Big Tee L    Big Tee R    Small Tee T Small Tee B  Dbl TR-BL   StepCnr BL  StepCnr BR  --
##
## Reading the debug sheet: red = big-block walls (4px), yellow = small-block
## walls (2px, anything 1 tile wide or 1 tile tall), green = the lone 1x1,
## blue = interior, i.e. the part of the cell that is inside the shape.
## Pieces drawn as a bare corner nub straddling a 2x2 of tiles are four
## orientations of one piece, one per tile -- the nub sits in the corner of the
## tile it belongs to.

#region Region geometry

## Size of the region BASIC mode reads from, in tiles.
const REGION_SIZE := Vector2i(4, 4)

## Size of the region TERRAIN (summation) mode reads from, in tiles. The basic
## block is its top-left corner, so switching modes never moves the origin.
const TERRAIN_REGION_SIZE := Vector2i(8, 6)


static func region_size(terrain: bool) -> Vector2i:
	return TERRAIN_REGION_SIZE if terrain else REGION_SIZE

#endregion


#region The table

## Marks a piece the art does not have yet. Anything mapped to this falls
## through FALLBACK instead of painting a wrong tile.
const UNMAPPED := Vector2i(-1, -1)

## Converts a human readable name into region coords. THIS IS THE TABLE TO EDIT.
const NAME_TO_TILE: Dictionary[String, Vector2i] = {
	# -- Original 4x4 block. Do not renumber; basic mode depends on it. -----
	"Vertical Column Top": Vector2i(0, 0),
	"Vertical Column Middle": Vector2i(0, 1),
	"Vertical Column Bottom": Vector2i(0, 2),
	"Corner Top Left": Vector2i(1, 0),
	"Edge Top": Vector2i(2, 0),
	"Corner Top Right": Vector2i(3, 0),
	"Edge Left": Vector2i(1, 1),
	"Fill": Vector2i(2, 1),
	"Edge Right": Vector2i(3, 1),
	"Corner Bottom Left": Vector2i(1, 2),
	"Edge Bottom": Vector2i(2, 2),
	"Corner Bottom Right": Vector2i(3, 2),
	"Single": Vector2i(0, 3),
	"Horizontal Bar Left": Vector2i(1, 3),
	"Horizontal Bar Middle": Vector2i(2, 3),
	"Horizontal Bar Right": Vector2i(3, 3),

	# -- Big-block inner corners -------------------------------------------
	# A cell walled in on all four sides but missing one DIAGONAL neighbour.
	# Named for the corner the nub sits in, which is the corner facing the
	# hole. This is the piece an L-shaped union needs at its reflex corner.
	"Inner Corner Bottom Right": Vector2i(4, 0),
	"Inner Corner Bottom Left": Vector2i(5, 0),
	"Inner Corner Top Right": Vector2i(4, 1),
	"Inner Corner Top Left": Vector2i(5, 1),

	# -- Big-block inner corners, opposite pair ----------------------------
	# Same cell, but BOTH diagonals of one axis are missing -- what the inside
	# of a filled hashtag looks like. Named for the two corners that are
	# notched. (These live down at x=4 rather than beside the singles above.)
	"Double Inner Corner Top Left Bottom Right": Vector2i(4, 4),
	"Double Inner Corner Top Right Bottom Left": Vector2i(4, 5),

	# -- Small-block corners -----------------------------------------------
	# A 1-wide run turning 90 degrees. Named like the big corners: "Top Left"
	# means the walls are on the top and left, so the run enters from the
	# right and leaves downwards, and the inner nub lands bottom-right.
	"Small Corner Top Left": Vector2i(4, 2),
	"Small Corner Top Right": Vector2i(5, 2),
	"Small Corner Bottom Left": Vector2i(4, 3),
	"Small Corner Bottom Right": Vector2i(5, 3),

	# -- Big -> small tees --------------------------------------------------
	# A big block's edge cell with a 1-wide arm branching out of it. Named
	# for where the arm points.
	"Big Tee Top": Vector2i(0, 4),
	"Big Tee Bottom": Vector2i(1, 4),
	"Big Tee Left": Vector2i(0, 5),
	"Big Tee Right": Vector2i(1, 5),

	# -- Small -> small tees ------------------------------------------------
	# Three 1-wide runs meeting. Named for the odd arm out: "Right" is a
	# vertical run with a branch leaving to the right, so the wall is on the
	# left.
	"Small Tee Right": Vector2i(2, 4),
	"Small Tee Left": Vector2i(3, 4),
	"Small Tee Top": Vector2i(2, 5),
	"Small Tee Bottom": Vector2i(3, 5),

	# -- Big block corner with an arm off BOTH sides ------------------------
	# The corner counterpart of the steps below: instead of one 1-wide arm
	# leaving a block edge, both open sides of a block CORNER carry one, so the
	# cell reads as a pseudo 4-way. Named for which corner of the block it is,
	# same as the plain corners: "Top Left" means the arms leave up and left.
	# Three nubs, one per pair of walls that meet; the inside corner stays open.
	"Step Corner Top Left": Vector2i(5, 4),
	"Step Corner Top Right": Vector2i(6, 4),
	"Step Corner Bottom Left": Vector2i(5, 5),
	"Step Corner Bottom Right": Vector2i(6, 5),

	# -- Small 4-way --------------------------------------------------------
	"Small Cross": Vector2i(7, 4),

	# -- Big <-> small steps ------------------------------------------------
	# A big block's EDGE cell whose perpendicular neighbour is a 1-wide arm,
	# i.e. the arm leaves flush with the block instead of centred in it, so the
	# wall has to jog from 4px down to 2px. Named "Step <wall side> <arm side>",
	# and laid out on that same grid: ROW picks the wall, COLUMN picks the arm.
	#
	#            x=6                 x=7
	#     y=0  Step Left Top       Step Left Bottom
	#     y=1  Step Right Top      Step Right Bottom
	#     y=2  Step Top Left       Step Top Right
	#     y=3  Step Bottom Left    Step Bottom Right
	#
	# These are the newest pieces, so the art may not exist yet. Until it does
	# they fall through FALLBACK to the plain edge piece, which paints a visible
	# seam but never a wrong shape or a hole.
	"Step Left Top": Vector2i(6, 0),
	"Step Left Bottom": Vector2i(7, 0),
	"Step Right Top": Vector2i(6, 1),
	"Step Right Bottom": Vector2i(7, 1),
	"Step Top Left": Vector2i(6, 2),
	"Step Top Right": Vector2i(7, 2),
	"Step Bottom Left": Vector2i(6, 3),
	"Step Bottom Right": Vector2i(7, 3),
}

## Where a piece borrows its art from when its own tile is UNMAPPED, or is
## mapped but not actually present in the tileset source yet. Chains are
## followed, so a fallback may itself fall back.
const FALLBACK: Dictionary[String, String] = {
	"Step Left Top": "Edge Left",
	"Step Left Bottom": "Edge Left",
	"Step Right Top": "Edge Right",
	"Step Right Bottom": "Edge Right",
	"Step Top Left": "Edge Top",
	"Step Top Right": "Edge Top",
	"Step Bottom Left": "Edge Bottom",
	"Step Bottom Right": "Edge Bottom",
	# Both of a corner's sides are open here, so the plain corner piece would
	# wall the arms off. Blank interior is the honest stand-in.
	"Step Corner Top Left": "Fill",
	"Step Corner Top Right": "Fill",
	"Step Corner Bottom Left": "Fill",
	"Step Corner Bottom Right": "Fill",
	# Half the notch beats none of it.
	"Double Inner Corner Top Left Bottom Right": "Inner Corner Top Left",
	"Double Inner Corner Top Right Bottom Left": "Inner Corner Top Right",
}

#endregion


#region Neighbour bits

const N := 1 << 0
const NE := 1 << 1
const E := 1 << 2
const SE := 1 << 3
const S := 1 << 4
const SW := 1 << 5
const W := 1 << 6
const NW := 1 << 7

const SIDES := N | E | S | W
const DIAGONALS := NE | SE | SW | NW

const OFFSETS: Dictionary[int, Vector2i] = {
	N: Vector2i(0, -1),
	NE: Vector2i(1, -1),
	E: Vector2i(1, 0),
	SE: Vector2i(1, 1),
	S: Vector2i(0, 1),
	SW: Vector2i(-1, 1),
	W: Vector2i(-1, 0),
	NW: Vector2i(-1, -1),
}

const SIDE_NAMES: Dictionary[int, String] = {
	N: "Top",
	E: "Right",
	S: "Bottom",
	W: "Left",
}

## Diagonal bit -> the "<vertical> <horizontal>" half of a piece name.
const DIAGONAL_NAMES: Dictionary[int, String] = {
	NE: "Top Right",
	SE: "Bottom Right",
	SW: "Bottom Left",
	NW: "Top Left",
}

const OPPOSITE: Dictionary[int, int] = {
	N: S,
	E: W,
	S: N,
	W: E,
}

#endregion


#region Basic mode (unchanged)

## Which named tile belongs at column/row (0-based) of a rect that is
## `width` x `height` tiles. This is the whole procedural rule for BASIC mode.
static func tile_name_at(column: int, row: int, width: int, height: int) -> String:
	if width == 1 and height == 1:
		return "Single"

	# Cols
	if width == 1:
		if row == 0:
			return "Vertical Column Top"
		if row == height - 1:
			return "Vertical Column Bottom"
		return "Vertical Column Middle"

	# Rows
	if height == 1:
		if column == 0:
			return "Horizontal Bar Left"
		if column == width - 1:
			return "Horizontal Bar Right"
		return "Horizontal Bar Middle"

	# Rects
	var vertical := "Top" if row == 0 else ("Bottom" if row == height - 1 else "Middle")
	var horizontal := "Left" if column == 0 else ("Right" if column == width - 1 else "Middle")

	if vertical == "Middle" and horizontal == "Middle":
		return "Fill"
	if vertical == "Middle":
		return "Edge " + horizontal
	if horizontal == "Middle":
		return "Edge " + vertical
	return "Corner %s %s" % [vertical, horizontal]

#endregion


#region Terrain mode

## The whole summation-mode rule, as one pure function so it can be reasoned
## about (and unit-tested) without a TileMapLayer in sight.
##
## [param is_thick] -- the cell belongs to a solid 2x2 somewhere, so it wears
## big-block (4px) walls. A 1-wide arm is never thick.
## [param filled] -- 8-bit mask of which neighbours are part of the terrain,
## built from the N..NW bits above.
## [param thin_sides] -- 4-bit subset of `filled` marking side neighbours that
## are filled but NOT thick, i.e. 1-wide arms hanging off this cell.
static func terrain_tile_name(is_thick: bool, filled: int, thin_sides: int) -> String:
	if is_thick:
		return _thick_tile_name(filled, thin_sides)
	return _thin_tile_name(filled)


static func _thick_tile_name(filled: int, thin_sides: int) -> String:
	var open_sides := SIDES & ~filled

	match _bit_count(open_sides):
		0:
			# Boxed in on all four sides. A 1-wide arm branching off is a real
			# opening, so it outranks a merely missing diagonal.
			var arms := _bit_count(thin_sides)
			if arms == 1:
				return "Big Tee " + SIDE_NAMES[thin_sides]
			if arms == 2:
				if thin_sides == (N | S) or thin_sides == (E | W):
					# Arms straight through opposite sides: no piece for it.
					return "Fill"
				# Arms off both sides of a block corner -- a pseudo 4-way.
				return "Step Corner " + _corner_name(thin_sides)
			if arms > 2:
				# Three or four arms off one cell: no piece for it either.
				return "Fill"

			var open_diagonals := DIAGONALS & ~filled
			if open_diagonals == 0:
				return "Fill"
			# Both diagonals of one axis missing: the inside of a hashtag.
			if open_diagonals == (NW | SE):
				return "Double Inner Corner Top Left Bottom Right"
			if open_diagonals == (NE | SW):
				return "Double Inner Corner Top Right Bottom Left"
			# The art has singles and opposite pairs, nothing else. Two
			# ADJACENT holes, three or four take the first and seam the rest.
			return "Inner Corner " + DIAGONAL_NAMES[_lowest_bit(open_diagonals)]
		1:
			# A straight edge. If the run continues into a 1-wide arm on one
			# of the two perpendicular sides, the wall has to step down.
			var wall := SIDE_NAMES[open_sides]
			var step := thin_sides & ~OPPOSITE[open_sides] & ~open_sides
			if _bit_count(step) == 1:
				return "Step %s %s" % [wall, SIDE_NAMES[step]]
			return "Edge " + wall
		2:
			if open_sides == (N | S):
				return "Horizontal Bar Middle"
			if open_sides == (E | W):
				return "Vertical Column Middle"
			return "Corner " + _corner_name(open_sides)

	# Three or four open sides on a "thick" cell can only mean the 2x2 that
	# made it thick sits diagonally, which the art has no piece for. The thin
	# rules give the closest shape.
	return _thin_tile_name(filled)


static func _thin_tile_name(filled: int) -> String:
	var sides := filled & SIDES

	match _bit_count(sides):
		0:
			return "Single"
		1:
			# One neighbour: this is the capped end of a run, and the cap goes
			# on the far side from that neighbour.
			if sides == N:
				return "Vertical Column Bottom"
			if sides == S:
				return "Vertical Column Top"
			if sides == W:
				return "Horizontal Bar Right"
			return "Horizontal Bar Left"
		2:
			if sides == (N | S):
				return "Vertical Column Middle"
			if sides == (E | W):
				return "Horizontal Bar Middle"
			# Two neighbours at right angles: the run turns here. Name it for
			# the two walled sides, matching how the big corners are named.
			return "Small Corner " + _corner_name(SIDES & ~sides)
		3:
			# The arm that has no partner opposite it is the branch.
			return "Small Tee " + SIDE_NAMES[OPPOSITE[SIDES & ~sides]]

	return "Small Cross"


## "Top Left" etc. from a two-bit mask of one vertical and one horizontal side.
static func _corner_name(mask: int) -> String:
	var vertical := "Top" if mask & N != 0 else "Bottom"
	var horizontal := "Left" if mask & W != 0 else "Right"
	return "%s %s" % [vertical, horizontal]


static func _bit_count(mask: int) -> int:
	var count := 0
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count


static func _lowest_bit(mask: int) -> int:
	return mask & -mask

#endregion


#region Lookup

## Follow FALLBACK until a name that is actually mapped turns up. Returns ""
## when the chain runs dry, which callers treat as "skip this cell".
static func resolve_name(tile_name: String) -> String:
	var current := tile_name
	# Bounded so a typo'd FALLBACK loop can't hang the editor.
	for _step in 8:
		if NAME_TO_TILE.get(current, UNMAPPED) != UNMAPPED:
			return current
		if not FALLBACK.has(current):
			return ""
		current = FALLBACK[current]
	return ""


## Every mapped name to try for a piece, best first: the piece itself, then
## whatever FALLBACK routes it to. The painter walks this until it finds a
## coordinate the tileset actually has a tile at, so a half-drawn sheet
## degrades to the nearest piece instead of leaving holes.
static func name_chain(tile_name: String) -> Array[String]:
	var chain: Array[String] = []
	var current := tile_name
	# Bounded so a typo'd FALLBACK loop can't hang the editor.
	for _step in 8:
		if NAME_TO_TILE.get(current, UNMAPPED) != UNMAPPED:
			chain.append(current)
		if not FALLBACK.has(current):
			break
		current = FALLBACK[current]
	return chain


## Resolve a named tile to a real atlas coordinate, given the top-left corner
## of the region in the tileset. Returns UNMAPPED for a name with no art.
static func atlas_coords(tile_name: String, region_origin: Vector2i) -> Vector2i:
	var resolved := resolve_name(tile_name)
	if resolved.is_empty():
		return UNMAPPED
	return region_origin + NAME_TO_TILE[resolved]


## Names that have real art, in dictionary order, for the debug dropdown.
static func tile_names() -> Array[String]:
	var names: Array[String] = []
	for key in NAME_TO_TILE:
		if NAME_TO_TILE[key] != UNMAPPED:
			names.append(key)
	return names


## coord-within-region -> piece name, for the (i) popover's labelled preview.
static func names_by_offset(terrain: bool) -> Dictionary[Vector2i, String]:
	var region := region_size(terrain)
	var result: Dictionary[Vector2i, String] = {}
	for key in NAME_TO_TILE:
		var offset: Vector2i = NAME_TO_TILE[key]
		if offset == UNMAPPED:
			continue
		if offset.x >= region.x or offset.y >= region.y:
			continue
		result[offset] = key
	return result

#endregion
