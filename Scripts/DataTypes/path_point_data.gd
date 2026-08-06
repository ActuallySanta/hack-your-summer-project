class_name PathPoint extends RefCounted

var length : float
var start : Vector2
var delta : Vector2
var delta_normal : Vector2

func _init(start_point: Vector2, end_point: Vector2) -> void:
	start = start_point
	delta = end_point - start_point
	delta_normal = delta.normalized()
	length = delta.length()
