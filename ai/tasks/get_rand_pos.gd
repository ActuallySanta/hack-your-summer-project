extends BTAction

func _tick(_delta: float) -> Status:
	blackboard.set_var("Position", agent.get_patrol_target())
	return SUCCESS
