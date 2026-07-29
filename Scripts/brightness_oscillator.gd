extends Node2D

@export var start_brightness: float = 1
@export var end_brightness: float = 0
@export var cycle_seconds: float = 1

var _game_time: float = 0.0
var _occilation_amount: float = 0.0
var _start_color := Color.WHITE
var _end_color := Color.BLACK
var _darkening = true
var _half_cycle_timer : float

func _ready() -> void:
	_half_cycle_timer = cycle_seconds / 2
	_start_color = Color(start_brightness, start_brightness, start_brightness)
	_end_color = Color(end_brightness, end_brightness, end_brightness)
	_occilation_amount = TAU / cycle_seconds

func _process(delta: float) -> void:
	if _game_time < 0:
		_game_time = 0
		_darkening = true
	elif _game_time > _half_cycle_timer:
		_game_time = _half_cycle_timer
		_darkening = false
	
	_game_time += delta if _darkening else -delta
	modulate = _start_color.lerp(_end_color, _game_time/_half_cycle_timer)
