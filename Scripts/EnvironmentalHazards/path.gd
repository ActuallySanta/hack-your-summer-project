@tool
class_name Path extends Node2D
@export_category("Behavior")
@export_enum("Jump", "Closed Loop", "Ping Pong") var loop_mode : String
#@export_enum("Linear", "Ease-in", "Ease-out", "Ease-in-out") var easing : String
@export var wait_at_point : bool = true
@export var wait_time_seconds : float = 1.0
@export var node_speed : float = 10.0
@export var use_children : bool = true
@export var start_node_offset : float = 20
@export var nodes_to_move : Array[ Node2D ]

@export_category("Points")
@export var points : Array[ Vector2 ]

var objects : Array[ PathFollowerData ]
var path : Array [ PathPoint ]

## Set by the Path Point Editor plugin while it is drawing drag handles for this
## path, so the two don't mark the same points twice. Not exported, so it never
## ends up saved in a scene.
var editor_handles_active := false:
	set(value):
		editor_handles_active = value
		queue_redraw()

func _ready() -> void:
	if points.size() <= 1:
		return
	assign_path()
	assign_followers()

func assign_followers():
	var nodes_to_add : Array[ Node2D ]
	# Add children as nodes
	if use_children:
		for node in get_children():
			if not node is Node2D:
				continue
			nodes_to_add.append(node as Node2D)
	
	# Add any additional nodes
	for node in nodes_to_move:
		nodes_to_add.append(node)
	
	# Add them as Followers
	var current_point : int = 0
	var current_distance : float = 0.0
	for node in nodes_to_add:
		objects.append(PathFollowerData.new(node, path[ current_point ], current_point, current_distance))
		current_distance += start_node_offset
		if current_distance < path[ current_point ].length:
			continue
		current_distance -= path[ current_point ].length
		current_point += 1
		if current_point >= path.size():
			current_point = 0

func assign_path():
	var max_index = points.size() - 1
	# For all three loop options: We first go from start to end of init list
	for point in max_index:
			path.append(PathPoint.new(points[ point ], points[ point + 1 ]))
	
	# Path already made: 0->1->2->3
	if loop_mode == "Jump":
		return
	
	# For closed loop, connect end to start 0->1->2->3->0
	if loop_mode == "Closed Loop":
		path.append(PathPoint.new(points[ max_index ], points[ 0 ]))
		return
	
	# For Pint Pong, we add the list backwards on itself: 0->1->2->3->2->1->0
	for point in max_index:
		var inverse_point = max_index - point
		path.append(PathPoint.new(points[ inverse_point ], points[ inverse_point - 1 ]))

func _process(delta: float) -> void:
	# Checked before the point count, so a path being built up from its first
	# point still redraws while its handles are dragged around.
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if points.size() <= 1:
		return

	for rider in objects:
		update_path_follower(rider, delta)

func update_path_follower(follower: PathFollowerData, delta: float) -> void:
	var need_to_update = follower.iterate(delta, path.size(), node_speed)
	if need_to_update:
		follower.current_point = path[ follower.point_index ]
		if wait_time_seconds > 0:
			follower.wait_time = wait_time_seconds
			follower.travelled_distance = 0
	follower.move_node()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not editor_handles_active:
		for point in points:
			draw_circle( point, 10, Color.CORNFLOWER_BLUE, false )
			draw_circle( point, 10, Color(Color.CORNFLOWER_BLUE, 0.5), true )
	for i in points.size() - 1:
		var a = points[ i ]
		var b = points[ i + 1]
		draw_dashed_line( a, b, Color.CORNFLOWER_BLUE, 1.0 )
	
	if loop_mode == "Closed Loop" and points.size() > 1:
		draw_dashed_line( points[ points.size() - 1 ], points[ 0 ], Color.CORNFLOWER_BLUE, 1.0 )
