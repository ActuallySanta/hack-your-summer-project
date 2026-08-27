extends Node2D

@export var obstacle_tilemaps : Array[ TileMapLayer ]
@export var transfer_cutoff : float = 16.0

@onready var navigator := $Navigator
@onready var sprite := $Sprite2D

var room_map : Array[ Array ]
var target_node : RepairNode
var pathing_in_order : Array[ Vector2 ]

func _ready() -> void:
	navigator.ignore_target = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Get the target
	if target_node == null:
		var path = create_path()
		pathing_in_order = path
		navigator.set_target_pos(pathing_in_order[ 0 ])
	# Nav to target
	if close_to_pos(pathing_in_order[ 0 ]):
		pathing_in_order.remove_at(0)
		navigator.set_target_pos(pathing_in_order[ 0 ])
	# Do end sequence
	if close_to_pos(target_node.global_position):
		target_node.start_repairs()
		navigator.ignore_target = false # Causes navigators to slow_stop
		target_node.on_repair_end.connect( reset )

func reset() -> void:
	target_node = null
	target_node.on_repair_end.disconnect( reset )

func close_to_pos(global_pos: Vector2) -> bool:
	return (global_position - global_pos).length() <= transfer_cutoff

func create_path() -> Array[ Vector2 ]:
	#TODO:
	# if room_map is empty:
	# 	Create a 2D bool array of points representing the combined width and height of all obstable_tilemaps
	# 	Convert a point to false if any obstable_tilemaps occupy a point with a non-empty tile
	# 	Mark two sets of coords, the first is the current repair drones position, the second is the position of the target_node
	# Once room_map exists:
	# 	Pathfind from point A to B using only "true" indecies
	# At every turn for the pathing:
	# 	Add a Vector2D to pathing_in_order such that moving to each node from start results in reaching the target (Note this means the end must also be a cord)
	# return the resulting "path"
	return [ Vector2.INF ]

func find_closest_repair_node() -> RepairNode:
	var repairable_nodes := get_tree().get_nodes_in_group("Repairable") as Array[ RepairNode ]
	if repairable_nodes.size() == 0:
		return null
	var closest : RepairNode = repairable_nodes[0]
	var dist_to_curr : float = (global_position - closest.global_position).length()
	for i in repairable_nodes:
		var dist = (global_position - i.global_position).length()
		if dist < dist_to_curr:
			closest = i
			dist_to_curr = dist
	return closest
