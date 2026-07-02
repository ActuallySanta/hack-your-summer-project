extends TileMapLayer

@export var horizontal_shift: float
@export var vertical_shift: float
@export var occilations_per_second: float

var _time: float
var _rps: float
var _root_position: Vector2
var _shift: Vector2

func _ready() -> void:
	_time = 0 
	_rps = occilations_per_second * TAU
	_root_position = global_position
	_shift = Vector2(horizontal_shift * 16, vertical_shift * 16)

func _process(delta: float) -> void:
	_time += delta
	global_position.x = _root_position.x + cos(_time * _rps) * _shift.x
	global_position.y = _root_position.y + sin(_time * _rps) * _shift.y
