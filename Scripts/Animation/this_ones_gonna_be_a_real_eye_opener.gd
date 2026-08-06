extends Node2D

@export_range(0.00, 1.00) var chance_to_skip : float = 0.00
@export var blink_out_time : float = 0.1

var children : Array[ Node2D ]
var to_reenable : Array[ float ]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in get_children():
		children.append( i )
		to_reenable.append( 0.00 )


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_update_down_eyes(delta)
			
	var eval := randf()
	if eval <= chance_to_skip:
		return 
	var index = randi() % children.size()
	disable_eye( index )

func enable_eye(index: int) -> void:
	children[ index ].visible = true
	
func disable_eye(index: int) -> void:
	children[ index ].visible = false
	to_reenable[ index ] = blink_out_time

func _update_down_eyes(delta: float) -> void:
	for i in to_reenable.size():
		if to_reenable[ i ] <= 0:
			continue
		to_reenable[ i ] -= delta
		if to_reenable[ i ] <= 0:
			enable_eye( i )
