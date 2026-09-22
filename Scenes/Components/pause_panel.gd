class_name PausePanel extends Node2D

var num = 0
var size = 6

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Attack"):
		num += 1
	elif Input.is_action_just_pressed("Shoot"):
		num -= 1
