class_name CollisionManager
extends Node

enum State { WALK, AIR, CROUCH}

@onready var walking_collider = $"../WalkingCollision"
@onready var jumping_collider = $"../JumpCollision"
@onready var crouch_collider = $"../CrouchCollision"

var colliders
var _active_collision

func _ready() -> void:
	_active_collision = State.WALK
	colliders = {
		State.WALK: walking_collider,
		State.AIR: jumping_collider,
		State.CROUCH: crouch_collider,
	}

func get_bounds() -> Array[Vector2]:
	var collider = colliders[ _active_collision ]
	var bounds = collider.shape.get_rect()
	return [ collider.to_global(bounds.end), collider.to_global(bounds.position) ]

func swap_active_collision(name: State):
	set_disabled(_active_collision, true)
	set_disabled(name, false)
	_active_collision = name

func set_disabled(name: State, disabled: bool):
	var collider = colliders[name]
	collider.set_deferred("disabled", disabled)
