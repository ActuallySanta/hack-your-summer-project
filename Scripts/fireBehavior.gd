extends Area2D

signal player_touched_death()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		CheckpointEventBus.player_needs_to_use_checkpoint.emit()
