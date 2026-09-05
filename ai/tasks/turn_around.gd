extends BTAction

func _tick(_delta: float) -> Status:
	agent.update_flip(1.0 if agent.isFlipped else -1.0)
	return SUCCESS
