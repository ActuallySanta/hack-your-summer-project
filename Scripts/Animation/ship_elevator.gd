class_name ShipElevator extends Elevator

@onready var top_floor_collider : Area2D = $TopFloor
@onready var bottom_floor_collider : Area2D = $BottomFloor

var _top_shapes : Array = []
var _bottom_shapes : Array = []

func setup() -> void:
	_top_shapes = _checker_shapes(top_floor_collider)
	_bottom_shapes = _checker_shapes(bottom_floor_collider)

	_snap_to_player()
	_snap_to_player.call_deferred()
	#GlobalSignals.player_spawned.connect(_snap_to_player)

func change_floor() -> void:
	if _in_transit():
		return
	_target_floor = 1 if _target_floor == 0 else 0

func _snap_to_player() -> void:
	if not is_inside_tree():
		return
	if PlayerOverlap.with_shapes(_top_shapes):
		snap_to_floor( 1 )
	elif PlayerOverlap.with_shapes(_bottom_shapes):
		snap_to_floor( 0 )

func _checker_shapes(checker: Area2D) -> Array:
	if checker == null:
		return []
	# The checkers are there to be measured against, not to take part in physics.
	checker.monitoring = false
	checker.monitorable = false
	return PlayerOverlap.collect_shapes(checker)
