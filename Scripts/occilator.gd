extends Node2D

@export var horizontal_shift: float
@export var vertical_shift: float = 1.0
@export var occilations_per_second: float = 1.0
@export var do_random_offset : bool

var _time: float
var _rps: float
var _root_position: Vector2
var _shift: Vector2
var _offset: float = 0

func _ready() -> void:
	if do_random_offset:
		_offset = randf_range(0, TAU)
	
	_time = 0 
	_rps = occilations_per_second * TAU
	_root_position = global_position
	_shift = Vector2(horizontal_shift * 16, vertical_shift * 16)

func _process(delta: float) -> void:
	_time += delta
	global_position.x = _root_position.x + cos(_time * _rps + _offset) * _shift.x
	global_position.y = _root_position.y + sin(_time * _rps + _offset) * _shift.y
