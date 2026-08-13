extends AnimatedSprite2D

func _process(_delta: float) -> void:
	if not is_playing():
		queue_free()
