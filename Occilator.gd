@abstract
class_name Occilator extends Node2D

@export var occilations_per_second: float = 1.0
@export var do_random_offset : bool

var stop_anim : bool = false:
	set(value):
		_need_reset = true
		stop_anim = value
var _need_reset : bool = false
var _time: float
var _rps: float
var _offset: float = 0

var occilation_sin : float

func _ready() -> void:
	if do_random_offset:
		_offset = randf_range(0, TAU)
	
	_time = 0 
	_rps = occilations_per_second * TAU
	
	setup()


func _process(delta: float) -> void:
	if stop_anim and _need_reset:
		reset()
		_time = 0
		_need_reset = false
		return
	elif stop_anim:
		return
	
	_time += delta
	occilation_sin = sin(_time * _rps + _offset)
	occilate()

@abstract
func setup() -> void

@abstract
func occilate() -> void

func reset() -> void:
	pass
