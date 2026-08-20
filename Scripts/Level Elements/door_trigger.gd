extends DoorTrigger

var _was_triggered := false

func _on_body_entered(body: Node2D) -> void:
	if not _was_triggered and body.is_in_group("player"):
		open_doors()
		_was_triggered = true
