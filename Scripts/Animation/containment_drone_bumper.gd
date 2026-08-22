@tool
class_name ContainmentDroneBumper extends ManualAnim

@onready var animator := $MinigunAnimator

func flash() -> void:
	if animator.is_playing():
		return
	animator.play("Shoot")
