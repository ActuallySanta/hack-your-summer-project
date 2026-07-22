@tool
extends Sprite2D

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		var parent = get_parent()
		if parent and "start_flipped" in parent:
			# Set flip_h to the value of the parent's variable
			flip_h = parent.start_flipped
	else:
		set_process(false)
