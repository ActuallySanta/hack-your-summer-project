extends Area2D

@export var function_to_call : String

var _was_triggered := false

func _on_body_entered(body: Node2D) -> void:
	if not _was_triggered and body.is_in_group("player"):
		var parent = get_parent()
		if parent.has_method(function_to_call):
			_was_triggered = true
			get_parent().call(function_to_call)
