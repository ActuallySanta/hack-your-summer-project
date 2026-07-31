class_name BreakableTileData extends RefCounted

const TIME_ANIM : float = 0.1
var replacedTileID : Vector2i
var coord : Vector2i
var respawnTime : float
var time : float
var state : int

func _init(coords: Vector2i, p_replacedTileID: Vector2i, p_respawn_time: float = 2, p_time = 0) -> void:
	coord = coords
	replacedTileID = p_replacedTileID
	respawnTime = p_respawn_time
	time = p_time
	state = 0

## Sends the tile back to the start of its break animation, as though it had
## only just been destroyed. Used when the tile cannot be rebuilt yet because
## the player is standing where the block would reappear.
func reset() -> void:
	state = 0
	time = 0

## Returns 0 if nothing should change, 1 if should go empty, and 2 if should reappear
func iterate(delta: float) -> int:
	time += delta
	if state < 6 and time >= TIME_ANIM:
		state += 1
		time = 0
		return state
	elif state == 6 and time >= respawnTime:
		state = 7
	elif state > 6 and state < 12 and time >= TIME_ANIM:
		state += 1
		time = 0
		return state
	elif state == 12:
		return -2
	return -1
