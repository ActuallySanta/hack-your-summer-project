@tool
extends Sprite2D

@onready var enemy = get_parent().get_parent()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false) 
		return

	if enemy and "start_flipped" in enemy:
		if enemy.start_flipped:
			flip_h = true
		else:
			flip_h = false
