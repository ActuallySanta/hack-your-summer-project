extends Node2D

@export_enum("None", "Horizontal", "Vertical") var preserve_axis : String
@export var factor = 0.2

var _camera : Camera2D
var _init_pos : Vector2
var _init_camera_pos : Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().physics_frame
	_camera = get_viewport().get_camera_2d()
	_init_pos = get_camera_pos()
	_init_camera_pos = global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_no_camera():
		return
	var current_pos = get_camera_pos()
	var _distance_traveled = current_pos - _init_pos
	global_position = _init_camera_pos + _distance_traveled * factor
	if preserve_axis == "Horizontal":
		global_position.x = _init_camera_pos.x
	if preserve_axis == "Vertical":
		global_position.y = _init_camera_pos.y

func is_no_camera() -> bool:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
		return _camera == null
	return false

func get_camera_pos() -> Vector2:
	if is_no_camera():
		return Vector2.ZERO
	return _camera.global_position
