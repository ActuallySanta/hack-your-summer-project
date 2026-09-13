class_name PositionOccilator extends Occilator

@export var horizontal_shift: float
@export var vertical_shift: float = 1.0

var _shift: Vector2
var _root_position: Vector2

func setup() -> void:
	_root_position = position
	_shift = Vector2(horizontal_shift * 16, vertical_shift * 16)

func occilate() -> void:
	position.x = _root_position.x + occilation_sin * _shift.x
	position.y = _root_position.y + occilation_sin * _shift.y

func reset() -> void:
	position = _root_position
