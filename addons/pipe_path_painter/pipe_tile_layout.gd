@tool
class_name PipeTileLayout
extends RefCounted

## The shape vocabulary for pipe-style paths.
##
## Every pipe tile is described by which of its four sides connect to a
## neighbour, packed into a 4-bit mask. There are exactly 15 non-empty masks,
## which is exactly the tile list you have to supply: 2 straights, 4 L turns,
## 4 T junctions, 1 cross, 4 dead ends.
##
## Working in masks is what makes merging free: painting a horizontal run
## through an existing vertical pipe is just `10 | 5 == 15`, a cross. Ending
## the run on it is `8 | 5 == 13`, a T. No special cases.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

## Clockwise from north. Order matters only for tidy glyph drawing.
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const DIRECTION_TO_BIT: Dictionary[Vector2i, int] = {
	Vector2i(0, -1): NORTH,
	Vector2i(1, 0): EAST,
	Vector2i(0, 1): SOUTH,
	Vector2i(-1, 0): WEST,
}

## Name -> connection mask. These names are what the config dialog shows and
## what gets written into the settings file, so renaming one orphans its saved
## coordinate. The masks themselves are fixed by geometry -- don't edit those.
const NAME_TO_MASK: Dictionary[String, int] = {
	"Straight Horizontal": EAST | WEST,
	"Straight Vertical": NORTH | SOUTH,

	"Turn North-East": NORTH | EAST,
	"Turn North-West": NORTH | WEST,
	"Turn South-East": SOUTH | EAST,
	"Turn South-West": SOUTH | WEST,

	"Tee North": NORTH | EAST | WEST,
	"Tee East": NORTH | EAST | SOUTH,
	"Tee South": EAST | SOUTH | WEST,
	"Tee West": NORTH | SOUTH | WEST,

	"Cross": NORTH | EAST | SOUTH | WEST,

	"End North": NORTH,
	"End East": EAST,
	"End South": SOUTH,
	"End West": WEST,
}

## Purely for grouping the config dialog's slot list.
const NAME_TO_CATEGORY: Dictionary[String, String] = {
	"Straight Horizontal": "Straights",
	"Straight Vertical": "Straights",
	"Turn North-East": "L Turns",
	"Turn North-West": "L Turns",
	"Turn South-East": "L Turns",
	"Turn South-West": "L Turns",
	"Tee North": "T Junctions",
	"Tee East": "T Junctions",
	"Tee South": "T Junctions",
	"Tee West": "T Junctions",
	"Cross": "Four-Way",
	"End North": "Dead Ends",
	"End East": "Dead Ends",
	"End South": "Dead Ends",
	"End West": "Dead Ends",
}

## A single click has no direction to infer a shape from. Rather than place
## nothing, fall back to this. Change it if you'd rather single clicks drop a
## vertical stub (NORTH | SOUTH) or a cross (15).
const SINGLE_CELL_MASK := EAST | WEST


static func mask_to_name(mask: int) -> String:
	for tile_name: String in NAME_TO_MASK:
		if NAME_TO_MASK[tile_name] == mask:
			return tile_name
	return ""


## Which bit of `from`'s mask points at `to`. 0 if they aren't orthogonal
## neighbours.
static func bit_toward(from: Vector2i, to: Vector2i) -> int:
	var bit: int = DIRECTION_TO_BIT.get(to - from, 0)
	return bit


static func mask_directions(mask: int) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	for direction in ALL_DIRECTIONS:
		var bit: int = DIRECTION_TO_BIT[direction]
		if mask & bit != 0:
			directions.append(direction)
	return directions


## Human-readable side list, e.g. "N-E-W". Used in tooltips so a name can
## never be misread.
static func mask_description(mask: int) -> String:
	var letters: Array[String] = []
	if mask & NORTH != 0:
		letters.append("N")
	if mask & EAST != 0:
		letters.append("E")
	if mask & SOUTH != 0:
		letters.append("S")
	if mask & WEST != 0:
		letters.append("W")
	return "-".join(letters)


