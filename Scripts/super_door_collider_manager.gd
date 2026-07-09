extends StaticBody2D

@export var x_positions = [ -32, 0, 32 ]

var _curr_door = 0

func move_to_next_door() -> void:
	_curr_door += 1
	if _curr_door < x_positions.size():
		$CollisionShape2D.position.x = x_positions[ _curr_door ]
		return
	
	clear_colliders()

func clear_colliders() -> void:
	$CollisionShape2D.queue_free()
