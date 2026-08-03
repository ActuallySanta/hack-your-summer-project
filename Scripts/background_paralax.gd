extends Node2D

@export_enum("None", "Horizontal", "Vertical") var preserve_axis : String
@export var factor = 0.2
const CAMERA_TELEPORT_DISTANCE : float = 256.0

var _camera : Camera2D
var _home : Vector2
var _camera_origin : Vector2
var _last_camera_pos : Vector2
var _tracking_camera : bool
var _needs_origin : bool = true

func _ready() -> void:
	_home = global_position
	GlobalSignals.player_spawned.connect(_take_new_origin)

## The camera is placed by Game's _process, which runs ahead of us in tree order,
## so the origin is taken on the next frame rather than immediately.
func _take_new_origin() -> void:
	_needs_origin = true

func _process(_delta: float) -> void:
	if is_no_camera():
		return

	var camera_pos := get_camera_pos()
	if _needs_origin:
		_camera_origin = camera_pos
		_needs_origin = false
	elif _tracking_camera and _last_camera_pos.distance_to(camera_pos) > CAMERA_TELEPORT_DISTANCE:
		_camera_origin += camera_pos - _last_camera_pos
	_last_camera_pos = camera_pos
	_tracking_camera = true

	global_position = _home + (camera_pos - _camera_origin) * factor
	if preserve_axis == "Horizontal":
		global_position.x = _home.x
	if preserve_axis == "Vertical":
		global_position.y = _home.y

func is_no_camera() -> bool:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		return not is_instance_valid(_camera)
	return false

func get_camera_pos() -> Vector2:
	if is_no_camera():
		return Vector2.ZERO
	return _camera.global_position
