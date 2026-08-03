extends Area2D

## Sets the position of a collider decided based on an index
func set_bone_pos(index: int, new_glob_pos: Vector2) -> void:
	var child := get_child( index ) as Node2D
	child.global_position = new_glob_pos