## The cells strictly after `from`, walking an axis-aligned L to `to`.
## Diagonals are never produced -- paths only ever turn 90 degrees.
static func bridge_cells(from: Vector2i, to: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if from == to:
		return cells

	var cursor := from
	var corner := Vector2i(to.x, from.y) if horizontal_first else Vector2i(from.x, to.y)
	for target: Vector2i in [corner, to]:
		while cursor.x != target.x:
			cursor.x += signi(target.x - cursor.x)
			cells.append(cursor)
		while cursor.y != target.y:
			cursor.y += signi(target.y - cursor.y)
			cells.append(cursor)
	return cells


static func line_cells(start: Vector2i, end: Vector2i, horizontal_first: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	cells.append_array(bridge_cells(start, end, horizontal_first))
	return cells


## Connection masks implied by walking `path`, before anything already on the
## layer is folded in. A cell the path crosses twice accumulates both visits,
## so self-crossing paths produce a cross on their own.
static func path_masks(path: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	var masks: Dictionary[Vector2i, int] = {}
	for cell in path:
		if not masks.has(cell):
			masks[cell] = 0

	for index in range(path.size() - 1):
		var a := path[index]
		var b := path[index + 1]
		if a == b:
			continue
		masks[a] = masks[a] | bit_toward(a, b)
		masks[b] = masks[b] | bit_toward(b, a)
	return masks


## The final shape of every cell a paint stroke touches.
##
## `existing` is a Callable taking a Vector2i and returning the mask already
## painted there (0 for empty or unrecognised). Keeping it a Callable is what
## lets the rules be exercised without a live TileMapLayer.
##
## Three things are folded together, all by OR:
##   - the path's own connections
##   - whatever tile was already in the cell (this is the merge: a horizontal
##     run through a vertical pipe becomes a cross, stopping on it becomes a T)
##   - any neighbour whose tile already points into the cell, so junctions
##     never end up half-drawn
static func resolve_paint(
	path: Array[Vector2i],
	existing: Callable,
	join_ends: bool
) -> Dictionary[Vector2i, int]:
	var walked := path_masks(path)
	if path.size() == 1 and walked[path[0]] == 0:
		walked[path[0]] = SINGLE_CELL_MASK

	var result: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in walked:
		var mask: int = walked[cell]
		mask |= mask_of(existing, cell)
		for direction in ALL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if mask_of(existing, neighbor) & bit_toward(neighbor, cell) != 0:
				mask |= bit_toward(cell, neighbor)
		result[cell] = mask

	if join_ends and not path.is_empty():
		_join_endpoint(path[0], walked, result, existing)
		_join_endpoint(path[path.size() - 1], walked, result, existing)

	return result


## Grow a connection between a path endpoint and any pipe sitting beside it,
## so two stubs never end up facing each other. Only endpoints do this --
## running alongside an existing pipe must not weld to it the whole way.
static func _join_endpoint(
	cell: Vector2i,
	walked: Dictionary[Vector2i, int],
	result: Dictionary[Vector2i, int],
	existing: Callable
) -> void:
	for direction in ALL_DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if walked.has(neighbor):
			continue

		var neighbor_mask := mask_of(existing, neighbor)
		if neighbor_mask == 0:
			continue

		var back := bit_toward(neighbor, cell)
		if neighbor_mask & back != 0:
			continue  # already joined

		var own: int = result.get(cell, 0)
		result[cell] = own | bit_toward(cell, neighbor)
		var theirs: int = result.get(neighbor, neighbor_mask)
		result[neighbor] = theirs | back


## The same rule run backwards. Erased cells map to 0; neighbours lose the
## connection that pointed into them, so a cross demotes to a T, a T to a
## corner, and a stub with nothing left to hold on to disappears.
static func resolve_erase(path: Array[Vector2i], existing: Callable) -> Dictionary[Vector2i, int]:
	var erased: Dictionary[Vector2i, bool] = {}
	for cell in path:
		erased[cell] = true

	var result: Dictionary[Vector2i, int] = {}
	for cell in path:
		result[cell] = 0

	for cell: Vector2i in erased:
		for direction in ALL_DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if erased.has(neighbor):
				continue
			var mask: int = result.get(neighbor, mask_of(existing, neighbor))
			if mask == 0:
				continue
			result[neighbor] = mask & ~bit_toward(neighbor, cell)

	return result


static func mask_of(existing: Callable, cell: Vector2i) -> int:
	var mask: int = existing.call(cell)
	return mask
