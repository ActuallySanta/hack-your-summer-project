class_name BreakableTileData extends RefCounted

const TIME_ANIM : float = 0.1
var replacedTileID : Vector2i
var coord : Vector2i
var break_type : int
var respawnTime : float
var time : float
var state : int

func _init(coords: Vector2i, tile_y_index: int, p_replacedTileID: Vector2i = Vector2i.ZERO, p_respawn_time: float = 2, p_time = 0) -> void:
	coord = coords
	replacedTileID = p_replacedTileID
	break_type = tile_y_index
	respawnTime = p_respawn_time
	time = p_time
	state = 0

## Sends the tile back to the start of its break animation, as though it had
## only just been destroyed. Used when the tile cannot be rebuilt yet because
## the player is standing where the block would reappear.
func reset() -> void:
	state = 0
	time = 0

func _to_string() -> String:
	var output : String = "Break Tile Data: [ position: "
	output += str(coord) + ", time: "
	output += str(time) + ", respawn time: "
	output += str(respawnTime) + ", state: "
	output += str(Vector2i(state, break_type)) + " ]"
	return output

## Returns 0 if nothing should change, 1 if should go empty, and 2 if should reappear
func iterate(delta: float) -> int:
	time += delta
	if state < 4 and time >= TIME_ANIM:
		state += 1
		time = 0
	elif state == 4 and time >= respawnTime:
		state = 5
	elif state > 4 and state < 9 and time >= TIME_ANIM:
		state += 1
		time = 0
	elif state == 9:
		state = -2
	else:
		return -1
	
	return state

func get_default() -> Vector2i:
	return Vector2i(0, break_type)
