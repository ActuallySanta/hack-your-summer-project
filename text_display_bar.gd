class_name TextBar extends TextElement

var start_pos : Vector2i
var axis : Axis
var size : int

func _init(starting_position: Vector2i, propagation_axis: Axis, length: int) -> void:
	start_pos = starting_position
	axis = propagation_axis
	size = length
