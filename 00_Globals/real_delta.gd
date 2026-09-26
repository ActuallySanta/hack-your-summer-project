extends Node

const MAX_REAL_DELTA_FOR_CAPPED := 0.1

var _real_time_usec : float
var _delta : float

func _ready() -> void:
	_real_time_usec = Time.get_ticks_usec()

func _process(__delta: float) -> void:
	var now := Time.get_ticks_usec()
	_delta = (now - _real_time_usec) / 1000000.0
	_real_time_usec = now

func get_delta() -> float: return _delta
func get_capped() -> float: return minf(get_delta(), MAX_REAL_DELTA_FOR_CAPPED)
