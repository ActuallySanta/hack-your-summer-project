extends RigidBody2D

@export_enum("UR", "UL", "DR", "DL") var start_direction : String
@export var speed : float
@export var stun_time : float

@onready var icon := $RepairDroneImage

var was_deactivated : bool = false
var is_deactivated : float = 0
var old_dir : State = State.Deactivated
var start_dir_as_state : State

enum State {
	Deactivated,
	UR,
	UL,
	DR,
	DL
}

func _ready() -> void:
	start_dir_as_state = State.UL if start_direction == "UL" else State.UR if start_direction == "UR" else State.DR if start_direction == "DR" else State.DL if start_direction == "UR" else State.Deactivated
	enable_thrusters( start_dir_as_state )

func _process(delta: float) -> void:
	if not check_activation(delta):
		return
	
	if abs(linear_velocity.length() - speed) > 5:
		print(linear_velocity.length(), " | ", speed)
		#enable_thrusters( calc_dir() )
	
	if check_dir():
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

func calc_dir() -> State:
	if linear_velocity.x > 0:
		if linear_velocity.y > 0:
			return State.DR
		elif linear_velocity.y < 0:
			return State.UR
	else:
		if linear_velocity.y > 0:
			return State.DL
		elif linear_velocity.y < 0:
			return State.UL
	
	return State.Deactivated

func check_dir() -> bool:
	var new_dir : State = calc_dir()
	if new_dir == old_dir:
		return false
	else:
		old_dir = new_dir
		return true

func enable_thrusters(direction: State):
	physics_material_override.bounce = 1.0
	physics_material_override.friction = 0.0
	gravity_scale = 0.0
	if direction == State.UR:
		linear_velocity = Vector2(1,-1).normalized() * speed
	elif direction == State.UL:
		linear_velocity = Vector2(-1,-1).normalized() * speed
	elif direction == State.DR:
		linear_velocity = Vector2(1,1).normalized() * speed
	elif direction == State.DL:
		linear_velocity = Vector2(-1,1).normalized() * speed
	
	check_dir()
	set_sprite( old_dir )

func disable_thrusters():
	is_deactivated = stun_time
	gravity_scale = 1.0
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 1.0
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
