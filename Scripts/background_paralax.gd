extends Node2D

@export var factor = 0.2

var _camera : Camera2D
var _init_pos : Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().physics_frame
	_camera = get_viewport().get_camera_2d()
	_init_pos = get_camera_pos()
	global_position = _init_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_no_camera():
		return
	var current_pos = get_camera_pos()
	var _distance_traveled = current_pos - _init_pos
	global_position = _init_pos + _distance_traveled * factor

func is_no_camera() -> bool:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
		return _camera == null
	return false

func get_camera_pos() -> Vector2:
	if is_no_camera():
		return Vector2.ZERO
	return _camera.global_position
