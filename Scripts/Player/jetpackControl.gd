extends Sprite2D

signal jetpack_updated(velocity: float)
const IDLE = preload("res://Sprites/Jetpack/jetpack_isOn_0.png")
const ACTIVE = preload("res://Sprites/Jetpack/jetpack_isOn_1.png")
@export var acceleration: float
@export var max_speed: float
var _was_on: bool
var _speed: float

func _ready() -> void:
	_was_on = false
	texture = IDLE

func _process(delta: float) -> void:
	var is_on = Input.is_action_pressed("Jump")
	if is_on == _was_on:
		update_jetpack(is_on)
		return
	
	texture = ACTIVE if is_on else IDLE
	_was_on = is_on
	
	if is_on:
		turn_jetpack_on()
	else:
		turn_jetpack_off()

func turn_jetpack_on():
	_speed = 0
	
func update_jetpack(is_on: bool):
	if not is_on:
		return
	
	_speed = minf(_speed + acceleration, max_speed);
	jetpack_updated.emit(_speed)
	pass
	
func turn_jetpack_off():
	pass
