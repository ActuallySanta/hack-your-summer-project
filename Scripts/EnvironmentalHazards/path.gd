@tool
class_name Path extends Node2D
@export_category("Behavior")
@export_enum("Jump", "Closed Loop", "Ping Pong") var loop_mode : String
@export var wait_at_point : bool = true
@export var wait_time_seconds : float = 1.0

@export_category("Points")
@export var points : Array[ Vector2 ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
	pass

func _draw() -> void:
	for point in points:
		draw_circle( point, 10, Color.CORNFLOWER_BLUE, false )
		draw_circle( point, 10, Color(Color.CORNFLOWER_BLUE, 0.5), true )
	for i in points.size() - 1:
		var a = points[ i ]
		var b = points[ i + 1]
		draw_dashed_line( a, b, Color.CORNFLOWER_BLUE, 1.0 )
	
	if loop_mode == "Closed Loop":
		draw_dashed_line( points[ points.size() - 1 ], points[ 0 ], Color.CORNFLOWER_BLUE, 1.0 )
