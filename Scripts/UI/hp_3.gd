extends TextureRect

func _ready() -> void:
	GlobalSignals.health_changed.connect(_on_health_changed)

func _on_health_changed(current: int, max_health: int) -> void:
	# HP3 is the last heart, index 2 (0-based)
	var heart_index = 2  # change to 0 for HP1, 1 for HP2, 2 for HP3
	var fill = clamp(current - heart_index, 0.0, 1.0)
	material.set_shader_parameter("fill_amount", fill)
