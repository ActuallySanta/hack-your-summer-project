## All TextElements are supposed to be designed as stupid; they do not check or cull data, only hold it
@abstract
class_name TextElement extends RefCounted

enum Axis { Point, Horizontal, Vertical, Both }
enum Direction { Up, Right, Down, Left }

var start_pos : Vector2i

@abstract
func get_element_dimensions() -> Vector2i
