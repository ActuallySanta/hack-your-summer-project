class_name BreakableTileData extends RefCounted
## The state of one cell of a BreakAbles layer while it is broken.

const TIME_ANIM : float = 0.1
const LAST_FRAME : int = 4

enum Phase {
	BREAKING,
	GONE,
	REPAIRING,
	DONE,
}

var coord : Vector2i
var break_type : int
var frame : int
var phase : Phase
var time : float

var frame_step : int
var time_gone : float
var repairs : bool

## One tile that was covering the block, remembered well enough to be put back
## exactly as it was on the exact layer it came off.
class Cover extends RefCounted:
	var layer : TileMapLayer
	var source : int
	var atlas : Vector2i
	var alternative : int

	func _init(p_layer: TileMapLayer, coord: Vector2i) -> void:
		layer = p_layer
		source = p_layer.get_cell_source_id( coord )
		atlas = p_layer.get_cell_atlas_coords( coord )
		alternative = p_layer.get_cell_alternative_tile( coord )

## Every tile lifted off this cell, one per layer that had one. A block covered
## by a wall tile and a piece of decoration on top of it has two.
var covers : Array[ Cover ]

func _init(coords: Vector2i, tile_y_index: int, p_frame_step: int = 1, p_time_gone: float = 2.0, p_repairs: bool = true) -> void:
	coord = coords
	break_type = tile_y_index
	frame_step = maxi( p_frame_step, 1 )
	time_gone = p_time_gone
	repairs = p_repairs
	frame = 0
	phase = Phase.BREAKING
	time = 0

func reset() -> void:
	frame = 1
	phase = Phase.BREAKING
	time = TIME_ANIM

func pull_cover_from(foreground: TileMapLayer) -> void:
	var only : Array[ TileMapLayer ] = [ foreground ]
	pull_covers_from( only )

## Lifts this cell off every layer in [param layers] that has a tile there, and
## remembers each one so it can go back where it came from. Layers without a tile
## over this cell are skipped, so a caller can hand over every layer that might
## be covering the block without checking first.
func pull_covers_from(layers: Array[ TileMapLayer ]) -> void:
	for layer in layers:
		if not is_instance_valid( layer ) or layer.get_cell_source_id( coord ) == -1:
			continue
		covers.append( Cover.new( layer, coord ) )
		layer.erase_cell( coord )

func forget_cover() -> void:
	covers.clear()

## Puts every tile that was covering the block back. Returns whether there was
## anything to put back, since a cover going back on is what changes whether the
## block under it should be drawn.
func restore_cover() -> bool:
	var restored := false
	for cover in covers:
		if not is_instance_valid( cover.layer ):
			continue
		cover.layer.set_cell( coord, cover.source, cover.atlas, cover.alternative )
		restored = true
	return restored

func _to_string() -> String:
	var output : String = "Break Tile Data: [ position: "
	output += str(coord) + ", time: "
	output += str(time) + ", time gone: "
	output += str(time_gone) + ", phase: "
	output += Phase.keys()[ phase ] + ", cell: "
	output += str(Vector2i(frame, break_type)) + " ]"
	return output

## Advances the animation. Returns true when the cell it should be drawn as has
## changed.
func iterate(delta: float) -> bool:
	time += delta
	match phase:
		Phase.BREAKING:
			if time < TIME_ANIM:
				return false
			time = 0
			frame += frame_step
			if frame > LAST_FRAME:
				frame = -1
				phase = Phase.GONE if repairs else Phase.DONE
		Phase.GONE:
			if time < time_gone:
				return false
			time = 0
			frame = LAST_FRAME
			phase = Phase.REPAIRING
		Phase.REPAIRING:
			if time < TIME_ANIM:
				return false
			time = 0
			frame = maxi( frame - frame_step, 0 )
			if frame == 0:
				phase = Phase.DONE
		Phase.DONE:
			return false
	return true

func get_default() -> Vector2i:
	return Vector2i(0, break_type)
