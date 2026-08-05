extends Area2D

## Sets the position of a collider decided based on an index
func set_bone_pos(index: int, new_pos: Vector2) -> void:
	if index >= get_child_count():
		return
	
	var child := get_child( index ) as Node2D
	if child:
		child.position = new_pos
