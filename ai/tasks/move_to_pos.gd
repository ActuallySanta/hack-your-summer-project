extends BTAction

## Walks the agent along X toward the blackboard "Position" until it arrives,
## reaches a ledge, or is blocked.

@export var arrive_threshold : float = 6.0
## Frames of near-zero progress before the walk is treated as blocked.
@export var stall_frames : int = 8

var _last_x : float
var _stalled : int

func _enter() -> void:
	_last_x = agent.global_position.x
	_stalled = 0

func _exit() -> void:
	# Also runs when a higher-priority branch aborts this task, which is the only
	# thing that stops the body sliding on into the next behaviour
	agent.velocity.x = 0.0

func _tick(delta: float) -> Status:
	var target_x : float = (blackboard.get_var("Position") as Vector2).x
	var curr_x : float = agent.global_position.x
	var travel : float = signf(target_x - curr_x)

	if not agent.has_ground_ahead():
		return SUCCESS

	# At 50 px/s the body moves ~0.8 px per frame, so a plain distance test is stepped
	# straight over and never lands inside the threshold - catch the crossing instead
	if signf(target_x - _last_x) != travel or absf(target_x - curr_x) <= arrive_threshold:
		return SUCCESS

	if _is_blocked(curr_x, travel, delta):
		return SUCCESS

	_last_x = curr_x
	agent.move(Vector2(target_x, agent.global_position.y))
	return RUNNING

# A target on the far side of a wall is never reached, so arrival alone cannot end
# the walk - without this the body leans into the wall for good
func _is_blocked(curr_x: float, travel: float, delta: float) -> bool:
	var wall_normal_x : float = agent.get_wall_normal().x
	if agent.is_on_wall() and not is_zero_approx(wall_normal_x) and signf(wall_normal_x) != travel:
		return true

	if absf(curr_x - _last_x) < agent.SPEED * delta * 0.25:
		_stalled += 1
	else:
		_stalled = 0
	return _stalled >= stall_frames
