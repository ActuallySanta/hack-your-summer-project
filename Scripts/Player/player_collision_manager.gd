## Owns the player's three collision shapes and which one is switched on.
##
## The walking, crouching and jumping shapes all share a bottom edge, so the body
## origin (and with it the camera) stays at one height however the player is moving.
class_name CollisionManager
extends Node

enum State { WALK, AIR, CROUCH }

@onready var walking_collider: CollisionShape2D = $"../WalkingCollision"
@onready var jumping_collider: CollisionShape2D = $"../JumpCollision"
@onready var crouch_collider: CollisionShape2D = $"../CrouchCollision"

var colliders: Dictionary[State, CollisionShape2D]
var _active_collision: State = State.WALK

func _ready() -> void:
	_active_collision = State.WALK
	colliders = {
		State.WALK: walking_collider,
		State.AIR: jumping_collider,
		State.CROUCH: crouch_collider,
	}

## The corners of the active shape in global space, as [top-right-ish, bottom-left-ish]
## -- callers take min/max rather than relying on which is which.
func get_bounds() -> Array[Vector2]:
	var collider := colliders[_active_collision]
	var bounds := collider.shape.get_rect()
	return [collider.to_global(bounds.end), collider.to_global(bounds.position)]

## The shape node for [param state], whether or not it is the active one. Used to ask
## "would this shape fit here" of a shape that is currently switched off.
func collider_for(state: State) -> CollisionShape2D:
	return colliders.get(state)

func active_state() -> State:
	return _active_collision

## Switches the player over to [param state]'s shape.
##
## The switch is immediate, not deferred. It used to go through
## [method Object.set_deferred], which left a frame where [method get_bounds] reported
## the new shape while the physics server was still using the old one -- so a mantle
## reach test, a wall probe or a headroom check taken on that frame was measuring a
## box the player did not have. The new shape is switched on before the old one is
## switched off, so there is never a frame with no shape at all either.
func swap_active_collision(state: State) -> void:
	if state == _active_collision:
		return
	set_disabled(state, false)
	set_disabled(_active_collision, true)
	_active_collision = state

func set_disabled(state: State, disabled: bool) -> void:
	var collider := colliders[state]
	if collider.disabled == disabled:
		return
	collider.disabled = disabled
