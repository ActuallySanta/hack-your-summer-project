extends TileMapLayer

@export var factor = 0.2

var _camera
var _init_pos : float
var _is_active : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_is_active = false
	await get_tree().physics_frame
	_is_active = true
	_camera = get_viewport().get_camera_2d()
	_init_pos = get_camera_pos_y()
	global_position.y = _init_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _is_active:
		return
	var current_height = get_camera_pos_y()
	var _distance_traveled = current_height - _init_pos
	global_position.y = _init_pos + _distance_traveled * factor

func get_camera_pos_y() -> float:
	return _camera.global_position.y
