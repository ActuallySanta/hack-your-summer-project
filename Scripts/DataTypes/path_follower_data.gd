class_name PathFollowerData extends RefCounted

## The path follower simple stores a nodes position along a path

var node : Node2D
var point_index : int
var travelled_distance : float
var ratio : float
var current_point : PathPoint

var wait_time : float

func _init(rider: Node2D, initial_point: PathPoint, initial_point_index: int = 0, start_distance: float = 0.0) -> void:
	node = rider
	point_index = initial_point_index
	current_point = initial_point
	travelled_distance = start_distance
	wait_time = 0

func iterate(delta: float, num_points: int, speed: float) -> bool:
	# Wait
	if wait_time > 0:
		wait_time -= delta
		return false
	
	# Traverse the path
	travelled_distance += speed * delta
	ratio = travelled_distance / current_point.length
	
	if travelled_distance < current_point.length:
		return false
		
	ratio = 0.0
	travelled_distance -= current_point.length
	point_index += 1
	
	if point_index == num_points:
		point_index = 0
	return true

func move_node() -> void:
	node.position = current_point.start + current_point.delta_normal * travelled_distance
