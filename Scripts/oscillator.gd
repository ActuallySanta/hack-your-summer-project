extends Node2D

@export var height: float = 1
@export var hover_cycle_seconds: float = 1

var _game_time: float = 0.0
var _occilation_amount: float = 0.0
var _start_position := Vector2.ZERO

func _ready() -> void:
	_start_position = position
	_occilation_amount = TAU / hover_cycle_seconds

func _process(delta: float) -> void:
	_game_time += delta
	var eval = height * sin(_game_time * _occilation_amount)
	position.y = _start_position.y + eval
