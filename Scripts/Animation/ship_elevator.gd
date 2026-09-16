class_name ShipElevator extends Elevator

@onready var top_floor_collider : Area2D = $TopFloor
@onready var bottom_floor_collider : Area2D = $BottomFloor

func setup() -> void:
	pass

func change_floor() -> void:
	if _in_transit():
		return
	_target_floor = 1 if _target_floor == 0 else 0


func remove_checkers() -> void:
	top_floor_collider.queue_free()
	bottom_floor_collider.queue_free()

func _on_top_floor_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		snap_to_floor( 1 )
		remove_checkers()

func _on_bottom_floor_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		snap_to_floor( 0 )
		remove_checkers()
