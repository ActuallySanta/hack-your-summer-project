extends BTAction
func _tick(delta: float) -> Status:
	
	var pos: Vector2 = agent.playerReference.position
	
	blackboard.set_var("Position",pos)
	
	return SUCCESS
