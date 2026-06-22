extends BTAction

@export var moveRange : float = 10.0

func _tick(delta: float) -> Status:
	
	var pos: Vector2 = agent.getValidPos()
	
	blackboard.set_var("Position",pos)
	
	return SUCCESS
