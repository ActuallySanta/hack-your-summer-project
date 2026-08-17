@tool
class_name RectTerrain
extends RefCounted

## Occupancy scratchpad for summation mode.
##
## Summation mode does not paint a rectangle -- it edits a SHAPE. So before
## touching anything the painter reads back which cells around the drag already
## belong to this region of this tileset, unions or subtracts the dragged rect
## into that set, and then re-picks a tile for every cell the change could have
## affected. Two rects dragged over each other come out as one merged chunk of
## terrain rather than one pasted on top of the other.
##
## Membership is derived, not stored: a cell is "ours" when its source id
## matches and its atlas coord lands inside the configured region. That means
## the tool picks up terrain painted in earlier sessions, and it will never
## claim a cell belonging to some other part of the tileset.

## How far beyond the edited rect we re-pick tiles. Adding a cell changes the
## thickness of its immediate neighbours, which changes the tile of THEIR
## neighbours -- so the blast radius is two.
const RETILE_MARGIN := 2

## How far beyond that we need real occupancy for those decisions to be right.
const READ_MARGIN := RETILE_MARGIN + 2

var _filled: Dictionary[Vector2i, bool] = {}
var _owned: Dictionary[Vector2i, bool] = {}
var _thick: Dictionary[Vector2i, bool] = {}


## Snapshot every cell of `area` that belongs to this source + region.
func read(
	layer: TileMapLayer,
	source_id: int,
	region_origin: Vector2i,
	region_size: Vector2i,
	area: Rect2i
) -> void:
	_filled.clear()
	_owned.clear()
	_thick.clear()

	var region := Rect2i(region_origin, region_size)
	for row in area.size.y:
		for column in area.size.x:
			var cell := area.position + Vector2i(column, row)
			if layer.get_cell_source_id(cell) != source_id:
				continue
			if not region.has_point(layer.get_cell_atlas_coords(cell)):
				continue
			_filled[cell] = true
			_owned[cell] = true


func fill_rect(rect: Rect2i) -> void:
	_thick.clear()
	for row in rect.size.y:
		for column in rect.size.x:
			_filled[rect.position + Vector2i(column, row)] = true


func clear_rect(rect: Rect2i) -> void:
	_thick.clear()
	for row in rect.size.y:
		for column in rect.size.x:
			_filled.erase(rect.position + Vector2i(column, row))


func is_filled(cell: Vector2i) -> bool:
	return _filled.has(cell)


## True when this cell was already part of the terrain before the drag, so the
## painter knows it is allowed to erase it.
func was_owned(cell: Vector2i) -> bool:
	return _owned.has(cell)


## A cell wears big-block (thick) walls when it belongs to a solid 2x2
## anywhere. A 1-wide arm never does, which is exactly the old tool's rule --
## drag a 1xN and every cell is a small piece, drag anything fatter and they
## are all big pieces.
func is_thick(cell: Vector2i) -> bool:
	if _thick.has(cell):
		return _thick[cell]

	var result := false
	if is_filled(cell):
		for offset_y in [-1, 0]:
			for offset_x in [-1, 0]:
				var base := cell + Vector2i(offset_x, offset_y)
				if (
					is_filled(base)
					and is_filled(base + Vector2i(1, 0))
					and is_filled(base + Vector2i(0, 1))
					and is_filled(base + Vector2i(1, 1))
				):
					result = true
					break
			if result:
				break

	_thick[cell] = result
	return result


## The piece this cell should be wearing, given everything around it.
func tile_name(cell: Vector2i) -> String:
	var filled := 0
	var thin_sides := 0

	for bit: int in RectTileLayout.OFFSETS:
		var neighbour: Vector2i = cell + RectTileLayout.OFFSETS[bit]
		if not is_filled(neighbour):
			continue
		filled |= bit
		if bit & RectTileLayout.SIDES != 0 and not is_thick(neighbour):
			thin_sides |= bit

	return RectTileLayout.terrain_tile_name(is_thick(cell), filled, thin_sides)
