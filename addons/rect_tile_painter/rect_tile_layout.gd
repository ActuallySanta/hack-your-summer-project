@tool
class_name RectTileLayout
extends RefCounted

## Size of the region a painter reads from, in tiles. Only used for the
## editor's region-origin clamping and the on-screen hint.
const REGION_SIZE := Vector2i(4, 4)

## Converts a human readable name into region Cords
const NAME_TO_TILE: Dictionary[String, Vector2i] = {
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
}

## Which named tile belongs at column/row (0-based) of a rect that is
## `width` x `height` tiles. This is the whole procedural rule.
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


## Resolve a named tile to a real atlas coordinate, given the top-left corner
## of the 4x4 region in the tileset.
static func atlas_coords(tile_name: String, region_origin: Vector2i) -> Vector2i:
	var offset: Vector2i = NAME_TO_TILE.get(tile_name, Vector2i.ZERO)
	return region_origin + offset


## Names in dictionary order, for the debug dropdown.
static func tile_names() -> Array[String]:
	var names: Array[String] = []
	for key in NAME_TO_TILE:
		names.append(key)
	return names
