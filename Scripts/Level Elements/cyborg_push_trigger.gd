extends Area2D

@export var target_cyborg : Node2D

func _ready() -> void:
	if GameManager.is_cyborg_pushed():
		target_cyborg.queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GlobalSignals.PushBlockingCyborg.emit()
		target_cyborg.queue_free()
