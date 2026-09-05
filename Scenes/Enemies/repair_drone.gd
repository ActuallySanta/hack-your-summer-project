extends RigidBody2D

#region What the drone is doing

const HIT_WALL_SFX := preload("res://Sounds/Entities/Enemies/Machines/RepairDrone/RD_Hit_wall.wav")
const HURT_SFX := preload("res://Sounds/Entities/Enemies/Machines/RepairDrone/RD_Hit.wav")
const DEATH_SFX := preload("res://Sounds/Entities/Enemies/Machines/RepairDrone/RD_DEATH.wav")
const FOUND_TARGET_SFX :=preload("res://Sounds/Entities/Enemies/Machines/RepairDrone/RD_Found.wav")

enum Mode {
	## Nothing to repair. Drifting on a diagonal at [member speed], bouncing off
	## walls, rescanning every [member idle_rescan_interval] seconds.
	Idle,
	## Flying the route in [member _path] toward [member _target].
	Seeking,
	## Parked at the target, counting down its repair timer.
	Repairing,
	## Shot with a stun bullet. Thrusters off, gravity on, falls to the floor.
	Stunned,
}
const IDLE_DIRECTIONS := {
	"UR": Vector2(1, -1),
	"UL": Vector2(-1, -1),
	"DR": Vector2(1, 1),
	"DL": Vector2(-1, 1),
}
const REPAIRABLE_GROUP := &"Repairable"
const _STOPPED_SPEED := 4.0

#endregion

#region Tuning

@export_enum("UR", "UL", "DR", "DL") var start_direction : String = "UR"

## Drift speed with nothing left to repair. Idling is the slower, more visible state;
## the speed it travels to a job at belongs to the [Navigator] child, along with
## everything else about how it flies there.
@export var speed : float = 100.0

## How close to a waypoint counts as having reached it.
@export var waypoint_cutoff : float = 32.0

## Seconds spent on the floor after a stun bullet.
@export var stun_time : float = 5.0

@export var idle_rescan_interval : float = 2.0
@export_range(-1.0, 1.0) var wall_bounce_dot : float = 0.5

#endregion

@onready var navigator : RigidBodyNavigator = $Navigator
@onready var sprite : RepairerSpriteAnimator = $Flasher/RepairerSpriteAnimator
@onready var flasher : Flasher = $Flasher
@onready var hitbox : CollisionShape2D = $Hitbox/CollisionShape2D
@onready var health_component : RoboHealth = $RoboHealth
@onready var hover_sfx : AudioStreamPlayer2D = $Hover
@onready var bang_sfx : AudioStreamPlayer2D = $Bangs

var _mode : Mode = Mode.Idle
var _target : RepairNode
## Remaining waypoints, the target last. Emptied as each one is reached.
var _path : Array[Vector2]
var _stun_left : float = 0.0
var _rescan_left : float = 0.0
## Heading at the end of the last powered tick, to measure the next one against.
## Zero while there is nothing worth comparing: stunned, or too slow to have a heading.
var _last_heading : Vector2 = Vector2.ZERO

func _ready() -> void:
	# Bounce and friction are switched between flying and stunned, so this body needs
	# its own copy of the material rather than the shared resource every drone loads.
	physics_material_override = physics_material_override.duplicate()
	health_component.on_death_event.connect( on_death )
	_enable_thrusters()
	restart_sequence()

func on_death() -> void:
	_release_target()
	play_banger( DEATH_SFX )
	queue_free()

#region The sequence

## Drops whatever the drone was doing and starts again from the scan: pick the closest
## repair node, ask [RoomPathfinder] how to get there, and fly it. Idles when the scan
## comes back empty.
func restart_sequence() -> void:
	_release_target()
	_path.clear()
	_target = _find_closest_repair_node()
	if _target == null:
		_enter_idle()
		return
	_path = RoomPathfinder.find_path(global_position, _target.global_position)
	_mode = Mode.Seeking

func _process(delta: float) -> void:
	match _mode:
		Mode.Stunned:
			_stun_left -= delta
			if _stun_left <= 0.0:
				_enable_thrusters()
				restart_sequence()
		Mode.Seeking:
			_advance_path()
		Mode.Repairing:
			# The node frees itself the moment it is fixed, and another drone may have
			# been the one to finish it.
			if not is_instance_valid(_target):
				restart_sequence()
		Mode.Idle:
			if idle_rescan_interval <= 0.0:
				return
			_rescan_left -= delta
			if _rescan_left <= 0.0:
				restart_sequence()

func _advance_path() -> void:
	if not is_instance_valid(_target):
		restart_sequence()
		return
	if _path.is_empty():
		_begin_repairs()
		return
	if global_position.distance_to(_destination()) <= waypoint_cutoff:
		_path.remove_at(0)
		if _path.is_empty():
			_begin_repairs()

