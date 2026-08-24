extends Bullet

@export var vertical_range : float

func post_init_operations() -> void:
	velocity.y = randf_range(-vertical_range, vertical_range)
