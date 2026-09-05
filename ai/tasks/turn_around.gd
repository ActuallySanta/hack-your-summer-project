extends BTAction

func _tick(_delta: float) -> Status:
	agent.toggle_flip()
	return SUCCESS