func _destination() -> Vector2:
	if _path.size() <= 1 and is_instance_valid(_target):
		return _target.global_position
	return _path[0]

func _begin_repairs() -> void:
	_mode = Mode.Repairing
	_target.start_repairs()
	if not _target.on_repair_end.is_connected(_on_repairs_finished):
		_target.on_repair_end.connect(_on_repairs_finished)

func _on_repairs_finished() -> void:
	restart_sequence()

func _release_target() -> void:
	if not is_instance_valid(_target):
		_target = null
		return
	if _target.on_repair_end.is_connected(_on_repairs_finished):
		_target.on_repair_end.disconnect(_on_repairs_finished)
	if _mode == Mode.Repairing:
		_target.stop_repairing()
	_target = null

func _find_closest_repair_node() -> RepairNode:
	var closest : RepairNode = null
	var closest_distance : float = INF
	for node in get_tree().get_nodes_in_group(REPAIRABLE_GROUP):
		var repairable := node as RepairNode
		if repairable == null or repairable.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(repairable.global_position)
		if distance < closest_distance:
			closest = repairable
			closest_distance = distance
	return closest

#endregion

#region Movement
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _mode == Mode.Stunned:
		return # Falling: gravity and the floor own the velocity

	_bang_if_deflected(state.linear_velocity)

	match _mode:
		Mode.Idle:
			state.linear_velocity = _snap_to_diagonal(state.linear_velocity) * speed
		Mode.Seeking:
			state.linear_velocity = navigator.steer_towards(global_position, state.linear_velocity, _destination())
		Mode.Repairing:
			state.linear_velocity = navigator.brake(global_position, state.linear_velocity)
	_face(state.linear_velocity)

	var speed_now := state.linear_velocity.length()
	_last_heading = state.linear_velocity / speed_now if speed_now > _STOPPED_SPEED else Vector2.ZERO

func _bang_if_deflected(velocity: Vector2) -> void:
	if _last_heading == Vector2.ZERO or velocity.length() <= _STOPPED_SPEED:
		return
	if _last_heading.dot(velocity.normalized()) < wall_bounce_dot:
		play_banger(HIT_WALL_SFX)

func _snap_to_diagonal(velocity: Vector2) -> Vector2:
	var fallback := _start_heading()
	var epsilon := maxf(speed, 1.0) * 0.001

	var x := signf(velocity.x) if absf(velocity.x) > epsilon else fallback.x
	var y := signf(velocity.y) if absf(velocity.y) > epsilon else fallback.y

	return Vector2(x, y).normalized()

func _start_heading() -> Vector2:
	return IDLE_DIRECTIONS.get(start_direction, Vector2(1, -1))

func _face(velocity: Vector2) -> void:
	if velocity.length() > _STOPPED_SPEED:
		sprite.get_closest_dir(velocity.normalized())

#endregion

#region Modes

func _enter_idle() -> void:
	_mode = Mode.Idle
	_rescan_left = idle_rescan_interval
	# Coming to a stop and then finding nothing to do would leave the drone parked
	# with no heading to snap, so give it its starting one back.
	if linear_velocity.length() <= _STOPPED_SPEED:
		linear_velocity = _start_heading().normalized() * speed

func _enable_thrusters() -> void:
	can_sleep = false
	sleeping = false
	hitbox.set_deferred("disabled", false)
	physics_material_override.bounce = 1.0
	physics_material_override.friction = 0.0
	gravity_scale = 0.0
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	hover_sfx.play()

func disable_thrusters() -> void:
	_release_target()
	_path.clear()
	_mode = Mode.Stunned
	_stun_left = stun_time
	_last_heading = Vector2.ZERO # Nothing to compare a bounce against until it flies again
	hitbox.set_deferred("disabled", true)
	# Lying on the floor is the one time it may sleep; _enable_thrusters wakes it.
	can_sleep = true
	gravity_scale = 1.0
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 1.0
	linear_damp_mode = DAMP_MODE_COMBINE
	linear_damp = 0.0
	sprite.show_deactivated()
	hover_sfx.stop()
	play_banger(DEATH_SFX)

#endregion

func play_banger(stream: AudioStreamWAV) -> void:
	bang_sfx.stream = stream
	bang_sfx.play()

func _on_hit(_hit_info: HitInfo, source: Hitbox) -> void:
	if source.has_method("get_damage_type"):
		var dmg_type : StringName = source.get_damage_type()
		if dmg_type == "stun_bullet":
			disable_thrusters()
			return
	flasher.flash()
	play_banger(HURT_SFX)
