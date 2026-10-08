class_name SmartTimer extends Node

var _callable : Callable
var _time_seconds : float
var _paused : bool

var _timer : float

func _init(time_seconds: float, callable: Callable, start_time: float = 0, start_paused: bool = false) -> void:
	_time_seconds = time_seconds
	_callable = callable
	_paused = start_paused
	_timer = _time_seconds - start_time

func increment(delta: float) -> void:
	if _paused: return
	if _timer > 0:
		_timer -= delta
		return
	_timer = _time_seconds
	_callable.call()

func pause() -> void: _paused = true
func unpause() -> void: _paused = false
