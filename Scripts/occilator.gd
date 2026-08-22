extends Node2D

@export var horizontal_shift: float
@export var vertical_shift: float = 1.0
@export var occilations_per_second: float = 1.0
@export var do_random_offset : bool

var stop_anim : bool = false:
	set(value):
		_need_reset = true
		stop_anim = value
var _need_reset : bool = false

var _time: float
var _rps: float
## Rest position in the parent's space, so the occilation follows the parent if
## it ever gets moved (e.g. a pickup teleported in by a boss on death).
var _root_position: Vector2
var _shift: Vector2
var _offset: float = 0

func _ready() -> void:
	if do_random_offset:
		_offset = randf_range(0, TAU)
	
	_time = 0 
	_rps = occilations_per_second * TAU
	_root_position = position
	_shift = Vector2(horizontal_shift * 16, vertical_shift * 16)

func _process(delta: float) -> void:
	if stop_anim and _need_reset:
		position = _root_position
		_time = 0
		_need_reset = false
		return
	elif stop_anim:
		return
	
	_time += delta
	position.x = _root_position.x + cos(_time * _rps + _offset) * _shift.x
	position.y = _root_position.y + sin(_time * _rps + _offset) * _shift.y
