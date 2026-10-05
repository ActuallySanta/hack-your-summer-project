class_name TextBar extends TextElement

var axis : Axis
var size : int

func _init(starting_position: Vector2i, propagation_axis: Axis, length: int) -> void:
	start_pos = starting_position
	axis = propagation_axis
	size = length

#TODO verify this works; literally just a guess make sure this works
func get_element_dimensions() -> Vector2i: return Vector2i(1, size) if axis == TextElement.Axis.Vertical else Vector2i(size, 1)
