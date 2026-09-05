extends BTAction

## Walks the agent along X toward the blackboard "Position" until it arrives,
## reaches a ledge, or stops making progress.

@export var arrive_threshold : float = 6.0
@export var stuck_speed : float = 4.0

var _last_x : float

func _enter() -> void:
	_last_x = agent.global_position.x

func _exit() -> void:
	# Also runs when a higher-priority branch aborts this task, which is the only
	# thing that stops the body sliding on into the next behaviour
	agent.velocity.x = 0.0

func _tick(delta: float) -> Status:
	var target_x : float = (blackboard.get_var("Position") as Vector2).x
	var curr_x : float = agent.global_position.x

	if not agent.has_ground_ahead():
		return SUCCESS

	# At 50 px/s the body moves ~0.8 px per frame, so a plain distance test is stepped
	# straight over and never lands inside the threshold - catch the crossing instead
	var crossed : bool = signf(target_x - _last_x) != signf(target_x - curr_x)
	if crossed or absf(target_x - curr_x) <= arrive_threshold:
		return SUCCESS

	# Walled in: the target is reachable in theory but the body is not advancing
	if not is_equal_approx(_last_x, curr_x) and absf(curr_x - _last_x) < stuck_speed * delta:
		return SUCCESS

	_last_x = curr_x
	agent.move(Vector2(target_x, agent.global_position.y), delta)
	return RUNNING
