extends BTAction

func _tick(delta: float) -> Status:
	
	var targetPos : Vector2 = blackboard.get_var("Position")
	
	var currPos : Vector2 = agent.global_transform.origin
	
	agent.move(targetPos,delta)
	
	if(currPos.distance_to(targetPos)<=0.5):
		agent.velocity = Vector2.ZERO
		return SUCCESS
	
	return RUNNING
