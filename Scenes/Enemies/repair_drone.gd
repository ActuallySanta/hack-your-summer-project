extends RigidBody2D

enum State {
	Deactivated,
	UR,
	UL,
	DR,
	DL
}

const DIRECTION_VECTORS := {
	State.UR: Vector2(1, -1),
	State.UL: Vector2(-1, -1),
	State.DR: Vector2(1, 1),
	State.DL: Vector2(-1, 1),
}

const STATE_NAMES := {
	"UR": State.UR,
	"UL": State.UL,
	"DR": State.DR,
	"DL": State.DL,
}

@export_enum("UR", "UL", "DR", "DL") var start_direction : String
@export var speed : float = 100.0
@export var stun_time : float = 5.0

@onready var icon := $RepairDroneImage
@onready var hitbox := $Hitbox/CollisionShape2D

var was_deactivated : bool = false
var is_deactivated : float = 0
var old_dir : State = State.Deactivated
var start_dir_as_state : State

func _ready() -> void:
	physics_material_override = physics_material_override.duplicate()
	start_dir_as_state = STATE_NAMES.get(start_direction, State.Deactivated)
	enable_thrusters( start_dir_as_state )

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not check_activation(state.step):
		return

	state.linear_velocity = snap_to_diagonal(state.linear_velocity) * speed

	if check_dir(state.linear_velocity):
		set_sprite(old_dir)

func check_activation(delta: float) -> bool:
	if is_deactivated > 0:
		was_deactivated = true
		is_deactivated -= delta
		return false
	elif was_deactivated:
		was_deactivated = false
		enable_thrusters( start_dir_as_state )
	return true

func snap_to_diagonal(velocity: Vector2) -> Vector2:
	var fallback : Vector2 = DIRECTION_VECTORS.get(old_dir, DIRECTION_VECTORS.get(start_dir_as_state, Vector2(1, -1)))
	var epsilon := maxf(speed, 1.0) * 0.001

	var x := signf(velocity.x) if absf(velocity.x) > epsilon else fallback.x
	var y := signf(velocity.y) if absf(velocity.y) > epsilon else fallback.y

	return Vector2(x, y).normalized()

func calc_dir(velocity: Vector2) -> State:
	if velocity.x > 0:
		if velocity.y > 0:
			return State.DR
		elif velocity.y < 0:
			return State.UR
	else:
		if velocity.y > 0:
			return State.DL
		elif velocity.y < 0:
			return State.UL

	return State.Deactivated

func check_dir(velocity: Vector2) -> bool:
	var new_dir : State = calc_dir(velocity)
	if new_dir == old_dir:
		return false
	else:
		old_dir = new_dir
		return true

func enable_thrusters(direction: State):
	hitbox.set_deferred("disabled", false)
	physics_material_override.bounce = 1.0
	physics_material_override.friction = 0.0
	gravity_scale = 0.0
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0

	var heading : Vector2 = DIRECTION_VECTORS.get(direction, Vector2.ZERO)
	linear_velocity = heading.normalized() * speed

	check_dir(linear_velocity)
	set_sprite( old_dir )

func disable_thrusters():
	hitbox.set_deferred("disabled", true)
	is_deactivated = stun_time
	gravity_scale = 1.0
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 1.0
	linear_damp_mode = DAMP_MODE_COMBINE
	linear_damp = 0.0
	set_sprite( State.Deactivated )

func set_sprite(thrust_dir: State) -> void:
	match thrust_dir:
		State.Deactivated:
			icon.frame_coords = Vector2i(0,0)
		State.DR:
			icon.frame_coords = Vector2i(0,1)
		State.DL:
			icon.frame_coords = Vector2i(1,1)
		State.UR:
			icon.frame_coords = Vector2i(0,2)
		State.UL:
			icon.frame_coords = Vector2i(1,2)

func _on_area_2d_area_entered(area: Area2D) -> void:
	disable_thrusters()
