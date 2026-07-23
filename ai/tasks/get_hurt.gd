extends BTAction

var _running : float

func _enter() -> void:
	_running = agent.stunDuration
	agent.velocity = Vector2.ZERO
	var kids = agent.get_children()
	for kid in kids:
		if kid.name == "HitSFX":
			kid.play()

func _tick(delta: float) -> Status:
	_running -= agent.stunDuration * delta
	if _running > 0:
		return Status.RUNNING
	
	blackboard.set_var("state","idle")
	return Status.SUCCESS
