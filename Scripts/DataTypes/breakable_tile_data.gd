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

var cover_layer : TileMapLayer
var cover_source : int = -1
var cover_atlas : Vector2i
var cover_alternative : int

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
	cover_layer = foreground
	cover_source = foreground.get_cell_source_id( coord )
	cover_atlas = foreground.get_cell_atlas_coords( coord )
	cover_alternative = foreground.get_cell_alternative_tile( coord )
	foreground.erase_cell( coord )

func forget_cover() -> void:
	cover_layer = null
	cover_source = -1

func restore_cover() -> void:
	if cover_source == -1 or not is_instance_valid( cover_layer ):
		return
	cover_layer.set_cell( coord, cover_source, cover_atlas, cover_alternative )

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
