class_name BreakableTileData extends RefCounted

const TIME_ANIM : float = 0.5
var replacedTileID : Vector2i
var coord : Vector2i
var respawnTime : float
var time : float
var state : int

func _init(coords: Vector2i, p_replacedTileID: Vector2i, p_respawn_time: float = 2, p_time = 0) -> void:
	coord = coords
	p_replacedTileID = replacedTileID
	respawnTime = p_respawn_time
	time = p_time
	state = -5

## Returns 0 if nothing should change, 1 if should go empty, and 2 if should reappear
func iterate(delta: float) -> int:
	time += delta
	if state < 0 and time >= 0.1:
		state += 1
		time = 0
		return state
	if state == 0:
		state = 1
		return state
	elif state == 1 and time >= respawnTime:
		state = 2
		return state
	return -10
