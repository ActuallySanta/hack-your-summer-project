extends BTAction

func _enter() -> void:
	agent.velocity = Vector2.ZERO
	var kids = agent.get_children()
	for kid in kids:
		if kid.name == "HitSFX":
			kid.play()

func _tick(delta: float) -> Status:
	await agent.get_tree().create_timer(agent.stunDuration).timeout
	blackboard.set_var("state","idle")
	return Status.SUCCESS
