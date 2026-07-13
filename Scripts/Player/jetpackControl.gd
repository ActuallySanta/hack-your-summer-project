extends Sprite2D

signal jetpack_updated(net_acceleration: float, max_speed: float, delta: float)
const IDLE = preload("res://Sprites/Jetpack/jetpack_isOn_0.png")
const ACTIVE = preload("res://Sprites/Jetpack/jetpack_isOn_1.png")
@export var net_acceleration: float
@export var max_speed: float
var _was_on: bool

func _ready() -> void:
	_was_on = false
	texture = IDLE

func _physics_process(delta: float) -> void:
	var is_on = Input.is_action_pressed("Jump")
	if is_on == _was_on:
		update_jetpack(is_on, delta)
		return
	
	texture = ACTIVE if is_on else IDLE
	_was_on = is_on
	
func update_jetpack(is_on: bool, delta: float):
	if not is_on:
		return
	
	jetpack_updated.emit(net_acceleration, max_speed, delta)
	pass
