@tool
extends Sprite2D  # Or Sprite2D / AnimatedSprite2D depending on your node type

# This node caches its parent (the Enemy)
@onready var enemy = get_parent()

func _process(_delta: float) -> void:
	# Only run inside the editor workspace
	if not Engine.is_editor_hint():
		set_process(false) # Disable during actual gameplay to save performance
		return

	# Safely read the value from the parent script
	if enemy and "start_flipped" in enemy:
		if enemy.start_flipped:
			flip_h = true
		else:
			flip_h = false
