class_name BrightnessOccilator extends Occilator

@export var start_brightness: float = 1
@export var end_brightness: float = 0

var _start_color := Color.WHITE
var _end_color := Color.BLACK

func setup() -> void:
	_start_color = Color(start_brightness, start_brightness, start_brightness)
	_end_color = Color(end_brightness, end_brightness, end_brightness)

func occilate() -> void:
	modulate = _start_color.lerp(_end_color, occilation_sin * occilation_sin)
