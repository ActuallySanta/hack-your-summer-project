extends Sprite2D

func is_active() -> bool:
	return frame != 0

func make_alive(alive: bool) -> void:
	frame = 1 if alive else 2
