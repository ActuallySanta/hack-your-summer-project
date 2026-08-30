## A [Navigator] for a body the physics engine owns.
##
## The base [Navigator] steers by writing a position every frame, which a
## [RigidBody2D] cannot accept: teleporting one out from under the solver skips its
## collisions entirely. This one never moves anything. It is a steering calculator the
## body drives from its own [method RigidBody2D._integrate_forces] -- the body hands
## over where it actually is and how fast it is actually going, and gets back the
## velocity to fly at this tick.
##
## That split is what lets walls stay the engine's job. A bounce arrives here as the
## velocity handed in, already reflected, and the steering pulls it back onto course
## from there instead of the body having to reflect anything by hand.
class_name RigidBodyNavigator extends Navigator

## The base class steers in [method Node._process] by writing [member _nav_position].
## Nothing here may move on its own clock, so this replaces that with nothing at all;
## [method steer_towards] and [method brake] are the only things that step it.
func _process(_delta: float) -> void:
	pass

## One tick of pursuit: where the body is, how fast it is going after the engine has
## resolved its collisions, and what it is heading for. Returns the velocity to fly.
func steer_towards(body_position: Vector2, body_velocity: Vector2, target: Vector2) -> Vector2:
	_sync(body_position, body_velocity)
	# Setting the target is what recomputes _steering, so position and velocity have
	# to be in first -- both are read while working it out.
	_target_current_pos = target
	_velocity += _steering
	return _velocity

## One tick of arriving: bleed the speed off rather than stopping dead, the same way
## a navigator that has reached its target does.
func brake(body_position: Vector2, body_velocity: Vector2) -> Vector2:
	_sync(body_position, body_velocity)
	slow_down_and_stop()
	return _velocity

func _sync(body_position: Vector2, body_velocity: Vector2) -> void:
	set_nav_position(body_position)
	_velocity = body_velocity
