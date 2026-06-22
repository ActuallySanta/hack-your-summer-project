extends BTAction

func _enter() -> void:
	agent.velocity = Vector2.ZERO

func _tick(delta: float) -> Status:
	await agent.get_tree().create_timer(agent.stunDuration).timeout
	return Status.SUCCESS
